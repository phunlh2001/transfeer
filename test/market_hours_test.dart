import 'package:flutter_test/flutter_test.dart';
import 'package:transfeer/utils/market_hours.dart';

// 2026-11-09 is a Monday; 11-13 Friday; 11-14 Saturday.
DateTime vn(int day, int h, int m) => DateTime.utc(2026, 11, day, h, m);

void main() {
  group('isTradingTime boundaries (Monday)', () {
    final cases = {
      (8, 59): false,
      (9, 0): true,
      (11, 29): true,
      (11, 30): false,
      (12, 59): false,
      (13, 0): true,
      (14, 59): true,
      (15, 0): false,
    };
    cases.forEach((t, expected) {
      test('${t.$1}:${t.$2} -> $expected', () {
        expect(isTradingTime(vn(9, t.$1, t.$2)), expected);
      });
    });
  });

  test('weekend is closed all day', () {
    expect(isTradingTime(vn(14, 10, 0)), isFalse); // Sat
    expect(isTradingTime(vn(15, 14, 0)), isFalse); // Sun
    expect(phaseOf(vn(14, 10, 0)), MarketPhase.weekend);
  });

  test('phases', () {
    expect(phaseOf(vn(9, 7, 0)), MarketPhase.beforeOpen);
    expect(phaseOf(vn(9, 10, 0)), MarketPhase.morning);
    expect(phaseOf(vn(9, 12, 0)), MarketPhase.lunchBreak);
    expect(phaseOf(vn(9, 14, 0)), MarketPhase.afternoon);
    expect(phaseOf(vn(9, 16, 0)), MarketPhase.afterClose);
  });

  test('vnNow converts UTC to UTC+7 (crosses midnight)', () {
    // Sun 2026-11-08 20:30 UTC = Mon 2026-11-09 03:30 VN
    final v = vnNow(DateTime.utc(2026, 11, 8, 20, 30));
    expect(v.weekday, DateTime.monday);
    expect(v.hour, 3);
    // Mon 02:30 UTC = Mon 09:30 VN -> trading
    expect(isTradingTime(vnNow(DateTime.utc(2026, 11, 9, 2, 30))), isTrue);
  });

  test('nextOpen', () {
    expect(nextOpen(vn(9, 7, 0)), vn(9, 9, 0));
    expect(nextOpen(vn(9, 11, 30)), vn(9, 13, 0));
    expect(nextOpen(vn(9, 15, 0)), vn(10, 9, 0));
    expect(nextOpen(vn(13, 15, 0)), vn(16, 9, 0)); // Fri -> Mon
    expect(nextOpen(vn(14, 10, 0)), vn(16, 9, 0)); // Sat -> Mon
    expect(nextOpen(vn(9, 10, 0)), vn(9, 10, 0)); // trading now
  });

  test('sessionEnd & nextBoundary', () {
    expect(sessionEnd(vn(9, 10, 0)), vn(9, 11, 30));
    expect(sessionEnd(vn(9, 14, 0)), vn(9, 15, 0));
    expect(sessionEnd(vn(9, 12, 0)), isNull);
    expect(nextBoundary(vn(9, 10, 0)), vn(9, 11, 30));
    expect(nextBoundary(vn(9, 12, 0)), vn(9, 13, 0));
    expect(nextBoundary(vn(13, 16, 0)), vn(16, 9, 0));
  });
}
