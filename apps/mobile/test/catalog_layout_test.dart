import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';
import 'package:verdi_mobile/features/catalog/presentation/widgets/species_picker.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

void main() {
  testWidgets('catalog at320px 320percent keyboard', (tester) async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
    final repo = getIt<CollectionRepository>() as MemoryCollectionRepository;
    final m = jsonDecode(
      File('assets/catalog/manifest.json').readAsStringSync(),
    ) as Map;
    repo.coordinator.catalog = CatalogState(
      version: m['catalogVersion'],
      manifest: m.cast<String, Object?>(),
      popularIds: (m['popularIds'] as List).cast<String>(),
      entries:
          (jsonDecode(
            File('assets/catalog/entries.json').readAsStringSync(),
          ) as List).map(
            (e) => CatalogEntry(
              m['catalogVersion'],
              (e as Map).cast<String, Object?>(),
            ),
          ),
    );
    final editor = PlantEditorCubit(repo);
    await editor.load(null);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3.2)),
          child: child!,
        ),
        home: Scaffold(body: SpeciesPicker(editor: editor)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final info = find.byTooltip('Species information');
    await Scrollable.ensureVisible(tester.element(info), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await editor.close();
    await getIt.reset();
  });
}
