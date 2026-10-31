import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../features/collection/data/repositories/collection_repository.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies({
  required String environment,
  CollectionRepository? repository,
}) async {
  if (repository != null) {
    getIt.registerSingleton<CollectionRepository>(repository);
  }
  getIt.init(environment: environment);
}
