import 'package:flutter/material.dart';

import '../services/update_installer.dart';
import '../services/update_service.dart';
import 'lottie_view.dart';

/// Checks GitHub for a newer release and, if found, shows the update sheet.
/// With [manual] = true it also reports "up to date" / "not supported".
Future<void> checkForUpdates(BuildContext context, {bool manual = false}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!UpdateService.supported) {
    if (manual) {
      messenger?.showSnackBar(const SnackBar(
          content: Text('Bản web luôn là phiên bản mới nhất.')));
    }
    return;
  }
  if (manual) {
    messenger?.showSnackBar(const SnackBar(
        content: Text('Đang kiểm tra cập nhật…'), duration: Duration(seconds: 1)));
  }
  final info = await UpdateService.check();
  if (!context.mounted) return;
  if (info == null) {
    if (manual) {
      messenger?.showSnackBar(
          const SnackBar(content: Text('Bạn đang dùng phiên bản mới nhất.')));
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    isDismissible: false,
    builder: (_) => UpdateSheet(info: info),
  );
}

class UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  const UpdateSheet({super.key, required this.info});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

enum _Stage { idle, downloading, extracting, needsPermission, installing, error }

class _UpdateSheetState extends State<UpdateSheet> {
  final _installer = UpdateInstaller();
  _Stage _stage = _Stage.idle;
  double? _progress;
  String? _error;
  String? _apkPath; // kept so "Cài đặt" can retry without downloading again

  bool get _busy =>
      _stage == _Stage.downloading ||
      _stage == _Stage.extracting ||
      _stage == _Stage.installing;

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _error = null;
    });
    try {
      _apkPath ??= await _installer.download(
        widget.info,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p != null && p >= 1 && widget.info.isZip) _stage = _Stage.extracting;
          });
        },
      );
      await _install();
    } on UpdateException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Đã xảy ra lỗi: $e');
    }
  }

  Future<void> _install() async {
    if (!mounted || _apkPath == null) return;
    setState(() => _stage = _Stage.installing);
    try {
      final r = await _installer.install(_apkPath!);
      if (!mounted) return;
      if (r == InstallResult.needsPermission) {
        setState(() => _stage = _Stage.needsPermission);
      } else {
        // The Android installer takes over from here.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).maybePop();
      }
    } on UpdateException catch (e) {
      _fail(e.message);
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.error;
      _error = msg;
    });
  }

  String get _statusText => switch (_stage) {
        _Stage.downloading => _progress == null
            ? 'Đang tải bản cập nhật…'
            : 'Đang tải về… ${(_progress! * 100).toStringAsFixed(0)}%',
        _Stage.extracting => 'Đang giải nén…',
        _Stage.installing => 'Đang mở trình cài đặt…',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = widget.info;
    final sizeMb = info.assetSize > 0
        ? ' · ${(info.assetSize / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const LottieView('chart', size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Có phiên bản mới!',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Phiên bản ${info.version}$sizeMb',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
              ]),
            ),
          ]),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Có gì mới', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(info.notes,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.45)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_busy) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _stage == _Stage.downloading ? _progress : null,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(_statusText, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            const SizedBox(height: 16),
          ],
          if (_stage == _Stage.needsPermission)
            _Notice(
              color: cs.tertiaryContainer,
              textColor: cs.onTertiaryContainer,
              icon: Icons.verified_user_rounded,
              text: 'Hãy bật "Cho phép từ nguồn này" cho Transfeer, '
                  'sau đó quay lại đây và bấm "Cài đặt".',
            ),
          if (_stage == _Stage.error)
            _Notice(
              color: cs.errorContainer,
              textColor: cs.onErrorContainer,
              icon: Icons.error_outline_rounded,
              text: _error ?? 'Cập nhật thất bại.',
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Để sau'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : _stage == _Stage.needsPermission
                        ? _install
                        : _start,
                icon: Icon(switch (_stage) {
                  _Stage.error => Icons.refresh_rounded,
                  _Stage.needsPermission => Icons.install_mobile_rounded,
                  _ => Icons.system_update_rounded,
                }),
                label: Text(switch (_stage) {
                  _Stage.error => 'Thử lại',
                  _Stage.needsPermission => 'Cài đặt',
                  _ => 'Cập nhật ngay',
                }),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;
  const _Notice({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: textColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)),
        ),
      ]),
    );
  }
}
