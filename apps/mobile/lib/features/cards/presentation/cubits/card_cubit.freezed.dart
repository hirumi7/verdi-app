// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'card_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CardState {
  bool get busy;
  List<PlantPhoto> get photos;
  List<String> get selected;
  String get imageChoice;
  bool get hasCover;
  String? get token;
  Uint8List? get bytes;
  String get name;
  String get species;
  List<String> get dates;
  String? get error;
  String? get outcome;

  /// Create a copy of CardState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CardStateCopyWith<CardState> get copyWith =>
      _$CardStateCopyWithImpl<CardState>(this as CardState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as CardState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CardState &&
            (identical(other.busy, _this.busy) || other.busy == _this.busy) &&
            const DeepCollectionEquality().equals(other.photos, _this.photos) &&
            const DeepCollectionEquality().equals(
              other.selected,
              _this.selected,
            ) &&
            (identical(other.imageChoice, _this.imageChoice) ||
                other.imageChoice == _this.imageChoice) &&
            (identical(other.hasCover, _this.hasCover) ||
                other.hasCover == _this.hasCover) &&
            (identical(other.token, _this.token) ||
                other.token == _this.token) &&
            const DeepCollectionEquality().equals(other.bytes, _this.bytes) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.species, _this.species) ||
                other.species == _this.species) &&
            const DeepCollectionEquality().equals(other.dates, _this.dates) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.outcome, _this.outcome) ||
                other.outcome == _this.outcome));
  }

  @override
  int get hashCode {
    final _this = this as CardState;
    return Object.hash(
      runtimeType,
      _this.busy,
      const DeepCollectionEquality().hash(_this.photos),
      const DeepCollectionEquality().hash(_this.selected),
      _this.imageChoice,
      _this.hasCover,
      _this.token,
      const DeepCollectionEquality().hash(_this.bytes),
      _this.name,
      _this.species,
      const DeepCollectionEquality().hash(_this.dates),
      _this.error,
      _this.outcome,
    );
  }

  @override
  String toString() {
    final _this = this as CardState;
    return 'CardState(busy: ${_this.busy}, photos: ${_this.photos}, selected: ${_this.selected}, imageChoice: ${_this.imageChoice}, hasCover: ${_this.hasCover}, token: ${_this.token}, bytes: ${_this.bytes}, name: ${_this.name}, species: ${_this.species}, dates: ${_this.dates}, error: ${_this.error}, outcome: ${_this.outcome})';
  }
}

/// @nodoc
abstract mixin class $CardStateCopyWith<$Res> {
  factory $CardStateCopyWith(CardState value, $Res Function(CardState) _then) =
      _$CardStateCopyWithImpl;
  @useResult
  $Res call({
    bool busy,
    List<PlantPhoto> photos,
    List<String> selected,
    String imageChoice,
    bool hasCover,
    String? token,
    Uint8List? bytes,
    String name,
    String species,
    List<String> dates,
    String? error,
    String? outcome,
  });
}

/// @nodoc
class _$CardStateCopyWithImpl<$Res> implements $CardStateCopyWith<$Res> {
  _$CardStateCopyWithImpl(this._self, this._then);

  final CardState _self;
  final $Res Function(CardState) _then;

