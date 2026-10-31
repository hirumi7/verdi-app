import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../data/repositories/collection_repository.dart';
import 'workspace_state.dart';
export 'workspace_state.dart';

@injectable
class WorkspaceCubit extends Cubit<WorkspaceState> {
  final CollectionRepository _repository;
  int _readSequence = 0;
  Timer? _undoTimer;
  Set<String> _undoRoutines = {};
  WorkspaceCubit(this._repository) : super(const WorkspaceState());
  LocalDate get today => _repository.today;
  String newId() => _repository.newId();
  List<PlantRow> get plantRows => [
    ...?state.read?.plants.page.items,
    for (final page in state.plantPages) ...page.page.items,
  ];
  ReadCursor? get plantCursor => state.plantPages.isEmpty
      ? state.read?.plants.page.nextCursor
      : state.plantPages.last.page.nextCursor;
  List<TodayRow> todayRows(TodaySection section) => [
    ...?state.read?.today[section]?.page.items,
    for (final page in state.todayPages[section] ?? <TodayPage>[])
      ...page.page.items,
  ];
  ReadCursor? todayCursor(TodaySection section) {
    final pages = state.todayPages[section] ?? <TodayPage>[];
    return pages.isEmpty
        ? state.read?.today[section]?.page.nextCursor
        : pages.last.page.nextCursor;
  }

  Future<void> loadMore({TodaySection? section}) async {
    if (state.loading || state.loadingMore) return;
    final cursor = section == null ? plantCursor : todayCursor(section);
    if (cursor == null) return;
    final sequence = _readSequence;
    emit(state.copyWith(loadingMore: true, errorCode: null));
    try {
      if (section == null) {
        final page = await _repository.morePlants(
          archived: state.archived,
          query: state.query,
          cursor: cursor,
        );
        if (!isClosed && sequence == _readSequence) {
          emit(
            state.copyWith(
              plantPages: [...state.plantPages, page],
              loadingMore: false,
            ),
          );
        }
      } else {
        final page = await _repository.moreToday(section, cursor);
        if (!isClosed && sequence == _readSequence) {
          emit(
            state.copyWith(
              todayPages: {
                ...state.todayPages,
                section: [...?state.todayPages[section], page],
              },
              loadingMore: false,
            ),
          );
        }
      }
    } catch (error) {
      if (!isClosed && sequence == _readSequence) {
        if (error is DomainException && error.code == 'READ_STALE') {
          await refresh();
        }
        if (!isClosed) {
          emit(state.copyWith(loadingMore: false, errorCode: code(error)));
        }
      }
    }
  }

  Future<void> refresh({bool? archived, String? query}) async {
    final sequence = ++_readSequence;
    emit(
      state.copyWith(
        loading: true,
        loadingMore: false,
        plantPages: [],
        todayPages: {},
        archived: archived ?? state.archived,
        query: query ?? state.query,
        errorCode: null,
      ),
    );
    try {
      final read = await _repository.read(
        archived: state.archived,
        query: state.query,
      );
      if (isClosed || sequence != _readSequence) return;
      emit(state.copyWith(read: read, loading: false));
    } catch (error) {
      if (!isClosed && sequence == _readSequence) {
        emit(state.copyWith(loading: false, errorCode: code(error)));
      }
    }
  }

  Future<PlantEditor> editor(String? id) => _repository.editor(id);
  Future<PlantDetail> detail(String id) => _repository.detail(id);
  Future<ReadPage<TimelineEntry>> timeline(
    String id, {
    bool includeVoided = false,
    ReadCursor? cursor,
  }) => _repository.timeline(id, includeVoided: includeVoided, cursor: cursor);
  Future<PreparedCommand> prepare(CoreCommand command, {String? commandId}) =>
      _repository.prepare(command, commandId: commandId);
  Future<CommandResolution> abandon(PreparedCommand preview) async {
    final result = await _repository.abandon(preview.intent.commandId);
    await refresh();
    return result;
  }

  /// The exact prepared command is retained until receipt recovery determines
  /// the result. No new ID is minted merely because a response was lost.
  Future<CommandSuccess> confirm(PreparedCommand preview) =>
      _write(preview.intent.command, () async {
        try {
          return await _repository.confirm(preview);
        } on UnknownCommandOutcome catch (error) {
          final result = await _repository.resolve(error.commandId);
          if (result.committed) return result.result!;
          rethrow;
        }
      });

  Future<CommandSuccess> submit(CoreCommand command) =>
      _write(command, () async {
        try {
          return await _repository.submit(command);
        } on UnknownCommandOutcome catch (error) {
          final result = await _repository.resolve(error.commandId);
          if (result.committed) return result.result!;
          rethrow;
        }
      });

  Future<CommandSuccess> _write(
    CoreCommand command,
    Future<CommandSuccess> Function() action,
  ) async {
    if (state.busy) throw CommandRejected('BUSY');
    emit(state.copyWith(busy: true, errorCode: null));
    try {
      final result = await action();
      if (isClosed) return result;
      final offer = result.undo;
      final invalidates =
          command is Undo ||
          result.newRevisions.keys.any(_undoRoutines.contains);
      if (offer != null || invalidates) _undoTimer?.cancel();
      emit(
        state.copyWith(
          busy: false,
          undo: offer ?? (invalidates ? null : state.undo),
          generation: state.generation + 1,
        ),
      );
      if (offer != null) {
        _undoRoutines = switch (command) {
          RoutineCommand c => {c.target.routineId},
          BulkComplete c => c.targets.map((t) => t.routineId).toSet(),
          _ => {},
        };
        _undoTimer = Timer(
          Duration(milliseconds: offer.expiresInMilliseconds),
          () {
            if (!isClosed) emit(state.copyWith(undo: null));
          },
        );
      }
      await refresh();
      return result;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, errorCode: code(error)));
      rethrow;
    }
  }

  void invalidateUndo() {
    _undoTimer?.cancel();
    _undoRoutines = {};
    _repository.invalidateUndo();
    emit(state.copyWith(undo: null));
  }

  static String code(Object error) => switch (error) {
    DomainException e => e.code,
    UnknownCommandOutcome() || RecoveryUnavailable() => 'UNKNOWN_OUTCOME',
    _ => 'STORAGE_UNAVAILABLE',
  };

  @override
  Future<void> close() {
    _undoTimer?.cancel();
    return super.close();
  }
}
