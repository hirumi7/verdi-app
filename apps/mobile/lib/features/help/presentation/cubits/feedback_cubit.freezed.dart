// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feedback_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedbackState {
  bool get ready;
  bool get busy;
  bool get dirty;
  String get subject;
  String get body;
  String? get subjectError;
  String? get bodyError;
  String? get status;

  /// Create a copy of FeedbackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FeedbackStateCopyWith<FeedbackState> get copyWith =>
      _$FeedbackStateCopyWithImpl<FeedbackState>(
        this as FeedbackState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as FeedbackState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FeedbackState &&
            (identical(other.ready, _this.ready) ||
                other.ready == _this.ready) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.dirty, _this.dirty) ||
                other.dirty == _this.dirty) &&
            (identical(other.subject, _this.subject) ||
                other.subject == _this.subject) &&
            (identical(other.body, _this.body) || other.body == _this.body) &&
            (identical(other.subjectError, _this.subjectError) ||
                other.subjectError == _this.subjectError) &&
            (identical(other.bodyError, _this.bodyError) ||
                other.bodyError == _this.bodyError) &&
            (identical(other.status, _this.status) ||
                other.status == _this.status));
  }

  @override
  int get hashCode {
    final _this = this as FeedbackState;
    return Object.hash(
      runtimeType,
      _this.ready,
      _this.busy,
      _this.dirty,
      _this.subject,
      _this.body,
      _this.subjectError,
      _this.bodyError,
      _this.status,
    );
  }

  @override
  String toString() {
    final _this = this as FeedbackState;
    return 'FeedbackState(ready: ${_this.ready}, busy: ${_this.busy}, dirty: ${_this.dirty}, subject: ${_this.subject}, body: ${_this.body}, subjectError: ${_this.subjectError}, bodyError: ${_this.bodyError}, status: ${_this.status})';
  }
}

/// @nodoc
abstract mixin class $FeedbackStateCopyWith<$Res> {
  factory $FeedbackStateCopyWith(
    FeedbackState value,
    $Res Function(FeedbackState) _then,
  ) = _$FeedbackStateCopyWithImpl;
  @useResult
  $Res call({
    bool ready,
    bool busy,
    bool dirty,
    String subject,
    String body,
    String? subjectError,
    String? bodyError,
    String? status,
  });
}

/// @nodoc
class _$FeedbackStateCopyWithImpl<$Res>
    implements $FeedbackStateCopyWith<$Res> {
  _$FeedbackStateCopyWithImpl(this._self, this._then);

  final FeedbackState _self;
  final $Res Function(FeedbackState) _then;

  /// Create a copy of FeedbackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ready = null,
    Object? busy = null,
    Object? dirty = null,
    Object? subject = null,
    Object? body = null,
    Object? subjectError = freezed,
    Object? bodyError = freezed,
    Object? status = freezed,
  }) {
    return _then(
      FeedbackState(
        ready: null == ready
            ? _self.ready
            : ready // ignore: cast_nullable_to_non_nullable
                  as bool,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        dirty: null == dirty
            ? _self.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        subject: null == subject
            ? _self.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _self.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        subjectError: freezed == subjectError
            ? _self.subjectError
            : subjectError // ignore: cast_nullable_to_non_nullable
                  as String?,
        bodyError: freezed == bodyError
            ? _self.bodyError
            : bodyError // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _self.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [FeedbackState].
extension FeedbackStatePatterns on FeedbackState {
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
    TResult Function(_FeedbackState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeedbackState() when $default != null:
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
    TResult Function(_FeedbackState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedbackState():
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
    TResult? Function(_FeedbackState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedbackState() when $default != null:
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
      bool ready,
      bool busy,
      bool dirty,
      String subject,
      String body,
      String? subjectError,
      String? bodyError,
      String? status,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeedbackState() when $default != null:
        return $default(
          _that.ready,
          _that.busy,
          _that.dirty,
          _that.subject,
          _that.body,
          _that.subjectError,
          _that.bodyError,
          _that.status,
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
      bool ready,
      bool busy,
      bool dirty,
      String subject,
      String body,
      String? subjectError,
      String? bodyError,
      String? status,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedbackState():
        return $default(
          _that.ready,
          _that.busy,
          _that.dirty,
          _that.subject,
          _that.body,
          _that.subjectError,
          _that.bodyError,
          _that.status,
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
      bool ready,
      bool busy,
      bool dirty,
      String subject,
      String body,
      String? subjectError,
      String? bodyError,
      String? status,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedbackState() when $default != null:
        return $default(
          _that.ready,
          _that.busy,
          _that.dirty,
          _that.subject,
          _that.body,
          _that.subjectError,
          _that.bodyError,
          _that.status,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FeedbackState implements FeedbackState {
  const _FeedbackState({
    this.ready = false,
    this.busy = false,
    this.dirty = false,
    this.subject = '',
    this.body = '',
    this.subjectError,
    this.bodyError,
    this.status,
  });

  @override
  @JsonKey()
  final bool ready;
  @override
  @JsonKey()
  final bool busy;
  @override
  @JsonKey()
  final bool dirty;
  @override
  @JsonKey()
  final String subject;
  @override
  @JsonKey()
  final String body;
  @override
  final String? subjectError;
  @override
  final String? bodyError;
  @override
  final String? status;

  /// Create a copy of FeedbackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FeedbackStateCopyWith<_FeedbackState> get copyWith =>
      __$FeedbackStateCopyWithImpl<_FeedbackState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FeedbackState &&
            (identical(other.ready, ready) || other.ready == ready) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.subjectError, subjectError) ||
                other.subjectError == subjectError) &&
            (identical(other.bodyError, bodyError) ||
                other.bodyError == bodyError) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      ready,
      busy,
      dirty,
      subject,
      body,
      subjectError,
      bodyError,
      status,
    );
  }

  @override
  String toString() {
    return 'FeedbackState(ready: $ready, busy: $busy, dirty: $dirty, subject: $subject, body: $body, subjectError: $subjectError, bodyError: $bodyError, status: $status)';
  }
}

/// @nodoc
abstract mixin class _$FeedbackStateCopyWith<$Res>
    implements $FeedbackStateCopyWith<$Res> {
  factory _$FeedbackStateCopyWith(
    _FeedbackState value,
    $Res Function(_FeedbackState) _then,
  ) = __$FeedbackStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    bool ready,
    bool busy,
    bool dirty,
    String subject,
    String body,
    String? subjectError,
    String? bodyError,
    String? status,
  });
}

/// @nodoc
class __$FeedbackStateCopyWithImpl<$Res>
    implements _$FeedbackStateCopyWith<$Res> {
  __$FeedbackStateCopyWithImpl(this._self, this._then);

  final _FeedbackState _self;
  final $Res Function(_FeedbackState) _then;

  /// Create a copy of FeedbackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? ready = null,
    Object? busy = null,
    Object? dirty = null,
    Object? subject = null,
    Object? body = null,
    Object? subjectError = freezed,
    Object? bodyError = freezed,
    Object? status = freezed,
  }) {
    return _then(
      _FeedbackState(
        ready: null == ready
            ? _self.ready
            : ready // ignore: cast_nullable_to_non_nullable
                  as bool,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        dirty: null == dirty
            ? _self.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        subject: null == subject
            ? _self.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _self.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        subjectError: freezed == subjectError
            ? _self.subjectError
            : subjectError // ignore: cast_nullable_to_non_nullable
                  as String?,
        bodyError: freezed == bodyError
            ? _self.bodyError
            : bodyError // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _self.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
