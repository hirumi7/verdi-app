import 'package:verdi_core/verdi_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../collection/data/repositories/collection_repository.dart';
import '../../collection/presentation/widgets/presentation_helpers.dart';
import '../../media/presentation/widgets/photo_preview.dart';
import '../data/optimization_service.dart';
import 'cubits/optimization_cubit.dart';

Future<String?> openOptimization(BuildContext context, String plantId) =>
    Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => OptimizationPage(plantId: plantId)),
    );

class OptimizationPage extends StatefulWidget {
  final String plantId;
  final CollectionRepository? repository;
  final OptimizationService? service;
  const OptimizationPage({
    super.key,
    required this.plantId,
    this.repository,
    this.service,
  });
  @override
  State<OptimizationPage> createState() => _OptimizationPageState();
}

class _OptimizationPageState extends State<OptimizationPage> {
  late final repository = widget.repository ?? getIt<CollectionRepository>();
  late final cubit = OptimizationCubit(
    repository,
    widget.service ?? NativeOptimizationService(repository),
    widget.plantId,
  );
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    cubit.load();
  }

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  Future<void> leave() async {
    if (leaving) return;
    if (cubit.state.running || cubit.state.recoveryRequired) {
      final s = strings(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.optimizationLeaveTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(s.optimizationLeaveBody),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(s.optimizationCancel),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      await cubit.cancel();
      if (!mounted || cubit.state.recoveryRequired || cubit.state.running) {
        return;
      }
    }
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> review() async {
    if (!await cubit.preview() || !mounted) return;
    final s = strings(context), preview = cubit.state.preview!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.optimizationReview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(s.optimizationWarning),
              const SizedBox(height: 16),
              for (final raw in preview['targets'] as List)
                Text(
                  '${dateLabel(context, LocalDate.parse((raw as Map)['observedDate'] as String))} · ${s.optimizationDimensions(raw['width'] as int, raw['height'] as int, raw['byteCount'] as int)}',
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.optimizationConfirm),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await cubit.start();
    } else {
      cubit.cancelPreview();
    }
  }

  Widget resultCard(
    Map<String, Object?> result,
    int index,
    OptimizationState state,
    bool locked,
  ) {
    final s = strings(context),
        photo = state.photos
            .where((p) => p.id == result['photoId'])
            .firstOrNull;
    final status = switch (result['state']) {
      'succeeded' => s.optimizationSucceeded,
      'failed' => s.optimizationFailed,
      'not_attempted' => s.optimizationNotAttempted,
      _ => s.optimizationPending,
    };
    return Card(
      key: ValueKey('optimization-result-${result['photoId']}'),
      child: Padding(
        padding: AppLayout.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.optimizationPhoto(index + 1)),
            if (photo != null) ...[
              PhotoPreview(
                photoId: photo.id,
                revision: photo.revision,
                height: 140,
              ),
              Text(dateLabel(context, photo.observedDate)),
              Text(
                s.optimizationDimensions(
                  photo.width,
                  photo.height,
                  photo.byteCount,
                ),
              ),
            ] else
              Text(s.optimizationPhotoUnavailable),
            Text(status),
            if (result['code'] case final String code)
              Text(switch (code) {
                'MEDIA_UNSUPPORTED' => s.optimizationUnsupported,
                'DISK_FULL' => s.optimizationDiskFull,
                'IO_FAILURE' => s.optimizationWriteFailure,
                _ => errorLabel(s, code),
              }),
            if (photo != null)
              OutlinedButton(
                onPressed: locked
                    ? null
                    : () => Navigator.of(context).pop(photo.id),
                child: Text(s.optimizationOpenPhoto),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OptimizationCubit, OptimizationState>(
    bloc: cubit,
    builder: (context, state) {
      final s = strings(context),
          locked = state.busy || state.running || state.recoveryRequired;
      final job = state.job, results = (job?['results'] as List?) ?? const [];
      final error = switch (state.error) {
        'DRAFT_CONFLICT' => s.optimizationConflict,
        'MEDIA_UNSUPPORTED' => s.optimizationUnsupported,
        'OPTIMIZATION_NOT_STARTED' => s.optimizationNotStarted,
        null => null,
        _ => s.optimizationGenericError,
      };
      return PopScope(
        canPop: leaving || !(state.running || state.recoveryRequired),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
          appBar: AppPageBar(
            context: context,
            title: Text(s.optimizePhotos),
            leading: BackButton(onPressed: leave),
          ),
          body: SafeArea(
            child: ListView(
              padding: AppLayout.pagePadding,
              children: [
                AppScrollTitle(title: Text(s.optimizePhotos)),
                Text(s.optimizationIntro),
                const SizedBox(height: 12),
                Text(s.optimizationWarning),
                if (state.busy || state.running)
                  const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error, semanticsLabel: error),
                  ),
                if (state.recoveryRequired) ...[
                  Text(s.optimizationRecoveryNeeded),
                  FilledButton(
                    onPressed: state.busy ? null : cubit.recover,
                    child: Text(s.optimizationRecovery),
                  ),
                ] else if (state.running) ...[
                  Text(s.optimizationRunning),
                  OutlinedButton(
                    onPressed: state.busy ? null : cubit.cancel,
                    child: Text(s.optimizationCancel),
                  ),
                ],
                if (job != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    s.optimizationResults,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(switch (job['state']) {
                    'complete' => s.optimizationComplete,
                    'cancelled' => s.optimizationCancelled,
                    'interrupted' => s.optimizationInterrupted,
                    _ => s.optimizationRunning,
                  }),
                  for (final status in [
                    'succeeded',
                    'failed',
                    'not_attempted',
                    'pending',
                  ])
                    Text(
                      '${switch (status) {
                        'succeeded' => s.optimizationSucceeded,
                        'failed' => s.optimizationFailed,
                        'not_attempted' => s.optimizationNotAttempted,
                        _ => s.optimizationPending,
                      }}: ${results.where((r) => (r as Map)['state'] == status).length}',
                    ),
                  for (var i = 0; i < results.length; i++)
                    resultCard(
                      (results[i] as Map).cast<String, Object?>(),
                      i,
                      state,
                      locked,
                    ),
                  Text(s.optimizationFailureHelp),
                ],
                const SizedBox(height: 16),
                if (state.photos.isEmpty && !state.busy)
                  Text(s.optimizationNoPhotos),
                for (final photo in state.photos)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppLayout.cardGap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhotoPreview(
                          photoId: photo.id,
                          revision: photo.revision,
                          height: 140,
                        ),
                        CheckboxListTile(
                          key: ValueKey('optimize-${photo.id}'),
                          value: state.selected.contains(photo.id),
                          onChanged: locked
                              ? null
                              : (_) => cubit.select(photo.id),
                          title: Text(dateLabel(context, photo.observedDate)),
                          subtitle: Text(
                            s.optimizationDimensions(
                              photo.width,
                              photo.height,
                              photo.byteCount,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton(
                  onPressed: locked || state.selected.isEmpty ? null : review,
                  child: Text(
                    '${s.optimizationReview} (${state.selected.length})',
                  ),
                ),
                if (!locked)
                  TextButton(onPressed: cubit.load, child: Text(s.retry)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
