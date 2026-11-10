import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;

  /// Download URL of the release attachment (a .zip containing the .apk).
  final String assetUrl;
  final String assetName;
  final int assetSize;
  final String notes;
  final String pageUrl;

  const UpdateInfo({
    required this.version,
    required this.assetUrl,
    required this.assetName,
    required this.assetSize,
    required this.notes,
    required this.pageUrl,
  });

  bool get isZip => assetName.toLowerCase().endsWith('.zip');
}

/// Checks the latest GitHub Release for a newer version (Android only).
///
/// Release convention: tag = version (e.g. `v2.1.0`), attachment = a `.zip`
/// with the `.apk` inside. A bare `.apk` attachment is accepted as fallback.
class UpdateService {
  static const String repo = 'phunlh2001/transfeer';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repo/releases/latest';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Returns the newer release, or null when up to date / unsupported / offline.
  static Future<UpdateInfo?> check({http.Client? client}) async {
    if (!supported) return null;
    try {
      final current = await currentVersion();
      final c = client ?? http.Client();
      final res = await c.get(Uri.parse(latestReleaseUrl), headers: {
        'Accept': 'application/vnd.github+json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      return parseRelease(json, current);
    } catch (_) {
      return null;
    }
  }

  static UpdateInfo? parseRelease(Map<String, dynamic> release, String current) {
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final tag = (release['tag_name'] ?? '').toString();
    if (tag.isEmpty || compareVersions(tag, current) <= 0) return null;

    final assets = ((release['assets'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    Map<String, dynamic>? pick(String ext) {
      for (final a in assets) {
        if ((a['name'] ?? '').toString().toLowerCase().endsWith(ext)) return a;
      }
      return null;
    }

    final asset = pick('.zip') ?? pick('.apk');
    if (asset == null) return null;
    return UpdateInfo(
      version: normalize(tag),
      assetUrl: asset['browser_download_url'].toString(),
      assetName: asset['name'].toString(),
      assetSize: (asset['size'] as num?)?.toInt() ?? 0,
      notes: (release['body'] ?? '').toString().trim(),
      pageUrl: (release['html_url'] ?? '').toString(),
    );
  }

  /// "v2.1.0+5" -> "2.1.0"
  static String normalize(String v) =>
      v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[+-]')).first;

  /// Semantic compare of x.y.z; returns <0, 0, >0.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        normalize(v).split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
