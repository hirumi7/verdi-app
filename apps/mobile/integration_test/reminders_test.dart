import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';

// Only the disposable Verdi Backup QA simulator. Preserve the user's simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'main UI permission, saved reminders and observed iOS pending queue',
    (tester) async {
      final repository = await NativeCollectionRepository.open();
      final snapshot = await repository.mediaSnapshot();
      final routine = snapshot.routines.values.firstWhere(
        (r) => !r.archived && r.status == RoutineStatus.active,
      );
      final detail = await repository.detail(routine.plantId);
      final target = detail.routines
          .firstWhere((r) => r.target.routineId == routine.id)
          .target;
      final preview = await repository.prepare(
        Snooze(target, repository.today.addDays(1)),
      );
      await repository.confirm(preview);
      await repository.close();
      await tester.pumpWidget(const CoreBootstrap());
      for (
        var i = 0;
        i < 150 && find.text('Settings').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminders').last);
      await tester.pumpAndSettle();
      final api = ReminderPlatformHostApi();
      Map<String, dynamic> state =
          jsonDecode(await api.readState()) as Map<String, dynamic>;
      if (state['authorization'] == 'notDetermined') {
        await tester.tap(find.text('Allow notifications'));
        // The OS dialog is handled via Simulator UI; no TCC database edits.
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(seconds: 1));
          state = jsonDecode(await api.readState()) as Map<String, dynamic>;
          if (state['authorization'] != 'notDetermined') break;
        }
      }
      expect(state['authorization'], 'authorized');
      final enabled = find.byType(SwitchListTile);
      for (
        var i = 0;
        i < 100 && tester.widget<SwitchListTile>(enabled).onChanged == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<SwitchListTile>(enabled).onChanged, isNotNull);
      if (tester.widget<SwitchListTile>(enabled).value == false) {
        await Scrollable.ensureVisible(tester.element(enabled), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(enabled);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<SwitchListTile>(enabled).value, true);
      await tester.scrollUntilVisible(
        find.text('Save reminder settings'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Save reminder settings')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save reminder settings'));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        state = jsonDecode(await api.readState()) as Map<String, dynamic>;
        if ((state['settings'] as Map)['reminders']['enabled'] == true &&
            (state['lastReconcile'] as Map?)?['state'] == 'complete') {
          break;
        }
      }
      final result = state['lastReconcile'] as Map;
      expect(result['state'], 'complete', reason: jsonEncode(state));
      expect(result['pendingConfirmed'], greaterThan(0));
      expect(result['pendingConfirmed'], lessThanOrEqualTo(60));
      expect((state['settings'] as Map)['theme'], 'dark');
      expect((state['settings'] as Map)['localeOverride'], 'en-GB');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final reopened = await NativeCollectionRepository.open();
      final after = await reopened.mediaSnapshot();
      expect(after.plants.length, snapshot.plants.length);
      expect(after.photos.length, snapshot.photos.length);
      expect(
        after.routines.values.expand((r) => r.events).length,
        snapshot.routines.values.expand((r) => r.events).length,
      );
      if (const bool.fromEnvironment('VERDI_REMINDER_DELIVERY')) {
        // Opt-in manual delivery handoff, using normal production commands on
        // the disposable QA data. No notification injection or database edits.
        final detail = await reopened.detail(routine.plantId);
        final target = detail.routines
            .firstWhere((r) => r.target.routineId == routine.id)
            .target;
        final fire = DateTime.now().add(const Duration(minutes: 3));
        await reopened.confirm(
          await reopened.prepare(
            Snooze(target, LocalDate(fire.year, fire.month, fire.day)),
          ),
        );
        state = jsonDecode(await api.readState()) as Map<String, dynamic>;
        await api.savePreferences(
          canonicalCommandJson({
            'operationId': reopened.newId(),
            'datasetId': reopened.datasetId,
            'expectedRevision': (state['settings'] as Map)['revision'],
            'values': {
              'enabled': true,
              'preferredMinute': fire.hour * 60 + fire.minute,
              'quietStartMinute': 0,
              'quietEndMinute': 0,
            },
          }),
        );
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          state = jsonDecode(await api.readState()) as Map<String, dynamic>;
          if ((state['lastReconcile'] as Map)['state'] == 'complete' &&
              ((state['lastReconcile'] as Map)['pendingConfirmed'] as int) >
                  0) {
            break;
          }
        }
        expect(
          (state['lastReconcile'] as Map)['pendingConfirmed'],
          greaterThan(0),
          reason: jsonEncode(state),
        );
        // ignore: avoid_print
        print(
          'Manual QA delivery scheduled at $fire; launch ordinary development app, then background or terminate it.',
        );
      }
      await reopened.close();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
