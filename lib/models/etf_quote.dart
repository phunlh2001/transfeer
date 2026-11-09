class EtfQuote {
  final String symbol;
  final String name;
  final String exchange;
  final double price;
  final double change;
  final double changePct;
  final double ref;
  final double ceiling;
  final double floor;
  final double high;
  final double low;
  final int volume;
  final double value;

  const EtfQuote({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.price,
    required this.change,
    required this.changePct,
    required this.ref,
    required this.ceiling,
    required this.floor,
    required this.high,
    required this.low,
    required this.volume,
    required this.value,
  });

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory EtfQuote.fromJson(Map<String, dynamic> j) => EtfQuote(
        symbol: (j['symbol'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        exchange: (j['exchange'] ?? '').toString(),
        price: _d(j['price']),
        change: _d(j['change']),
        changePct: _d(j['changePct']),
        ref: _d(j['ref']),
        ceiling: _d(j['ceiling']),
        floor: _d(j['floor']),
        high: _d(j['high']),
        low: _d(j['low']),
        volume: _d(j['volume']).round(),
        value: _d(j['value']),
      );
}
