import 'package:package_info_plus/package_info_plus.dart';

Future<String>? _cached;

/// App version string, e.g. "2.0.0" (cached).
Future<String> appVersion() => _cached ??= PackageInfo.fromPlatform()
    .then((i) => i.version)
    .catchError((_) => '2.0.0');
