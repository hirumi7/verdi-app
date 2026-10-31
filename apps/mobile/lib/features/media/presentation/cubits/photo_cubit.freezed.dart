// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PhotoState {
  List<PlantPhoto> get photos;
  String? get coverId;
  MediaDraft? get replacement;
  bool get busy;
  String? get errorCode;
  String? get preparationId;
  String? get preparationKind;

  /// Create a copy of PhotoState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PhotoStateCopyWith<PhotoState> get copyWith =>
      _$PhotoStateCopyWithImpl<PhotoState>(this as PhotoState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as PhotoState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PhotoState &&
            const DeepCollectionEquality().equals(other.photos, _this.photos) &&
            (identical(other.coverId, _this.coverId) ||
                other.coverId == _this.coverId) &&
            (identical(other.replacement, _this.replacement) ||
                other.replacement == _this.replacement) &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            (identical(other.errorCode, _this.errorCode) ||
                other.errorCode == _this.errorCode) &&
            (identical(other.preparationId, _this.preparationId) ||
                other.preparationId == _this.preparationId) &&
            (identical(other.preparationKind, _this.preparationKind) ||
                other.preparationKind == _this.preparationKind));
  }

  @override
  int get hashCode {
    final _this = this as PhotoState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.photos),
      _this.coverId,
      _this.replacement,
      _this.busy,
      _this.errorCode,
      _this.preparationId,
      _this.preparationKind,
    );
  }

  @override
  String toString() {
    final _this = this as PhotoState;
    return 'PhotoState(photos: ${_this.photos}, coverId: ${_this.coverId}, replacement: ${_this.replacement}, busy: ${_this.busy}, errorCode: ${_this.errorCode}, preparationId: ${_this.preparationId}, preparationKind: ${_this.preparationKind})';
  }
}

/// @nodoc
abstract mixin class $PhotoStateCopyWith<$Res> {
  factory $PhotoStateCopyWith(
    PhotoState value,
    $Res Function(PhotoState) _then,
  ) = _$PhotoStateCopyWithImpl;
  @useResult
  $Res call({
    List<PlantPhoto> photos,
    String? coverId,
    MediaDraft? replacement,
    bool busy,
    String? errorCode,
    String? preparationId,
    String? preparationKind,
  });
}

/// @nodoc
class _$PhotoStateCopyWithImpl<$Res> implements $PhotoStateCopyWith<$Res> {
  _$PhotoStateCopyWithImpl(this._self, this._then);

  final PhotoState _self;
  final $Res Function(PhotoState) _then;

  /// Create a copy of PhotoState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? photos = null,
    Object? coverId = freezed,
    Object? replacement = freezed,
    Object? busy = null,
    Object? errorCode = freezed,
    Object? preparationId = freezed,
    Object? preparationKind = freezed,
  }) {
    return _then(
      PhotoState(
        photos: null == photos
            ? _self.photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        coverId: freezed == coverId
            ? _self.coverId
            : coverId // ignore: cast_nullable_to_non_nullable
                  as String?,
        replacement: freezed == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as MediaDraft?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        preparationId: freezed == preparationId
            ? _self.preparationId
            : preparationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        preparationKind: freezed == preparationKind
            ? _self.preparationKind
            : preparationKind // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [PhotoState].
extension PhotoStatePatterns on PhotoState {
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
    TResult Function(_PhotoState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PhotoState() when $default != null:
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
    TResult Function(_PhotoState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PhotoState():
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
    TResult? Function(_PhotoState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PhotoState() when $default != null:
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
      String? coverId,
      MediaDraft? replacement,
      bool busy,
      String? errorCode,
      String? preparationId,
      String? preparationKind,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PhotoState() when $default != null:
        return $default(
          _that.photos,
          _that.coverId,
          _that.replacement,
          _that.busy,
          _that.errorCode,
          _that.preparationId,
          _that.preparationKind,
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
      String? coverId,
      MediaDraft? replacement,
      bool busy,
      String? errorCode,
      String? preparationId,
      String? preparationKind,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PhotoState():
        return $default(
          _that.photos,
          _that.coverId,
          _that.replacement,
          _that.busy,
          _that.errorCode,
          _that.preparationId,
          _that.preparationKind,
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
      String? coverId,
      MediaDraft? replacement,
      bool busy,
      String? errorCode,
      String? preparationId,
      String? preparationKind,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PhotoState() when $default != null:
        return $default(
          _that.photos,
          _that.coverId,
          _that.replacement,
          _that.busy,
          _that.errorCode,
          _that.preparationId,
          _that.preparationKind,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PhotoState implements PhotoState {
  const _PhotoState({
    List<PlantPhoto> photos = const [],
    this.coverId,
    this.replacement,
    this.busy = false,
    this.errorCode,
    this.preparationId,
    this.preparationKind,
  }) : _photos = photos;

  final List<PlantPhoto> _photos;
  @override
  @JsonKey()
  List<PlantPhoto> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  @override
  final String? coverId;
  @override
  final MediaDraft? replacement;
  @override
  @JsonKey()
  final bool busy;
  @override
  final String? errorCode;
  @override
  final String? preparationId;
  @override
  final String? preparationKind;

  /// Create a copy of PhotoState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PhotoStateCopyWith<_PhotoState> get copyWith =>
      __$PhotoStateCopyWithImpl<_PhotoState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PhotoState &&
            const DeepCollectionEquality().equals(other.photos, _photos) &&
            (identical(other.coverId, coverId) || other.coverId == coverId) &&
            (identical(other.replacement, replacement) ||
                other.replacement == replacement) &&
            (identical(other.busy, busy) || other.busy == busy) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            (identical(other.preparationId, preparationId) ||
                other.preparationId == preparationId) &&
            (identical(other.preparationKind, preparationKind) ||
                other.preparationKind == preparationKind));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_photos),
      coverId,
      replacement,
      busy,
      errorCode,
      preparationId,
      preparationKind,
    );
  }

  @override
  String toString() {
    return 'PhotoState(photos: $photos, coverId: $coverId, replacement: $replacement, busy: $busy, errorCode: $errorCode, preparationId: $preparationId, preparationKind: $preparationKind)';
  }
}

/// @nodoc
abstract mixin class _$PhotoStateCopyWith<$Res>
    implements $PhotoStateCopyWith<$Res> {
  factory _$PhotoStateCopyWith(
    _PhotoState value,
    $Res Function(_PhotoState) _then,
  ) = __$PhotoStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<PlantPhoto> photos,
    String? coverId,
    MediaDraft? replacement,
    bool busy,
    String? errorCode,
    String? preparationId,
    String? preparationKind,
  });
}

/// @nodoc
class __$PhotoStateCopyWithImpl<$Res> implements _$PhotoStateCopyWith<$Res> {
  __$PhotoStateCopyWithImpl(this._self, this._then);

  final _PhotoState _self;
  final $Res Function(_PhotoState) _then;

  /// Create a copy of PhotoState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? photos = null,
    Object? coverId = freezed,
    Object? replacement = freezed,
    Object? busy = null,
    Object? errorCode = freezed,
    Object? preparationId = freezed,
    Object? preparationKind = freezed,
  }) {
    return _then(
      _PhotoState(
        photos: null == photos
            ? _self._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        coverId: freezed == coverId
            ? _self.coverId
            : coverId // ignore: cast_nullable_to_non_nullable
                  as String?,
        replacement: freezed == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as MediaDraft?,
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        preparationId: freezed == preparationId
            ? _self.preparationId
            : preparationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        preparationKind: freezed == preparationKind
            ? _self.preparationKind
            : preparationKind // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
