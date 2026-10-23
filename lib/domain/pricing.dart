import 'dart:math' as math;

import 'fee_model.dart';

/// All prices are integer sen. Sample values from the spec (§5); mirrored in
/// functions/src/domain/pricing.ts, which is the authority for charges.

enum GroupPackage {
  saver('Group Saver'),
  flex('Group Flex');

  const GroupPackage(this.label);
  final String label;
}

enum Addon {
  language(800, 'Language help'),
  consultSitIn(1000, 'Consult sit-in'),
  medicineCollection(500, 'Medicine collection'),
  visitSummary(500, 'Visit summary'),
  wheelchairOnArrival(500, 'Wheelchair on arrival');

  const Addon(this.sen, this.label);
  final int sen;
  final String label;
}

const groupCapacity = 3;
const _shares = {
  GroupPackage.saver: [4000, 3000, 2200],
  GroupPackage.flex: [5500, 4500, 3500],
};

const escortHourlySen = 3000;
/// Fallback private ride price for bookings made before rides were priced by route.
const privateRideSen = 2400;
const defaultEscortHours = 4.0;

const roadFactor = 1.3;

/// Price per rider for a group of [riders] (1..3).
int groupShareSen(GroupPackage p, int riders) {
  if (riders < 1 || riders > groupCapacity) {
    throw ArgumentError.value(riders, 'riders', 'must be 1..$groupCapacity');
  }
  return _shares[p]![riders - 1];
}

int addonsSen(Iterable<Addon> addons) => addons.fold(0, (t, a) => t + a.sen);

/// Level 2 estimate: escort hours plus the private ride both ways.
int escortEstimateSen({double hours = defaultEscortHours, int rideSen = privateRideSen}) =>
    (escortHourlySen * hours).round() + rideSen;

/// Level 2 final charge: actual time rounded up to 30-minute steps, plus ride.
int escortFinalSen(Duration actual, {int rideSen = privateRideSen}) {
  final halfHours = (actual.inMinutes / 30).ceil();
  return halfHours * (escortHourlySen ~/ 2) + rideSen;
}

/// Refund per rider when a group locks: everyone ends at the final-size share,
/// never above what they paid.
List<int> settleGroupRefunds(GroupPackage p, List<int> paidShares) {
  if (paidShares.isEmpty) return const [];
  final finalShare = groupShareSen(p, paidShares.length);
  return [for (final paid in paidShares) math.max(0, paid - finalShare)];
}

class CancelOutcome {
  const CancelOutcome({required this.refundSen, required this.creditSen});
  final int refundSen;
  final int creditSen;
}

/// Before lock (24h+ ahead) is always a full refund. After lock: Saver becomes
/// CareWay credit; Flex and Level 2 refund 50%.
CancelOutcome cancelOutcome({
  required GroupPackage? package,
  required int level,
  required int paidSen,
  required bool afterLock,
}) {
  if (!afterLock) return CancelOutcome(refundSen: paidSen, creditSen: 0);
  if (level == 1 && package == GroupPackage.saver) {
    return CancelOutcome(refundSen: 0, creditSen: paidSen);
  }
  return CancelOutcome(refundSen: paidSen ~/ 2, creditSen: 0);
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0088;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Home -> pharmacy -> home, with a road factor, rounded to 0.1 km.
double routeKm(double lat1, double lng1, double lat2, double lng2) =>
    (2 * haversineKm(lat1, lng1, lat2, lng2) * roadFactor * 10).round() / 10;

/// One-way road distance, rounded to 0.1 km.
double legKm(double lat1, double lng1, double lat2, double lng2) =>
    (haversineKm(lat1, lng1, lat2, lng2) * roadFactor * 10).round() / 10;

enum TripKind { ride, delivery }

/// Floor under a model estimate per trip: Grab's RM5 minimum fare; for a
/// medicine run, Lalamove's RM5 base plus RM10 waiting at the pharmacy counter.
const minFareSen = {TripKind.ride: 500, TripKind.delivery: 1500};

/// Local (UTC+8) hour of [at].
int mytHour(DateTime at) => (at.toUtc().hour + 8) % 24;

class RouteLeg {
  const RouteLeg(this.km, this.departAt);
  final double km;
  final DateTime departAt;
}

class RouteCost {
  const RouteCost({required this.km, required this.baseSen, required this.distanceSen, required this.trafficSen});
  final double km;
  final int baseSen;
  final int distanceSen;

  /// Peak-hour surcharge or night discount the fee model learned.
  final int trafficSen;
  int get totalSen => baseSen + distanceSen + trafficSen;
}

/// Each leg is priced as its own trip by the fee model, then the parts are summed.
RouteCost routeCost(List<RouteLeg> legs, TripKind kind) {
  final model = FeeModel.current;
  final w = kind == TripKind.ride ? model.ride : model.delivery;
  var km = 0.0;
  var base = 0, distance = 0, traffic = 0;
  for (final l in legs) {
    final x = feeFeatures(l.km, mytHour(l.departAt));
    final d = (w.perKm * x[1]).round();
    final t = (w.perKmPeak * x[2] + w.perKmNight * x[3]).round();
    // A short trip is topped up to the minimum fare through the base line.
    base += math.max(w.base.round(), minFareSen[kind]! - d - t);
    distance += d;
    traffic += t;
    km += l.km;
  }
  return RouteCost(km: (km * 10).round() / 10, baseSen: base, distanceSen: distance, trafficSen: traffic);
}

/// Level 2 private ride: pickup → hospital an hour before the appointment,
/// back three hours after.
RouteCost privateRideCost(double fromLat, double fromLng, double toLat, double toLng, DateTime apptAt) {
  final km = legKm(fromLat, fromLng, toLat, toLng);
  return routeCost([
    RouteLeg(km, apptAt.subtract(const Duration(hours: 1))),
    RouteLeg(km, apptAt.add(const Duration(hours: 3))),
  ], TripKind.ride);
}

/// Medicine run fee for a [routeKm] round trip starting at [departAt].
RouteCost deliveryFee(double routeKm, DateTime departAt) => routeCost([RouteLeg(routeKm, departAt)], TripKind.delivery);
