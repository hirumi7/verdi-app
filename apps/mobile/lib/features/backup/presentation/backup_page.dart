import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../collection/presentation/widgets/presentation_helpers.dart';
import '../data/backup_service.dart';
import 'backup_cubit.dart';

/// Installed above the router, so replacement discards every old route/provider.
class BackupHost extends InheritedWidget {
  final String datasetId;
  final String Function() newId;
  final Future<void> Function(bool restored) reopen;
  const BackupHost({
    super.key,
    required super.child,
    required this.datasetId,
    required this.newId,
    required this.reopen,
  });
  static BackupHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackupHost>();
  @override
  bool updateShouldNotify(BackupHost oldWidget) =>
      oldWidget.datasetId != datasetId;
}

class BackupPage extends StatefulWidget {
  final BackupService? service;
  const BackupPage({super.key, this.service});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupCubit? _cubit;
  bool _opening = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final host = BackupHost.maybeOf(context)!;
    _cubit = BackupCubit(
      widget.service ?? NativeBackupService(),
      datasetId: host.datasetId,
      newId: host.newId,
    )..load();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _confirm() async {
    final s = strings(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.backupReplaceTitle),
        content: Text(s.backupReplaceWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.backupReplace),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _cubit!.confirm();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<BackupCubit, BackupState>(
    bloc: _cubit,
    listener: (context, state) async {
      final host = BackupHost.maybeOf(context)!;
      if (state.phase == 'complete' &&
          state.result['datasetId'] != host.datasetId &&
          !_opening) {
        _opening = true;
        await host.reopen(true);
      }
    },
    builder: (context, state) {
      final s = strings(context), cubit = _cubit!;
      final preview = backupMap(state.result['preview']),
          counts = backupMap(preview['counts'] ?? state.result['counts']);
      final disabled =
          state.busy ||
          state.working ||
          state.replacing ||
          state.phase == 'preview_ready';
      final code = state.error ?? state.result['code'] as String?;
      return PopScope(
        canPop: !state.replacing && !state.committedBoundary,
        child: Scaffold(
          appBar: AppPageBar(
            context: context,
            title: const SizedBox.shrink(),
            automaticallyImplyLeading: !state.replacing,
          ),
          body: SafeArea(
            child: ListView(
              padding: AppLayout.pagePadding,
              children: [
                AppPageHeader(title: s.backupTitle),
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/illustrations/backup.png',
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.backupExplanation,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(s.backupPrivacy),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: disabled ? null : cubit.create,
                  icon: const Icon(Icons.save_alt),
                  label: Text(s.backupCreate),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: disabled ? null : cubit.choose,
                  icon: const Icon(Icons.folder_open),
                  label: Text(s.backupChoose),
                ),
                const SizedBox(height: 24),
                if (state.busy || state.working || state.replacing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    state.replacing || state.committedBoundary
                        ? s.backupReplacing
                        : s.backupWorking,
                  ),
                ],
                if (code != null) ...[
                  Text(
                    _error(context, code),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.replacing || state.committedBoundary)
                    OutlinedButton(
                      onPressed: state.busy ? null : cubit.poll,
                      child: Text(s.backupCheckStatus),
                    ),
                ],
                if (state.phase == 'preview_ready' && !state.replacing) ...[
                  Text(
                    s.backupPreview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.backupCounts(
                      '${counts['activePlants'] ?? 0}',
                      '${counts['archivedPlants'] ?? 0}',
                      '${counts['events'] ?? 0}',
                      '${counts['journalEntries'] ?? 0}',
                      '${counts['photos'] ?? 0}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(s.backupReplaceWarning),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: state.busy ? null : _confirm,
                    child: Text(s.backupReplace),
                  ),
                ],
                if (state.fileCreated) ...[
                  Text(
                    state.shareResult == 'handedToOS' ||
                            state.phase == 'handed_to_os'
                        ? s.backupHanded
                        : s.backupCreated,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(s.backupKeepOutside),
                  if (state.shareResult == 'cancelled')
                    Text(s.backupShareCancelled),
                  if (state.shareResult == 'failed') Text(s.backupShareFailed),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: disabled ? null : cubit.share,
                    child: Text(s.backupShare),
                  ),
                ],
                if (state.phase == 'complete') Text(s.backupRestored),
                if (state.phase == 'cancelled' && !state.fileCreated)
                  Text(s.backupCancelled),
                if (state.phase == 'failed' &&
                    state.result['recovery'] == 'open_recovery')
                  FilledButton(
                    onPressed: state.busy
                        ? null
                        : () => BackupHost.maybeOf(context)!.reopen(false),
                    child: Text(s.retryOpening),
                  ),
                if (state.phase == 'failed' &&
                    state.job['kind'] == 'import' &&
                    state.result['recovery'] != 'open_recovery')
                  OutlinedButton(
                    onPressed: state.busy ? null : cubit.retry,
                    child: Text(s.backupReviewAgain),
                  ),
                if ((state.working || state.phase == 'preview_ready') &&
                    !state.committedBoundary)
                  TextButton(
                    onPressed: state.busy ? null : cubit.cancel,
                    child: Text(s.cancel),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  String _error(BuildContext context, String code) {
    final s = strings(context);
    return switch (code) {
      'PREVIEW_STALE' => s.backupStale,
      'BUSY' || 'MEDIA_BUSY' => s.backupBusy,
      'DISK_FULL' => s.backupDiskFull,
      'MEDIA_MISSING' => s.backupMissingPhoto,
      'BACKUP_VERSION_UNSUPPORTED' => s.backupUnsupported,
      'BACKUP_LIMIT' => s.backupLimit,
      'BACKUP_SCHEMA_INVALID' ||
      'BACKUP_ARCHIVE_INVALID' ||
      'BACKUP_PATH_INVALID' ||
      'BACKUP_REFERENCE_INVALID' ||
      'BACKUP_HASH_MISMATCH' ||
      'BACKUP_CRC_MISMATCH' => s.backupInvalid,
      _ => s.backupFailure,
    };
  }
}
