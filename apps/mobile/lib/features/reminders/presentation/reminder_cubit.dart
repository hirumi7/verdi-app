import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/reminder_service.dart';
part 'reminder_cubit.freezed.dart';

Map<String, Object?> reminderMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : {};

@freezed
abstract class ReminderState with _$ReminderState {
  const ReminderState._();
  const factory ReminderState({
    Map<String, Object?>? data,
    @Default({}) Map<String, Object?> draft,
    Map<String, Object?>? tap,
    @Default(false) bool busy,
    @Default(false) bool unresolved,
    @Default(false) bool saved,
    String? error,
  }) = _ReminderState;
  Map<String, Object?> get projection => reminderMap(data?['lastReconcile']);
  String get permission => data?['authorization'] as String? ?? 'unavailable';
  bool get hasSchedule => data?['hasSavedSchedule'] == true;
}

class ReminderCubit extends Cubit<ReminderState> {
  final ReminderService service;
  final String Function() newId;
  late final StreamSubscription<void> _events;
  Map<String, Object?>? _pending;
  int? _baseRevision;
  bool _refreshing = false,
      _refreshAgain = false,
      _reloadAgain = false,
      _reconcileAgain = false;
  int _generation = 0;
  ReminderCubit(this.service, this.newId) : super(const ReminderState()) {
    _events = service.changes.listen((_) => refresh());
  }
  Future<void> refresh({bool reconcile = false, bool reload = false}) async {
    if (_refreshing) {
      _refreshAgain = true;
      _reloadAgain = _reloadAgain || reload;
      _reconcileAgain = _reconcileAgain || reconcile;
      return;
    }
    if (state.busy || isClosed) return;
    _refreshing = true;
    final generation = _generation;
    try {
      if (reconcile) await service.call('reconcile');
      final data = await service.call('readState');
      final tap = await service.call('readTap');
      if (generation != _generation || isClosed) return;
      final settings = reminderMap(data?['settings']);
      final reset = reload || _baseRevision == null;
      if (reset) _baseRevision = settings['revision'] as int?;
      final draft = reset
          ? (Map<String, Object?>.of(reminderMap(settings['reminders']))
              ..remove('settingsRevision'))
          : state.draft;
      if (!isClosed) {
        emit(
          state.copyWith(
            data: data,
            draft: draft,
            tap: tap,
            error: state.unresolved ? state.error : null,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: code(e)));
    } finally {
      _refreshing = false;
      if (_refreshAgain) {
        _refreshAgain = false;
        final reload = _reloadAgain, reconcile = _reconcileAgain;
        _reloadAgain = false;
        _reconcileAgain = false;
        unawaited(refresh(reload: reload, reconcile: reconcile));
      }
    }
  }

  void edit(String key, Object value) {
    if (state.busy || state.unresolved) return;
    emit(state.copyWith(draft: {...state.draft, key: value}, saved: false));
  }

  Future<void> save() async {
    if (state.busy || _baseRevision == null || state.data == null) return;
    _generation++;
    final retry = _pending != null;
    _pending ??= {
      'operationId': newId(),
      'datasetId': state.data!['datasetId'],
      'expectedRevision': _baseRevision,
      'values': Map<String, Object?>.of(state.draft),
    };
    emit(
      state.copyWith(busy: true, unresolved: true, error: null, saved: false),
    );
    try {
      final resolved = retry
          ? await service.call('resolvePreferences', _pending)
          : null;
      if (resolved?['committed'] != true) {
        await service.call('savePreferences', _pending);
      }
      _pending = null;
      _baseRevision = null;
      if (!isClosed) {
        emit(state.copyWith(busy: false, unresolved: false, saved: true));
      }
      await refresh(reload: true);
    } catch (e) {
      final error = code(e);
      if ([
        'REVISION_CONFLICT',
        'FIELD_INVALID',
        'DATASET_CHANGED',
        'COMMAND_ID_REUSED',
      ].contains(error)) {
        _pending = null;
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            unresolved: _pending != null,
            error: error,
          ),
        );
      }
    }
  }

  Future<void> permission() =>
      _action('requestPermission', {'context': 'settings'});
  Future<void> openSettings() => _action('openSettings');
  Future<void> retryQueue() async {
    await refresh(reconcile: true);
  }

  Future<void> acknowledgeTap(String eventId) async {
    try {
      await service.call('acknowledgeTap', {'eventId': eventId});
      if (!isClosed && state.tap?['eventId'] == eventId) {
        emit(state.copyWith(tap: null));
      }
      await refresh();
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: code(e)));
    }
  }

  Future<void> _action(String method, [Map<String, Object?>? args]) async {
    if (state.busy || state.unresolved) return;
    emit(state.copyWith(busy: true, error: null));
    String? failure;
    try {
      await service.call(method, args);
    } catch (e) {
      failure = code(e);
    }
    if (!isClosed) emit(state.copyWith(busy: false));
    await refresh();
    if (!isClosed && failure != null) emit(state.copyWith(error: failure));
  }

  static String code(Object e) =>
      e is PlatformException ? e.code : 'REMINDERS_UNAVAILABLE';
  @override
  Future<void> close() {
    unawaited(_events.cancel());
    unawaited(service.dispose());
    return super.close();
  }
}
