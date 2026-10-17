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
  });

  test('escort final rounds up to 30-minute steps', () {
    expect(escortFinalSen(const Duration(hours: 3, minutes: 10)), 3 * 3000 + 1500 + 2400);
    expect(escortFinalSen(const Duration(hours: 3)), 9000 + 2400);
  });

  test('settle worked example: 40/30/22 -> refunds 18/8/0', () {
    expect(settleGroupRefunds(GroupPackage.saver, [4000, 3000, 2200]), [1800, 800, 0]);
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
      final o = cancelOutcome(package: GroupPackage.saver, level: 1, paidSen: 2200, afterLock: false);
      expect((o.refundSen, o.creditSen), (2200, 0));
    });

    test('saver after lock becomes CareWay credit', () {
      final o = cancelOutcome(package: GroupPackage.saver, level: 1, paidSen: 2200, afterLock: true);
      expect((o.refundSen, o.creditSen), (0, 2200));
    });

    test('flex after lock refunds 50%', () {
      final o = cancelOutcome(package: GroupPackage.flex, level: 1, paidSen: 3500, afterLock: true);
      expect((o.refundSen, o.creditSen), (1750, 0));
    });

    test('level 2 after lock refunds 50%', () {
      final o = cancelOutcome(package: null, level: 2, paidSen: 14400, afterLock: true);
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

    test('fee is RM 5 base plus RM 0.50 per km', () {
      final fee = deliveryFee(10.0);
      expect((fee.baseSen, fee.distanceSen, fee.totalSen), (500, 500, 1000));
      expect(deliveryFee(0).totalSen, 500);
    });
  });
}
