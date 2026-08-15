/// Helper class for weight unit conversions
class WeightConverter {
  static const double kgToLbFactor = 2.20462;
  static const double lbToKgFactor = 0.453592;

  /// Convert kg to lb
  static double kgToLb(double kg) {
    return kg * kgToLbFactor;
  }

  /// Convert lb to kg
  static double lbToKg(double lb) {
    return lb * lbToKgFactor;
  }

  /// Format weight with proper decimal places
  static String formatWeight(double weight, {int decimals = 1}) {
    return weight.toStringAsFixed(decimals);
  }

  /// Parse weight string to double, handling both formats
  static double parseWeight(String input) {
    return double.tryParse(input) ?? 0.0;
  }

  /// Get display string for weight with unit
  static String displayWeight(double weight, String unit, {int decimals = 1}) {
    return '${formatWeight(weight, decimals: decimals)} $unit';
  }

  /// Convert weight between units
  static double convertWeight(double weight, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return weight;

    if (fromUnit == 'kg' && toUnit == 'lb') {
      return kgToLb(weight);
    } else if (fromUnit == 'lb' && toUnit == 'kg') {
      return lbToKg(weight);
    }

    return weight;
  }
}

