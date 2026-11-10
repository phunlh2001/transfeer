/// HOSE trading hours, evaluated in Vietnam time (UTC+7) regardless of the
/// device timezone. Public holidays are not handled.
///
/// All "VN" DateTimes here are UTC-flagged values whose fields hold the
/// Vietnam wall-clock time, so arithmetic is never affected by local DST.
library;

enum MarketPhase { beforeOpen, morning, lunchBreak, afternoon, afterClose, weekend }

const int _morningOpen = 9 * 60; // 09:00
const int _morningClose = 11 * 60 + 30; // 11:30
const int _afternoonOpen = 13 * 60; // 13:00
const int _afternoonClose = 15 * 60; // 15:00

const List<String> tradingSessionsLabel = ['09:00 – 11:30', '13:00 – 15:00'];

/// Current Vietnam wall-clock time.
DateTime vnNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));

bool _isWeekend(DateTime vn) =>
    vn.weekday == DateTime.saturday || vn.weekday == DateTime.sunday;

int _minuteOfDay(DateTime vn) => vn.hour * 60 + vn.minute;

DateTime _at(DateTime vn, int minuteOfDay, {int addDays = 0}) => DateTime.utc(
    vn.year, vn.month, vn.day + addDays, minuteOfDay ~/ 60, minuteOfDay % 60);

MarketPhase phaseOf(DateTime vn) {
  if (_isWeekend(vn)) return MarketPhase.weekend;
  final m = _minuteOfDay(vn);
  if (m < _morningOpen) return MarketPhase.beforeOpen;
  if (m < _morningClose) return MarketPhase.morning;
  if (m < _afternoonOpen) return MarketPhase.lunchBreak;
  if (m < _afternoonClose) return MarketPhase.afternoon;
  return MarketPhase.afterClose;
}

bool isTradingTime(DateTime vn) {
  final p = phaseOf(vn);
  return p == MarketPhase.morning || p == MarketPhase.afternoon;
}

DateTime _nextWeekdayOpen(DateTime vn) {
  var d = _at(vn, _morningOpen, addDays: 1);
  while (_isWeekend(d)) {
    d = _at(d, _morningOpen, addDays: 1);
  }
  return d;
}

/// Start of the next trading session (returns [vn] itself when trading now).
DateTime nextOpen(DateTime vn) {
  switch (phaseOf(vn)) {
    case MarketPhase.beforeOpen:
      return _at(vn, _morningOpen);
    case MarketPhase.lunchBreak:
      return _at(vn, _afternoonOpen);
    case MarketPhase.morning:
    case MarketPhase.afternoon:
      return vn;
    case MarketPhase.afterClose:
    case MarketPhase.weekend:
      return _nextWeekdayOpen(vn);
  }
}

/// End of the current session, or null when the market is closed.
DateTime? sessionEnd(DateTime vn) => switch (phaseOf(vn)) {
      MarketPhase.morning => _at(vn, _morningClose),
      MarketPhase.afternoon => _at(vn, _afternoonClose),
      _ => null,
    };

/// Next moment the phase can change (open/close boundary).
DateTime nextBoundary(DateTime vn) {
  if (!_isWeekend(vn)) {
    final m = _minuteOfDay(vn);
    for (final b in const [_morningOpen, _morningClose, _afternoonOpen, _afternoonClose]) {
      if (m < b) return _at(vn, b);
    }
  }
  return _nextWeekdayOpen(vn);
}
