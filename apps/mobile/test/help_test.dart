import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/help/data/feedback_service.dart';
import 'package:verdi_mobile/features/help/presentation/help_pages.dart';
import 'package:verdi_mobile/features/help/presentation/cubits/feedback_cubit.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

import 'presentation_test.dart' show press, field;

class FakeFeedback implements FeedbackService {
  final copied = <String>[];
  bool loadFails = false, copyFails = false;
  Completer<FeedbackMetadata>? pendingLoad;
  Completer<void>? pendingCopy;
  @override
  Future<FeedbackMetadata> metadata() async {
    if (loadFails) throw PlatformException(code: 'unavailable');
    return pendingLoad?.future ??
        Future.value(
          const FeedbackMetadata(
            '00000000-0000-4000-8000-000000000001',
            '0.1.0',
            '1',
            '18.3.1',
          ),
        );
  }

  @override
  Future<void> copy(String text) async {
    copied.add(text);
    if (copyFails) throw PlatformException(code: 'channel-error');
    if (pendingCopy != null) await pendingCopy!.future;
  }
}

Widget app(Widget page) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: page,
);
void main() {
  testWidgets(
    'copy only after explicit action contains exact reviewed edited fields',
    (t) async {
      final api = FakeFeedback();
      await t.pumpWidget(app(FeedbackPage(service: api)));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Direct support contact is not configured'),
        findsOneWidget,
      );
      expect(api.copied, isEmpty);
      expect(
        t.widget<TextField>(field('Message')).controller!.text,
        'Verdi Preview 0.1.0 (build 1)\niOS 18.3.1\n\nDescribe your feedback:\n',
      );
      await t.enterText(field('Subject'), '  My feedback  ');
      await t.enterText(field('Message'), '  More detail\n');
      await press(t, 'Copy feedback');
      expect(api.copied, ['  My feedback  \n\n  More detail\n']);
      expect(find.text('Feedback copied. Nothing was sent.'), findsOneWidget);
    },
  );
  testWidgets(
    'failed load retries; failed copy preserves edits without auto retry',
    (t) async {
      final api = FakeFeedback()..loadFails = true;
      await t.pumpWidget(app(FeedbackPage(service: api)));
      await t.pumpAndSettle();
      expect(
        find.textContaining('App details could not be loaded'),
        findsOneWidget,
      );
      api.loadFails = false;
      await press(t, 'Retry');
      await t.enterText(field('Message'), 'My retained text');
      api.copyFails = true;
      await press(t, 'Copy feedback');
      expect(find.textContaining('Copying was not confirmed'), findsOneWidget);
      expect(
        t.widget<TextField>(field('Message')).controller!.text,
        'My retained text',
      );
      await t.pump(const Duration(seconds: 20));
      expect(api.copied.length, 1);
    },
  );
  testWidgets('changed feedback asks before discard; cancel retains form', (
    t,
  ) async {
    final api = FakeFeedback();
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FeedbackPage(service: api),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await press(t, 'Open');
    await t.enterText(field('Message'), 'Keep this');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Discard this feedback draft?'), findsOneWidget);
    await press(t, 'Cancel');
    expect(t.widget<TextField>(field('Message')).controller!.text, 'Keep this');
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, 'Discard changes');
    expect(find.text('Open'), findsOneWidget);
  });
  testWidgets(
    'privacy and feedback remain usable at 320 percent text with keyboard',
    (t) async {
      t.view.physicalSize = const Size(375, 667);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(() {
        t.view.reset();
        t.platformDispatcher.clearAllTestValues();
      });
      await t.pumpWidget(app(const PrivacyPage()));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Deletion and copies'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(t.takeException(), isNull);
      final api = FakeFeedback();
      await t.pumpWidget(app(FeedbackPage(service: api)));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        field('Message'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(field('Message'), 'Keyboard feedback');
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      await press(t, 'Copy feedback');
      expect(api.copied.single, endsWith('Keyboard feedback'));
      expect(t.takeException(), isNull);
    },
  );
  test('bounds, NUL and malformed UTF16 reject without losing text; emoji count as graphemes', () async {
    final api = FakeFeedback(),
        c = FeedbackCubit(
          api,
          initialSubject: 'Feedback',
          initialBody: (_) => '',
        );
    await c.load();
    for (final subject in [
      '',
      'x' * 201,
      'bad\u0000',
      String.fromCharCode(0xd800),
    ]) {
      c.edit(subject: subject);
      await c.copy();
      expect(c.state.subject, subject);
      expect(c.state.subjectError, isNotNull);
    }
    c.edit(subject: '🌱' * 200, body: 'x' * 4001);
    await c.copy();
    expect(c.state.bodyError, isNotNull);
    expect(api.copied, isEmpty);
    c.edit(body: 'Fine');
    await c.copy();
    expect(api.copied.length, 1);
    await c.close();
  });
  test(
    'load and copy deadlines allow recovery and ignore late success',
    () async {
      final api = FakeFeedback()..pendingLoad = Completer();
      final c = FeedbackCubit(
        api,
        initialSubject: 'Feedback',
        initialBody: (_) => 'Versions only',
        deadline: const Duration(milliseconds: 1),
      );
      await c.load();
      expect(c.state.status, 'loadFailed');
      expect(c.state.busy, false);
      api.pendingLoad!.complete(
        const FeedbackMetadata('id', 'late', 'late', 'late'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.state.ready, false);
      api.pendingLoad = null;
      await c.load();
      c.edit(body: 'Edited');
      api.pendingCopy = Completer();
      await c.copy();
      expect(c.state.status, 'copyUnknown');
      expect(c.state.body, 'Edited');
      api.pendingCopy!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.status, 'copyUnknown');
      expect(api.copied.length, 1);
      await c.close();
    },
  );
  test(
    'closed page ignores delayed metadata and sends no clipboard content',
    () async {
      final api = FakeFeedback()..pendingLoad = Completer();
      final c = FeedbackCubit(
        api,
        initialSubject: 'Feedback',
        initialBody: (_) => 'Versions only',
      );
      final pending = c.load();
      await c.close();
      api.pendingLoad!.complete(const FeedbackMetadata('id', '1', '2', '3'));
      await pending;
      expect(api.copied, isEmpty);
    },
  );
  test('native metadata rejects destinations, extra private fields and malformed versions', () {
    final good = {
      'draftId': '00000000-0000-4000-8000-000000000001',
      'destination': null,
      'appVersion': '0.1.0',
      'build': '1',
      'osVersion': null,
    };
    expect(FeedbackMetadata.parse(jsonEncode(good)).osVersion, isNull);
    for (final bad in [
      {...good, 'destination': 'invented@example.com'},
      {...good, 'photos': []},
      {...good, 'appVersion': 'x' * 81},
      {...good, 'build': 'bad\u0000'},
    ]) {
      expect(
        () => FeedbackMetadata.parse(jsonEncode(bad)),
        throwsFormatException,
      );
    }
  });
}
