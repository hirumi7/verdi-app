// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'optimization_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OptimizationState {
  List<PlantPhoto> get photos;
  List<String> get selected;
  bool get busy;
  bool get running;
  bool get recoveryRequired;
  Map<String, Object?>? get preview;
  Map<String, Object?>? get job;
  String? get error;

  /// Create a copy of OptimizationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OptimizationStateCopyWith<OptimizationState> get copyWith =>
      _$OptimizationStateCopyWithImpl<OptimizationState>(
        this as OptimizationState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as OptimizationState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OptimizationState &&
            const DeepCollectionEquality().equals(other.photos, _this.photos) &&
            const DeepCollectionEquality().equals(
              other.selected,
              _this.selected,
            ) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.running, _this.running) ||
                other.running == _this.running) &&
            (identical(other.recoveryRequired, _this.recoveryRequired) ||
                other.recoveryRequired == _this.recoveryRequired) &&
            const DeepCollectionEquality().equals(
              other.preview,
              _this.preview,
            ) &&
            const DeepCollectionEquality().equals(other.job, _this.job) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as OptimizationState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.photos),
      const DeepCollectionEquality().hash(_this.selected),
      _this.busy,
      _this.running,
      _this.recoveryRequired,
      const DeepCollectionEquality().hash(_this.preview),
      const DeepCollectionEquality().hash(_this.job),
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as OptimizationState;
    return 'OptimizationState(photos: ${_this.photos}, selected: ${_this.selected}, busy: ${_this.busy}, running: ${_this.running}, recoveryRequired: ${_this.recoveryRequired}, preview: ${_this.preview}, job: ${_this.job}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $OptimizationStateCopyWith<$Res> {
  factory $OptimizationStateCopyWith(
    OptimizationState value,
    $Res Function(OptimizationState) _then,
  ) = _$OptimizationStateCopyWithImpl;
  @useResult
  $Res call({
    List<PlantPhoto> photos,
    List<String> selected,
    bool busy,
    bool running,
    bool recoveryRequired,
    Map<String, Object?>? preview,
    Map<String, Object?>? job,
    String? error,
  });
}

