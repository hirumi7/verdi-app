// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reminder_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReminderState {
  Map<String, Object?>? get data;
  Map<String, Object?> get draft;
  Map<String, Object?>? get tap;
  bool get busy;
  bool get unresolved;
  bool get saved;
  String? get error;

  /// Create a copy of ReminderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReminderStateCopyWith<ReminderState> get copyWith =>
      _$ReminderStateCopyWithImpl<ReminderState>(
        this as ReminderState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ReminderState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReminderState &&
            const DeepCollectionEquality().equals(other.data, _this.data) &&
            const DeepCollectionEquality().equals(other.draft, _this.draft) &&
            const DeepCollectionEquality().equals(other.tap, _this.tap) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.unresolved, _this.unresolved) ||
                other.unresolved == _this.unresolved) &&
            (identical(other.saved, _this.saved) ||
                other.saved == _this.saved) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as ReminderState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.data),
      const DeepCollectionEquality().hash(_this.draft),
      const DeepCollectionEquality().hash(_this.tap),
      _this.busy,
      _this.unresolved,
      _this.saved,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as ReminderState;
    return 'ReminderState(data: ${_this.data}, draft: ${_this.draft}, tap: ${_this.tap}, busy: ${_this.busy}, unresolved: ${_this.unresolved}, saved: ${_this.saved}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $ReminderStateCopyWith<$Res> {
  factory $ReminderStateCopyWith(
    ReminderState value,
    $Res Function(ReminderState) _then,
  ) = _$ReminderStateCopyWithImpl;
  @useResult
  $Res call({
    Map<String, Object?>? data,
    Map<String, Object?> draft,
    Map<String, Object?>? tap,
    bool busy,
    bool unresolved,
    bool saved,
    String? error,
  });
}

/// @nodoc
class _$ReminderStateCopyWithImpl<$Res>
    implements $ReminderStateCopyWith<$Res> {
  _$ReminderStateCopyWithImpl(this._self, this._then);

  final ReminderState _self;
  final $Res Function(ReminderState) _then;

  /// Create a copy of ReminderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = freezed,
    Object? draft = null,
    Object? tap = freezed,
    Object? busy = null,
    Object? unresolved = null,
    Object? saved = null,
    Object? error = freezed,
  }) {
    return _then(
      ReminderState(
        data: freezed == data
            ? _self.data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        draft: null == draft
            ? _self.draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        tap: freezed == tap
            ? _self.tap
            : tap // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        unresolved: null == unresolved
            ? _self.unresolved
            : unresolved // ignore: cast_nullable_to_non_nullable
                  as bool,
        saved: null == saved
            ? _self.saved
            : saved // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReminderState].
extension ReminderStatePatterns on ReminderState {
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
    TResult Function(_ReminderState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReminderState() when $default != null:
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
    TResult Function(_ReminderState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReminderState():
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
    TResult? Function(_ReminderState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReminderState() when $default != null:
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
      Map<String, Object?>? data,
      Map<String, Object?> draft,
      Map<String, Object?>? tap,
      bool busy,
      bool unresolved,
      bool saved,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReminderState() when $default != null:
        return $default(
          _that.data,
          _that.draft,
          _that.tap,
          _that.busy,
          _that.unresolved,
          _that.saved,
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
      Map<String, Object?>? data,
      Map<String, Object?> draft,
      Map<String, Object?>? tap,
      bool busy,
      bool unresolved,
      bool saved,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReminderState():
        return $default(
          _that.data,
          _that.draft,
          _that.tap,
          _that.busy,
          _that.unresolved,
          _that.saved,
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
      Map<String, Object?>? data,
      Map<String, Object?> draft,
      Map<String, Object?>? tap,
      bool busy,
      bool unresolved,
      bool saved,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReminderState() when $default != null:
        return $default(
          _that.data,
          _that.draft,
          _that.tap,
          _that.busy,
          _that.unresolved,
          _that.saved,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ReminderState extends ReminderState {
  const _ReminderState({
    Map<String, Object?>? data,
    Map<String, Object?> draft = const {},
    Map<String, Object?>? tap,
    this.busy = false,
    this.unresolved = false,
    this.saved = false,
    this.error,
  }) : _data = data,
       _draft = draft,
       _tap = tap,
       super._();

  final Map<String, Object?>? _data;
  @override
  Map<String, Object?>? get data {
    final value = _data;
    if (value == null) return null;
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final Map<String, Object?> _draft;
  @override
  @JsonKey()
  Map<String, Object?> get draft {
    if (_draft is EqualUnmodifiableMapView) return _draft;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_draft);
  }

  final Map<String, Object?>? _tap;
  @override
  Map<String, Object?>? get tap {
    final value = _tap;
    if (value == null) return null;
    if (_tap is EqualUnmodifiableMapView) return _tap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final bool busy;
  @override
  @JsonKey()
  final bool unresolved;
  @override
  @JsonKey()
  final bool saved;
  @override
  final String? error;

  /// Create a copy of ReminderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReminderStateCopyWith<_ReminderState> get copyWith =>
      __$ReminderStateCopyWithImpl<_ReminderState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReminderState &&
            const DeepCollectionEquality().equals(other.data, _data) &&
            const DeepCollectionEquality().equals(other.draft, _draft) &&
            const DeepCollectionEquality().equals(other.tap, _tap) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.unresolved, unresolved) ||
                other.unresolved == unresolved) &&
            (identical(other.saved, saved) || other.saved == saved) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_data),
      const DeepCollectionEquality().hash(_draft),
      const DeepCollectionEquality().hash(_tap),
      busy,
      unresolved,
      saved,
      error,
    );
  }

  @override
  String toString() {
    return 'ReminderState(data: $data, draft: $draft, tap: $tap, busy: $busy, unresolved: $unresolved, saved: $saved, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ReminderStateCopyWith<$Res>
    implements $ReminderStateCopyWith<$Res> {
  factory _$ReminderStateCopyWith(
    _ReminderState value,
    $Res Function(_ReminderState) _then,
  ) = __$ReminderStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    Map<String, Object?>? data,
    Map<String, Object?> draft,
    Map<String, Object?>? tap,
    bool busy,
    bool unresolved,
    bool saved,
    String? error,
  });
}

/// @nodoc
class __$ReminderStateCopyWithImpl<$Res>
    implements _$ReminderStateCopyWith<$Res> {
  __$ReminderStateCopyWithImpl(this._self, this._then);

  final _ReminderState _self;
  final $Res Function(_ReminderState) _then;

  /// Create a copy of ReminderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? data = freezed,
    Object? draft = null,
    Object? tap = freezed,
    Object? busy = null,
    Object? unresolved = null,
    Object? saved = null,
    Object? error = freezed,
  }) {
    return _then(
      _ReminderState(
        data: freezed == data
            ? _self._data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        draft: null == draft
            ? _self._draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        tap: freezed == tap
            ? _self._tap
            : tap // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        unresolved: null == unresolved
            ? _self.unresolved
            : unresolved // ignore: cast_nullable_to_non_nullable
                  as bool,
        saved: null == saved
            ? _self.saved
            : saved // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
