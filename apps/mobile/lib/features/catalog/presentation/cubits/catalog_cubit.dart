import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../collection/data/repositories/collection_repository.dart';
part 'catalog_cubit.freezed.dart';

@freezed
abstract class CatalogView with _$CatalogView {
  const factory CatalogView({
    CatalogState? catalog,
    @Default('') String query,
    @Default(true) bool loading,
    @Default(false) bool failed,
  }) = _CatalogView;
}

class CatalogCubit extends Cubit<CatalogView> {
  final CollectionRepository repository;
  int _request = 0;
  CatalogCubit(this.repository) : super(const CatalogView());
  void query(String value) => emit(state.copyWith(query: value));
  Future<void> load({bool retry = false}) async {
    final request = ++_request;
    emit(state.copyWith(loading: true, failed: false));
    try {
      final catalog = await repository.catalog(retry: retry);
      if (!isClosed && request == _request) {
        emit(state.copyWith(catalog: catalog, loading: false));
      }
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(state.copyWith(loading: false, failed: true));
      }
    }
  }
}
