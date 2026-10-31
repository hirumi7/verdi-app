// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkspaceState {
  WorkspaceRead? get read;
  bool get loading;
  bool get busy;
  bool get loadingMore;
  List<PlantsPage> get plantPages;
  Map<TodaySection, List<TodayPage>> get todayPages;
  bool get archived;
  String get query;
  String? get errorCode;
  UndoOffer? get undo;
  int get generation;

  /// Create a copy of WorkspaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WorkspaceStateCopyWith<WorkspaceState> get copyWith =>
      _$WorkspaceStateCopyWithImpl<WorkspaceState>(
        this as WorkspaceState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as WorkspaceState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WorkspaceState &&
            (identical(other.read, _this.read) || other.read == _this.read) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.loadingMore, _this.loadingMore) ||
                other.loadingMore == _this.loadingMore) &&
            const DeepCollectionEquality().equals(
              other.plantPages,
              _this.plantPages,
            ) &&
            const DeepCollectionEquality().equals(
              other.todayPages,
              _this.todayPages,
            ) &&
            (identical(other.archived, _this.archived) ||
                other.archived == _this.archived) &&
            (identical(other.query, _this.query) ||
                other.query == _this.query) &&
            (identical(other.errorCode, _this.errorCode) ||
                other.errorCode == _this.errorCode) &&
            (identical(other.undo, _this.undo) || other.undo == _this.undo) &&
            (identical(other.generation, _this.generation) ||
                other.generation == _this.generation));
  }

  @override
  int get hashCode {
    final _this = this as WorkspaceState;
    return Object.hash(
      runtimeType,
      _this.read,
      _this.loading,
      _this.busy,
      _this.loadingMore,
      const DeepCollectionEquality().hash(_this.plantPages),
      const DeepCollectionEquality().hash(_this.todayPages),
      _this.archived,
      _this.query,
      _this.errorCode,
      _this.undo,
      _this.generation,
    );
  }

  @override
  String toString() {
    final _this = this as WorkspaceState;
    return 'WorkspaceState(read: ${_this.read}, loading: ${_this.loading}, busy: ${_this.busy}, loadingMore: ${_this.loadingMore}, plantPages: ${_this.plantPages}, todayPages: ${_this.todayPages}, archived: ${_this.archived}, query: ${_this.query}, errorCode: ${_this.errorCode}, undo: ${_this.undo}, generation: ${_this.generation})';
  }
}

/// @nodoc
abstract mixin class $WorkspaceStateCopyWith<$Res> {
  factory $WorkspaceStateCopyWith(
    WorkspaceState value,
    $Res Function(WorkspaceState) _then,
  ) = _$WorkspaceStateCopyWithImpl;
  @useResult
  $Res call({
    WorkspaceRead? read,
    bool loading,
    bool busy,
    bool loadingMore,
    List<PlantsPage> plantPages,
    Map<TodaySection, List<TodayPage>> todayPages,
    bool archived,
    String query,
    String? errorCode,
    UndoOffer? undo,
    int generation,
  });
}

