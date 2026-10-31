import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/features/backup/data/backup_service.dart';
import 'package:verdi_mobile/features/backup/presentation/backup_cubit.dart';
import 'package:verdi_mobile/features/backup/presentation/backup_page.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';

Map<String, Object?> job(
  String phase, {
  String kind = 'import',
  Map<String, Object?> extra = const {},
}) => {
  'operationId': 'job',
  'operation': {
    'kind': kind,
    'state': {'kind': phase, ...extra},
  },
};

class FakeBackup implements BackupService {
  Map<String, Object?>? value;
  final calls = <String>[];
  String? selected;
  Object? confirmError;
  Completer<void>? gate;
  @override
  Future<Map<String, Object?>?> call(
    String method,
    Map<String, Object?> args,
  ) async {
    calls.add(method);
    if (gate != null) await gate!.future;
    if (method == 'confirmImport') {
      if (confirmError != null) throw confirmError!;
      value = job(
        'complete',
        extra: {'datasetId': 'new', 'counts': <String, Object?>{}},
      );
    }
    if (method == 'cancelBackup') value = job('cancelled');
    return value;
  }

  @override
  Future<String?> choose() async => selected;
  @override
  Future<String> share(Map<String, Object?> args) async {
    calls.add('share');
    return 'cancelled';
  }
}

void main() {
  test(
    'picker cancellation starts no import and repeated create is guarded',
    () async {
      final service = FakeBackup(),
          cubit = BackupCubit(
            FakeBackup(),
            datasetId: 'old',
            newId: () => 'id',
          );
      await cubit.choose();
      expect(cubit.state.operation, isNull);
      await cubit.close();
      service.gate = Completer<void>();
      final guarded = BackupCubit(service, datasetId: 'old', newId: () => 'id');
      final first = guarded.create();
      await guarded.create();
      expect(service.calls, ['startExport']);
      service.gate!.complete();
      await first;
      await guarded.close();
    },
  );
  test(
    'creating a file never shares and explicit sharing renews the handle',
    () async {
      final service = FakeBackup()
        ..value = job(
          'file_created',
          kind: 'export',
          extra: {'exportHandle': 'handle'},
        );
      final cubit = BackupCubit(service, datasetId: 'old', newId: () => 'id');
      await cubit.create();
      expect(service.calls, ['startExport']);
      await cubit.share();
      expect(service.calls, [
        'startExport',
        'renewExportHandle',
        'share',
        'backupStatus',
      ]);
      expect(cubit.state.shareResult, 'cancelled');
      await cubit.close();
    },
  );
  testWidgets(
    'large text preview requires confirmation; cancellation preserves old collection',
    (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeBackup()
        ..value = job(
          'preview_ready',
          extra: {
            'preview': {
              'counts': {
                'activePlants': 6,
                'archivedPlants': 1,
                'events': 8,
                'journalEntries': 2,
                'photos': 3,
              },
            },
          },
        );
      var reopened = 0;
      await tester.pumpWidget(
        BackupHost(
          datasetId: 'old',
          newId: () => 'id',
          reopen: (_) async {
            reopened++;
          },
          child: MaterialApp(
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: BackupPage(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final replace = find.text('Replace collection');
      await tester.scrollUntilVisible(replace, 300);
      await tester.tap(replace);
      await tester.pumpAndSettle();
      expect(find.text('Replace this collection?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(service.calls.contains('confirmImport'), isFalse);
      expect(reopened, 0);
      await tester.tap(replace);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Replace collection').last,
      );
      await tester.pumpAndSettle();
      expect(service.calls.where((c) => c == 'confirmImport').length, 1);
      expect(reopened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('failed switch offers reopening the retained collection', (
    tester,
  ) async {
    final service = FakeBackup()
      ..value = job(
        'failed',
        extra: {
          'code': 'IO_FAILURE',
          'recovery': 'open_recovery',
          'oldDatasetPreserved': true,
        },
      );
    bool? restored;
    await tester.pumpWidget(
      BackupHost(
        datasetId: 'old',
        newId: () => 'id',
        reopen: (value) async {
          restored = value;
        },
        child: MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: BackupPage(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry opening'), 250);
    await tester.tap(find.text('Retry opening'));
    await tester.pumpAndSettle();
    expect(restored, isFalse);
    expect(service.calls.contains('retryImport'), isFalse);
  });

  testWidgets(
    'restore notice mounts above router without requiring an overlay',
    (tester) async {
      await configureDependencies(environment: 'memory');
      await tester.pumpWidget(const VerdiApp(restored: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your backup was restored and the collection was reopened.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Your backup was restored and the collection was reopened.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await getIt.reset();
    },
  );
  test(
    'busy confirmation returns to review after authoritative preview status',
    () async {
      final service = FakeBackup()
        ..value = job('preview_ready', extra: {'preview': <String, Object?>{}})
        ..confirmError = PlatformException(code: 'BUSY');
      final cubit = BackupCubit(service, datasetId: 'old', newId: () => 'id');
      await cubit.load();
      await cubit.confirm();
      expect(cubit.state.error, 'BUSY');
      await cubit.poll();
      expect(cubit.state.phase, 'preview_ready');
      expect(cubit.state.replacing, isFalse);
      service.confirmError = null;
      await cubit.confirm();
      expect(cubit.state.phase, 'complete');
      await cubit.close();
    },
  );
}
