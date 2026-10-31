// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/collection/data/repositories/collection_repository.dart'
    as _i816;
import '../../features/collection/presentation/cubits/plant_editor_cubit.dart'
    as _i186;
import '../../features/collection/presentation/cubits/workspace_cubit.dart'
    as _i422;
import '../../mock/memory_collection_repository.dart' as _i517;

const String _memory = 'memory';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i816.CollectionRepository>(
      () => _i517.MemoryCollectionRepository(),
      registerFor: {_memory},
    );
    gh.factory<_i186.PlantEditorCubit>(
      () => _i186.PlantEditorCubit(gh<_i816.CollectionRepository>()),
    );
    gh.factory<_i422.WorkspaceCubit>(
      () => _i422.WorkspaceCubit(gh<_i816.CollectionRepository>()),
    );
    return this;
  }
}
