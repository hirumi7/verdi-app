import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/pro/data/store_service.dart';
import 'package:verdi_mobile/features/pro/presentation/pro_cubit.dart';
import 'package:verdi_mobile/features/pro/presentation/pro_page.dart';
import 'package:verdi_mobile/features/collection/presentation/widgets/presentation_helpers.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/workspace_cubit.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

import 'presentation_test.dart' show seed, press;

class FakeStore implements StoreService {
  final events = StreamController<void>.broadcast();
  Map<String, Object?> access = {
    'access': 'free',
    'status': 'idle',
    'busy': false,
    'testEnvironment': true,
  };
  Map<String, Object?>? offer = {
    'displayName': 'Verdi Pro',
    'displayPrice': '£12.34',
  };
  Map<String, Object?>? request;
  Completer<Map<String, Object?>?>? purchaseWait;
  VoidCallback? onPurchase;
  int purchases = 0, restores = 0, pendingRetries = 0;
  bool fail = false;
  final cancelledIntents = <String>[];
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
      case 'loadOffer':
        return offer;
      case 'retryPending':
        pendingRetries++;
        request = args;
        return access;
      case 'purchase':
        purchases++;
        request = args;
        if (purchaseWait != null) return purchaseWait!.future;
        if (fail) throw StateError('offline');
        onPurchase?.call();
        access = {...access, 'access': 'pro', 'status': 'verified'};
        return access;
      case 'restore':
        restores++;
        if (fail) throw StateError('offline');
        return access;
      case 'cancel':
        cancelledIntents.add(args!['intentId']! as String);
        if (fail) throw StateError('offline');
        return access;
      default:
        return access;
    }
  }
}

