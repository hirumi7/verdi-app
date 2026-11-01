import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:verdi_core/verdi_core.dart';

import '../../../core/native/draft_bridge.g.dart';

abstract interface class CardService {
  Future<Map<String, Object?>> prepare(Map<String, Object?> request);
  Future<Uint8List> read(String token);
  Future<Map<String, Object?>> handoff(String token, {required bool save});
  Future<void> release(String token);
}

final class NativeCardService implements CardService {
  final CardPlatformHostApi host;
  final Duration deadline;
  NativeCardService({
    CardPlatformHostApi? host,
    this.deadline = const Duration(seconds: 30),
  }) : host = host ?? CardPlatformHostApi();
  @override
  Future<Map<String, Object?>> prepare(Map<String, Object?> request) async =>
      (jsonDecode(await host.prepareCard(canonicalCommandJson(request))) as Map)
          .cast<String, Object?>();
  @override
  Future<Uint8List> read(String token) => host.readCard(token);
  @override
  Future<Map<String, Object?>> handoff(
    String token, {
    required bool save,
  }) async => (jsonDecode(
    await (save
        ? host
              .saveCard(token)
              .timeout(
                deadline,
                onTimeout: () =>
                    throw PlatformException(code: 'PHOTO_SAVE_UNKNOWN'),
              )
        : host.shareCard(token)),
  ) as Map).cast<String, Object?>();
  @override
  Future<void> release(String token) => host.releaseCard(token);
}
