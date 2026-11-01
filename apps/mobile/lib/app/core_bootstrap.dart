import '../features/pro/presentation/pro_page.dart';
import '../features/pro/data/store_service.dart';
import '../features/reminders/data/reminder_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/collection/data/repositories_impl/native_collection_repository.dart';
import '../features/collection/presentation/cubits/workspace_cubit.dart';
import '../features/collection/presentation/widgets/presentation_helpers.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';
import '../features/backup/presentation/backup_page.dart';

/// A failed open never becomes an empty collection. Retry retains native files.
class CoreBootstrap extends StatefulWidget {
  final Future<NativeCollectionRepository> Function() openRepository;
  const CoreBootstrap({
    super.key,
    this.openRepository = NativeCollectionRepository.open,
  });
  @override
  State<CoreBootstrap> createState() => _CoreBootstrapState();
}

class _CoreBootstrapState extends State<CoreBootstrap>
    with WidgetsBindingObserver {
  NativeCollectionRepository? repository;
  ReminderService? reminderService;
  late final StoreService storeService = NativeStoreService();
  WorkspaceCubit? recoveryWorkspace;
  List<PendingCoreAction> pending = [];
  bool busy = true, ready = false;
  String? error;
  bool restored = false;
  bool replacingDataset = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) repository?.invalidateUndo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    storeService.dispose();
    recoveryWorkspace?.close();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() => busy = true);
    try {
      final old = repository;
      if (old != null) {
        try {
          await old.close();
        } catch (_) {
          if (!replacingDataset) rethrow;
        }
      }
      repository = null;
      repository = await widget.openRepository();
      await recoveryWorkspace?.close();
      recoveryWorkspace = WorkspaceCubit(repository!);
      pending = repository!.pendingActions;
      if (pending.isEmpty) await _finish();
      if (mounted) {
        setState(() {
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = WorkspaceCubit.code(e);
        });
      }
    }
  }

  Future<void> _finish() async {
    await getIt.reset();
    await configureDependencies(environment: 'native', repository: repository);
    reminderService = NativeReminderService();
    if (mounted) setState(() => ready = true);
  }

  Future<void> _recover(
    BuildContext context,
    PendingCoreAction action,
    bool retry,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final resolution = await repository!.resolve(action.intent.commandId);
      if (!resolution.committed) {
        if (retry) {
          final command = action.intent.command;
          if (command is SaveDraft ||
              command is DiscardDraft ||
              command is Undo) {
            await repository!.retryPending(action);
          } else {
            final preview = await repository!.prepare(
              command,
              commandId: action.intent.commandId,
            );
            if (context.mounted) {
              setState(() => busy = false);
              await reviewCommand(
                context,
                preview,
                explanation: strings(context).recoveredActionReview,
              );
              if (mounted) setState(() => busy = true);
            }
          }
        } else {
          if (!context.mounted) return;
          setState(() => busy = false);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AppAlertDialog(
              scrollable: true,
              title: Text(strings(context).cancelPendingTitle),
              content: Text(strings(context).retainDraftExplanation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings(context).keepPending),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(strings(context).cancelPendingAction),
                ),
              ],
            ),
          );
          if (mounted) setState(() => busy = true);
          if (confirm == true) {
            await repository!.abandon(action.intent.commandId);
          }
        }
      }
      pending = await repository!.pending();
      if (pending.isEmpty) await _finish();
    } catch (e) {
      error = WorkspaceCubit.code(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reopenAfterRestore(bool didRestore) async {
    setState(() {
      ready = false;
      busy = true;
      replacingDataset = true;
      restored = didRestore;
      error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _open();
  }

  Widget _storeHost(Widget child) => repository == null
      ? child
      : ProHost(
          service: storeService,
          datasetId: repository!.datasetId,
          newId: repository!.newId,
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    if (ready) {
      final settings = repository!.settings;
      final locale = settings['localeOverride'] as String?;
      final supported =
          locale == null || const ['en', 'en-US', 'en-GB'].contains(locale);
      return _storeHost(
        BackupHost(
          datasetId: repository!.datasetId,
          newId: repository!.newId,
          reopen: _reopenAfterRestore,
          child: VerdiApp(
            key: ValueKey(repository!.datasetId),
            reminderService: reminderService,
            reminderNewId: repository!.newId,
            restored: restored,
            localeFallback: !supported,
            locale: supported && locale != null
                ? Locale.fromSubtags(
                    languageCode: 'en',
                    countryCode: locale.contains('-')
                        ? locale.split('-').last
                        : null,
                  )
                : null,
            themeMode: settings['theme'] == 'dark'
                ? ThemeMode.dark
                : settings['theme'] == 'light'
                ? ThemeMode.light
                : ThemeMode.system,
          ),
        ),
      );
    }
    Widget page = Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    pending.isEmpty
                        ? strings(context).openingPlants
                        : strings(context).recoveryHeading,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(strings(context).developmentStorage),
                  const SizedBox(height: 16),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null) ...[
                    Text(strings(context).retainedStorageError),
                    ErrorNotice(error!),
                    if (pending.isEmpty)
                      FilledButton(
                        onPressed: busy ? null : _open,
                        child: Text(strings(context).retryOpening),
                      ),
                  ],
                  if (pending.isNotEmpty)
                    Text(strings(context).pendingActionExplanation),
                  for (final action in pending)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _actionLabel(
                                strings(context),
                                action.intent.command,
                              ),
                            ),
                            if (action.label.isNotEmpty) Text(action.label),
                            Text(
                              action.intent.commandId,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _recover(context, action, true),
                                  child: Text(
                                    strings(context).retryPendingAction,
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _recover(context, action, false),
                                  child: Text(
                                    strings(context).cancelPendingAction,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (recoveryWorkspace != null) {
      page = BlocProvider.value(value: recoveryWorkspace!, child: page);
    }
    return _storeHost(
      MaterialApp(
        title: 'Verdi',
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: page,
      ),
    );
  }
}

String _actionLabel(AppStrings s, CoreCommand command) => switch (command) {
  CreateCustomCareType() => s.addCustomCare,
  RenameCustomCareType() => s.renameCareType,
  RetireCustomCareType() => s.retireCareType,
  CreateRoutine() => s.addCare,
  MediaCommand() => s.journalAndPhotos,
  SaveDraft() => s.saveDraftAction,
  SavePlant() => s.reviewSave,
  DiscardDraft() => s.discard,
  CompleteCurrent() || BulkComplete() => s.confirmCare,
  CheckNotNeeded() => s.checkedNotNeeded,
  Snooze() => s.moveCheck,
  Skip() => s.skipCheck,
  SetInterval() => s.editInterval,
  ClearOverride() => s.clearOverride,
  PauseRoutine() => s.pause,
  ResumeRoutine() => s.resume,
  RetireRoutine() => s.retire,
  AddPastCare() => s.addPastCare,
  CorrectEvent c => c.restore ? s.restoreCare : s.correctCare,
  VoidEvent() => s.removeCare,
  ArchivePlant() => s.archive,
  RestorePlant() => s.restore,
  DeletePlant() => s.deleteForever,
  Undo() => s.undo,
};
