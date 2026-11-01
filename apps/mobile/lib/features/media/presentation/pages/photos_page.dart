import '../../../optimization/presentation/optimization_page.dart';
import '../../../cards/presentation/card_page.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/native/draft_bridge.g.dart';
import '../../../../core/router/app_router.dart';
import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/widgets/presentation_helpers.dart';
import '../cubits/photo_cubit.dart';
import '../widgets/photo_preview.dart';

@RoutePage()
class PhotosPage extends StatefulWidget {
  final String plantId;
  final String? photoId;
  const PhotosPage({super.key, required this.plantId, this.photoId});
  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  late final PhotoCubit cubit;
  String? selected, localError, exportOutcome, exportError;
  LocalDate? exportedDate;
  bool picking = false, exporting = false;
  @override
  void initState() {
    super.initState();
    selected = widget.photoId;
    cubit = PhotoCubit(getIt<CollectionRepository>(), widget.plantId);
    cubit.load(photoId: selected);
  }

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  Future<void> perform(
    Future<PreparedCommand> Function() prepare,
    String title,
    String explanation,
  ) async {
    try {
      final preview = await prepare();
      if (!mounted) return;
      final result = await reviewCommand(
        context,
        preview,
        title: title,
        explanation: explanation,
      );
      if (result != null) await cubit.load(photoId: selected);
    } catch (e) {
      cubit.error(e);
    }
  }

