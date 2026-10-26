import 'package:bowie/core/error/app_failure.dart';

/// The heaviest weight the app accepts, in kg.
const maxWeightKg = 150.0;

/// "23,5" or "23.5" in kg. Empty means no weight.
double? parseWeight(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  final weight = double.tryParse(value);
  if (weight == null) {
    throw const AppFailure('Digite o peso em kg, por exemplo 23,5.');
  }
  return weight;
}

/// One decimal place, as the app keeps it.
double roundWeight(double kg) => (kg * 10).round() / 10;

/// 23.0 → "23"; 23.5 → "23,5".
String formatWeight(double kg) {
  final rounded = roundWeight(kg);
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

/// "23,5 kg".
String formatKg(double kg) => '${formatWeight(kg)} kg';
