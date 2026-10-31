import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Shared command encoder; wire schemas, not this function, supply defaults.
/// Rejects floating-point values and non-ASCII object keys. Arrays retain order.
String canonicalCommandJson(Object? value) {
  if (value == null || value is bool || value is String)
    return jsonEncode(value);
  if (value is int && value >= -9007199254740991 && value <= 9007199254740991) {
    return '$value';
  }
  if (value is List<Object?>) {
    return '[${value.map(canonicalCommandJson).join(',')}]';
  }
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    if (keys.any((key) => key.codeUnits.any((unit) => unit > 127))) {
      throw const FormatException('Command keys must be ASCII');
    }
    return '{${keys.map((key) => '${jsonEncode(key)}:${canonicalCommandJson(value[key])}').join(',')}}';
  }
  throw const FormatException('Not a canonical command value');
}

String commandHash(String commandType, Map<String, Object?> payload) => sha256
    .convert(
      utf8.encode(
        canonicalCommandJson({
          'commandType': commandType,
          'normalisedPayload': payload,
        }),
      ),
    )
    .toString();
