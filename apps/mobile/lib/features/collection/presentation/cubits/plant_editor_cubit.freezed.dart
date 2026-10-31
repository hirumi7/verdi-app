// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plant_editor_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlantEditorState {
  CustomPlantFields? get fields;
  PlantDraft? get draft;
  bool get loading;
  bool get picking;
  List<RoutineRead> get existingRoutines;
  bool get saving;
  bool get dirty;
  bool get photoPending;
  bool get photoFailed;
  String? get errorCode;
  Map<String, String> get errors;

  /// Create a copy of PlantEditorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlantEditorStateCopyWith<PlantEditorState> get copyWith =>
      _$PlantEditorStateCopyWithImpl<PlantEditorState>(
        this as PlantEditorState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as PlantEditorState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlantEditorState &&
            (identical(other.fields, _this.fields) ||
                other.fields == _this.fields) &&
            (identical(other.draft, _this.draft) ||
                other.draft == _this.draft) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.picking, _this.picking) ||
                other.picking == _this.picking) &&
            const DeepCollectionEquality().equals(
              other.existingRoutines,
              _this.existingRoutines,
            ) &&
            (identical(other.saving, _this.saving) ||
                other.saving == _this.saving) &&
            (identical(other.dirty, _this.dirty) ||
                other.dirty == _this.dirty) &&
            (identical(other.photoPending, _this.photoPending) ||
                other.photoPending == _this.photoPending) &&
            (identical(other.photoFailed, _this.photoFailed) ||
                other.photoFailed == _this.photoFailed) &&
            (identical(other.errorCode, _this.errorCode) ||
                other.errorCode == _this.errorCode) &&
            const DeepCollectionEquality().equals(other.errors, _this.errors));
  }

  @override
  int get hashCode {
    final _this = this as PlantEditorState;
    return Object.hash(
      runtimeType,
      _this.fields,
      _this.draft,
      _this.loading,
      _this.picking,
      const DeepCollectionEquality().hash(_this.existingRoutines),
      _this.saving,
      _this.dirty,
      _this.photoPending,
      _this.photoFailed,
      _this.errorCode,
      const DeepCollectionEquality().hash(_this.errors),
    );
  }

  @override
  String toString() {
    final _this = this as PlantEditorState;
    return 'PlantEditorState(fields: ${_this.fields}, draft: ${_this.draft}, loading: ${_this.loading}, picking: ${_this.picking}, existingRoutines: ${_this.existingRoutines}, saving: ${_this.saving}, dirty: ${_this.dirty}, photoPending: ${_this.photoPending}, photoFailed: ${_this.photoFailed}, errorCode: ${_this.errorCode}, errors: ${_this.errors})';
  }
}

/// @nodoc
abstract mixin class $PlantEditorStateCopyWith<$Res> {
  factory $PlantEditorStateCopyWith(
    PlantEditorState value,
    $Res Function(PlantEditorState) _then,
  ) = _$PlantEditorStateCopyWithImpl;
  @useResult
  $Res call({
    CustomPlantFields? fields,
    PlantDraft? draft,
    bool loading,
    bool picking,
    List<RoutineRead> existingRoutines,
    bool saving,
    bool dirty,
    bool photoPending,
    bool photoFailed,
    String? errorCode,
    Map<String, String> errors,
  });
}