/// @nodoc
class _$OptimizationStateCopyWithImpl<$Res>
    implements $OptimizationStateCopyWith<$Res> {
  _$OptimizationStateCopyWithImpl(this._self, this._then);

  final OptimizationState _self;
  final $Res Function(OptimizationState) _then;

  /// Create a copy of OptimizationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? photos = null,
    Object? selected = null,
    Object? busy = null,
    Object? running = null,
    Object? recoveryRequired = null,
    Object? preview = freezed,
    Object? job = freezed,
    Object? error = freezed,
  }) {
    return _then(
      OptimizationState(
        photos: null == photos
            ? _self.photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        selected: null == selected
            ? _self.selected
            : selected // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        running: null == running
            ? _self.running
            : running // ignore: cast_nullable_to_non_nullable
                  as bool,
        recoveryRequired: null == recoveryRequired
            ? _self.recoveryRequired
            : recoveryRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        preview: freezed == preview
            ? _self.preview
            : preview // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        job: freezed == job
            ? _self.job
            : job // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [OptimizationState].
extension OptimizationStatePatterns on OptimizationState {
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
    TResult Function(_OptimizationState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OptimizationState() when $default != null:
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
    TResult Function(_OptimizationState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OptimizationState():
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
    TResult? Function(_OptimizationState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OptimizationState() when $default != null:
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
      List<PlantPhoto> photos,
      List<String> selected,
      bool busy,
      bool running,
      bool recoveryRequired,
      Map<String, Object?>? preview,
      Map<String, Object?>? job,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OptimizationState() when $default != null:
        return $default(
          _that.photos,
          _that.selected,
          _that.busy,
          _that.running,
          _that.recoveryRequired,
          _that.preview,
          _that.job,
          _that.error,
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
      List<PlantPhoto> photos,
      List<String> selected,
      bool busy,
      bool running,
      bool recoveryRequired,
      Map<String, Object?>? preview,
      Map<String, Object?>? job,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OptimizationState():
        return $default(
          _that.photos,
          _that.selected,
          _that.busy,
          _that.running,
          _that.recoveryRequired,
          _that.preview,
          _that.job,
          _that.error,
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
      List<PlantPhoto> photos,
      List<String> selected,
      bool busy,
      bool running,
      bool recoveryRequired,
      Map<String, Object?>? preview,
      Map<String, Object?>? job,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OptimizationState() when $default != null:
        return $default(
          _that.photos,
          _that.selected,
          _that.busy,
          _that.running,
          _that.recoveryRequired,
          _that.preview,
          _that.job,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _OptimizationState implements OptimizationState {
  const _OptimizationState({
    List<PlantPhoto> photos = const [],
    List<String> selected = const [],
    this.busy = false,
    this.running = false,
    this.recoveryRequired = false,
    Map<String, Object?>? preview,
    Map<String, Object?>? job,
    this.error,
  }) : _photos = photos,
       _selected = selected,
       _preview = preview,
       _job = job;

  final List<PlantPhoto> _photos;
  @override
  @JsonKey()
  List<PlantPhoto> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  final List<String> _selected;
  @override
  @JsonKey()
  List<String> get selected {
    if (_selected is EqualUnmodifiableListView) return _selected;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selected);
  }

  @override
  @JsonKey()
  final bool busy;
  @override
  @JsonKey()
  final bool running;
  @override
  @JsonKey()
  final bool recoveryRequired;
  final Map<String, Object?>? _preview;
  @override
  Map<String, Object?>? get preview {
    final value = _preview;
    if (value == null) return null;
    if (_preview is EqualUnmodifiableMapView) return _preview;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final Map<String, Object?>? _job;
  @override
  Map<String, Object?>? get job {
    final value = _job;
    if (value == null) return null;
    if (_job is EqualUnmodifiableMapView) return _job;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? error;

  /// Create a copy of OptimizationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OptimizationStateCopyWith<_OptimizationState> get copyWith =>
      __$OptimizationStateCopyWithImpl<_OptimizationState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OptimizationState &&
            const DeepCollectionEquality().equals(other.photos, _photos) &&
            const DeepCollectionEquality().equals(other.selected, _selected) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.running, running) || other.running == running) &&
            (identical(other.recoveryRequired, recoveryRequired) ||
                other.recoveryRequired == recoveryRequired) &&
            const DeepCollectionEquality().equals(other.preview, _preview) &&
            const DeepCollectionEquality().equals(other.job, _job) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_photos),
      const DeepCollectionEquality().hash(_selected),
      busy,
      running,
      recoveryRequired,
      const DeepCollectionEquality().hash(_preview),
      const DeepCollectionEquality().hash(_job),
      error,
    );
  }

  @override
  String toString() {
    return 'OptimizationState(photos: $photos, selected: $selected, busy: $busy, running: $running, recoveryRequired: $recoveryRequired, preview: $preview, job: $job, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$OptimizationStateCopyWith<$Res>
    implements $OptimizationStateCopyWith<$Res> {
  factory _$OptimizationStateCopyWith(
    _OptimizationState value,
    $Res Function(_OptimizationState) _then,
  ) = __$OptimizationStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<PlantPhoto> photos,
    List<String> selected,
    bool busy,
    bool running,
    bool recoveryRequired,
    Map<String, Object?>? preview,
    Map<String, Object?>? job,
    String? error,
  });
}

/// @nodoc
class __$OptimizationStateCopyWithImpl<$Res>
    implements _$OptimizationStateCopyWith<$Res> {
  __$OptimizationStateCopyWithImpl(this._self, this._then);

  final _OptimizationState _self;
  final $Res Function(_OptimizationState) _then;

  /// Create a copy of OptimizationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? photos = null,
    Object? selected = null,
    Object? busy = null,
    Object? running = null,
    Object? recoveryRequired = null,
    Object? preview = freezed,
    Object? job = freezed,
    Object? error = freezed,
  }) {
    return _then(
      _OptimizationState(
        photos: null == photos
            ? _self._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        selected: null == selected
            ? _self._selected
            : selected // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        running: null == running
            ? _self.running
            : running // ignore: cast_nullable_to_non_nullable
                  as bool,
        recoveryRequired: null == recoveryRequired
            ? _self.recoveryRequired
            : recoveryRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        preview: freezed == preview
            ? _self._preview
            : preview // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        job: freezed == job
            ? _self._job
            : job // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
