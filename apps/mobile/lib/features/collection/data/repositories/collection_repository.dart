import 'package:verdi_core/verdi_core.dart';

final class WorkspaceRead {
  final PlantsPage plants;
  final Map<TodaySection, TodayPage> today;
  const WorkspaceRead(this.plants, this.today);
}

abstract interface class CollectionRepository {
  String get datasetId;
  String newId();
  Future<WorkspaceRead> read({required bool archived, required String query});
  Future<PlantsPage> morePlants({
    required bool archived,
    required String query,
    required ReadCursor cursor,
  });
  Future<TodayPage> moreToday(TodaySection section, ReadCursor cursor);
  Future<PlantEditor> editor(String? plantId);
  Future<PlantDetail> detail(String plantId);
  Future<ReadPage<TimelineEntry>> timeline(
    String plantId, {
    bool includeVoided = false,
    ReadCursor? cursor,
  });
  Future<PreparedCommand> prepare(CoreCommand command, {String? commandId});
  Future<CommandSuccess> confirm(PreparedCommand preview);
  Future<CommandSuccess> submit(CoreCommand command);
  Future<CommandResolution> resolve(String commandId);
  Future<CommandResolution> abandon(String commandId);
  void invalidateUndo();
  LocalDate get today;
}