/// @nodoc
class _$PlantEditorStateCopyWithImpl<$Res>
    implements $PlantEditorStateCopyWith<$Res> {
  _$PlantEditorStateCopyWithImpl(this._self, this._then);

  final PlantEditorState _self;
  final $Res Function(PlantEditorState) _then;

  /// Create a copy of PlantEditorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fields = freezed,
    Object? draft = freezed,
    Object? loading = null,
    Object? picking = null,
    Object? existingRoutines = null,
    Object? saving = null,
    Object? dirty = null,
    Object? photoPending = null,
    Object? photoFailed = null,
    Object? errorCode = freezed,
    Object? errors = null,
  }) {
    return _then(
      PlantEditorState(
        fields: freezed == fields
            ? _self.fields
            : fields // ignore: cast_nullable_to_non_nullable
                  as CustomPlantFields?,
        draft: freezed == draft
            ? _self.draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as PlantDraft?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        picking: null == picking
            ? _self.picking
            : picking // ignore: cast_nullable_to_non_nullable
                  as bool,
        existingRoutines: null == existingRoutines
            ? _self.existingRoutines
            : existingRoutines // ignore: cast_nullable_to_non_nullable
                  as List<RoutineRead>,
        saving: null == saving
            ? _self.saving
            : saving // ignore: cast_nullable_to_non_nullable
                  as bool,
        dirty: null == dirty
            ? _self.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        photoPending: null == photoPending
            ? _self.photoPending
            : photoPending // ignore: cast_nullable_to_non_nullable
                  as bool,
        photoFailed: null == photoFailed
            ? _self.photoFailed
            : photoFailed // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        errors: null == errors
            ? _self.errors
            : errors // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [PlantEditorState].
extension PlantEditorStatePatterns on PlantEditorState {
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
    TResult Function(_PlantEditorState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState() when $default != null:
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
    TResult Function(_PlantEditorState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState():
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
    TResult? Function(_PlantEditorState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState() when $default != null:
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
      CustomPlantFields? fields,
      PlantDraft? draft,
      bool loading,
      bool picking,
      List<RoutineRead> existingRoutines,
      bool saving,
      bool dirty,
      bool photoPending,
      bool photoFailed,
      String? errorCode,
      Map<String, String> errors,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState() when $default != null:
        return $default(
          _that.fields,
          _that.draft,
          _that.loading,
          _that.picking,
          _that.existingRoutines,
          _that.saving,
          _that.dirty,
          _that.photoPending,
          _that.photoFailed,
          _that.errorCode,
          _that.errors,
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
      CustomPlantFields? fields,
      PlantDraft? draft,
      bool loading,
      bool picking,
      List<RoutineRead> existingRoutines,
      bool saving,
      bool dirty,
      bool photoPending,
      bool photoFailed,
      String? errorCode,
      Map<String, String> errors,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState():
        return $default(
          _that.fields,
          _that.draft,
          _that.loading,
          _that.picking,
          _that.existingRoutines,
          _that.saving,
          _that.dirty,
          _that.photoPending,
          _that.photoFailed,
          _that.errorCode,
          _that.errors,
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
      CustomPlantFields? fields,
      PlantDraft? draft,
      bool loading,
      bool picking,
      List<RoutineRead> existingRoutines,
      bool saving,
      bool dirty,
      bool photoPending,
      bool photoFailed,
      String? errorCode,
      Map<String, String> errors,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlantEditorState() when $default != null:
        return $default(
          _that.fields,
          _that.draft,
          _that.loading,
          _that.picking,
          _that.existingRoutines,
          _that.saving,
          _that.dirty,
          _that.photoPending,
          _that.photoFailed,
          _that.errorCode,
          _that.errors,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PlantEditorState implements PlantEditorState {
  const _PlantEditorState({
    this.fields,
    this.draft,
    this.loading = true,
    this.picking = false,
    List<RoutineRead> existingRoutines = const [],
    this.saving = false,
    this.dirty = false,
    this.photoPending = false,
    this.photoFailed = false,
    this.errorCode,
    Map<String, String> errors = const {},
  }) : _existingRoutines = existingRoutines,
       _errors = errors;

  @override
  final CustomPlantFields? fields;
  @override
  final PlantDraft? draft;
  @override
  @JsonKey()
  final bool loading;
  @override
  @JsonKey()
  final bool picking;
  final List<RoutineRead> _existingRoutines;
  @override
  @JsonKey()
  List<RoutineRead> get existingRoutines {
    if (_existingRoutines is EqualUnmodifiableListView)
      return _existingRoutines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_existingRoutines);
  }

  @override
  @JsonKey()
  final bool saving;
  @override
  @JsonKey()
  final bool dirty;
  @override
  @JsonKey()
  final bool photoPending;
  @override
  @JsonKey()
  final bool photoFailed;
  @override
  final String? errorCode;
  final Map<String, String> _errors;
  @override
  @JsonKey()
  Map<String, String> get errors {
    if (_errors is EqualUnmodifiableMapView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_errors);
  }

  /// Create a copy of PlantEditorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlantEditorStateCopyWith<_PlantEditorState> get copyWith =>
      __$PlantEditorStateCopyWithImpl<_PlantEditorState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlantEditorState &&
            (identical(other.fields, fields) || other.fields == fields) &&
            (identical(other.draft, draft) || other.draft == draft) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.picking, picking) || other.picking == picking) &&
            const DeepCollectionEquality().equals(
              other.existingRoutines,
              _existingRoutines,
            ) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.photoPending, photoPending) ||
                other.photoPending == photoPending) &&
            (identical(other.photoFailed, photoFailed) ||
                other.photoFailed == photoFailed) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            const DeepCollectionEquality().equals(other.errors, _errors));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      fields,
      draft,
      loading,
      picking,
      const DeepCollectionEquality().hash(_existingRoutines),
      saving,
      dirty,
      photoPending,
      photoFailed,
      errorCode,
      const DeepCollectionEquality().hash(_errors),
    );
  }

  @override
  String toString() {
    return 'PlantEditorState(fields: $fields, draft: $draft, loading: $loading, picking: $picking, existingRoutines: $existingRoutines, saving: $saving, dirty: $dirty, photoPending: $photoPending, photoFailed: $photoFailed, errorCode: $errorCode, errors: $errors)';
  }
}

/// @nodoc
abstract mixin class _$PlantEditorStateCopyWith<$Res>
    implements $PlantEditorStateCopyWith<$Res> {
  factory _$PlantEditorStateCopyWith(
    _PlantEditorState value,
    $Res Function(_PlantEditorState) _then,
  ) = __$PlantEditorStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    CustomPlantFields? fields,
    PlantDraft? draft,
    bool loading,
    bool picking,
    List<RoutineRead> existingRoutines,
    bool saving,
    bool dirty,
    bool photoPending,
    bool photoFailed,
    String? errorCode,
    Map<String, String> errors,
  });
}

