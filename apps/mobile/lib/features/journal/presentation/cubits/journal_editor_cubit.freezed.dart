// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_editor_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JournalEditorState {
  JournalDraft? get draft;
  JournalFields? get fields;
  bool get loading;
  bool get saving;
  bool get preparing;
  bool get changed;
  bool get attachmentFailed;
  bool get attachmentPending;
  String? get errorCode;
  Map<String, String> get errors;

  /// Create a copy of JournalEditorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalEditorStateCopyWith<JournalEditorState> get copyWith =>
      _$JournalEditorStateCopyWithImpl<JournalEditorState>(
        this as JournalEditorState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as JournalEditorState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalEditorState &&
            (identical(other.draft, _this.draft) ||
                other.draft == _this.draft) &&
            (identical(other.fields, _this.fields) ||
                other.fields == _this.fields) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.saving, _this.saving) ||
                other.saving == _this.saving) &&
            (identical(other.preparing, _this.preparing) ||
                other.preparing == _this.preparing) &&
            (identical(other.changed, _this.changed) ||
                other.changed == _this.changed) &&
            (identical(other.attachmentFailed, _this.attachmentFailed) ||
                other.attachmentFailed == _this.attachmentFailed) &&
            (identical(other.attachmentPending, _this.attachmentPending) ||
                other.attachmentPending == _this.attachmentPending) &&
            (identical(other.errorCode, _this.errorCode) ||
                other.errorCode == _this.errorCode) &&
            const DeepCollectionEquality().equals(other.errors, _this.errors));
  }

  @override
  int get hashCode {
    final _this = this as JournalEditorState;
    return Object.hash(
      runtimeType,
      _this.draft,
      _this.fields,
      _this.loading,
      _this.saving,
      _this.preparing,
      _this.changed,
      _this.attachmentFailed,
      _this.attachmentPending,
      _this.errorCode,
      const DeepCollectionEquality().hash(_this.errors),
    );
  }

  @override
  String toString() {
    final _this = this as JournalEditorState;
    return 'JournalEditorState(draft: ${_this.draft}, fields: ${_this.fields}, loading: ${_this.loading}, saving: ${_this.saving}, preparing: ${_this.preparing}, changed: ${_this.changed}, attachmentFailed: ${_this.attachmentFailed}, attachmentPending: ${_this.attachmentPending}, errorCode: ${_this.errorCode}, errors: ${_this.errors})';
  }
}

/// @nodoc
abstract mixin class $JournalEditorStateCopyWith<$Res> {
  factory $JournalEditorStateCopyWith(
    JournalEditorState value,
    $Res Function(JournalEditorState) _then,
  ) = _$JournalEditorStateCopyWithImpl;
  @useResult
  $Res call({
    JournalDraft? draft,
    JournalFields? fields,
    bool loading,
    bool saving,
    bool preparing,
    bool changed,
    bool attachmentFailed,
    bool attachmentPending,
    String? errorCode,
    Map<String, String> errors,
  });
}

