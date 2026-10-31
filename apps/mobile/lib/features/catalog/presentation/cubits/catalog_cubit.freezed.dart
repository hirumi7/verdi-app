// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogView {
  CatalogState? get catalog;
  String get query;
  bool get loading;
  bool get failed;

  /// Create a copy of CatalogView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CatalogViewCopyWith<CatalogView> get copyWith =>
      _$CatalogViewCopyWithImpl<CatalogView>(this as CatalogView, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as CatalogView;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CatalogView &&
            (identical(other.catalog, _this.catalog) ||
                other.catalog == _this.catalog) &&
            (identical(other.query, _this.query) ||
                other.query == _this.query) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.failed, _this.failed) ||
                other.failed == _this.failed));
  }

  @override
  int get hashCode {
    final _this = this as CatalogView;
    return Object.hash(
      runtimeType,
      _this.catalog,
      _this.query,
      _this.loading,
      _this.failed,
    );
  }

  @override
  String toString() {
    final _this = this as CatalogView;
    return 'CatalogView(catalog: ${_this.catalog}, query: ${_this.query}, loading: ${_this.loading}, failed: ${_this.failed})';
  }
}

/// @nodoc
abstract mixin class $CatalogViewCopyWith<$Res> {
  factory $CatalogViewCopyWith(
    CatalogView value,
    $Res Function(CatalogView) _then,
  ) = _$CatalogViewCopyWithImpl;
  @useResult
  $Res call({CatalogState? catalog, String query, bool loading, bool failed});
}

/// @nodoc
class _$CatalogViewCopyWithImpl<$Res> implements $CatalogViewCopyWith<$Res> {
  _$CatalogViewCopyWithImpl(this._self, this._then);

  final CatalogView _self;
  final $Res Function(CatalogView) _then;

  /// Create a copy of CatalogView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? catalog = freezed,
    Object? query = null,
    Object? loading = null,
    Object? failed = null,
  }) {
    return _then(
      CatalogView(
        catalog: freezed == catalog
            ? _self.catalog
            : catalog // ignore: cast_nullable_to_non_nullable
                  as CatalogState?,
        query: null == query
            ? _self.query
            : query // ignore: cast_nullable_to_non_nullable
                  as String,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        failed: null == failed
            ? _self.failed
            : failed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [CatalogView].
extension CatalogViewPatterns on CatalogView {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_CatalogView value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CatalogView() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_CatalogView value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CatalogView():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_CatalogView value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CatalogView() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
      CatalogState? catalog,
      String query,
      bool loading,
      bool failed,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CatalogView() when $default != null:
        return $default(
          _that.catalog,
          _that.query,
          _that.loading,
          _that.failed,
        );
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
      CatalogState? catalog,
      String query,
      bool loading,
      bool failed,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CatalogView():
        return $default(
          _that.catalog,
          _that.query,
          _that.loading,
          _that.failed,
        );
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
      CatalogState? catalog,
      String query,
      bool loading,
      bool failed,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CatalogView() when $default != null:
        return $default(
          _that.catalog,
          _that.query,
          _that.loading,
          _that.failed,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CatalogView implements CatalogView {
  const _CatalogView({
    this.catalog,
    this.query = '',
    this.loading = true,
    this.failed = false,
  });

  @override
  final CatalogState? catalog;
  @override
  @JsonKey()
  final String query;
  @override
  @JsonKey()
  final bool loading;
  @override
  @JsonKey()
  final bool failed;

  /// Create a copy of CatalogView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CatalogViewCopyWith<_CatalogView> get copyWith =>
      __$CatalogViewCopyWithImpl<_CatalogView>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CatalogView &&
            (identical(other.catalog, catalog) || other.catalog == catalog) &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.failed, failed) || other.failed == failed));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, catalog, query, loading, failed);
  }

  @override
  String toString() {
    return 'CatalogView(catalog: $catalog, query: $query, loading: $loading, failed: $failed)';
  }
}

/// @nodoc
abstract mixin class _$CatalogViewCopyWith<$Res>
    implements $CatalogViewCopyWith<$Res> {
  factory _$CatalogViewCopyWith(
    _CatalogView value,
    $Res Function(_CatalogView) _then,
  ) = __$CatalogViewCopyWithImpl;
  @override
  @useResult
  $Res call({CatalogState? catalog, String query, bool loading, bool failed});
}

/// @nodoc
class __$CatalogViewCopyWithImpl<$Res> implements _$CatalogViewCopyWith<$Res> {
  __$CatalogViewCopyWithImpl(this._self, this._then);

  final _CatalogView _self;
  final $Res Function(_CatalogView) _then;

  /// Create a copy of CatalogView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? catalog = freezed,
    Object? query = null,
    Object? loading = null,
    Object? failed = null,
  }) {
    return _then(
      _CatalogView(
        catalog: freezed == catalog
            ? _self.catalog
            : catalog // ignore: cast_nullable_to_non_nullable
                  as CatalogState?,
        query: null == query
            ? _self.query
            : query // ignore: cast_nullable_to_non_nullable
                  as String,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        failed: null == failed
            ? _self.failed
            : failed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}