/// @nodoc
class __$PlantEditorStateCopyWithImpl<$Res>
    implements _$PlantEditorStateCopyWith<$Res> {
  __$PlantEditorStateCopyWithImpl(this._self, this._then);

  final _PlantEditorState _self;
  final $Res Function(_PlantEditorState) _then;

  /// Create a copy of PlantEditorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? fields = freezed,
    Object? draft = freezed,
    Object? loading = null,
    Object? picking = null,
    Object? existingRoutines = null,
    Object? saving = null,
    Object? dirty = null,
    Object? photoPending = null,
    Object? photoFailed = null,
    Object? errorCode = freezed,
    Object? errors = null,
  }) {
    return _then(
      _PlantEditorState(
        fields: freezed == fields
            ? _self.fields
            : fields // ignore: cast_nullable_to_non_nullable
                  as CustomPlantFields?,
        draft: freezed == draft
            ? _self.draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as PlantDraft?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        picking: null == picking
            ? _self.picking
            : picking // ignore: cast_nullable_to_non_nullable
                  as bool,
        existingRoutines: null == existingRoutines
            ? _self._existingRoutines
            : existingRoutines // ignore: cast_nullable_to_non_nullable
                  as List<RoutineRead>,
        saving: null == saving
            ? _self.saving
            : saving // ignore: cast_nullable_to_non_nullable
                  as bool,
        dirty: null == dirty
            ? _self.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        photoPending: null == photoPending
            ? _self.photoPending
            : photoPending // ignore: cast_nullable_to_non_nullable
                  as bool,
        photoFailed: null == photoFailed
            ? _self.photoFailed
            : photoFailed // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorCode: freezed == errorCode
            ? _self.errorCode
            : errorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        errors: null == errors
            ? _self._errors
            : errors // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
      ),
    );
  }
}
