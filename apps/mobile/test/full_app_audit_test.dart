import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/widgets/schedule_audit.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

import 'package:verdi_mobile/features/collection/presentation/widgets/presentation_helpers.dart'
    show chooseInterval;

import 'presentation_test.dart' show seed, press;

class AuditRepository implements CollectionRepository {
  AuditRepository(this.delegate);
  final CollectionRepository delegate;
  bool fail = false;
  int reads = 0;
  @override
  Future<CollectionSnapshot> mediaSnapshot() async {
    reads++;
    if (fail) throw DomainException('STORAGE_UNAVAILABLE');
    return delegate.mediaSnapshot();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(getIt.reset);
  testWidgets(
    'search survives archive and delete, and explicit clear restores empty collection',
    (t) async {
      final repo = getIt<CollectionRepository>();
      await seed(repo, 'Fern');
      await t.pumpWidget(const VerdiApp());
      await t.pumpAndSettle();
      await press(t, 'Plants');
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search plants',
      );
      await t.enterText(search, '  Fern  ');
      await t.pumpAndSettle();
      await press(t, 'Fern');
      await press(t, 'Archive plant');
      await press(t, 'Confirm');
      expect(t.widget<TextField>(search).controller!.text, '  Fern  ');
      await press(t, 'Archived');
      await press(t, 'Fern');
      await press(t, 'Delete forever');
      await press(t, 'Confirm');
      expect(t.widget<TextField>(search).controller!.text, '  Fern  ');
      expect((await repo.mediaSnapshot()).plants, isEmpty);
      await t.tap(find.byTooltip('Clear search'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(search).controller!.text, '');
      expect(find.text('No archived plants'), findsOneWidget);
      await press(t, 'Active');
      expect(find.text('No plants yet'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'fresh schedule audit retries and scrolls without mutation ${brightness.name}',
      (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 3.2;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearAllTestValues();
        });
        final repo = getIt<CollectionRepository>();
        await seed(repo, 'Fern');
        final plant = (await repo.mediaSnapshot()).plants.values.single;
        final routine = (await repo.detail(plant.id)).routines.single;
        await repo.confirm(
          await repo.prepare(
            SetInterval(routine.target, CareInterval(10, IntervalUnit.day)),
          ),
        );
        final snapshot = await repo.mediaSnapshot();
        final change = snapshot.scheduleChanges.values.single;
        final audit = AuditRepository(repo)..fail = true;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(brightness),
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showScheduleAudit(
                    context,
                    repository: audit,
                    datasetId: snapshot.datasetId,
                    plantId: plant.id,
                    changeId: change.id,
                  ),
                  child: const Text('Audit'),
                ),
              ),
            ),
          ),
        );
        await press(t, 'Audit');
        expect(audit.reads, 1);
        audit.fail = false;
        await press(t, 'Retry');
        expect(audit.reads, 2);
        expect(find.text('Interval changed'), findsOneWidget);
        await press(t, 'After');
        expect(find.textContaining('10 days'), findsWidgets);
        await press(t, 'Close');
        expect((await repo.mediaSnapshot()).revision, snapshot.revision);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('schedule audit refuses a stale dataset', (t) async {
    final repo = getIt<CollectionRepository>();
    await seed(repo, 'Fern');
    final snapshot = await repo.mediaSnapshot();
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScheduleAudit(
                context,
                repository: repo,
                datasetId: 'old-dataset',
                plantId: snapshot.plants.keys.single,
                changeId: 'missing',
              ),
              child: const Text('Audit'),
            ),
          ),
        ),
      ),
    );
    await press(t, 'Audit');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Before'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect((await repo.mediaSnapshot()).revision, snapshot.revision);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('interval input and focus survive keyboard opening and closing', (
    t,
  ) async {
    addTearDown(t.view.resetViewInsets);
    CareInterval? result;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await chooseInterval(
                  context,
                  CareInterval(7, IntervalUnit.day),
                );
              },
              child: const Text('Interval'),
            ),
          ),
        ),
      ),
    );
    await press(t, 'Interval');
    await t.enterText(find.byType(TextFormField), '123');
    await t.pump();
    final initial = t.widget<EditableText>(find.byType(EditableText));
    final focus = initial.focusNode;
    for (final inset in [260.0, 0.0, 260.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: inset);
      await t.pumpAndSettle();
      final field = t.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '123');
      expect(field.focusNode, same(focus));
      expect(field.focusNode.hasFocus, true);
      expect(t.takeException(), isNull);
    }
    await press(t, 'Continue');
    expect(result!.count, 123);
    expect(result!.unit, IntervalUnit.day);
    await t.pumpWidget(const SizedBox());
  });
}