  /// Create a copy of CardState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? busy = null,
    Object? photos = null,
    Object? selected = null,
    Object? imageChoice = null,
    Object? hasCover = null,
    Object? token = freezed,
    Object? bytes = freezed,
    Object? name = null,
    Object? species = null,
    Object? dates = null,
    Object? error = freezed,
    Object? outcome = freezed,
  }) {
    return _then(
      CardState(
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        photos: null == photos
            ? _self.photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        selected: null == selected
            ? _self.selected
            : selected // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        imageChoice: null == imageChoice
            ? _self.imageChoice
            : imageChoice // ignore: cast_nullable_to_non_nullable
                  as String,
        hasCover: null == hasCover
            ? _self.hasCover
            : hasCover // ignore: cast_nullable_to_non_nullable
                  as bool,
        token: freezed == token
            ? _self.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String?,
        bytes: freezed == bytes
            ? _self.bytes
            : bytes // ignore: cast_nullable_to_non_nullable
                  as Uint8List?,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        species: null == species
            ? _self.species
            : species // ignore: cast_nullable_to_non_nullable
                  as String,
        dates: null == dates
            ? _self.dates
            : dates // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        outcome: freezed == outcome
            ? _self.outcome
            : outcome // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [CardState].
extension CardStatePatterns on CardState {
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
    TResult Function(_CardState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CardState() when $default != null:
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
    TResult Function(_CardState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CardState():
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
    TResult? Function(_CardState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CardState() when $default != null:
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
      bool busy,
      List<PlantPhoto> photos,
      List<String> selected,
      String imageChoice,
      bool hasCover,
      String? token,
      Uint8List? bytes,
      String name,
      String species,
      List<String> dates,
      String? error,
      String? outcome,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CardState() when $default != null:
        return $default(
          _that.busy,
          _that.photos,
          _that.selected,
          _that.imageChoice,
          _that.hasCover,
          _that.token,
          _that.bytes,
          _that.name,
          _that.species,
          _that.dates,
          _that.error,
          _that.outcome,
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
      bool busy,
      List<PlantPhoto> photos,
      List<String> selected,
      String imageChoice,
      bool hasCover,
      String? token,
      Uint8List? bytes,
      String name,
      String species,
      List<String> dates,
      String? error,
      String? outcome,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CardState():
        return $default(
          _that.busy,
          _that.photos,
          _that.selected,
          _that.imageChoice,
          _that.hasCover,
          _that.token,
          _that.bytes,
          _that.name,
          _that.species,
          _that.dates,
          _that.error,
          _that.outcome,
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
      bool busy,
      List<PlantPhoto> photos,
      List<String> selected,
      String imageChoice,
      bool hasCover,
      String? token,
      Uint8List? bytes,
      String name,
      String species,
      List<String> dates,
      String? error,
      String? outcome,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CardState() when $default != null:
        return $default(
          _that.busy,
          _that.photos,
          _that.selected,
          _that.imageChoice,
          _that.hasCover,
          _that.token,
          _that.bytes,
          _that.name,
          _that.species,
          _that.dates,
          _that.error,
          _that.outcome,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CardState implements CardState {
  const _CardState({
    this.busy = false,
    List<PlantPhoto> photos = const [],
    List<String> selected = const [],
    this.imageChoice = 'illustration',
    this.hasCover = false,
    this.token,
    this.bytes,
    this.name = '',
    this.species = '',
    List<String> dates = const [],
    this.error,
    this.outcome,
  }) : _photos = photos,
       _selected = selected,
       _dates = dates;

  @override
  @JsonKey()
  final bool busy;
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
  final String imageChoice;
  @override
  @JsonKey()
  final bool hasCover;
  @override
  final String? token;
  @override
  final Uint8List? bytes;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String species;
  final List<String> _dates;
  @override
  @JsonKey()
  List<String> get dates {
    if (_dates is EqualUnmodifiableListView) return _dates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dates);
  }

  @override
  final String? error;
  @override
  final String? outcome;

  /// Create a copy of CardState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CardStateCopyWith<_CardState> get copyWith =>
      __$CardStateCopyWithImpl<_CardState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CardState &&
            (identical(other.busy, busy) || other.busy == busy) &&
            const DeepCollectionEquality().equals(other.photos, _photos) &&
            const DeepCollectionEquality().equals(other.selected, _selected) &&
            (identical(other.imageChoice, imageChoice) ||
                other.imageChoice == imageChoice) &&
            (identical(other.hasCover, hasCover) ||
                other.hasCover == hasCover) &&
            (identical(other.token, token) || other.token == token) &&
            const DeepCollectionEquality().equals(other.bytes, bytes) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.species, species) || other.species == species) &&
            const DeepCollectionEquality().equals(other.dates, _dates) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.outcome, outcome) || other.outcome == outcome));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      busy,
      const DeepCollectionEquality().hash(_photos),
      const DeepCollectionEquality().hash(_selected),
      imageChoice,
      hasCover,
      token,
      const DeepCollectionEquality().hash(bytes),
      name,
      species,
      const DeepCollectionEquality().hash(_dates),
      error,
      outcome,
    );
  }

  @override
  String toString() {
    return 'CardState(busy: $busy, photos: $photos, selected: $selected, imageChoice: $imageChoice, hasCover: $hasCover, token: $token, bytes: $bytes, name: $name, species: $species, dates: $dates, error: $error, outcome: $outcome)';
  }
}

/// @nodoc
abstract mixin class _$CardStateCopyWith<$Res>
    implements $CardStateCopyWith<$Res> {
  factory _$CardStateCopyWith(
    _CardState value,
    $Res Function(_CardState) _then,
  ) = __$CardStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    bool busy,
    List<PlantPhoto> photos,
    List<String> selected,
    String imageChoice,
    bool hasCover,
    String? token,
    Uint8List? bytes,
    String name,
    String species,
    List<String> dates,
    String? error,
    String? outcome,
  });
}

/// @nodoc
class __$CardStateCopyWithImpl<$Res> implements _$CardStateCopyWith<$Res> {
  __$CardStateCopyWithImpl(this._self, this._then);

  final _CardState _self;
  final $Res Function(_CardState) _then;

  /// Create a copy of CardState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? busy = null,
    Object? photos = null,
    Object? selected = null,
    Object? imageChoice = null,
    Object? hasCover = null,
    Object? token = freezed,
    Object? bytes = freezed,
    Object? name = null,
    Object? species = null,
    Object? dates = null,
    Object? error = freezed,
    Object? outcome = freezed,
  }) {
    return _then(
      _CardState(
        busy: null == busy
            ? _self.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
        photos: null == photos
            ? _self._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<PlantPhoto>,
        selected: null == selected
            ? _self._selected
            : selected // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        imageChoice: null == imageChoice
            ? _self.imageChoice
            : imageChoice // ignore: cast_nullable_to_non_nullable
                  as String,
        hasCover: null == hasCover
            ? _self.hasCover
            : hasCover // ignore: cast_nullable_to_non_nullable
                  as bool,
        token: freezed == token
            ? _self.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String?,
        bytes: freezed == bytes
            ? _self.bytes
            : bytes // ignore: cast_nullable_to_non_nullable
                  as Uint8List?,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        species: null == species
            ? _self.species
            : species // ignore: cast_nullable_to_non_nullable
                  as String,
        dates: null == dates
            ? _self._dates
            : dates // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        outcome: freezed == outcome
            ? _self.outcome
            : outcome // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
