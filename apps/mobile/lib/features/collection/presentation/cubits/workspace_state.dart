import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../data/repositories/collection_repository.dart';
part 'workspace_state.freezed.dart';

@freezed
abstract class WorkspaceState with _$WorkspaceState {
  const factory WorkspaceState({
    WorkspaceRead? read,
    @Default(false) bool loading,
    @Default(false) bool busy,
    @Default(false) bool loadingMore,
    @Default([]) List<PlantsPage> plantPages,
    @Default({}) Map<TodaySection, List<TodayPage>> todayPages,
    @Default(false) bool archived,
    @Default('') String query,
    String? errorCode,
    UndoOffer? undo,
    @Default(0) int generation,
  }) = _WorkspaceState;
}
