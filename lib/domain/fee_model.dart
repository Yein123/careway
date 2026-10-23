import 'dart:convert';

import 'package:flutter/services.dart';

/// Fee model: a linear regression learned from Malaysian market prices (Grab,
/// Lalamove and GrabExpress rate cards with TomTom drive times). The app loads
/// the same model file the server charges with,
/// functions/src/models/fee_model.json (trained by
/// functions/scripts/train-fee-model.js). Mirrors functions/src/domain/fee_model.ts.
///   cost = base + perKm × km + perKmPeak × km in the peaks + perKmNight × km at night
class FeeWeights {
  const FeeWeights({required this.base, required this.perKm, required this.perKmPeak, required this.perKmNight});

  factory FeeWeights.fromJson(Map<String, dynamic> m) => FeeWeights(
    base: (m['base'] as num).toDouble(),
    perKm: (m['perKm'] as num).toDouble(),
    perKmPeak: (m['perKmPeak'] as num).toDouble(),
    perKmNight: (m['perKmNight'] as num).toDouble(),
  );

  final double base;
  final double perKm;
  final double perKmPeak;
  final double perKmNight;
}

class FeeModel {
  const FeeModel({required this.ride, required this.delivery, this.trainedAt = ''});

  factory FeeModel.fromJson(Map<String, dynamic> m) {
    final models = m['models'] as Map<String, dynamic>;
    FeeWeights weights(String kind) => FeeWeights.fromJson((models[kind] as Map<String, dynamic>)['weights'] as Map<String, dynamic>);
    return FeeModel(ride: weights('ride'), delivery: weights('delivery'), trainedAt: m['trainedAt'] as String? ?? '');
  }

  /// The model file, bundled as an asset (see pubspec.yaml).
  static const assetPath = 'functions/src/models/fee_model.json';

  final FeeWeights ride;
  final FeeWeights delivery;
  final String trainedAt;

  static FeeModel? _current;

  /// The loaded model; [load] runs at startup, before any price is shown.
  static FeeModel get current => _current ?? (throw StateError('Fee model not loaded. Call FeeModel.load() first.'));
  static set current(FeeModel m) => _current = m;

  static Future<FeeModel> load([AssetBundle? bundle]) async {
    final json = await (bundle ?? rootBundle).loadString(assetPath);
    return _current = FeeModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}

bool isPeak(int hour) => (hour >= 7 && hour < 10) || (hour >= 17 && hour < 20);
bool isNight(int hour) => hour >= 22 || hour < 6;

/// [1, km, km in the peaks, km at night] for one trip setting off at local [hour].
List<double> feeFeatures(double km, int hour) => [1, km, isPeak(hour) ? km : 0, isNight(hour) ? km : 0];

double predictSen(FeeWeights w, double km, int hour) {
  final x = feeFeatures(km, hour);
  return w.base + w.perKm * x[1] + w.perKmPeak * x[2] + w.perKmNight * x[3];
}
