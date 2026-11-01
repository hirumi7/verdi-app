import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/cubits/plant_editor_cubit.dart';
import '../../../collection/presentation/widgets/presentation_helpers.dart';
import '../cubits/catalog_cubit.dart';

class SpeciesPicker extends StatefulWidget {
  final PlantEditorCubit editor;
  const SpeciesPicker({super.key, required this.editor});
  @override
  State<SpeciesPicker> createState() => _SpeciesPickerState();
}

class _SpeciesPickerState extends State<SpeciesPicker> {
  late final catalog = CatalogCubit(getIt<CollectionRepository>())..load();
  bool choosing = false;
  @override
  void dispose() {
    catalog.close();
    super.dispose();
  }

  Future<void> choose(CatalogEntry? entry) async {
    setState(() => choosing = true);
    try {
      if (entry == null) {
        await widget.editor.selectCustom(catalog.state.query);
      } else {
        await widget.editor.select(entry);
      }
    } catch (_) {
      /* Editor owns durable error and exact retry payload. */
    }
    if (mounted) setState(() => choosing = false);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CatalogCubit, CatalogView>(
    bloc: catalog,
    builder: (context, state) {
      final s = strings(context), data = state.catalog;
      final entries = data?.search(state.query) ?? <CatalogEntry>[];
      return ListView(
        key: const ValueKey('species-results'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (AppLayout.largeText(context))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppScrollTitle(title: Text(s.chooseSpecies)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: s.searchSpecies,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: catalog.query,
            ),
          ),
          if (state.loading || choosing) const LinearProgressIndicator(),
          if (widget.editor.state.errorCode != null)
            ErrorNotice(widget.editor.state.errorCode!),

          if (state.failed ||
              data?.available != true ||
              data?.limitation != null ||
              (normalizeCatalogName(state.query).isEmpty &&
                  data?.popularComplete != true))
            ListTile(
              title: Text(s.catalogLimited),
              subtitle: Text(s.catalogCustomAvailable),
              trailing: TextButton(
                onPressed: choosing ? null : () => catalog.load(retry: true),
                child: Text(s.retry),
              ),
            ),
          if (normalizeCatalogName(state.query).isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.popularSpecies,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          if (!state.loading &&
              entries.isEmpty &&
              state.query.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.noSpeciesMatches(state.query.trim())),
                  TextButton(
                    onPressed: choosing ? null : () => choose(null),
                    child: Text(s.createCustomQuery(state.query.trim())),
                  ),
                ],
              ),
            ),
          for (final entry in entries)
            ListTile(
              key: ValueKey('species-${entry.id}'),
              leading: const GenericPlantImage(size: 48),
              title: Text(entry.commonName),
              subtitle: Text(
                '${entry.scientificName}\n${s.difficulty}: ${entry.difficulty == 'unknown' ? s.unknown : entry.difficulty} · ${s.toxicity}: ${entry.toxicityLabel}${(entry.toxicity['animalScope'] as List).isEmpty ? '' : ' (${(entry.toxicity['animalScope'] as List).join(', ')})'}',
              ),
              onTap: choosing ? null : () => choose(entry),
              trailing: IconButton(
                tooltip: s.speciesInformation,
                icon: const Icon(Icons.info_outline),
                onPressed: choosing
                    ? null
                    : () => showSpeciesInformation(
                        context,
                        entry,
                        manifest: data?.manifest,
                      ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('choose-custom'),
                  onPressed: choosing ? null : () => choose(null),
                  icon: const Icon(Icons.add),
                  label: Text(s.customPlant),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class GenericPlantImage extends StatelessWidget {
  final double size;
  const GenericPlantImage({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/illustrations/empty-plants.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) =>
          Icon(Icons.local_florist_outlined, size: size),
    ),
  );
}

Future<void> showSpeciesInformation(
  BuildContext context,
  CatalogEntry entry, {
  Map<String, Object?>? manifest,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final s = strings(context);
    String light(String value) => switch (value) {
      'low' => s.lowLight,
      'medium' => s.mediumLight,
      'bright-indirect' => s.brightIndirect,
      'direct' => s.directLight,
      _ => s.unknown,
    };
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppPageBar(context: context, title: Text(s.speciesInformation)),
        body: ListView(
          padding: AppLayout.pagePadding,
          children: [
            AppScrollTitle(title: Text(s.speciesInformation)),
            const Center(child: GenericPlantImage()),
            Text(
              s.genericIllustration,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              entry.commonName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(entry.scientificName),
            if (entry.altNames.isNotEmpty) Text(entry.altNames.join(' · ')),
            const SizedBox(height: 20),
            Text('${s.category}: ${entry.data['category']}'),
            Text('${s.light}: ${light(entry.light)}'),
            Text(
              '${s.difficulty}: ${entry.difficulty == 'unknown' ? s.unknown : entry.difficulty}',
            ),
            Text(
              '${s.toxicity}: ${entry.toxicity['value'] == 'unknown' ? s.unknown : entry.toxicityLabel}',
            ),
            if ((entry.toxicity['animalScope'] as List).isNotEmpty)
              Text((entry.toxicity['animalScope'] as List).join(', ')),
            Text(entry.toxicity['qualification'] as String),
            const SizedBox(height: 20),
            Text(entry.careNotes),
            for (final suggestion in entry.selection.suggestions) ...[
              const SizedBox(height: 16),
              Text(
                '${kindLabel(s, suggestion.careKind)} · ${s.routineEvery(suggestion.interval.count, unitLabel(s, suggestion.interval.unit))}',
              ),
              Text(s.suggestionOnly),
              Text(suggestion.context),
              Text(suggestion.sourceLabel),
            ],
            const SizedBox(height: 24),
            Text(
              s.sourcesCredits,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final source in entry.sources) ...[
              Text(source['title'] as String),
              Text(source['publisherOrCreator'] as String),
              Text(source['locator'] as String),
              SelectableText(
                (source['publicUrl'] ?? source['retainedEvidenceRef'])
                    as String,
              ),
            ],
            Text(
              '${s.contentReviewed}: ${(entry.data['contentReview'] as Map)['reviewedAt']}',
            ),
            Text(
              (entry.data['textRightsReview'] as Map)['attributionText']
                  as String,
            ),
            for (final asset in (manifest?['assets'] as List? ?? const [])) ...[
              Text((asset['rightsReview'] as Map)['attributionText'] as String),
              for (final source in asset['provenance'] as List)
                Text('${source['title']} · ${source['locator']}'),
            ],
            Text(s.catalogCredits),
          ],
        ),
      ),
    );
  },
);
