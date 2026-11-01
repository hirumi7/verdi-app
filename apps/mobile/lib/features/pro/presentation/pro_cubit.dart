import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/store_service.dart';

final class ProState {
  final Map<String, Object?> access;
  final Map<String, Object?>? offer;
  final bool loading, working;
  final String? error;
  const ProState({
    this.access = const {},
    this.offer,
    this.loading = false,
    this.working = false,
    this.error,
  });
  bool get pro => access['access'] == 'pro';
  Map<String, Object?>? get attempt =>
      (access['attempt'] as Map?)?.cast<String, Object?>();
  String get phase => attempt?['phase'] as String? ?? '';
  String get status => access['status'] as String? ?? '';
  bool get pendingApproval =>
      phase == 'pending' || attempt?['priorPending'] == true;
  bool get outstanding =>
      access['busy'] == true || pendingApproval || phase == 'purchasing';
}

class ProCubit extends Cubit<ProState> {
  final StoreService service;
  StreamSubscription<void>? _subscription;
  int _sequence = 0;
  bool _working = false;
  String? _operationError;
  ProCubit(this.service) : super(const ProState()) {
    _subscription = service.changes.listen((_) => read());
  }
  Future<void> read({bool refresh = false}) async {
    final sequence = ++_sequence;
    try {
      final access =
          await service.call(refresh ? 'refresh' : 'readState') ?? {};
      if (refresh ||
          const [
            'verified',
            'restored',
            'cancelled',
            'failed',
            'unverified',
            'pending',
            'revoked',
          ].contains(access['status'])) {
        _operationError = null;
      }
      if (!isClosed && sequence == _sequence) {
        emit(
          ProState(
            access: access,
            offer: state.offer,
            working: _working,
            error: _operationError,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && sequence == _sequence) {
        emit(
          ProState(
            access: state.access,
            offer: state.offer,
            working: _working,
            error: 'STORE_RESULT_UNKNOWN',
          ),
        );
      }
    }
  }

  Future<void> load() async {
    if (isClosed) return;
    emit(
      ProState(
        access: state.access,
        offer: state.offer,
        loading: true,
        working: _working,
      ),
    );
    await read();
    try {
      final offer = await service.call('loadOffer');
      if (!isClosed) {
        emit(
          ProState(
            access: state.access,
            offer: offer,
            working: _working,
            error: state.error,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          ProState(
            access: state.access,
            working: _working,
            error: 'STORE_RESULT_UNKNOWN',
          ),
        );
      }
    }
  }

  Future<void> perform(String method, [Map<String, Object?>? request]) async {
    if (_working || (state.outstanding && method == 'purchase')) return;
    _working = true;
    _operationError = null;
    ++_sequence;
    emit(ProState(access: state.access, offer: state.offer, working: true));
    try {
      await service.call(method, request);
    } catch (_) {
      _operationError = 'STORE_RESULT_UNKNOWN';
      if (!isClosed) {
        emit(
          ProState(
            access: state.access,
            offer: state.offer,
            working: true,
            error: 'STORE_RESULT_UNKNOWN',
          ),
        );
      }
    } finally {
      _working = false;
      // The native operation may outlive this transport call. Read, never repurchase.
      await read();
    }
  }

  Future<void> abandon(String intentID) async {
    await service.call('cancel', {'intentId': intentID});
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