Widget localized(Widget child) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);
Map<String, Object?> request() => {
  'intentId': '00000000-0000-4000-8000-000000000001',
  'datasetId': '00000000-0000-4000-8000-000000000002',
  'commandId': null,
  'payloadHash': null,
};
void main() {
  test(
    'one outstanding call and an unknown transport result never repurchases',
    () async {
      final service = FakeStore()..purchaseWait = Completer();
      final cubit = ProCubit(service);
      await cubit.load();
      final first = cubit.perform('purchase', request());
      await cubit.perform('purchase', request());
      expect(service.purchases, 1);
      service.access = {
        ...service.access,
        'busy': true,
        'attempt': {'phase': 'purchasing'},
      };
      service.purchaseWait!.completeError(StateError('timeout'));
      await first;
      expect(cubit.state.outstanding, isTrue);
      await cubit.perform('purchase', request());
      expect(service.purchases, 1);
      service.access = {
        ...service.access,
        'busy': false,
        'access': 'pro',
        'status': 'verified',
        'attempt': null,
      };
      await cubit.read();
      expect(cubit.state.pro, isTrue);
      await cubit.close();
      await service.dispose();
    },
  );
  test('restore failure and missing offer preserve cached access', () async {
    final service = FakeStore()
      ..offer = null
      ..fail = true;
    service.access = {
      ...service.access,
      'access': 'pro',
      'freshness': 'cached',
    };
    final cubit = ProCubit(service);
    await cubit.load();
    await cubit.perform('restore');
    expect(cubit.state.pro, isTrue);
    expect(cubit.state.offer, isNull);
    expect(cubit.state.error, isNotNull);
    expect(service.restores, 1);
    await cubit.close();
    await service.dispose();
  });
  testWidgets(
    'one-time localized price and unavailable offer keep free exit reachable at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeStore()..offer = null;
      await tester.pumpWidget(
        localized(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(3.2),
            ),
            child: ProPage(service: service, request: request()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('£'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Continue Free'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );
  testWidgets('reopening an interrupted purchase reuses its durable intent', (
    tester,
  ) async {
    final service = FakeStore();
    final prior = {
      ...request(),
      'intentId': '00000000-0000-4000-8000-000000000099',
      'phase': 'recoveryRequired',
      'continuationAbandoned': false,
    };
    service.access = {...service.access, 'attempt': prior};
    await tester.pumpWidget(
      localized(ProPage(service: service, request: request())),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Get Pro');
    expect(service.request!['intentId'], prior['intentId']);
    expect(service.purchases, 1);
    await tester.pumpWidget(const SizedBox());
    await service.dispose();
  });
  testWidgets(
    'pending retry requires confirmation and keeps the durable intent',
    (tester) async {
      final service = FakeStore();
      final prior = {
        ...request(),
        'phase': 'recoveryRequired',
        'priorPending': true,
        'continuationAbandoned': true,
      };
      service.access = {...service.access, 'attempt': prior};
      await tester.pumpWidget(
        localized(ProPage(service: service, request: request())),
      );
      await tester.pumpAndSettle();
      final buy = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get Pro'),
      );
      expect(buy.onPressed, isNull);
      await press(tester, 'Retry pending purchase');
      expect(
        find.textContaining('An earlier approval request'),
        findsOneWidget,
      );
      await press(tester, 'Cancel');
      expect(service.pendingRetries, 0);
      await press(tester, 'Retry pending purchase');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Retry pending purchase'),
      );
      await tester.pumpAndSettle();
      expect(service.pendingRetries, 1);
      expect(service.purchases, 0);
      expect(service.request!['intentId'], prior['intentId']);
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );
  testWidgets(
    'approval during retry confirmation closes gated offer without retry',
    (tester) async {
      final service = FakeStore();
      final gated = {
        ...request(),
        'commandId': '00000000-0000-4000-8000-000000000009',
        'payloadHash': 'hash',
      };
      service.access = {
        ...service.access,
        'attempt': {...gated, 'phase': 'pending', 'priorPending': true},
      };
      var returns = 0;
      bool? result;
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ProPage(service: service, request: gated),
                    ),
                  );
                  returns++;
                },
                child: const Text('Open gated offer'),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Open gated offer');
      await press(tester, 'Retry pending purchase');
      expect(find.byType(AlertDialog), findsOneWidget);
      service.access = {
        ...service.access,
        'access': 'pro',
        'status': 'verified',
      };
      service.events.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ProPage), findsNothing);
      expect(service.pendingRetries, 0);
      expect(returns, 1);
      expect(result, isTrue);
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );
  testWidgets(
    'leaving a changed-context recovery abandons the submitted old intent',
    (tester) async {
      final service = FakeStore()..purchaseWait = Completer();
      final prior = {
        ...request(),
        'intentId': '00000000-0000-4000-8000-000000000099',
        'datasetId': '00000000-0000-4000-8000-000000000098',
        'phase': 'recoveryRequired',
      };
      service.access = {...service.access, 'attempt': prior};
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProPage(service: service, request: request()),
                  ),
                ),
                child: const Text('Open offer'),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Open offer');
      await tester.tap(find.text('Get Pro'));
      await tester.pump();
      expect(service.request!['intentId'], prior['intentId']);
      final exit = find.text('Continue Free');
      await tester.scrollUntilVisible(
        exit,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(exit);
      await tester.pump(const Duration(seconds: 1));
      expect(service.cancelledIntents, [prior['intentId']]);
      service.purchaseWait!.complete(service.access);
      await tester.pumpAndSettle();
      expect(find.byType(ProPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );
  testWidgets(
    'gated sixth plant gets fresh same-ID confirmation after purchase, saved only once',
    (tester) async {
      final repository = MemoryCollectionRepository();
      for (var i = 0; i < 5; i++) {
        await seed(repository, 'Fern $i');
      }
      final draft = repository.newId();
      final saved = await repository.submit(
        SaveDraft(
          draftId: draft,
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(
            name: 'Sixth fern',
            speciesName: 'Synthetic',
          ),
        ),
      );
      final preview = await repository.prepare(
        SavePlant(draftId: draft, draftRevision: saved.newRevisions[draft]!),
      );
      expect(preview.effects.gate, PreviewGate.activeLimit);
      final service = FakeStore()
        ..onPurchase = () => repository.store.setProForTest(true);
      final workspace = WorkspaceCubit(repository);
      CommandSuccess? result;
      await tester.pumpWidget(
        ProHost(
          service: service,
          datasetId: repository.datasetId,
          newId: repository.newId,
          child: BlocProvider.value(
            value: workspace,
            child: localized(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await reviewCommand(context, preview);
                    },
                    child: const Text('Review'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Review');
      await press(tester, 'Verdi Pro');
      expect(find.text('£12.34'), findsOneWidget);
      await press(tester, 'Get Pro');
      expect((await repository.mediaSnapshot()).activePlants.length, 5);
      expect(service.request!['commandId'], preview.intent.commandId);
      expect(service.request!['payloadHash'], preview.intent.payloadHash);
      await press(tester, 'Confirm');
      expect(result!.commandId, preview.intent.commandId);
      expect((await repository.mediaSnapshot()).activePlants.length, 6);
      final resolved = await repository.resolve(preview.intent.commandId);
      expect(resolved.committed, isTrue);
      expect((await repository.mediaSnapshot()).activePlants.length, 6);
      await tester.pumpWidget(const SizedBox());
      await workspace.close();
      await service.dispose();
    },
  );
}
