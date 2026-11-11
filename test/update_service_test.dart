import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:transfeer/services/update_installer.dart';
import 'package:transfeer/services/update_service.dart';

void main() {
  group('compareVersions', () {
    test('ordering', () {
      expect(UpdateService.compareVersions('2.0.0', '2.0.1'), lessThan(0));
      expect(UpdateService.compareVersions('2.0.1', '2.1.0'), lessThan(0));
      expect(UpdateService.compareVersions('2.1.0', '10.0.0'), lessThan(0));
      expect(UpdateService.compareVersions('v2.0.0', '2.0.0'), 0);
      expect(UpdateService.compareVersions('2.0.0+5', '2.0.0'), 0);
      expect(UpdateService.compareVersions('2.0', '2.0.0'), 0);
      expect(UpdateService.compareVersions('3.0.0', '2.9.9'), greaterThan(0));
    });
  });

  group('parseRelease', () {
    Map<String, dynamic> release(String tag, {List<String> assets = const ['app-release.zip']}) => {
          'tag_name': tag,
          'body': 'Sửa lỗi',
          'html_url': 'https://github.com/phunlh2001/transfeer/releases/tag/$tag',
          'draft': false,
          'prerelease': false,
          'assets': [
            for (final a in assets)
              {'name': a, 'size': 22373156, 'browser_download_url': 'https://example.com/$a'}
          ],
        };

    test('newer release with zip', () {
      final u = UpdateService.parseRelease(release('v2.1.0'), '2.0.0')!;
      expect(u.version, '2.1.0');
      expect(u.assetUrl, 'https://example.com/app-release.zip');
      expect(u.isZip, isTrue);
      expect(u.assetSize, 22373156);
      expect(u.notes, 'Sửa lỗi');
    });

    test('prefers zip over apk', () {
      final u = UpdateService.parseRelease(
          release('v2.1.0', assets: ['app-release.apk', 'transfeer-v2.1.0.zip']), '2.0.0')!;
      expect(u.assetName, 'transfeer-v2.1.0.zip');
    });

    test('falls back to bare apk', () {
      final u = UpdateService.parseRelease(release('v2.1.0', assets: ['app-release.apk']), '2.0.0')!;
      expect(u.isZip, isFalse);
    });

    test('same or older version -> null', () {
      expect(UpdateService.parseRelease(release('v2.0.0'), '2.0.0'), isNull);
      expect(UpdateService.parseRelease(release('v1.0.0'), '2.0.0'), isNull);
    });

    test('no installable asset -> null', () {
      expect(UpdateService.parseRelease(release('v3.0.0', assets: ['notes.txt']), '2.0.0'), isNull);
    });

    test('prerelease ignored', () {
      final r = release('v3.0.0')..['prerelease'] = true;
      expect(UpdateService.parseRelease(r, '2.0.0'), isNull);
    });
  });

  group('extractApk', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('transfeer_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String makeZip(Map<String, List<int>> files) {
      final a = Archive();
      files.forEach((name, data) => a.addFile(ArchiveFile.bytes(name, data)));
      final path = '${tmp.path}/update.zip';
      File(path).writeAsBytesSync(ZipEncoder().encodeBytes(a));
      return path;
    }

    test('extracts the apk (also from a subfolder)', () {
      final payload = List<int>.generate(50000, (i) => i % 251);
      final zip = makeZip({'README.txt': [1, 2, 3], 'build/app-release.apk': payload});
      final out = '${tmp.path}/out.apk';
      expect(extractApk([zip, out]), isNull);
      expect(File(out).readAsBytesSync(), payload);
    });

    test('zip without apk -> error message', () {
      final zip = makeZip({'README.txt': [1, 2, 3]});
      expect(extractApk([zip, '${tmp.path}/out.apk']), contains('không chứa'));
    });

    test('corrupt zip -> error message', () {
      final bad = '${tmp.path}/bad.zip';
      File(bad).writeAsStringSync('not a zip');
      expect(extractApk([bad, '${tmp.path}/out.apk']), isNotNull);
    });

    test('real v1.0.0 release zip layout', () {
      // Same layout as the published app-release.zip: app-release.apk at root.
      final zip = makeZip({'app-release.apk': List<int>.filled(1024, 7)});
      expect(extractApk([zip, '${tmp.path}/out.apk']), isNull);
    });
  });

  test('bundled Lottie files parse', () async {
    for (final name in ['loading', 'market_closed', 'chart', 'coins', 'growth']) {
      final bytes = File('assets/lottie/$name.json').readAsBytesSync();
      final comp = await LottieComposition.fromBytes(bytes);
      expect(comp.duration, greaterThan(Duration.zero), reason: name);
      expect(comp.layers, isNotEmpty, reason: name);
    }
  });
}
