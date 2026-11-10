import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/etf_quote.dart';

class EtfApi {
  static const String endpoint = 'https://transfeer-be.onrender.com/api/etf';

  final http.Client _client;
  EtfApi({http.Client? client}) : _client = client ?? http.Client();

  Future<EtfQuote> fetchQuote() async {
    // Cache-buster so browsers/proxies never serve a stale (ETag) response.
    final uri = Uri.parse(endpoint).replace(
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Lỗi máy chủ (mã ${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu trả về không hợp lệ');
    }
    return EtfQuote.fromJson(body);
  }
}
