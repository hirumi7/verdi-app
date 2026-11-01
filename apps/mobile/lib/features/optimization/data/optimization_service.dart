import 'package:verdi_core/verdi_core.dart';

import '../../collection/data/repositories/collection_repository.dart';
import '../../collection/data/repositories_impl/native_collection_repository.dart';

abstract interface class OptimizationService {
  Future<Map<String, Object?>?> call(
    String operation,
    Map<String, Object?> args,
  );
  Future<void> saveDraft(SaveMediaDraft command, String commandId);
}

final class NativeOptimizationService implements OptimizationService {
  final CollectionRepository repository;
  NativeOptimizationService(this.repository);
  NativeCollectionRepository get native =>
      repository is NativeCollectionRepository
      ? repository as NativeCollectionRepository
      : throw CommandRejected('NOT_ELIGIBLE');
  @override
  Future<Map<String, Object?>?> call(
    String operation,
    Map<String, Object?> args,
  ) => native.optimization(operation, args);
  @override
  Future<void> saveDraft(SaveMediaDraft command, String commandId) async {
    await native.submitOptimizationDraft(command, commandId);
  }
}
