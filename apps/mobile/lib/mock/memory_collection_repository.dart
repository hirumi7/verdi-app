import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:verdi_core/verdi_core.dart';

import '../features/collection/data/repositories/collection_repository.dart';

@LazySingleton(as: CollectionRepository, env: ['memory'])
class MemoryCollectionRepository implements CollectionRepository {
  final _random = Random.secure();
  final _elapsed = Stopwatch()..start();
  late final MemoryCoreStore store;
  late final MemoryOperationCoordinator coordinator;
  FrozenCommand? _unresolved;
  @override
  late final String datasetId;

  MemoryCollectionRepository() {
    datasetId = newId();
    store = MemoryCoreStore(datasetId: datasetId, nextId: newId);
    coordinator = MemoryOperationCoordinator(
      store,
      clock: () {
        // Explicit UTC synthetic clock. The native adapter must supply local date
        // and IANA zone atomically at transaction entry before real-data use.
        final now = DateTime.now().toUtc();
        return ClockReading(
          CareClock(LocalDate(now.year, now.month, now.day), now, 'Etc/UTC'),
          _elapsed.elapsed,
        );
      },
    );
  }

  @override
  String newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  LocalDate get today {
    final now = DateTime.now().toUtc();
    return LocalDate(now.year, now.month, now.day);
  }

  @override
  Future<WorkspaceRead> read({required bool archived, required String query}) =>
      Future.sync(
        () => WorkspaceRead(
          coordinator.listPlants(
            datasetId: datasetId,
            archived: archived,
            query: query,
          ),
          {
            for (final section in TodaySection.values)
              section: coordinator.getToday(
                datasetId: datasetId,
                section: section,
              ),
          },
        ),
      );

  @override
  Future<PlantsPage> morePlants({
    required bool archived,
    required String query,
    required ReadCursor cursor,
  }) => Future.sync(
    () => coordinator.listPlants(
      datasetId: datasetId,
      archived: archived,
      query: query,
      cursor: cursor,
    ),
  );
  @override
  Future<TodayPage> moreToday(TodaySection section, ReadCursor cursor) =>
      Future.sync(
        () => coordinator.getToday(
          datasetId: datasetId,
          section: section,
          cursor: cursor,
        ),
      );
  @override
  Future<PlantEditor> editor(String? plantId) => Future.sync(
    () => coordinator.getPlantEditor(datasetId: datasetId, plantId: plantId),
  );
  @override
  Future<PlantDetail> detail(String plantId) => Future.sync(
    () => coordinator.getPlantDetail(datasetId: datasetId, plantId: plantId),
  );
  @override
  Future<ReadPage<TimelineEntry>> timeline(
    String plantId, {
    bool includeVoided = false,
    ReadCursor? cursor,
  }) => Future.sync(
    () => coordinator.listTimeline(
      datasetId: datasetId,
      plantId: plantId,
      includeVoided: includeVoided,
      cursor: cursor,
    ),
  );
  @override
  Future<PreparedCommand> prepare(CoreCommand command, {String? commandId}) =>
      Future.sync(
        () => coordinator.prepare(
          datasetId: datasetId,
          command: command,
          commandId: commandId,
        ),
      );
  @override
  Future<CommandSuccess> confirm(PreparedCommand preview) => Future.sync(
    () => _execute(preview.intent, previewToken: preview.previewToken),
  );
  @override
  Future<CommandSuccess> submit(CoreCommand command) => Future.sync(() {
    final old = _unresolved;
    if (old != null && old.payloadHash == command.payloadHash) {
      return _execute(old);
    }
    _resolveBeforeNewIntent();
    return _execute(coordinator.freeze(datasetId: datasetId, command: command));
  });

  void _resolveBeforeNewIntent() {
    final old = _unresolved;
    if (old == null) return;
    final result = coordinator.resolvePendingCommand(
      datasetId: datasetId,
      commandId: old.commandId,
    );
    if (!result.committed) throw UnknownCommandOutcome(old.commandId);
    _unresolved = null;
  }

  CommandSuccess _execute(FrozenCommand intent, {String? previewToken}) {
    if (_unresolved != null && _unresolved!.commandId != intent.commandId) {
      _resolveBeforeNewIntent();
    }
    _unresolved = intent;
    try {
      final result = coordinator.execute(
        datasetId: datasetId,
        commandId: intent.commandId,
        command: intent.command,
        previewToken: previewToken,
      );
      _unresolved = null;
      return result;
    } on CommandRejected {
      _unresolved = null;
      rethrow;
    }
  }

  @override
  Future<CommandResolution> resolve(String commandId) => Future.sync(() {
    final result = coordinator.resolvePendingCommand(
      datasetId: datasetId,
      commandId: commandId,
    );
    if (result.committed && _unresolved?.commandId == commandId) {
      _unresolved = null;
    }
    return result;
  });
  @override
  Future<CommandResolution> abandon(String commandId) => Future.sync(() {
    final result = coordinator.abandonPendingCommand(
      datasetId: datasetId,
      commandId: commandId,
    );
    if (_unresolved?.commandId == commandId) _unresolved = null;
    return result;
  });
  @override
  void invalidateUndo() => coordinator.invalidateUndoOffers();
}
