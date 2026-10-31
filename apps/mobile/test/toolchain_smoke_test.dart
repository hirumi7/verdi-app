import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/router/app_router.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/workspace_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(() => getIt.reset());

  test(
    'generated DI, Freezed state and routes support a real custom draft save',
    () async {
      final repository = getIt<CollectionRepository>();
      expect(repository, isA<MemoryCollectionRepository>());
      expect(getIt<CollectionRepository>(), same(repository));
      final workspace = getIt<WorkspaceCubit>();
      final editor = getIt<PlantEditorCubit>();
      await workspace.refresh();
      expect(workspace.state.read!.plants.activeCount, 0);
      final changed = workspace.state.copyWith(query: 'fern');
      expect(changed.query, 'fern');
      expect(workspace.state.query, isEmpty);
      await editor.load(null);
      editor.update(name: 'Synthetic fern', species: 'Example species');
      await editor.flush();
      expect(editor.state.draft!.fields.name, 'Synthetic fern');
      final preview = await editor.preview();
      final saved = await workspace.confirm(preview);
      expect(saved.primaryType, 'plant');
      expect(workspace.state.read!.plants.activeCount, 1);
      expect((await repository.editor(null)).draft, isNull);
      final router = AppRouter();
      expect(router.routes.single.children!.length, 3);
      router.dispose();
      await editor.close();
      await workspace.close();
    },
  );
}
