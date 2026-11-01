import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../core/native/draft_bridge.g.dart';

abstract interface class StoreService {
  Stream<void> get changes;
  Future<Map<String, Object?>?> call(
    String method, [
    Map<String, Object?>? request,
  ]);
  Future<void> dispose();
}

final class NativeStoreService extends StorePlatformEventsApi
    implements StoreService {
  final StorePlatformHostApi _api;
  final Duration deadline;
  final _changes = StreamController<void>.broadcast();
  NativeStoreService({
    StorePlatformHostApi? api,
    this.deadline = const Duration(seconds: 30),
  }) : _api = api ?? StorePlatformHostApi() {
    StorePlatformEventsApi.setUp(this);
  }
  @override
  Stream<void> get changes => _changes.stream;
  @override
  void changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<Map<String, Object?>?> call(
    String method, [
    Map<String, Object?>? request,
  ]) async {
    final operation = switch (method) {
      'readState' => _api.readState(),
      'refresh' => _api.refresh(),
      'loadOffer' => _api.loadOffer(),
      'purchase' => _api.purchase(canonicalCommandJson(request)),
      'restore' => _api.restorePurchases(),
      'retryPending' => _api.retryPendingPurchase(
        request!['intentId']! as String,
      ),
      'cancel' => _api.cancelIntent(request!['intentId']! as String),
      _ => throw ArgumentError.value(method),
    };
    final text = await operation.timeout(
      deadline,
      onTimeout: () => throw PlatformException(code: 'STORE_RESULT_UNKNOWN'),
    );
    if (text.length > 65536) {
      throw const FormatException('STORE_RESPONSE_LIMIT');
    }
    final value = jsonDecode(text);
    return value == null ? null : (value as Map).cast<String, Object?>();
  }

  @override
  Future<void> dispose() {
    StorePlatformEventsApi.setUp(null);
    return _changes.close();
  }
}
