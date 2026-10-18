// Backup export / JSON restore (web BackupSettings subset).

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/backup_service.dart';
import '../../domain/backup_snapshot.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final snapshot = BackupService.createSnapshot();
      final name = defaultBackupFileName();
      final json = snapshot.toPrettyJson();
      final bytes = Uint8List.fromList(utf8.encode(json));

      if (kIsWeb) {
        await FilePicker.saveFile(
          dialogTitle: 'Save Accountant backup',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: bytes,
          mimeType: 'application/json',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: 'Accountant backup',
            text: 'Accountant backup · ${snapshot.exportedAt}',
          ),
        );
      }
      if (!mounted) return;
      AppToast.success(context, 'Backup ready to share or save.');
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Couldn’t export backup.',
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return;

    final file = files.first;
    String? text;
    try {
      final bytes = await file.readAsBytes();
      text = utf8.decode(bytes);
    } catch (_) {
      text = null;
    }
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Couldn’t read that file.',
        tone: AppToastTone.error,
      );
      return;
    }

    if (!mounted) return;
    final ok = await AppToast.confirm(
      context,
      title: 'Replace all data?',
      message:
          'Importing this backup replaces transactions, budgets, jars, accounts, debts, scheduled payments, and matching settings. This can’t be undone.',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final snapshot = await BackupService.restoreFromJsonText(text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppToast.success(
        context,
        'Restored ${snapshot.transactions.length} transactions · ${snapshot.accounts.length} accounts.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e is StateError ? e.message : 'Invalid Accountant backup.',
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Backup & restore'),
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg + bottom,
        ),
        children: [
          Text(
            'Use the same JSON format as the Accountant web app. Export a backup there, then upload it here — or share a backup from this phone.',
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file_rounded, color: colors.accent),
                  title: const Text('Upload backup JSON'),
                  subtitle: const Text('Replace local data from a .json file'),
                  enabled: !_busy,
                  onTap: _import,
                ),
                Divider(height: 1, color: colors.border),
                ListTile(
                  leading: Icon(Icons.ios_share_rounded, color: colors.accent),
                  title: const Text('Export backup'),
                  subtitle: const Text('Share or save current data as JSON'),
                  enabled: !_busy,
                  onTap: _export,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
