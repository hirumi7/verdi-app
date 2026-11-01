import 'presentation_test.dart' show seed;

import 'package:auto_route/auto_route.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/core/router/app_router.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/pages/today_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/features/reminders/data/reminder_service.dart';
import 'package:verdi_mobile/features/reminders/presentation/reminder_cubit.dart';
import 'package:verdi_mobile/features/reminders/presentation/reminder_page.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

class FakeReminders implements ReminderService {
  final events = StreamController<void>.broadcast();
  int revision = 1, saves = 0;
  bool fail = false, committed = false;
  Map<String, Object?>? tap;
  int acknowledgements = 0;
  Map<String, Object?>? firstRequest;
  Completer<Map<String, Object?>?>? heldTap;
  Map<String, Object?> values = {
    'enabled': false,
    'preferredMinute': 540,
    'quietStartMinute': 0,
    'quietEndMinute': 0,
  };
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<void> dispose() => events.close();
  @override
  Future<Map<String, Object?>?> call(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    switch (method) {
      case 'readState':
        return {
          'datasetId': 'dataset',
          'authorization': 'denied',
          'hasSavedSchedule': true,
          'settings': {
            'revision': revision,
            'reminders': {...values, 'settingsRevision': revision},
          },
          'lastReconcile': {
            'state': 'denied',
            'pendingConfirmed': 0,
            'omittedCapacity': 5,
            'pastCount': 2,
          },
        };
      case 'readTap':
        final hold = heldTap;
        heldTap = null;
        return hold == null ? tap : await hold.future;
      case 'acknowledgeTap':
        acknowledgements++;
        tap = null;
        return null;
      case 'reconcile':
        return {};
      case 'savePreferences':
        saves++;
        firstRequest ??= Map.of(args!);
        values = Map.of(args!['values']! as Map<String, Object?>);
        committed = true;
        revision++;
        if (fail) {
          fail = false;
          throw PlatformException(code: 'UNKNOWN_OUTCOME');
        }
        return {'committed': true};
      case 'resolvePreferences':
        expect(args, firstRequest);
        return {'committed': committed};
      default:
        return {};
    }
  }
}

class HangingReminderApi extends ReminderPlatformHostApi {
  @override
  Future<String> savePreferences(String request) => Completer<String>().future;
}

class CapturingReminderApi extends ReminderPlatformHostApi {
  final requests = <String>[];
  @override
  Future<String> savePreferences(String request) async {
    requests.add(request);
    return '{"committed":true}';
  }

