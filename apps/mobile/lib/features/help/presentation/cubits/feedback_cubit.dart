import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/widgets.dart';

import '../../data/feedback_service.dart';
part 'feedback_cubit.freezed.dart';

@freezed
abstract class FeedbackState with _$FeedbackState {
  const factory FeedbackState({
    @Default(false) bool ready,
    @Default(false) bool busy,
    @Default(false) bool dirty,
    @Default('') String subject,
    @Default('') String body,
    String? subjectError,
    String? bodyError,
    String? status,
  }) = _FeedbackState;
}

class FeedbackCubit extends Cubit<FeedbackState> {
  final FeedbackService service;
  final String initialSubject;
  final String Function(FeedbackMetadata) initialBody;
  final Duration deadline;
  String? baselineSubject, baselineBody;
  FeedbackCubit(
    this.service, {
    required this.initialSubject,
    required this.initialBody,
    this.deadline = const Duration(seconds: 10),
  }) : super(const FeedbackState());
  Future<void> load() async {
    if (state.busy || state.ready) return;
    emit(state.copyWith(busy: true, status: null));
    try {
      final metadata = await service.metadata().timeout(deadline);
      if (isClosed) return;
      baselineSubject = initialSubject;
      baselineBody = initialBody(metadata);
      emit(
        state.copyWith(
          ready: true,
          busy: false,
          subject: baselineSubject!,
          body: baselineBody!,
          status: null,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(busy: false, status: 'loadFailed'));
    }
  }

  void edit({String? subject, String? body}) {
    if (!state.ready || state.busy) return;
    final nextSubject = subject ?? state.subject, nextBody = body ?? state.body;
    emit(
      state.copyWith(
        subject: nextSubject,
        body: nextBody,
        dirty: nextSubject != baselineSubject || nextBody != baselineBody,
        subjectError: null,
        bodyError: null,
        status: null,
      ),
    );
  }

  Future<void> copy() async {
    if (state.busy || !state.ready) return;
    final subjectError =
        !validFeedbackText(state.subject) ||
            state.subject.trim().isEmpty ||
            state.subject.characters.length > 200
        ? 'subject'
        : null;
    final bodyError =
        !validFeedbackText(state.body) || state.body.characters.length > 4000
        ? 'body'
        : null;
    emit(
      state.copyWith(
        subjectError: subjectError,
        bodyError: bodyError,
        status: null,
      ),
    );
    if (subjectError != null || bodyError != null) return;
    final text = '${state.subject}\n\n${state.body}';
    emit(state.copyWith(busy: true));
    try {
      await service.copy(text).timeout(deadline);
      if (!isClosed) emit(state.copyWith(busy: false, status: 'copied'));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(busy: false, status: 'copyUnknown'));
    }
  }
}
