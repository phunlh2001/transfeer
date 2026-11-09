class UnitCalcResult {
  final int units;
  final double cost;
  final double leftover;

  /// Average money per unit actually spent; null when no unit is affordable.
  final double? avgPerUnit;

  /// Extra money needed to afford one unit (0 when at least one is affordable).
  final double shortfall;

  const UnitCalcResult({
    required this.units,
    required this.cost,
    required this.leftover,
    required this.avgPerUnit,
    required this.shortfall,
  });
}

/// Whole units (odd lots allowed), no fee.
UnitCalcResult calcUnits(double money, double price) {
  if (money <= 0 || price <= 0) {
    return UnitCalcResult(
      units: 0,
      cost: 0,
      leftover: money > 0 ? money : 0,
      avgPerUnit: null,
      shortfall: price > 0 ? price : 0,
    );
  }
  final units = (money / price).floor();
  final cost = units * price;
  return UnitCalcResult(
    units: units,
    cost: cost,
    leftover: money - cost,
    avgPerUnit: units > 0 ? cost / units : null,
    shortfall: units > 0 ? 0 : price - money,
  );
}
