import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'update_service.dart';

/// User-facing (Vietnamese) error from the update flow.
class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}

enum InstallResult { started, needsPermission }

/// Downloads the release zip, extracts the APK and opens the Android installer.
class UpdateInstaller {
  static const MethodChannel _channel = MethodChannel('transfeer/installer');
  static const String apkFileName = 'transfeer-update.apk';

  final http.Client _client;
  UpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  /// Downloads [info]'s attachment and returns the path of the APK to install.
  /// [onProgress] receives 0..1, or null when the total size is unknown.
  Future<String> download(UpdateInfo info, {required void Function(double?) onProgress}) async {
    final dirPath = await _channel.invokeMethod<String>('updatesDir');
    if (dirPath == null) throw const UpdateException('Không tìm thấy thư mục lưu bản cập nhật.');
    final dir = Directory(dirPath);
    // Remove leftovers from previous updates.
    for (final f in dir.listSync()) {
      try {
        f.deleteSync(recursive: true);
      } catch (_) {}
    }

    final target = File('${dir.path}/${info.isZip ? 'update.zip' : apkFileName}');
    final http.StreamedResponse res;
    try {
      res = await _client
          .send(http.Request('GET', Uri.parse(info.assetUrl)))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const UpdateException('Không kết nối được máy chủ. Vui lòng kiểm tra mạng.');
    }
    if (res.statusCode != 200) {
      throw UpdateException('Tải bản cập nhật thất bại (mã lỗi ${res.statusCode}).');
    }

    final total = res.contentLength ?? (info.assetSize > 0 ? info.assetSize : null);
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == null || total == 0 ? null : (received / total).clamp(0.0, 1.0));
      }
    } on TimeoutException {
      throw const UpdateException('Mạng quá chậm, tải về bị gián đoạn. Vui lòng thử lại.');
    } finally {
      await sink.close();
    }

    if (!info.isZip) return target.path;

    final apkPath = '${dir.path}/$apkFileName';
    final error = await compute(extractApk, [target.path, apkPath]);
    try {
      target.deleteSync();
    } catch (_) {}
    if (error != null) throw UpdateException(error);
    return apkPath;
  }

  /// Opens the system installer for [apkPath].
  Future<InstallResult> install(String apkPath) async {
    try {
      final r = await _channel.invokeMethod<String>('installApk', {'path': apkPath});
      return r == 'needs_permission' ? InstallResult.needsPermission : InstallResult.started;
    } on PlatformException catch (e) {
      throw UpdateException('Không mở được trình cài đặt: ${e.message ?? e.code}');
    }
  }
}

/// Extracts the first `.apk` inside the zip at args[0] to args[1].
/// Returns null on success or a Vietnamese error message.
/// Top-level so it can run in a background isolate via [compute].
String? extractApk(List<String> args) {
  final zipPath = args[0];
  final outPath = args[1];
  InputFileStream? input;
  try {
    input = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeStream(input);
    ArchiveFile? apk;
    for (final f in archive.files) {
      if (f.isFile && f.name.toLowerCase().endsWith('.apk')) {
        apk = f;
        break;
      }
    }
    if (apk == null) return 'File .zip không chứa file cài đặt .apk.';
    final out = OutputFileStream(outPath);
    apk.writeContent(out);
    out.closeSync();
    return null;
  } catch (e) {
    return 'Không giải nén được bản cập nhật ($e).';
  } finally {
    input?.closeSync();
  }
}
