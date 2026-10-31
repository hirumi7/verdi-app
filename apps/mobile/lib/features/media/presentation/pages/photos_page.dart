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
  String? selected, localError;
  bool picking = false;
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
    final s = strings(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    if (yes != true) return;
    try {
      final outcome = await MediaPlatformHostApi().exportPhoto(
        photo.id,
        photo.revision,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == 'handedToOS'
                  ? s.originalHandedToOS
                  : outcome == 'cancelled'
                  ? s.shareCancelled
                  : s.shareFailed,
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => localError = e.code);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PhotoCubit, PhotoState>(
    bloc: cubit,
    builder: (context, state) {
      final s = strings(context),
          photo = state.photos.where((p) => p.id == selected).firstOrNull,
          busy = state.busy || picking;
      return Scaffold(
        appBar: AppBar(title: Text(s.photos)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
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
              if (photo != null) ...[
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
                    OutlinedButton.icon(
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
                    OutlinedButton.icon(
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
                  ],
                ),
                const Divider(height: 32),
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
                        onPressed: busy ? null : () => replace(photo, 'camera'),
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
                  if (state.replacement!.basePhotoRevision != photo.revision)
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
                                content: Text(s.discardReplacementExplanation),
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
                const Divider(height: 32),
              ],
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          PhotoPreview(
                            photoId: item.id,
                            revision: item.revision,
                            height: 120,
                          ),
                          Text(dateLabel(context, item.observedDate)),
                          if (item.id == state.coverId) Text(s.coverPhoto),
                        ],
                      ),
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