  @override
  Future<String> resolvePreferences(String request) async {
    requests.add(request);
    return '{"committed":true}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lost native save reply has a bounded unknown-outcome deadline',
    () async {
      final service = NativeReminderService(
        api: HangingReminderApi(),
        deadline: const Duration(milliseconds: 5),
      );
      await expectLater(
        service.call('savePreferences', {}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'UNKNOWN_OUTCOME',
          ),
        ),
      );
      await service.dispose();
    },
  );
  test('save and resolution send identical recursively canonical bytes', () async {
    final api = CapturingReminderApi();
    final native = NativeReminderService(api: api);
    final values = <String, Object?>{
      'operationId': 'id',
      'datasetId': 'dataset',
      'expectedRevision': 1,
      'values': <String, Object?>{
        'quietStartMinute': 0,
        'preferredMinute': 540,
        'enabled': true,
        'quietEndMinute': 0,
      },
    };
    await native.call('savePreferences', values);
    await native.call('resolvePreferences', values);
    const expected =
        '{"datasetId":"dataset","expectedRevision":1,"operationId":"id","values":{"enabled":true,"preferredMinute":540,"quietEndMinute":0,"quietStartMinute":0}}';
    expect(api.requests, [expected, expected]);
    await native.dispose();
  });
  testWidgets(
    'current and stale taps render without overlay failure; a modal defers acknowledgement',
    (tester) async {
      await getIt.reset();
      await configureDependencies(environment: 'memory');
      final repository = getIt<CollectionRepository>(),
          service = FakeReminders()..tap = {'eventId': 'tap1', 'current': true};
      await tester.pumpWidget(
        VerdiApp(reminderService: service, reminderNewId: repository.newId),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.acknowledgements, 1);
      expect(
        find.text(
          'Review your current checks below. Opening a reminder does not record care.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminders').last);
      await tester.pumpAndSettle();
      service.tap = {'eventId': 'tap2', 'current': false};
      service.events.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPage), findsOneWidget);
      expect(service.acknowledgements, 1);
      expect(find.text('Open Today'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Today'));
      await tester.pumpAndSettle();
      expect(service.acknowledgements, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    },
  );
  testWidgets(
    'foreground tap keeps unflushed plant editor text and durable tap pending',
    (tester) async {
      await getIt.reset();
      await configureDependencies(environment: 'memory');
      final repository = getIt<CollectionRepository>(),
          service = FakeReminders();
      await tester.pumpWidget(
        VerdiApp(reminderService: service, reminderNewId: repository.newId),
      );
      await tester.pumpAndSettle();
      final router = AutoRouter.of(tester.element(find.byType(TodayPage)));
      unawaited(router.push(PlantEditorRoute()));
      await tester.pumpAndSettle();
      final custom = find.text('Add a custom plant');
      if (custom.evaluate().isNotEmpty) {
        await tester.tap(custom);
        await tester.pumpAndSettle();
      }
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Plant name',
      );
      await tester.enterText(name, 'Unflushed reminder draft');
      service.tap = {'eventId': 'editor-tap', 'current': true};
      service.events.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(name, findsOneWidget);
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Unflushed reminder draft',
      );
      expect(service.acknowledgements, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    },
  );
  testWidgets(
    'hidden Today editor survives notification while Settings is active',
    (tester) async {
      await getIt.reset();
      await configureDependencies(environment: 'memory');
      final repository = getIt<CollectionRepository>(),
          service = FakeReminders();
      await tester.pumpWidget(
        VerdiApp(reminderService: service, reminderNewId: repository.newId),
      );
      await tester.pumpAndSettle();
      final router = AutoRouter.of(tester.element(find.byType(TodayPage)));
      unawaited(router.push(PlantEditorRoute()));
      await tester.pumpAndSettle();
      final custom = find.text('Add a custom plant');
      if (custom.evaluate().isNotEmpty) {
        await tester.tap(custom);
        await tester.pumpAndSettle();
      }
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Plant name',
      );
      await tester.enterText(name, 'Unflushed reminder draft');
      final tabs = AutoTabsRouter.of(tester.element(name));
      tabs.setActiveIndex(2);
      await tester.pump();
      service.tap = {'eventId': 'editor-tap', 'current': true};
      service.events.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(name, findsNothing);
      expect(service.acknowledgements, 0);
      tabs.setActiveIndex(0);
      await tester.pump();
      expect(name, findsOneWidget);
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Unflushed reminder draft',
      );
      expect(service.acknowledgements, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    },
  );
  testWidgets('notification preserves unflushed journal note', (tester) async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
    final repository = getIt<CollectionRepository>(), service = FakeReminders();
    await seed(repository, 'Reminder journal plant');
    final plant = (await repository.mediaSnapshot()).plants.values.single;
    await tester.pumpWidget(
      VerdiApp(reminderService: service, reminderNewId: repository.newId),
    );
    await tester.pumpAndSettle();
    final router = AutoRouter.of(tester.element(find.byType(TodayPage)));
    unawaited(router.push(JournalEditorRoute(plantId: plant.id)));
    await tester.pumpAndSettle();
    final note = find.byWidgetPredicate(
      (w) => w is TextField && w.maxLines != 1,
    );
    await tester.enterText(note, 'Unsaved journal reminder text');
    service.tap = {'eventId': 'journal-tap', 'current': true};
    service.events.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      tester.widget<TextField>(note).controller!.text,
      'Unsaved journal reminder text',
    );
    expect(service.acknowledgements, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await getIt.reset();
  });
  test('ambiguous saved preferences retain original request and resolve without duplicate save', () async {
    final service = FakeReminders()..fail = true;
    var ids = 0;
    final cubit = ReminderCubit(service, () => 'id${++ids}');
    await cubit.refresh();
    cubit.edit('enabled', true);
    await cubit.save();
    expect(cubit.state.unresolved, true);
    cubit.edit('preferredMinute', 600);
    expect(cubit.state.draft['preferredMinute'], 540);
    await cubit.save();
    expect(cubit.state.unresolved, false);
    expect(cubit.state.saved, true);
    expect(service.saves, 1);
    expect(ids, 1);
    await cubit.close();
  });
  test('old in-flight refresh cannot overwrite committed settings or lose queued reload', () async {
    final service = FakeReminders();
    final cubit = ReminderCubit(service, () => 'id');
    await cubit.refresh();
    final held = Completer<Map<String, Object?>?>();
    service.heldTap = held;
    final old = cubit.refresh();
    await Future<void>.delayed(Duration.zero);
    cubit.edit('preferredMinute', 600);
    await cubit.save();
    held.complete(null);
    await old;
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.draft['preferredMinute'], 600);
    expect(cubit.state.data?['settings'], containsPair('revision', 2));
    await cubit.close();
  });
  testWidgets(
    'reminder settings remain scrollable and usable at 320px and 320% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = ReminderCubit(FakeReminders(), () => 'id');
      await cubit.refresh();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
          home: ReminderHost(cubit: cubit, child: const ReminderPage()),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Save reminder settings'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await Scrollable.ensureVisible(
        tester.element(find.text('Save reminder settings')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save reminder settings'));
      await tester.pumpAndSettle();
      expect(cubit.state.saved, true);
      await tester.scrollUntilVisible(
        find.text('Retry scheduling'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
}
