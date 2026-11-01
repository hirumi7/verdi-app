import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../core/native/draft_bridge.g.dart';

abstract interface class ReminderService {
  Stream<void> get changes;
  Future<Map<String, Object?>?> call(
    String method, [
    Map<String, Object?>? args,
  ]);
  Future<void> dispose();
}

final class NativeReminderService extends ReminderPlatformEventsApi
    implements ReminderService {
  final ReminderPlatformHostApi _api;
  final Duration deadline;
  final _changes = StreamController<void>.broadcast();
  NativeReminderService({
    ReminderPlatformHostApi? api,
    this.deadline = const Duration(seconds: 20),
  }) : _api = api ?? ReminderPlatformHostApi() {
    ReminderPlatformEventsApi.setUp(this);
  }
  @override
  Stream<void> get changes => _changes.stream;
  @override
  void changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<Map<String, Object?>?> call(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final String text;
    switch (method) {
      case 'readState':
        text = await _bounded(_api.readState(), method);
      case 'reconcile':
        text = await _bounded(_api.reconcile(), method);
      case 'readTap':
        text = await _bounded(_api.readTap(), method);
      case 'savePreferences':
        text = await _bounded(
          _api.savePreferences(canonicalCommandJson(args)),
          method,
        );
      case 'resolvePreferences':
        text = await _bounded(
          _api.resolvePreferences(canonicalCommandJson(args)),
          method,
        );
      case 'requestPermission':
        text = await _api.requestPermission(args!['context']! as String);
      case 'openSettings':
        await _api.openSettings();
        return null;
      case 'acknowledgeTap':
        await _bounded(
          _api.acknowledgeTap(args!['eventId']! as String),
          method,
        );
        return null;
      default:
        throw ArgumentError.value(method);
    }
    if (text.length > 65536) throw const FormatException('REMINDER_LIMIT');
    final value = jsonDecode(text);
    return value == null ? null : (value as Map).cast<String, Object?>();
  }

  Future<T> _bounded<T>(Future<T> operation, String method) =>
      operation.timeout(
        deadline,
        onTimeout: () => throw PlatformException(
          code: method == 'savePreferences' || method == 'resolvePreferences'
              ? 'UNKNOWN_OUTCOME'
              : 'REMINDERS_UNAVAILABLE',
        ),
      );
  @override
  Future<void> dispose() {
    ReminderPlatformEventsApi.setUp(null);
    return _changes.close();
  }
}
