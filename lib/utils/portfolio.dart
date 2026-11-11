import 'dart:math' as math;

/// What the user owns right now (editable totals).
/// DCA purchases are added on top of these totals when recorded.
class Holding {
  final double invested; // total VND put in
  final double units; // CCQ currently held
  final DateTime? since; // first purchase date (for the yearly growth rate)

  const Holding({required this.invested, required this.units, this.since});

  bool get isValid => invested > 0 && units > 0;
  double get avgCost => units > 0 ? invested / units : 0;

  Holding copyWith({double? invested, double? units, DateTime? since}) => Holding(
        invested: invested ?? this.invested,
        units: units ?? this.units,
        since: since ?? this.since,
      );
}

/// One DCA buy: [units] CCQ at [price] on [date].
class Purchase {
  final int id;
  final DateTime date;
  final double price;
  final double units;
  const Purchase({required this.id, required this.date, required this.price, required this.units});

  double get cost => price * units;

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date.millisecondsSinceEpoch, 'price': price, 'units': units};

  static Purchase fromJson(Map<String, dynamic> j) => Purchase(
        id: (j['id'] as num).toInt(),
        date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num).toInt()),
        price: (j['price'] as num).toDouble(),
        units: (j['units'] as num).toDouble(),
      );
}

/// Whole CCQ that [money] buys at [price] (odd lots allowed).
double unitsFor(double money, double price) =>
    price > 0 ? (money / price).floorToDouble() : 0;

enum DcaFrequency {
  weekly(52, 'Hàng tuần', 'tuần'),
  monthly(12, 'Hàng tháng', 'tháng');

  final int perYear;
  final String label; // "Hàng tuần"
  final String unit; // "tuần" -> "mỗi tuần"
  const DcaFrequency(this.perYear, this.label, this.unit);

  static DcaFrequency parse(String? s) =>
      DcaFrequency.values.firstWhere((f) => f.name == s, orElse: () => DcaFrequency.monthly);
}

class Performance {
  final double value; // units × price
  final double gain; // value − invested
  final double gainPct; // gain / invested × 100
  /// Yearly growth as a fraction (0.12 = 12%/year), money-weighted so that
  /// DCA buys made recently don't drag it down. Null when there is not enough
  /// dated history (less than [minDays]).
  final double? annualRate;
  final double? years; // time since the first dated money went in
  const Performance(this.value, this.gain, this.gainPct, this.annualRate, this.years);

  /// Less than a year of history: the annualised figure can be extreme.
  bool get isShortPeriod => years != null && years! < 1;
}

const int minDays = 30;

/// [h] = current totals (already including [buys]).
Performance evaluate(Holding h, double price, DateTime now, [List<Purchase> buys = const []]) {
  final value = h.units * price;
  final gain = value - h.invested;
  final pct = h.invested > 0 ? gain / h.invested * 100 : 0.0;

  // Cash flows: the part of the total not explained by logged buys is dated at
  // `since`; each logged buy at its own date; today's value comes back.
  final flows = <(DateTime, double)>[];
  final logged = buys.fold<double>(0, (s, b) => s + b.cost);
  final base = h.invested - logged;
  var ok = value > 0 && h.invested > 0;
  if (base > 1) {
    if (h.since == null) {
      ok = false;
    } else {
      flows.add((h.since!, -base));
    }
  }
  for (final b in buys) {
    flows.add((b.date, -b.cost));
  }
  double? rate, years;
  if (ok && flows.isNotEmpty) {
    final first = flows.map((f) => f.$1).reduce((a, b) => a.isBefore(b) ? a : b);
    final days = now.difference(first).inHours / 24;
    if (days >= minDays) {
      years = days / 365.25;
      rate = xirr([...flows, (now, value)]);
    }
  }
  return Performance(value, gain, pct.toDouble(), rate, years);
}

/// Annual rate r where Σ cf·(1+r)^(−t) = 0 (t in years from the first flow).
/// Solved by bisection; null if there is no sign change in [-99%, +1000%].
double? xirr(List<(DateTime, double)> flows) {
  if (flows.length < 2) return null;
  final t0 = flows.map((f) => f.$1).reduce((a, b) => a.isBefore(b) ? a : b);
  double npv(double r) {
    var s = 0.0;
    for (final (d, cf) in flows) {
      final t = d.difference(t0).inHours / 24 / 365.25;
      s += cf / math.pow(1 + r, t);
    }
    return s;
  }

  var lo = -0.99, hi = 10.0;
  var fLo = npv(lo), fHi = npv(hi);
  if (fLo.isNaN || fHi.isNaN || fLo * fHi > 0) return null;
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    final f = npv(mid);
    if (f.abs() < 1e-6 || (hi - lo) < 1e-10) return mid;
    if (f * fLo < 0) {
      hi = mid;
      fHi = f;
    } else {
      lo = mid;
      fLo = f;
    }
  }
  return (lo + hi) / 2;
}

class ProjectionPoint {
  final int year;
  final double value;
  final double contributed;
  const ProjectionPoint(this.year, this.value, this.contributed);
}

class Projection {
  final List<ProjectionPoint> points; // year 0..N
  const Projection(this.points);
  ProjectionPoint get last => points.last;
  double get finalValue => last.value;
  double get contributed => last.contributed;
  double get profit => last.value - last.contributed;
  double get profitPct => contributed > 0 ? profit / contributed * 100 : 0;
}

/// Grows [startValue] at [annualRate] (fraction), adding [amount] VND at the
/// end of every period ([perYear] = 52 weekly / 12 monthly), for [years] years.
/// [startContributed] is the money already put in (the cost basis).
Projection project({
  required double startValue,
  required double startContributed,
  required double amount,
  required double annualRate,
  required int years,
  int perYear = 12,
}) {
  final r = math.max(annualRate, -0.99);
  final p = math.pow(1 + r, 1 / perYear).toDouble() - 1;
  var value = startValue;
  var contributed = startContributed;
  final points = [ProjectionPoint(0, value, contributed)];
  for (var y = 1; y <= years; y++) {
    for (var i = 0; i < perYear; i++) {
      value = value * (1 + p) + amount;
      contributed += amount;
    }
    points.add(ProjectionPoint(y, value, contributed));
  }
  return Projection(points);
}

/// "10,5" / "10.5" / "-3" -> 10.5 / -3 (percent). Null if empty/invalid.
double? parsePercent(String s) {
  final t = s.trim().replaceAll(',', '.').replaceAll('%', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// 12.345 -> "12,3" (one decimal, Vietnamese comma).
String fmtRate(double pct) =>
    pct.toStringAsFixed(1).replaceAll('.', ',').replaceFirst(RegExp(r',0$'), '');
