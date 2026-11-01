import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/cards/data/card_service.dart';
import 'package:verdi_mobile/features/cards/presentation/card_page.dart';
import 'package:verdi_mobile/features/cards/presentation/cubits/card_cubit.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

import 'presentation_test.dart' show seed, press;

class FakeCards implements CardService {
  int prepared = 0, handoffs = 0;
  final released = <String>[];
  Completer<Map<String, Object?>>? pending;
  String? failure;
  bool lostSaveReply = false;
  Map<String, Object?> result = {'outcome': 'cancelled', 'code': null};
  final image = File('assets/illustrations/empty-plants.png').readAsBytesSync();
  @override
  Future<Map<String, Object?>> prepare(Map<String, Object?> request) async {
    prepared++;
    if (failure != null) throw PlatformException(code: failure!);
    return pending?.future ??
        Future.value({
          'token': 'token-$prepared',
          'plantName': 'Fern',
          'speciesName': 'Synthetic fern',
          'dates': <String>[],
        });
  }

  @override
  Future<Uint8List> read(String token) async => image;
  @override
  Future<void> release(String token) async {
    released.add(token);
  }

  @override
  Future<Map<String, Object?>> handoff(
    String token, {
    required bool save,
  }) async {
    handoffs++;
    if (save && lostSaveReply) throw PlatformException(code: 'channel-error');
    return result;
  }
}

class UnresponsiveCardHost extends CardPlatformHostApi {
  int calls = 0;
  final completion = Completer<String>();
  @override
  Future<String> saveCard(String token) {
    calls++;
    return completion.future;
  }
}

void main() {
  late CollectionRepository repo;
  late String plant;
  late FakeCards api;
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
    repo = getIt<CollectionRepository>();
    await seed(repo, 'Fern');
    plant = (await repo.mediaSnapshot()).plants.keys.single;
    api = FakeCards();
  });
  tearDown(() => getIt.reset());
  Widget app({bool comparison = false}) => MaterialApp(
    theme: AppTheme.build(Brightness.light),
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: CardPage(
      plantId: plant,
      repository: repo,
      service: api,
      comparison: comparison,
    ),
  );
  testWidgets(
    'preview is explicit, denied save preserves bytes, cancelled share reports only cancellation',
    (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(api.prepared, 0);
      expect(api.handoffs, 0);
      await press(t, 'Preview card');
      expect(api.prepared, 1);
      expect(api.handoffs, 0);
      api.result = {'outcome': 'failed', 'code': 'PHOTO_SAVE_DENIED'};
      await press(t, 'Save image');
      expect(find.textContaining('Photos access was denied'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      api.result = {'outcome': 'cancelled', 'code': null};
      await press(t, 'Share');
      expect(find.textContaining('Sharing cancelled'), findsOneWidget);
      expect(api.handoffs, 2);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(api.released, ['token-1']);
    },
  );
  testWidgets(
    'comparison with fewer than two explains missing input and never generates',
    (t) async {
      await t.pumpWidget(app(comparison: true));
      await t.pumpAndSettle();
      expect(find.textContaining('Add at least two photos'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(api.prepared, 0);
    },
  );
  testWidgets(
    'small screen 320 percent card preview and actions remain scrollable',
    (t) async {
      t.view.physicalSize = const Size(375, 667);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(() {
        t.view.reset();
        t.platformDispatcher.clearAllTestValues();
      });
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await press(t, 'Preview card');
      await press(t, 'Share');
      expect(t.takeException(), isNull);
      expect(api.handoffs, 1);
    },
  );
  test(
    'closing while preparing releases delayed token and never hands off',
    () async {
      final c = CardCubit(repo, api, plant);
      await c.load();
      api.pending = Completer();
      final loading = c.prepare();
      await Future<void>.delayed(Duration.zero);
      await c.close();
      api.pending!.complete({
        'token': 'late',
        'plantName': 'Fern',
        'speciesName': 'Fern',
        'dates': <String>[],
      });
      await loading;
      expect(api.released, ['late']);
      expect(api.handoffs, 0);
    },
  );
  test('comparison selection requires two and preserves selection through optional Pro gate', () async {
    final c = CardCubit(repo, api, plant, comparison: true);
    await c.load();
    PlantPhoto photo(String id) => PlantPhoto(
      id,
      plant,
      null,
      1,
      'test',
      'hash',
      1,
      'image/png',
      1,
      1,
      LocalDate.parse('2026-10-20'),
      'library',
      null,
      DateTime.utc(2026),
    );
    c.emit(
      c.state.copyWith(photos: [photo('one'), photo('two'), photo('three')]),
    );
    c.select('one');
    await c.prepare();
    expect(api.prepared, 0);
    c.select('two');
    c.select('three');
    expect(c.state.selected, ['one', 'two']);
    api.failure = 'PRO_REQUIRED';
    await c.prepare();
    expect(c.state.error, 'PRO_REQUIRED');
    expect(c.state.selected, ['one', 'two']);
    expect(api.handoffs, 0);
    api.failure = null;
    expect(api.prepared, 1);
    await c.prepare();
    expect(api.prepared, 2);
    expect(api.handoffs, 0);
    await c.close();
  });
  test(
    'failed refresh preserves old preview and successful refresh releases it',
    () async {
      final c = CardCubit(repo, api, plant);
      await c.load();
      await c.prepare();
      api.failure = 'MEDIA_MISSING';
      await c.prepare();
      expect(c.state.token, 'token-1');
      expect(c.state.bytes, api.image);
      api.failure = null;
      await c.prepare();
      expect(c.state.token, 'token-3');
      expect(api.released, ['token-1']);
      expect(api.handoffs, 0);
      await c.close();
    },
  );
  testWidgets(
    'lost save reply shows uncertainty and never retries automatically',
    (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await press(t, 'Preview card');
      api.lostSaveReply = true;
      await press(t, 'Save image');
      expect(
        find.textContaining('Check Photos before choosing Save image again'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(api.handoffs, 1);
      await t.pump(const Duration(seconds: 40));
      expect(api.handoffs, 1);
    },
  );
  test(
    'unresolved native save deadline is unknown and late reply never retries',
    () async {
      final host = UnresponsiveCardHost(),
          service = NativeCardService(
            host: host,
            deadline: const Duration(milliseconds: 1),
          );
      await expectLater(
        service.handoff('preview', save: true),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'PHOTO_SAVE_UNKNOWN',
          ),
        ),
      );
      expect(host.calls, 1);
      host.completion.complete('{"outcome":"saved","code":null}');
      await Future<void>.delayed(Duration.zero);
      expect(host.calls, 1);
    },
  );
}