/// @nodoc
class _$JournalEditorStateCopyWithImpl<$Res>
    implements $JournalEditorStateCopyWith<$Res> {
  _$JournalEditorStateCopyWithImpl(this._self, this._then);

  final JournalEditorState _self;
  final $Res Function(JournalEditorState) _then;

  /// Create a copy of JournalEditorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? draft = freezed,
    Object? fields = freezed,
    Object? loading = null,
    Object? saving = null,
    Object? preparing = null,
    Object? changed = null,
    Object? attachmentFailed = null,
    Object? attachmentPending = null,
    Object? errorCode = freezed,
    Object? errors = null,
  }) {
    return _then(
      JournalEditorState(
        draft: freezed == draft
            ? _self.draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as JournalDraft?,
        fields: freezed == fields
            ? _self.fields
            : fields // ignore: cast_nullable_to_non_nullable
                  as JournalFields?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        saving: null == saving
            ? _self.saving
            : saving // ignore: cast_nullable_to_non_nullable
                  as bool,
        preparing: null == preparing
            ? _self.preparing
            : preparing // ignore: cast_nullable_to_non_nullable
                  as bool,
        changed: null == changed
            ? _self.changed
            : changed // ignore: cast_nullable_to_non_nullable
                  as bool,
        attachmentFailed: null == attachmentFailed
            ? _self.attachmentFailed
            : attachmentFailed // ignore: cast_nullable_to_non_nullable
                  as bool,
        attachmentPending: null == attachmentPending
            ? _self.attachmentPending
            : attachmentPending // ignore: cast_nullable_to_non_nullable
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

/// Adds pattern-matching-related methods to [JournalEditorState].
extension JournalEditorStatePatterns on JournalEditorState {
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
    TResult Function(_JournalEditorState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState() when $default != null:
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
    TResult Function(_JournalEditorState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState():
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
    TResult? Function(_JournalEditorState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState() when $default != null:
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
      JournalDraft? draft,
      JournalFields? fields,
      bool loading,
      bool saving,
      bool preparing,
      bool changed,
      bool attachmentFailed,
      bool attachmentPending,
      String? errorCode,
      Map<String, String> errors,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState() when $default != null:
        return $default(
          _that.draft,
          _that.fields,
          _that.loading,
          _that.saving,
          _that.preparing,
          _that.changed,
          _that.attachmentFailed,
          _that.attachmentPending,
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
      JournalDraft? draft,
      JournalFields? fields,
      bool loading,
      bool saving,
      bool preparing,
      bool changed,
      bool attachmentFailed,
      bool attachmentPending,
      String? errorCode,
      Map<String, String> errors,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState():
        return $default(
          _that.draft,
          _that.fields,
          _that.loading,
          _that.saving,
          _that.preparing,
          _that.changed,
          _that.attachmentFailed,
          _that.attachmentPending,
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
      JournalDraft? draft,
      JournalFields? fields,
      bool loading,
      bool saving,
      bool preparing,
      bool changed,
      bool attachmentFailed,
      bool attachmentPending,
      String? errorCode,
      Map<String, String> errors,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEditorState() when $default != null:
        return $default(
          _that.draft,
          _that.fields,
          _that.loading,
          _that.saving,
          _that.preparing,
          _that.changed,
          _that.attachmentFailed,
          _that.attachmentPending,
          _that.errorCode,
          _that.errors,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _JournalEditorState implements JournalEditorState {
  const _JournalEditorState({
    this.draft,
    this.fields,
    this.loading = true,
    this.saving = false,
    this.preparing = false,
    this.changed = false,
    this.attachmentFailed = false,
    this.attachmentPending = false,
    this.errorCode,
    Map<String, String> errors = const {},
  }) : _errors = errors;

  @override
  final JournalDraft? draft;
  @override
  final JournalFields? fields;
  @override
  @JsonKey()
  final bool loading;
  @override
  @JsonKey()
  final bool saving;
  @override
  @JsonKey()
  final bool preparing;
  @override
  @JsonKey()
  final bool changed;
  @override
  @JsonKey()
  final bool attachmentFailed;
  @override
  @JsonKey()
  final bool attachmentPending;
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

  /// Create a copy of JournalEditorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JournalEditorStateCopyWith<_JournalEditorState> get copyWith =>
      __$JournalEditorStateCopyWithImpl<_JournalEditorState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JournalEditorState &&
            (identical(other.draft, draft) || other.draft == draft) &&
            (identical(other.fields, fields) || other.fields == fields) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.preparing, preparing) ||
                other.preparing == preparing) &&
            (identical(other.changed, changed) || other.changed == changed) &&
            (identical(other.attachmentFailed, attachmentFailed) ||
                other.attachmentFailed == attachmentFailed) &&
            (identical(other.attachmentPending, attachmentPending) ||
                other.attachmentPending == attachmentPending) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            const DeepCollectionEquality().equals(other.errors, _errors));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      draft,
      fields,
      loading,
      saving,
      preparing,
      changed,
      attachmentFailed,
      attachmentPending,
      errorCode,
      const DeepCollectionEquality().hash(_errors),
    );
  }

  @override
  String toString() {
    return 'JournalEditorState(draft: $draft, fields: $fields, loading: $loading, saving: $saving, preparing: $preparing, changed: $changed, attachmentFailed: $attachmentFailed, attachmentPending: $attachmentPending, errorCode: $errorCode, errors: $errors)';
  }
}

/// @nodoc
abstract mixin class _$JournalEditorStateCopyWith<$Res>
    implements $JournalEditorStateCopyWith<$Res> {
  factory _$JournalEditorStateCopyWith(
    _JournalEditorState value,
    $Res Function(_JournalEditorState) _then,
  ) = __$JournalEditorStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    JournalDraft? draft,
    JournalFields? fields,
    bool loading,
    bool saving,
    bool preparing,
    bool changed,
    bool attachmentFailed,
    bool attachmentPending,
    String? errorCode,
    Map<String, String> errors,
  });
}

/// @nodoc
class __$JournalEditorStateCopyWithImpl<$Res>
    implements _$JournalEditorStateCopyWith<$Res> {
  __$JournalEditorStateCopyWithImpl(this._self, this._then);

  final _JournalEditorState _self;
  final $Res Function(_JournalEditorState) _then;

  /// Create a copy of JournalEditorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? draft = freezed,
    Object? fields = freezed,
    Object? loading = null,
    Object? saving = null,
    Object? preparing = null,
    Object? changed = null,
    Object? attachmentFailed = null,
    Object? attachmentPending = null,
    Object? errorCode = freezed,
    Object? errors = null,
  }) {
    return _then(
      _JournalEditorState(
        draft: freezed == draft
            ? _self.draft
            : draft // ignore: cast_nullable_to_non_nullable
                  as JournalDraft?,
        fields: freezed == fields
            ? _self.fields
            : fields // ignore: cast_nullable_to_non_nullable
                  as JournalFields?,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        saving: null == saving
            ? _self.saving
            : saving // ignore: cast_nullable_to_non_nullable
                  as bool,
        preparing: null == preparing
            ? _self.preparing
            : preparing // ignore: cast_nullable_to_non_nullable
                  as bool,
        changed: null == changed
            ? _self.changed
            : changed // ignore: cast_nullable_to_non_nullable
                  as bool,
        attachmentFailed: null == attachmentFailed
            ? _self.attachmentFailed
            : attachmentFailed // ignore: cast_nullable_to_non_nullable
                  as bool,
        attachmentPending: null == attachmentPending
            ? _self.attachmentPending
            : attachmentPending // ignore: cast_nullable_to_non_nullable
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
