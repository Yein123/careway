import 'dart:math' as math;

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
const privateRideSen = 2400;
const defaultEscortHours = 4.0;

const deliveryBaseSen = 500;
const deliveryPerKmSen = 50;
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
int escortEstimateSen({double hours = defaultEscortHours}) =>
    (escortHourlySen * hours).round() + privateRideSen;

/// Level 2 final charge: actual time rounded up to 30-minute steps, plus ride.
int escortFinalSen(Duration actual) {
  final halfHours = (actual.inMinutes / 30).ceil();
  return halfHours * (escortHourlySen ~/ 2) + privateRideSen;
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
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Home -> pharmacy -> home, with a road factor, rounded to 0.1 km.
double routeKm(double lat1, double lng1, double lat2, double lng2) =>
    (2 * haversineKm(lat1, lng1, lat2, lng2) * roadFactor * 10).round() / 10;

class DeliveryFee {
  const DeliveryFee({required this.baseSen, required this.distanceSen});
  final int baseSen;
  final int distanceSen;
  int get totalSen => baseSen + distanceSen;
}

DeliveryFee deliveryFee(double routeKm) =>
    DeliveryFee(baseSen: deliveryBaseSen, distanceSen: (deliveryPerKmSen * routeKm).round());
