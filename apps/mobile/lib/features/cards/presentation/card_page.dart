import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../collection/data/repositories/collection_repository.dart';
import '../../collection/presentation/widgets/presentation_helpers.dart';
import '../../media/presentation/widgets/photo_preview.dart';
import '../../pro/presentation/pro_page.dart';
import '../data/card_service.dart';
import 'cubits/card_cubit.dart';

Future<void> openCard(
  BuildContext context,
  String plantId, {
  bool comparison = false,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    builder: (_) => CardPage(plantId: plantId, comparison: comparison),
  ),
);

class CardPage extends StatefulWidget {
  final String plantId;
  final bool comparison;
  final CardService? service;
  final CollectionRepository? repository;
  const CardPage({
    super.key,
    required this.plantId,
    this.comparison = false,
    this.service,
    this.repository,
  });
  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  final scroll = ScrollController();
  late final cubit = CardCubit(
    widget.repository ?? getIt<CollectionRepository>(),
    widget.service ?? NativeCardService(),
    widget.plantId,
    comparison: widget.comparison,
  );
  @override
  void initState() {
    super.initState();
    cubit.load();
  }

  @override
  void dispose() {
    scroll.dispose();
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CardCubit, CardState>(
    bloc: cubit,
    builder: (context, state) {
      final s = strings(context);
      final error = switch (state.error) {
        'CARD_EXPIRED' || 'PREVIEW_STALE' => s.cardRefreshRequired,
        'DATASET_CHANGED' ||
        'STALE_TARGET' ||
        'NOT_FOUND' => s.cardReselectRequired,
        'MEDIA_MISSING' || 'MEDIA_INVALID' => s.cardMediaUnavailable,
        'PRO_REQUIRED' => s.cardProRequired,
        'PHOTO_SAVE_DENIED' => s.cardPermissionDenied,
        'PHOTO_SAVE_UNKNOWN' => s.cardSaveUnknown,
        'PHOTO_SAVE_FAILED' => s.cardSaveFailed,
        null => null,
        _ => s.cardFailed,
      };
      final outcome = switch (state.outcome) {
        'saved' => s.cardSaved,
        'handedToOS' => s.cardHandedToOS,
        'cancelled' => s.cardCancelled,
        _ => null,
      };
      final feedback = <Widget>[
        if (error != null) Semantics(liveRegion: true, child: Text(error)),
        if (outcome != null) Semantics(liveRegion: true, child: Text(outcome)),
        if (state.error == 'PRO_REQUIRED')
          OutlinedButton(
            onPressed: state.busy
                ? null
                : () async {
                    await openPro(context);
                  },
            child: Text(s.cardViewPro),
          ),
        if ([
          'DATASET_CHANGED',
          'STALE_TARGET',
          'NOT_FOUND',
          'MEDIA_MISSING',
          'MEDIA_INVALID',
        ].contains(state.error))
          OutlinedButton(
            onPressed: state.busy ? null : cubit.load,
            child: Text(s.cardReload),
          ),
      ];
      return Scaffold(
        appBar: AppPageBar(
          context: context,
          title: Text(widget.comparison ? s.comparePhotos : s.sharePlantCard),
        ),
        body: SafeArea(
          child: ListView(
            controller: scroll,
            padding: AppLayout.pagePadding,
            children: [
              AppScrollTitle(
                title: Text(
                  widget.comparison ? s.comparePhotos : s.sharePlantCard,
                ),
              ),
              if (state.busy) const LinearProgressIndicator(),
              if (state.bytes == null) ...feedback,
              if (state.bytes != null)
                FigmaFormSection(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      state.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(state.species),
                    for (final date in state.dates) Text(date),
                    const SizedBox(height: 12),
                    Image.memory(
                      state.bytes!,
                      excludeFromSemantics: true,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => cubit.handoff(save: true),
                          icon: const Icon(Icons.save_alt),
                          label: Text(s.cardSave),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => cubit.handoff(save: false),
                          icon: const Icon(Icons.ios_share),
                          label: Text(s.cardShare),
                        ),
                      ],
                    ),
                    ...feedback,
                  ],
                ),
              Text(s.cardPrivacy),
              const SizedBox(height: 16),
              if (widget.comparison) ...[
                Text(s.cardChooseTwo),
                if (state.photos.length < 2) Text(s.cardNeedsTwo),
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
                          value: state.selected.contains(photo.id),
                          onChanged: state.busy
                              ? null
                              : (_) => cubit.select(photo.id),
                          title: Text(dateLabel(context, photo.observedDate)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                FigmaSection(
                  child: FigmaGroup(
                    children: [
                      SwitchListTile(
                        value: state.imageChoice == 'illustration',
                        onChanged: state.busy || !state.hasCover
                            ? null
                            : (value) => cubit.imageChoice(
                                value ? 'illustration' : 'cover',
                              ),
                        title: Text(s.cardUseIllustration),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    state.busy ||
                        (widget.comparison && state.selected.length != 2)
                    ? null
                    : () async {
                        await cubit.prepare();
                        if (mounted &&
                            cubit.state.bytes != null &&
                            scroll.hasClients) {
                          scroll.jumpTo(0);
                        }
                      },
                child: Text(
                  state.token == null ? s.cardPreview : s.cardRefresh,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
