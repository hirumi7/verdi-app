import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/optimization/data/optimization_service.dart';
import 'package:verdi_mobile/features/optimization/presentation/cubits/optimization_cubit.dart';
import 'package:verdi_mobile/features/optimization/presentation/optimization_page.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

import '../packages/verdi_core/test/support/storage_scenario.dart';
import 'presentation_test.dart' show press;

class Repo implements CollectionRepository {
  final CollectionSnapshot snapshot;
  int sequence = 500;
  Future<Map<String, Object?>> Function(String)? preparation;
  Repo(this.snapshot);
  @override
  Future<CollectionSnapshot> mediaSnapshot() async => snapshot;
  @override
  String get datasetId => snapshot.datasetId;
  @override
  String newId() => fixtureId(sequence++);
  @override
  Future<Map<String, Object?>> photoPreparation(String id) => preparation!(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class Jobs implements OptimizationService {
  final Map<String, Map<String, Object?>> jobs = {};
  final List<Map<String, Object?>> finishes = [];
  final drafts = <String>[];
  Completer<void>? draftWait;
  String kind = 'failed', failure = 'MEDIA_UNSUPPORTED';
  bool lostStart = false, stopFails = false;
  int stopCalls = 0;
  Map<String, Object?>? latest;
  @override
  Future<void> saveDraft(SaveMediaDraft command, String commandId) async {
    drafts.add(commandId);
    if (draftWait != null) await draftWait!.future;
  }

  @override
  Future<Map<String, Object?>?> call(
    String op,
    Map<String, Object?> args,
  ) async {
    if (op == 'latestOptimizationJob') return latest;
    if (op == 'previewOptimization') {
      return {
        'previewToken': 'preview',
        'targets': (args['targets'] as List)
            .map(
              (t) => {
                ...(t as Map).cast<String, Object?>(),
                'observedDate': '2026-10-20',
                'width': 2400,
                'height': 1600,
                'byteCount': 6000,
              },
            )
            .toList(),
        'longEdge': 1280,
        'jpegQualityPercent': 85,
      };
    }
    if (op == 'startOptimization') {
      final id = args['jobId'] as String;
      final job = {
        'jobId': id,
        'plantId': 'plant',
        'state': 'running',
        'cancelAllowed': true,
        'results': [
          {
            'photoId': fixtureId(99),
            'photoRevision': 1,
            'draftId': 'draft-$id',
            'draftCommandId': 'draft-command-$id',
            'preparationId': 'prep-$id',
            'replaceCommandId': 'replace-$id',
            'state': 'pending',
            'code': null,
          },
        ],
      };
      // Valid UUIDs for actual SaveMediaDraft validation.
      (job['results'] as List).first['draftId'] = fixtureId(200 + jobs.length);
      (job['results'] as List).first['draftCommandId'] = fixtureId(
        300 + jobs.length,
      );
      jobs[id] = job;
      latest = job;
      if (lostStart) throw const RecoveryUnavailable();
      return job;
    }
    if (op == 'prepareOptimizationPhoto') {
      return {'kind': kind, 'code': failure, 'draftRevision': 1};
    }
    final job = jobs[args['jobId']]!;
    if (op == 'stopOptimization') {
      stopCalls++;
      if (stopFails) throw const RecoveryUnavailable();
      job['state'] = args['reason'];
      job['cancelAllowed'] = false;
      for (final target in job['results'] as List) {
        if (target['state'] == 'pending') target['state'] = 'not_attempted';
      }
      return job;
    }
    if (op == 'finishOptimizationTarget') {
      finishes.add(args);
      final target = (job['results'] as List).first as Map;
      target['state'] = 'failed';
      target['code'] = args['code'];
      job['state'] = 'complete';
      job['cancelAllowed'] = false;
      return job;
    }
    return job;
  }
}

void main() {
  late Repo repo;
  late Jobs service;
  late String plant;
  late StorageScenario data;
  setUp(() {
    data = StorageScenario();
    data.run(
      SaveDraft(
        draftId: fixtureId(3),
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: 'Optimization QA',
          speciesName: 'Synthetic fern',
        ),
      ),
    );
    data.run(SavePlant(draftId: fixtureId(3), draftRevision: 1));
    plant = data.projection.snapshot.plants.keys.single;
    data.rows['photos']!.add([
      fixtureId(99),
      plant,
      null,
      1,
      'media/${fixtureId(99)}/${'a' * 64}.jpg',
      'a' * 64,
      6000,
      'image/jpeg',
      2400,
      1600,
      '2026-10-20',
      'library',
      null,
      '2026-10-20T00:00:00.000Z',
    ]);
    data.projection.hydrate(
      data.rows,
      data.projection.snapshot.revision,
      data.projection.storageRevision + 1,
    );
    repo = Repo(data.projection.snapshot);
    service = Jobs();
  });
  Future<OptimizationCubit> ready() async {
    final c = OptimizationCubit(repo, service, plant);
    await c.load();
    c.select(fixtureId(99));
    expect(await c.preview(), true);
    return c;
  }

  test('nothing selected automatically; explicit confirmation handles known failure without retry', () async {
    final c = OptimizationCubit(repo, service, plant);
    await c.load();
    expect(c.state.selected, isEmpty);
    await c.start();
    expect(service.jobs, isEmpty);
    c.select(fixtureId(99));
    await c.preview();
    c.cancelPreview();
    expect(service.jobs, isEmpty);
    await c.preview();
    await c.start();
    expect(c.state.job?['state'], 'complete');
    expect(service.finishes.single['code'], 'MEDIA_UNSUPPORTED');
    expect(service.drafts.length, 1);
    expect(c.state.selected, isEmpty);
    await c.close();
  });
  test('lost start reply stops recorded job without running a child', () async {
    service.lostStart = true;
    final c = await ready();
    await c.start();
    expect(service.stopCalls, 1);
    expect(service.drafts, isEmpty);
    expect(c.state.job?['state'], 'interrupted');
    expect(c.state.recoveryRequired, false);
    await c.close();
  });
  test('unknown cancellation keeps blocking recovery until terminal acknowledgement', () async {
    service.stopFails = true;
    service.kind = 'copying';
    final wait = Completer<Map<String, Object?>>();
    repo.preparation = (_) => wait.future;
    final c = await ready();
    final run = c.start();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await c.cancel();
    expect(c.state.recoveryRequired, true);
    expect(c.state.running, true);
    await c.start();
    expect(service.jobs.length, 1);
    service.stopFails = false;
    await c.recover();
    expect(c.state.job?['state'], 'interrupted');
    expect(c.state.recoveryRequired, false);
    wait.complete({'kind': 'failed', 'code': 'IO_FAILURE'});
    await run;
    expect(service.finishes, isEmpty);
    await c.close();
  });
  test(
    'late old preparation cannot fail or abandon a new overlapping job',
    () async {
      service.kind = 'copying';
      final oldPoll = Completer<Map<String, Object?>>();
      repo.preparation = (_) => oldPoll.future;
      final c = await ready();
      final oldRun = c.start();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await c.cancel();
      final firstId = c.state.job!['jobId'];
      service.draftWait = Completer<void>();
      c.select(fixtureId(99));
      await c.preview();
      final newRun = c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.job!['jobId'], isNot(firstId));
      oldPoll.complete({'kind': 'failed', 'code': 'IO_FAILURE'});
      await oldRun;
      expect(service.finishes, isEmpty);
      expect(c.state.running, true);
      expect(c.state.job!['state'], 'running');
      await c.cancel();
      service.draftWait!.complete();
      await newRun;
      await c.close();
    },
  );
  testWidgets(
    'small screen large text selection and cancelled review stay usable',
    (t) async {
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.verdi_mobile.MediaPlatformHostApi.previewPhoto',
        StandardMessageCodec(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            channel,
            (_) async => [
              File('assets/illustrations/empty-plants.png').readAsBytesSync(),
            ],
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(channel, null),
      );
      t.view.physicalSize = const Size(375, 667);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
          home: OptimizationPage(
            plantId: plant,
            repository: repo,
            service: service,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(service.jobs, isEmpty);
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.byType(CheckboxListTile),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        t.element(find.byType(Checkbox)),
        alignment: .5,
      );
      await t.pump();
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();
      // Preview fake supplies the same native metadata used in the confirmation.
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(t.takeException(), isNull);
      await press(t, 'Review selected photos (1)');
      await press(t, 'Cancel');
      expect(service.jobs, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
}
