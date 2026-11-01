import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_mobile/features/cards/presentation/card_page.dart';
import 'package:verdi_mobile/features/cards/presentation/cubits/card_cubit.dart';

import 'card_test.dart' show FakeCards;

import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/media/presentation/pages/photos_page.dart';
import 'package:verdi_mobile/features/reminders/presentation/reminder_cubit.dart';
import 'package:verdi_mobile/features/reminders/presentation/reminder_page.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

import 'photo_recovery_test.dart' show MediaScenarioRepository;
import 'presentation_test.dart' show press;
import 'reminder_test.dart' show FakeReminders;

const previewChannel = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.verdi_mobile.MediaPlatformHostApi.previewPhoto',
  StandardMessageCodec(),
);
const exportChannel = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.verdi_mobile.MediaPlatformHostApi.exportPhoto',
  StandardMessageCodec(),
);

Widget app(Widget home, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: AppTheme.build(brightness),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MediaScenarioRepository repository;
  setUp(() async {
    await getIt.reset();
    repository = MediaScenarioRepository();
    getIt.registerSingleton<CollectionRepository>(repository);
    messenger.setMockDecodedMessageHandler<Object?>(
      previewChannel,
      (_) async => [
        File('assets/illustrations/empty-plants.png').readAsBytesSync(),
      ],
    );
  });
  tearDown(() async {
    messenger.setMockDecodedMessageHandler<Object?>(previewChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(exportChannel, null);
    await getIt.reset();
  });

  for (final outcome in [
    'cancelled',
    'failed',
    'handedToOS',
    'channel-error',
    'MEDIA_MISSING',
    'DISK_FULL',
  ]) {
    testWidgets(
      'original export keeps $outcome visible and serializes handoffs',
      (t) async {
        if (outcome == 'MEDIA_MISSING' || outcome == 'DISK_FULL') {
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 3.2;
          addTearDown(() {
            t.view.reset();
            t.platformDispatcher.clearAllTestValues();
          });
        }
        final reply = Completer<Object?>();
        var calls = 0;
        messenger.setMockDecodedMessageHandler<Object?>(exportChannel, (_) {
          calls++;
          return reply.future;
        });
        await t.pumpWidget(
          app(
            PhotosPage(plantId: repository.plant, photoId: repository.photo),
            brightness: outcome == 'DISK_FULL'
                ? Brightness.dark
                : Brightness.light,
          ),
        );
        await t.pumpAndSettle();
        final export = find.widgetWithText(OutlinedButton, 'Export original');
        if (export.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            export,
            250,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await t.ensureVisible(export);
        await t.pumpAndSettle();
        final invoke = t.widget<OutlinedButton>(export).onPressed!;
        invoke();
        invoke(); // Same-turn taps must not create two confirmation routes.
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.widgetWithText(FilledButton, 'Share original'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(calls, 1);
        invoke();
        expect(calls, 1);
        reply.complete(
          outcome == 'channel-error' ||
                  outcome == 'MEDIA_MISSING' ||
                  outcome == 'DISK_FULL'
              ? [outcome, null, null]
              : [outcome],
        );
        await t.pumpAndSettle();
        final message = switch (outcome) {
          'cancelled' => 'Sharing cancelled.',
          'failed' ||
          'MEDIA_MISSING' ||
          'DISK_FULL' => 'The original could not be shared.',
          'handedToOS' => 'Original handed to the selected app.',
          _ => 'The sharing result is uncertain.',
        };
        final status = find.textContaining(message);
        expect(
          status,
          findsOneWidget,
        ); // Mounted at completion, before any scroll.
        expect(
          find.ancestor(
            of: status,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
          ),
          findsOneWidget,
        );
        await t.scrollUntilVisible(
          status,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pump(const Duration(seconds: 15));
        expect(status, findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(calls, 1);
        expect(t.takeException(), isNull);
        if (outcome == 'MEDIA_MISSING' || outcome == 'DISK_FULL') {
          expect(
            find.textContaining('The sharing result is uncertain.'),
            findsNothing,
          );
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'late original export reply after disposal cannot update or retry',
    (t) async {
      final reply = Completer<Object?>();
      var calls = 0;
      messenger.setMockDecodedMessageHandler<Object?>(exportChannel, (_) {
        calls++;
        return reply.future;
      });
      await t.pumpWidget(
        app(PhotosPage(plantId: repository.plant, photoId: repository.photo)),
      );
      await t.pumpAndSettle();
      await press(t, 'Export original');
      await t.tap(find.widgetWithText(FilledButton, 'Share original'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox());
      reply.complete(['handedToOS']);
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison handoff feedback stays mounted before a long photo inventory',
    (t) async {
      final rows = repository.scenario.rows;
      for (var i = 0; i < 30; i++) {
        final row = [...rows['photos']!.first];
        row[0] = '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
        rows['photos']!.add(row);
      }
      final projection = repository.scenario.projection;
      projection.hydrate(
        rows,
        projection.snapshot.revision,
        projection.storageRevision + 1,
      );
      final api = FakeCards();
      await t.pumpWidget(
        app(
          CardPage(
            plantId: repository.plant,
            repository: repository,
            service: api,
            comparison: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      final builder = t.widget<BlocBuilder<CardCubit, CardState>>(
        find.byType(BlocBuilder<CardCubit, CardState>),
      );
      final cubit = builder.bloc!;
      cubit.select(cubit.state.photos[0].id);
      cubit.select(cubit.state.photos[1].id);
      await t.pumpAndSettle();
      await press(t, 'Preview card');
      api.lostSaveReply = true;
      await press(t, 'Save image');
      expect(
        find.textContaining('The save result is uncertain'),
        findsOneWidget,
      );
      api.lostSaveReply = false;
      api.result = {'outcome': 'saved', 'code': null};
      await press(t, 'Save image');
      expect(find.textContaining('Image saved'), findsOneWidget);
      expect(api.handoffs, 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'reminder groups retain explicit save at 320px large ${brightness.name}',
      (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 3.2;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearAllTestValues();
        });
        final service = FakeReminders();
        final cubit = ReminderCubit(service, repository.newId);
        await cubit.refresh();
        await t.pumpWidget(
          app(
            ReminderHost(cubit: cubit, child: const ReminderPage()),
            brightness: brightness,
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byType(SwitchListTile));
        await t.pumpAndSettle();
        expect(service.saves, 0);
        expect(cubit.state.draft['enabled'], true);
        await press(t, 'Save reminder settings');
        expect(service.saves, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await cubit.close();
      },
    );
  }
}
