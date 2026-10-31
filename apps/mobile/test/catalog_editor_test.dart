import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';

import 'presentation_test.dart' show press, field;

import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/catalog/presentation/cubits/catalog_cubit.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

CatalogState bundle() {
  final m = (jsonDecode(
    File('assets/catalog/manifest.json').readAsStringSync(),
  ) as Map).cast<String, Object?>();
  return CatalogState(
    version: m['catalogVersion'] as String,
    manifest: m,
    popularIds: (m['popularIds'] as List).cast<String>(),
    entries:
        (jsonDecode(
          File('assets/catalog/entries.json').readAsStringSync(),
        ) as List).map(
          (e) => CatalogEntry(m['catalogVersion'] as String, (e as Map).cast()),
        ),
  );
}

class DelayedCatalog extends MemoryCollectionRepository {
  final requests = <Completer<CatalogState>>[];
  @override
  Future<CatalogState> catalog({bool retry = false}) {
    final c = Completer<CatalogState>();
    requests.add(c);
    return c.future;
  }
}

class FailDraftOnce extends MemoryCollectionRepository {
  bool fail = true;
  @override
  Future<CommandSuccess> submit(CoreCommand c) {
    if (c is SaveDraft && fail) {
      fail = false;
      throw CommandRejected('BUSY');
    }
    return super.submit(c);
  }
}

void main() {
  testWidgets(
    'search, info return, new query and custom prefill preserve the editor',
    (tester) async {
      await getIt.reset();
      await configureDependencies(environment: 'memory');
      final r = getIt<CollectionRepository>() as MemoryCollectionRepository;
      r.coordinator.catalog = bundle();
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Add a plant');
      await tester.enterText(field('Search species'), 'SWISS');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Species information').first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(field('Search species'), 'pothos');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Golden pothos'), findsOneWidget);
      await tester.enterText(field('Search species'), 'My mystery fern');
      await tester.pumpAndSettle();
      expect(find.text('No matches for “My mystery fern”'), findsOneWidget);
      await press(tester, 'Create “My mystery fern” as a custom plant');
      expect(
        (await r.editor(null)).draft!.fields.speciesName,
        'My mystery fern',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await getIt.reset();
    },
  );
  test(
    'older catalog response cannot replace latest results or query',
    () async {
      final repository = DelayedCatalog();
      final c = CatalogCubit(repository);
      final first = c.load();
      c.query('swiss');
      final second = c.load(retry: true);
      repository.requests[1].complete(bundle());
      await second;
      repository.requests[0].complete(CatalogState());
      await first;
      expect(c.state.catalog!.available, isTrue);
      expect(c.state.query, 'swiss');
      await c.close();
    },
  );
  test('selection does not leave picker before acknowledged draft; retry preserves fields', () async {
    final r = FailDraftOnce();
    r.coordinator.catalog = bundle();
    final c = PlantEditorCubit(r);
    await c.load(null);
    expect(c.state.picking, isTrue);
    c.update(name: 'Kept name', notes: 'Kept notes');
    await expectLater(
      c.select(r.coordinator.catalog.entry('sp_epipremnum_aureum')!),
      throwsA(isA<CommandRejected>()),
    );
    expect(c.state.picking, isTrue);
    expect(c.state.fields!.name, 'Kept name');
    expect((await r.editor(null)).draft, isNull);
    await c.select(r.coordinator.catalog.entry('sp_epipremnum_aureum')!);
    expect(c.state.picking, isFalse);
    expect((await r.editor(null)).draft!.fields.notes, 'Kept notes');
    await c.close();
    final recovered = PlantEditorCubit(r);
    await recovered.load(null);
    expect(recovered.state.picking, isFalse);
    expect(
      recovered.state.fields!.catalogSelection!.speciesId,
      'sp_epipremnum_aureum',
    );
    await recovered.close();
  });
  test('stale selection preserves custom draft and requires review', () async {
    final r = MemoryCollectionRepository(), catalog = bundle();
    r.coordinator.catalog = catalog;
    final c = PlantEditorCubit(r);
    await c.load(null);
    c.update(name: 'Keep', species: 'Custom');
    await c.flush();
    r.coordinator.catalog = CatalogState();
    await expectLater(
      c.select(catalog.entries.first),
      throwsA(isA<CommandRejected>()),
    );
    expect(c.state.fields!.speciesName, 'Custom');
    expect(c.state.fields!.catalogSelection, isNull);
    await c.close();
  });
}
