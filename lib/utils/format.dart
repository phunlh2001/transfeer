import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _int = NumberFormat('#,##0', 'en_US');

/// 1234567 -> "1.234.567" (Vietnamese grouping).
String fmtNum(num v) => _int.format(v.round()).replaceAll(',', '.');
String fmtVnd(num v) => '${fmtNum(v)} ₫';
String fmtSigned(num v) =>
    '${v > 0 ? '+' : v < 0 ? '−' : ''}${fmtNum(v.abs())}';
String fmtPct(num v) =>
    '${v > 0 ? '+' : v < 0 ? '−' : ''}${v.abs().toStringAsFixed(2).replaceAll('.', ',')}%';

/// Compact VND: 598627000 -> "598,6 tr", 1.2e9 -> "1,2 tỷ".
String fmtCompactVnd(num v) {
  String one(double x) =>
      x.toStringAsFixed(x.abs() >= 100 ? 0 : 1).replaceAll('.', ',');
  if (v.abs() >= 1e9) return '${one(v / 1e9)} tỷ';
  if (v.abs() >= 1e6) return '${one(v / 1e6)} tr';
  return fmtNum(v);
}

String fmtTime(DateTime t) => DateFormat('HH:mm:ss').format(t);

/// DateTime.weekday (1 = Monday) -> "Thứ Hai" … "Chủ Nhật".
String weekdayVi(int weekday) => const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ][(weekday - 1) % 7];

/// Spelled-out amount for quick-pick chips: 1e6 -> "1 triệu", 1e9 -> "1 tỷ".
String fmtWordsVnd(num v) {
  String n(double x) =>
      (x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1)).replaceAll('.', ',');
  if (v.abs() >= 1e9) return '${n(v / 1e9)} tỷ';
  if (v.abs() >= 1e6) return '${n(v / 1e6)} triệu';
  if (v.abs() >= 1e3) return '${n(v / 1e3)} nghìn';
  return fmtNum(v);
}

/// "1.000.000" -> 1000000.
double parseVnd(String s) =>
    double.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Inserts "." thousand separators as the user types.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.length > 15) digits = digits.substring(0, 15);
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = fmtNum(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
