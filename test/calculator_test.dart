import 'package:flutter_test/flutter_test.dart';
import 'package:transfeer/models/etf_quote.dart';
import 'package:transfeer/utils/calculator.dart';
import 'package:transfeer/utils/format.dart';

void main() {
  group('calcUnits', () {
    test('remainder', () {
      final r = calcUnits(1000000, 23100);
      expect(r.units, 43);
      expect(r.cost, 993300);
      expect(r.leftover, 6700);
      expect(r.avgPerUnit, 23100);
      expect(r.shortfall, 0);
    });

    test('exact division', () {
      final r = calcUnits(231000, 23100);
      expect(r.units, 10);
      expect(r.leftover, 0);
    });

    test('money below price', () {
      final r = calcUnits(20000, 23100);
      expect(r.units, 0);
      expect(r.avgPerUnit, isNull);
      expect(r.leftover, 20000);
      expect(r.shortfall, 3100);
    });

    test('zero / invalid input', () {
      expect(calcUnits(0, 23100).units, 0);
      expect(calcUnits(1000, 0).units, 0);
    });

    test('large value', () {
      final r = calcUnits(10000000000, 23100);
      expect(r.units, 432900);
      expect(r.cost + r.leftover, 10000000000);
    });
  });

  test('EtfQuote.fromJson parses sample', () {
    final q = EtfQuote.fromJson({
      'symbol': 'FUESSV30',
      'name': 'Quỹ ETF SSIAM VN30',
      'exchange': 'HOSE',
      'price': 23100,
      'change': -300,
      'changePct': -1.282,
      'ref': 23400,
      'ceiling': 25030,
      'floor': 21770,
      'high': 23350,
      'low': 22800,
      'volume': 26000,
      'value': 598627000,
    });
    expect(q.price, 23100.0);
    expect(q.changePct, closeTo(-1.282, 1e-9));
    expect(q.volume, 26000);
  });

  test('formatters', () {
    expect(fmtNum(1234567), '1.234.567');
    expect(fmtPct(-1.282), '−1,28%');
    expect(fmtCompactVnd(598627000), '599 tr');
    expect(parseVnd('1.000.000'), 1000000);
  });
}
