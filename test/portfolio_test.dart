import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:transfeer/utils/portfolio.dart';

void main() {
  group('evaluate', () {
    test('gain / loss and percentage', () {
      const h = Holding(invested: 10000000, units: 500); // avg 20.000
      final p = evaluate(h, 23100, DateTime(2026, 11, 11));
      expect(p.value, 11550000);
      expect(p.gain, 1550000);
      expect(p.gainPct, closeTo(15.5, 1e-9));
      expect(p.annualRate, isNull); // no first-buy date
      expect(h.avgCost, 20000);
    });

    test('loss', () {
      const h = Holding(invested: 10000000, units: 400);
      final p = evaluate(h, 23100, DateTime(2026, 11, 11));
      expect(p.gain, -760000);
      expect(p.gainPct, closeTo(-7.6, 1e-9));
    });

    test('annualised rate (CAGR) over 2 years', () {
      final since = DateTime(2024, 11, 11);
      final now = since.add(const Duration(days: 731)); // 2.0014 years
      final h = Holding(invested: 100, units: 1, since: since);
      final p = evaluate(h, 121, now); // +21% over 2 years ≈ 10%/year
      expect(p.annualRate!, closeTo(0.10, 0.001));
      expect(p.isShortPeriod, isFalse);
    });

    test('less than 30 days -> no rate; under 1 year -> short period', () {
      final now = DateTime(2026, 11, 11);
      final h1 = Holding(invested: 100, units: 1, since: now.subtract(const Duration(days: 10)));
      expect(evaluate(h1, 110, now).annualRate, isNull);
      final h2 = Holding(invested: 100, units: 1, since: now.subtract(const Duration(days: 120)));
      final p2 = evaluate(h2, 110, now);
      expect(p2.annualRate, isNotNull);
      expect(p2.isShortPeriod, isTrue);
    });
  });

  group('project', () {
    test('no growth, no contribution keeps value', () {
      final r = project(startValue: 1e6, startContributed: 1e6, amount: 0, annualRate: 0, years: 5);
      expect(r.points.length, 6);
      expect(r.finalValue, closeTo(1e6, 1e-6));
      expect(r.profit, closeTo(0, 1e-6));
    });

    test('compounds yearly rate exactly', () {
      final r = project(startValue: 1e6, startContributed: 1e6, amount: 0, annualRate: 0.10, years: 10);
      expect(r.finalValue, closeTo(1e6 * 2.5937424601, 1));
    });

    test('monthly contributions, 0% growth', () {
      final r = project(startValue: 5e6, startContributed: 4e6, amount: 1e6, annualRate: 0, years: 5);
      expect(r.contributed, 4e6 + 60e6);
      expect(r.finalValue, closeTo(65e6, 1e-3));
      expect(r.profit, closeTo(1e6, 1e-3)); // the existing unrealised gain
    });

    test('monthly contributions with growth = annuity formula', () {
      const c = 2e6;
      final r = project(startValue: 0, startContributed: 0, amount: c, annualRate: 0.12, years: 10);
      // Future value of an ordinary annuity at the equivalent monthly rate.
      final i = math.pow(1.12, 1 / 12) - 1;
      final fv = c * ((math.pow(1 + i, 120) - 1) / i);
      expect(r.finalValue, closeTo(fv, 1));
      expect(r.contributed, 240e6);
    });
  });

  group('DCA', () {
    test('weekly plan = 52 buys a year', () {
      final r = project(
          startValue: 0, startContributed: 0, amount: 500e3, annualRate: 0, years: 5, perYear: 52);
      expect(r.contributed, 500e3 * 52 * 5);
      expect(r.finalValue, closeTo(130e6, 1e-3));
    });

    test('weekly compounding still matches the yearly rate', () {
      final r = project(
          startValue: 1e6, startContributed: 1e6, amount: 0, annualRate: 0.08, years: 5, perYear: 52);
      expect(r.finalValue, closeTo(1e6 * math.pow(1.08, 5), 1));
    });

    test('unitsFor rounds down to whole CCQ', () {
      expect(unitsFor(1e6, 23100), 43);
      expect(unitsFor(20000, 23100), 0);
    });

    test('xirr: single flow equals CAGR', () {
      final r = xirr([(DateTime(2024, 1, 1), -100), (DateTime(2026, 1, 1), 121)])!;
      expect(r, closeTo(0.10, 0.001));
    });

    test('recent DCA buys do not drag the yearly rate down', () {
      // 10tr two years ago grew 21% (≈10%/yr); a 10tr buy yesterday is flat.
      final now = DateTime(2026, 11, 11);
      final buy = Purchase(id: 1, date: now.subtract(const Duration(days: 1)), price: 100, units: 100000);
      final h = Holding(invested: 20e6, units: 221000, since: DateTime(2024, 11, 11));
      final p = evaluate(h, 100, now, [buy]); // value 22.1tr
      expect(p.gainPct, closeTo(10.5, 1e-9)); // simple % on total money
      expect(p.annualRate!, closeTo(0.10, 0.002)); // money-weighted
    });

    test('total with unknown start date + buys -> no rate', () {
      final now = DateTime(2026, 11, 11);
      final buy = Purchase(id: 1, date: DateTime(2025, 1, 1), price: 100, units: 10);
      const h = Holding(invested: 2000, units: 20);
      expect(evaluate(h, 120, now, [buy]).annualRate, isNull);
    });

    test('purchase json round-trip', () {
      final b = Purchase(id: 7, date: DateTime(2026, 3, 2), price: 22950, units: 43);
      final c = Purchase.fromJson(b.toJson());
      expect([c.id, c.date, c.price, c.units, c.cost], [7, DateTime(2026, 3, 2), 22950, 43, 22950 * 43]);
    });
  });

  test('parsePercent / fmtRate', () {
    expect(parsePercent('10,5'), 10.5);
    expect(parsePercent('-3'), -3);
    expect(parsePercent(''), isNull);
    expect(fmtRate(12.0), '12');
    expect(fmtRate(12.34), '12,3');
  });
}