  Future<void> replace(PlantPhoto photo, String source) async {
    setState(() {
      picking = true;
      localError = null;
    });
    try {
      await cubit.editor(photo);
      final selection = await MediaPlatformHostApi().choosePhoto(source);
      if (selection == null || !mounted) return;
      final date = await chooseDate(
        context,
        initial: cubit.repository.today,
        latest: cubit.repository.today,
        helpText: strings(context).photoObservationDate,
      );
      if (date != null) await cubit.attach(photo, selection, date);
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is PlatformException
              ? e.code
              : e is DomainException
              ? e.code
              : 'UNKNOWN_OUTCOME',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> export(PlantPhoto photo) async {
    if (exporting) return;
    final s = strings(context);
    setState(() {
      exporting = true;
      exportOutcome = null;
      exportError = null;
      exportedDate = photo.observedDate;
    });
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(s.exportOriginal),
          content: Text(s.originalMetadataWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.shareOriginal),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (yes != true) {
        setState(() => exportOutcome = 'cancelled');
        return;
      }
      final outcome = await MediaPlatformHostApi().exportPhoto(
        photo.id,
        photo.revision,
      );
      if (mounted) setState(() => exportOutcome = outcome);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          const rejected = {
            'MEDIA_MISSING',
            'MEDIA_INVALID',
            'STALE_TARGET',
            'NOT_FOUND',
            'DISK_FULL',
            'IO_FAILURE',
            'MEDIA_UNAVAILABLE',
            'STORAGE_UNAVAILABLE',
            'SESSION_INVALID',
          };
          exportOutcome = rejected.contains(e.code) ? 'failed' : 'unknown';
          exportError = rejected.contains(e.code) ? e.code : null;
        });
      }
    } catch (_) {
      // A lost reply cannot establish whether the OS received the original.
      if (mounted) setState(() => exportOutcome = 'unknown');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PhotoCubit, PhotoState>(
    bloc: cubit,
    builder: (context, state) {
      final s = strings(context),
          photo = state.photos.where((p) => p.id == selected).firstOrNull,
          busy = state.busy || picking || exporting;
      final exportFeedback = <Widget>[
        if (exportError != null) ErrorNotice(exportError!),
        if (exportOutcome != null || exporting)
          FigmaFormSection(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  '${s.exportOriginal} · ${exportedDate == null ? '' : dateLabel(context, exportedDate!)}\n${exporting ? s.originalExporting : switch (exportOutcome) {
                          'handedToOS' => s.originalHandedToOS,
                          'cancelled' => s.shareCancelled,
                          'failed' => s.shareFailed,
                          _ => s.originalExportUnknown,
                        }}',
                ),
              ),
            ],
          ),
      ];
      return Scaffold(
        appBar: AppPageBar(context: context, title: Text(s.photos)),
        body: SafeArea(
          child: ListView(
            padding: AppLayout.pagePadding,
            children: [
              AppScrollTitle(title: Text(s.photos)),
              SizedBox(
                height: 4,
                child: busy ? const LinearProgressIndicator() : null,
              ),
              if (localError ?? state.errorCode case final String error) ...[
                ErrorNotice(error),
                if (error == 'CAMERA_DENIED')
                  TextButton(
                    onPressed: () => MediaPlatformHostApi().openMediaSettings(),
                    child: Text(s.openSettings),
                  ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            if (photo != null && state.preparationId != null) {
                              await cubit.retry(photo);
                            } else {
                              await cubit.load(photoId: selected);
                            }
                            if (mounted) setState(() => localError = null);
                          } catch (e) {
                            cubit.error(e);
                          }
                        },
                  child: Text(s.retry),
                ),
              ],
              if (photo == null) ...exportFeedback,
              if (photo != null) ...[
                FigmaFormSection(
                  children: [
                    PhotoPreview(
                      photoId: photo.id,
                      revision: photo.revision,
                      height: 340,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dateLabel(context, photo.observedDate),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (state.coverId == photo.id) Text(s.coverPhoto),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FigmaPhotoAction(
                          onPressed: busy
                              ? null
                              : () async {
                                  await context.router.push(
                                    PlantEditorRoute(
                                      plantId: widget.plantId,
                                      coverPhotoId: photo.id,
                                    ),
                                  );
                                  await cubit.load(photoId: selected);
                                },
                          icon: const Icon(Icons.check),
                          label: Text(s.setCover),
                        ),
                        FigmaPhotoAction(
                          onPressed: busy
                              ? null
                              : () => openCard(
                                  context,
                                  widget.plantId,
                                  comparison: true,
                                ),
                          icon: const Icon(Icons.compare),
                          label: Text(s.comparePhotos),
                        ),
                        FigmaPhotoAction(
                          destructive: true,
                          onPressed: busy
                              ? null
                              : () => perform(
                                  () => cubit.repository.prepare(
                                    DeletePhoto(photo.id, photo.revision),
                                  ),
                                  s.deletePhoto,
                                  s.deletePhotoExplanation,
                                ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(s.deletePhoto),
                        ),
                        if (state.coverId == photo.id)
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    await context.router.push(
                                      PlantEditorRoute(
                                        plantId: widget.plantId,
                                        removeCover: true,
                                      ),
                                    );
                                    await cubit.load(photoId: selected);
                                  },
                            child: Text(s.removeCover),
                          ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final date = await chooseDate(
                                    context,
                                    initial: photo.observedDate,
                                    latest: cubit.repository.today,
                                    helpText: s.photoObservationDate,
                                  );
                                  if (date != null) {
                                    await perform(
                                      () => cubit.repository.prepare(
                                        UpdatePhotoObservation(
                                          photo.id,
                                          photo.revision,
                                          date,
                                        ),
                                      ),
                                      s.changePhotoDate,
                                      s.photoDateExplanation,
                                    );
                                  }
                                },
                          child: Text(s.changePhotoDate),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => export(photo),
                          icon: const Icon(Icons.ios_share),
                          label: Text(s.exportOriginal),
                        ),
                      ],
                    ),
                    ...exportFeedback,
                  ],
                ),
                FigmaFormSection(
                  children: [
                    Text(
                      s.replacePhoto,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(s.replacementExplanation),
                    if (state.replacement?.readyPhotoIds.isNotEmpty == true)
                      PhotoPreview(
                        photoId: state.replacement!.readyPhotoIds.single,
                      ),
                    if (state.replacement == null ||
                        (state.replacement!.readyPhotoIds.isEmpty &&
                            state.preparationKind != 'copying'))
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => replace(photo, 'camera'),
                            child: Text(s.camera),
                          ),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => replace(photo, 'library'),
                            child: Text(s.library),
                          ),
                        ],
                      ),
                    if (state.preparationKind == 'copying')
                      OutlinedButton(
                        onPressed: busy ? null : () => cubit.resolve(photo.id),
                        child: Text(s.checkAttachment),
                      ),
                    if (state.preparationKind == 'ready')
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => perform(
                                () => cubit.prepareReplacement(photo),
                                s.replacePhoto,
                                s.replacementExplanation,
                              ),
                        child: Text(s.reviewReplacement),
                      ),
                    if (state.replacement != null) ...[
                      if (state.replacement!.basePhotoRevision !=
                          photo.revision)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => perform(
                                  () => cubit.rebase(photo),
                                  s.reviewJournalConflict,
                                  s.rebasePhotoExplanation,
                                ),
                          child: Text(s.reviewJournalConflict),
                        ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.discardReplacement),
                                    content: Text(
                                      s.discardReplacementExplanation,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(s.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(s.discard),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true) {
                                  try {
                                    await cubit.discardReplacement();
                                  } catch (e) {
                                    cubit.error(e);
                                  }
                                }
                              },
                        child: Text(s.discardReplacement),
                      ),
                    ],
                  ],
                ),
              ],
              if (photo == null)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            openCard(context, widget.plantId, comparison: true),
                  icon: const Icon(Icons.compare),
                  label: Text(s.comparePhotos),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final chosen = await openOptimization(
                          context,
                          widget.plantId,
                        );
                        if (chosen != null && mounted) {
                          setState(() => selected = chosen);
                        }
                        await cubit.load(photoId: selected);
                      },
                icon: const Icon(Icons.photo_size_select_large),
                label: Text(s.optimizePhotos),
              ),
              const SizedBox(height: 24),
              if (state.photos.isEmpty) Text(s.photosEmpty),
              for (final item in state.photos)
                Card(
                  child: InkWell(
                    onTap: busy
                        ? null
                        : () {
                            setState(() => selected = item.id);
                            cubit.load(photoId: item.id);
                          },
                    child: ListTile(
                      selected: item.id == selected,
                      leading: SizedBox(
                        width: 56,
                        child: PhotoPreview(
                          photoId: item.id,
                          revision: item.revision,
                          height: 64,
                        ),
                      ),
                      title: Text(dateLabel(context, item.observedDate)),
                      subtitle: item.id == state.coverId
                          ? Text(s.coverPhoto)
                          : null,
                      trailing: item.id == selected
                          ? const Icon(Icons.check)
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