/// @nodoc
class _$WorkspaceStateCopyWithImpl<$Res>
    implements $WorkspaceStateCopyWith<$Res> {
  _$WorkspaceStateCopyWithImpl(this._self, this._then);

  final WorkspaceState _self;
  final $Res Function(WorkspaceState) _then;

  /// Create a copy of WorkspaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? read = freezed,
    Object? loading = null,
    Object? busy = null,
    Object? loadingMore = null,
    Object? plantPages = null,
    Object? todayPages = null,
    Object? archived = null,
    Object? query = null,
    Object? errorCode = freezed,
    Object? undo = freezed,
    Object? generation = null,
  }) {
    return _then(
      WorkspaceState(
        read: freezed == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as WorkspaceRead?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadingMore: null == loadingMore
            ? _self.loadingMore
            : loadingMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        plantPages: null == plantPages
            ? _self.plantPages
            : plantPages // ignore: cast_nullable_to_non_nullable
                  as List<PlantsPage>,
        todayPages: null == todayPages
            ? _self.todayPages
            : todayPages // ignore: cast_nullable_to_non_nullable
                  as Map<TodaySection, List<TodayPage>>,
        archived: null == archived
            ? _self.archived
            : archived // ignore: cast_nullable_to_non_nullable
                  as bool,
        query: null == query
            ? _self.query
            : query // ignore: cast_nullable_to_non_nullable
                  as String,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        undo: freezed == undo
            ? _self.undo
            : undo // ignore: cast_nullable_to_non_nullable
                  as UndoOffer?,
        generation: null == generation
            ? _self.generation
            : generation // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [WorkspaceState].
extension WorkspaceStatePatterns on WorkspaceState {
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
    TResult Function(_WorkspaceState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState() when $default != null:
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
    TResult Function(_WorkspaceState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState():
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
    TResult? Function(_WorkspaceState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState() when $default != null:
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
      WorkspaceRead? read,
      bool loading,
      bool busy,
      bool loadingMore,
      List<PlantsPage> plantPages,
      Map<TodaySection, List<TodayPage>> todayPages,
      bool archived,
      String query,
      String? errorCode,
      UndoOffer? undo,
      int generation,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState() when $default != null:
        return $default(
          _that.read,
          _that.loading,
          _that.busy,
          _that.loadingMore,
          _that.plantPages,
          _that.todayPages,
          _that.archived,
          _that.query,
          _that.errorCode,
          _that.undo,
          _that.generation,
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
      WorkspaceRead? read,
      bool loading,
      bool busy,
      bool loadingMore,
      List<PlantsPage> plantPages,
      Map<TodaySection, List<TodayPage>> todayPages,
      bool archived,
      String query,
      String? errorCode,
      UndoOffer? undo,
      int generation,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState():
        return $default(
          _that.read,
          _that.loading,
          _that.busy,
          _that.loadingMore,
          _that.plantPages,
          _that.todayPages,
          _that.archived,
          _that.query,
          _that.errorCode,
          _that.undo,
          _that.generation,
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
      WorkspaceRead? read,
      bool loading,
      bool busy,
      bool loadingMore,
      List<PlantsPage> plantPages,
      Map<TodaySection, List<TodayPage>> todayPages,
      bool archived,
      String query,
      String? errorCode,
      UndoOffer? undo,
      int generation,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WorkspaceState() when $default != null:
        return $default(
          _that.read,
          _that.loading,
          _that.busy,
          _that.loadingMore,
          _that.plantPages,
          _that.todayPages,
          _that.archived,
          _that.query,
          _that.errorCode,
          _that.undo,
          _that.generation,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WorkspaceState implements WorkspaceState {
  const _WorkspaceState({
    this.read,
    this.loading = false,
    this.busy = false,
    this.loadingMore = false,
    List<PlantsPage> plantPages = const [],
    Map<TodaySection, List<TodayPage>> todayPages = const {},
    this.archived = false,
    this.query = '',
    this.errorCode,
    this.undo,
    this.generation = 0,
  }) : _plantPages = plantPages,
       _todayPages = todayPages;

  @override
  final WorkspaceRead? read;
  @override
  @JsonKey()
  final bool loading;
  @override
  @JsonKey()
  final bool busy;
  @override
  @JsonKey()
  final bool loadingMore;
  final List<PlantsPage> _plantPages;
  @override
  @JsonKey()
  List<PlantsPage> get plantPages {
    if (_plantPages is EqualUnmodifiableListView) return _plantPages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_plantPages);
  }

  final Map<TodaySection, List<TodayPage>> _todayPages;
  @override
  @JsonKey()
  Map<TodaySection, List<TodayPage>> get todayPages {
    if (_todayPages is EqualUnmodifiableMapView) return _todayPages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_todayPages);
  }

  @override
  @JsonKey()
  final bool archived;
  @override
  @JsonKey()
  final String query;
  @override
  final String? errorCode;
  @override
  final UndoOffer? undo;
  @override
  @JsonKey()
  final int generation;

  /// Create a copy of WorkspaceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WorkspaceStateCopyWith<_WorkspaceState> get copyWith =>
      __$WorkspaceStateCopyWithImpl<_WorkspaceState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WorkspaceState &&
            (identical(other.read, read) || other.read == read) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.loadingMore, loadingMore) ||
                other.loadingMore == loadingMore) &&
            const DeepCollectionEquality().equals(
              other.plantPages,
              _plantPages,
            ) &&
            const DeepCollectionEquality().equals(
              other.todayPages,
              _todayPages,
            ) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            (identical(other.undo, undo) || other.undo == undo) &&
            (identical(other.generation, generation) ||
                other.generation == generation));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      read,
      loading,
      busy,
      loadingMore,
      const DeepCollectionEquality().hash(_plantPages),
      const DeepCollectionEquality().hash(_todayPages),
      archived,
      query,
      errorCode,
      undo,
      generation,
    );
  }

  @override
  String toString() {
    return 'WorkspaceState(read: $read, loading: $loading, busy: $busy, loadingMore: $loadingMore, plantPages: $plantPages, todayPages: $todayPages, archived: $archived, query: $query, errorCode: $errorCode, undo: $undo, generation: $generation)';
  }
}

/// @nodoc
abstract mixin class _$WorkspaceStateCopyWith<$Res>
    implements $WorkspaceStateCopyWith<$Res> {
  factory _$WorkspaceStateCopyWith(
    _WorkspaceState value,
    $Res Function(_WorkspaceState) _then,
  ) = __$WorkspaceStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    WorkspaceRead? read,
    bool loading,
    bool busy,
    bool loadingMore,
    List<PlantsPage> plantPages,
    Map<TodaySection, List<TodayPage>> todayPages,
    bool archived,
    String query,
    String? errorCode,
    UndoOffer? undo,
    int generation,
  });
}

/// @nodoc
class __$WorkspaceStateCopyWithImpl<$Res>
    implements _$WorkspaceStateCopyWith<$Res> {
  __$WorkspaceStateCopyWithImpl(this._self, this._then);

  final _WorkspaceState _self;
  final $Res Function(_WorkspaceState) _then;

  /// Create a copy of WorkspaceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? read = freezed,
    Object? loading = null,
    Object? busy = null,
    Object? loadingMore = null,
    Object? plantPages = null,
    Object? todayPages = null,
    Object? archived = null,
    Object? query = null,
    Object? errorCode = freezed,
    Object? undo = freezed,
    Object? generation = null,
  }) {
    return _then(
      _WorkspaceState(
        read: freezed == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as WorkspaceRead?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadingMore: null == loadingMore
            ? _self.loadingMore
            : loadingMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        plantPages: null == plantPages
            ? _self._plantPages
            : plantPages // ignore: cast_nullable_to_non_nullable
                  as List<PlantsPage>,
        todayPages: null == todayPages
            ? _self._todayPages
            : todayPages // ignore: cast_nullable_to_non_nullable
                  as Map<TodaySection, List<TodayPage>>,
        archived: null == archived
            ? _self.archived
            : archived // ignore: cast_nullable_to_non_nullable
                  as bool,
        query: null == query
            ? _self.query
            : query // ignore: cast_nullable_to_non_nullable
                  as String,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        undo: freezed == undo
            ? _self.undo
            : undo // ignore: cast_nullable_to_non_nullable
                  as UndoOffer?,
        generation: null == generation
            ? _self.generation
            : generation // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}
