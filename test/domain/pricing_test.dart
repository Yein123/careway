import 'package:careway/domain/fee_model.dart';
import 'package:careway/domain/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupShareSen', () {
    test('saver share falls as riders join', () {
      expect(groupShareSen(GroupPackage.saver, 1), 4000);
      expect(groupShareSen(GroupPackage.saver, 2), 3000);
      expect(groupShareSen(GroupPackage.saver, 3), 2200);
    });

    test('flex shares', () {
      expect(groupShareSen(GroupPackage.flex, 1), 5500);
      expect(groupShareSen(GroupPackage.flex, 2), 4500);
      expect(groupShareSen(GroupPackage.flex, 3), 3500);
    });

    test('rider count outside 1..3 throws', () {
      expect(() => groupShareSen(GroupPackage.saver, 4), throwsArgumentError);
      expect(() => groupShareSen(GroupPackage.saver, 0), throwsArgumentError);
    });
  });

  test('addonsSen sums add-on prices', () {
    expect(addonsSen([Addon.language, Addon.consultSitIn]), 1800);
    expect(addonsSen([]), 0);
  });

  test('escort estimate is 4 hours plus private ride', () {
    expect(escortEstimateSen(), 14400);
    expect(escortEstimateSen(rideSen: 2500), 14500);
  });

  test('escort final rounds up to 30-minute steps', () {
    expect(
      escortFinalSen(const Duration(hours: 3, minutes: 10)),
      3 * 3000 + 1500 + 2400,
    );
    expect(escortFinalSen(const Duration(hours: 3)), 9000 + 2400);
    expect(escortFinalSen(const Duration(hours: 3), rideSen: 2500), 9000 + 2500);
  });

  test('settle worked example: 40/30/22 -> refunds 18/8/0', () {
    expect(settleGroupRefunds(GroupPackage.saver, [4000, 3000, 2200]), [
      1800,
      800,
      0,
    ]);
  });

  test('settle after cancel never charges more', () {
    final refunds = settleGroupRefunds(GroupPackage.saver, [4000, 3000]);
    expect(refunds, [1000, 0]);
    expect(refunds.every((r) => r >= 0), isTrue);
  });

  test('settle a lone rider pays the cap with no refund', () {
    expect(settleGroupRefunds(GroupPackage.saver, [4000]), [0]);
  });

  group('cancelOutcome', () {
    test('before lock is a full refund', () {
      final o = cancelOutcome(
        package: GroupPackage.saver,
        level: 1,
        paidSen: 2200,
        afterLock: false,
      );
      expect((o.refundSen, o.creditSen), (2200, 0));
    });

    test('saver after lock becomes CareWay credit', () {
      final o = cancelOutcome(
        package: GroupPackage.saver,
        level: 1,
        paidSen: 2200,
        afterLock: true,
      );
      expect((o.refundSen, o.creditSen), (0, 2200));
    });

    test('flex after lock refunds 50%', () {
      final o = cancelOutcome(
        package: GroupPackage.flex,
        level: 1,
        paidSen: 3500,
        afterLock: true,
      );
      expect((o.refundSen, o.creditSen), (1750, 0));
    });

    test('level 2 after lock refunds 50%', () {
      final o = cancelOutcome(
        package: null,
        level: 2,
        paidSen: 14400,
        afterLock: true,
      );
      expect((o.refundSen, o.creditSen), (7200, 0));
    });
  });

  group('delivery', () {
    test('haversine one degree of longitude at the equator', () {
      expect(haversineKm(0, 0, 0, 1), closeTo(111.19, 0.01));
    });

    test('route is round trip with road factor, 1 decimal', () {
      expect(routeKm(0, 0, 0, 1), 289.1);
      expect(routeKm(3.1, 101.5, 3.1, 101.5), 0);
    });

    test('fee is the delivery model on the round trip', () {
      // 11 AM local (03:00 UTC): off peak.
      final fee = deliveryFee(10.0, DateTime.utc(2026, 10, 26, 3));
      final w = FeeModel.current.delivery;
      expect((fee.baseSen, fee.distanceSen, fee.trafficSen), (w.base.round(), (w.perKm * 10).round(), 0));
      expect(fee.totalSen, fee.baseSen + fee.distanceSen);
    });

    test('a very short run is topped up to the minimum fee', () {
      expect(deliveryFee(0, DateTime.utc(2026, 10, 26, 3)).totalSen, minFareSen[TripKind.delivery]);
    });
  });

  group('fee model', () {
    final rideWeights = FeeModel.current.ride;

    test('the app loads the model file the server charges with', () {
      expect(FeeModel.current.trainedAt, isNotEmpty);
      expect(FeeModel.current.delivery.perKm, greaterThan(0));
    });

    // Local (UTC+8) hour h on 26 Oct 2026.
    DateTime at(int h) => DateTime.utc(2026, 10, 26).add(Duration(hours: h - 8));

    test('local hour is UTC+8', () {
      expect(mytHour(at(8)), 8);
      expect(mytHour(at(23)), 23);
    });

    test('the same ride costs more in the morning peak than at midday or night', () {
      int leg(int h) => routeCost([RouteLeg(10, at(h))], TripKind.ride).totalSen;
      expect(leg(8), greaterThan(leg(13)));
      expect(leg(13), greaterThan(leg(23)));
    });

    test('each leg is its own trip: two bases, traffic only on the peak leg', () {
      final c = routeCost([RouteLeg(10, at(8)), RouteLeg(10, at(13))], TripKind.ride);
      expect(c.km, 20);
      expect(c.baseSen, 2 * rideWeights.base.round());
      expect(c.trafficSen, (rideWeights.perKmPeak * 10).round());
    });

    test('private ride goes an hour before the appointment and back three hours after', () {
      final km = legKm(3.187, 101.518, 3.2196, 101.5826);
      final ride = privateRideCost(3.187, 101.518, 3.2196, 101.5826, at(9));
      final legs = routeCost([RouteLeg(km, at(8)), RouteLeg(km, at(12))], TripKind.ride);
      expect(ride.totalSen, legs.totalSen);
    });

    test('predictions match the functions model (same weights, same features)', () {
      expect(predictSen(rideWeights, 10, 13), closeTo(rideWeights.base + rideWeights.perKm * 10, 1e-9));
      expect(isPeak(8) && isPeak(18) && !isPeak(13), isTrue);
      expect(isNight(23) && isNight(5) && !isNight(6), isTrue);
    });
  });
}
