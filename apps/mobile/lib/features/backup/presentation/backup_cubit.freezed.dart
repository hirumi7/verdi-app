// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BackupState {
  Map<String, Object?>? get operation;
  bool get busy;
  bool get replacing;
  String? get error;
  String? get shareResult;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BackupStateCopyWith<BackupState> get copyWith =>
      _$BackupStateCopyWithImpl<BackupState>(this as BackupState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as BackupState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BackupState &&
            const DeepCollectionEquality().equals(
              other.operation,
              _this.operation,
            ) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.replacing, _this.replacing) ||
                other.replacing == _this.replacing) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.shareResult, _this.shareResult) ||
                other.shareResult == _this.shareResult));
  }

  @override
  int get hashCode {
    final _this = this as BackupState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.operation),
      _this.busy,
      _this.replacing,
      _this.error,
      _this.shareResult,
    );
  }

  @override
  String toString() {
    final _this = this as BackupState;
    return 'BackupState(operation: ${_this.operation}, busy: ${_this.busy}, replacing: ${_this.replacing}, error: ${_this.error}, shareResult: ${_this.shareResult})';
  }
}

/// @nodoc
abstract mixin class $BackupStateCopyWith<$Res> {
  factory $BackupStateCopyWith(
    BackupState value,
    $Res Function(BackupState) _then,
  ) = _$BackupStateCopyWithImpl;
  @useResult
  $Res call({
    Map<String, Object?>? operation,
    bool busy,
    bool replacing,
    String? error,
    String? shareResult,
  });
}

/// @nodoc
class _$BackupStateCopyWithImpl<$Res> implements $BackupStateCopyWith<$Res> {
  _$BackupStateCopyWithImpl(this._self, this._then);

  final BackupState _self;
  final $Res Function(BackupState) _then;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? operation = freezed,
    Object? busy = null,
    Object? replacing = null,
    Object? error = freezed,
    Object? shareResult = freezed,
  }) {
    return _then(
      BackupState(
        operation: freezed == operation
            ? _self.operation
            : operation // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        replacing: null == replacing
            ? _self.replacing
            : replacing // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        shareResult: freezed == shareResult
            ? _self.shareResult
            : shareResult // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BackupState].
extension BackupStatePatterns on BackupState {
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
    TResult Function(_BackupState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BackupState() when $default != null:
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
    TResult Function(_BackupState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BackupState():
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
    TResult? Function(_BackupState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BackupState() when $default != null:
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
      Map<String, Object?>? operation,
      bool busy,
      bool replacing,
      String? error,
      String? shareResult,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BackupState() when $default != null:
        return $default(
          _that.operation,
          _that.busy,
          _that.replacing,
          _that.error,
          _that.shareResult,
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
      Map<String, Object?>? operation,
      bool busy,
      bool replacing,
      String? error,
      String? shareResult,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BackupState():
        return $default(
          _that.operation,
          _that.busy,
          _that.replacing,
          _that.error,
          _that.shareResult,
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
      Map<String, Object?>? operation,
      bool busy,
      bool replacing,
      String? error,
      String? shareResult,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BackupState() when $default != null:
        return $default(
          _that.operation,
          _that.busy,
          _that.replacing,
          _that.error,
          _that.shareResult,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BackupState extends BackupState {
  const _BackupState({
    Map<String, Object?>? operation,
    this.busy = false,
    this.replacing = false,
    this.error,
    this.shareResult,
  }) : _operation = operation,
       super._();

  final Map<String, Object?>? _operation;
  @override
  Map<String, Object?>? get operation {
    final value = _operation;
    if (value == null) return null;
    if (_operation is EqualUnmodifiableMapView) return _operation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final bool busy;
  @override
  @JsonKey()
  final bool replacing;
  @override
  final String? error;
  @override
  final String? shareResult;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BackupStateCopyWith<_BackupState> get copyWith =>
      __$BackupStateCopyWithImpl<_BackupState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BackupState &&
            const DeepCollectionEquality().equals(
              other.operation,
              _operation,
            ) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.replacing, replacing) ||
                other.replacing == replacing) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.shareResult, shareResult) ||
                other.shareResult == shareResult));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_operation),
      busy,
      replacing,
      error,
      shareResult,
    );
  }

  @override
  String toString() {
    return 'BackupState(operation: $operation, busy: $busy, replacing: $replacing, error: $error, shareResult: $shareResult)';
  }
}

/// @nodoc
abstract mixin class _$BackupStateCopyWith<$Res>
    implements $BackupStateCopyWith<$Res> {
  factory _$BackupStateCopyWith(
    _BackupState value,
    $Res Function(_BackupState) _then,
  ) = __$BackupStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    Map<String, Object?>? operation,
    bool busy,
    bool replacing,
    String? error,
    String? shareResult,
  });
}

/// @nodoc
class __$BackupStateCopyWithImpl<$Res> implements _$BackupStateCopyWith<$Res> {
  __$BackupStateCopyWithImpl(this._self, this._then);

  final _BackupState _self;
  final $Res Function(_BackupState) _then;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? operation = freezed,
    Object? busy = null,
    Object? replacing = null,
    Object? error = freezed,
    Object? shareResult = freezed,
  }) {
    return _then(
      _BackupState(
        operation: freezed == operation
            ? _self._operation
            : operation // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        replacing: null == replacing
            ? _self.replacing
            : replacing // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        shareResult: freezed == shareResult
            ? _self.shareResult
            : shareResult // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
