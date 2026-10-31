import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Shared command encoder; wire schemas, not this function, supply defaults.
/// Rejects floating-point values and non-ASCII object keys. Arrays retain order.
String canonicalCommandJson(Object? value) {
  final writer = _CanonicalWriter();
  writer.write(value, 0);
  return writer.output.toString();
}

const canonicalCommandByteLimit = 4 * 1024 * 1024;
const canonicalCommandDepthLimit = 64;

class _CanonicalWriter {
  final output = StringBuffer();
  int bytes = 0;

  void emit(String text) {
    final size = utf8.encode(text).length;
    if (size > canonicalCommandByteLimit - bytes) {
      throw const FormatException('Canonical command exceeds byte limit');
    }
    bytes += size;
    output.write(text);
  }

  void string(String text) {
    // UTF-16 length is a lower bound for the encoded JSON byte length.
    if (text.length > canonicalCommandByteLimit - bytes) {
      throw const FormatException('Canonical command exceeds byte limit');
    }
    // JSON escapes lone UTF-16 units losslessly. Draft input is not final Text;
    // field validation must not be smuggled into the shared hash function.
    emit(jsonEncode(text));
  }

  void write(Object? value, int depth) {
    if (value == null || value is bool) {
      emit(jsonEncode(value));
      return;
    }
    if (value is String) {
      string(value);
      return;
    }
    if (value is int &&
        value >= -9007199254740991 &&
        value <= 9007199254740991) {
      emit('$value');
      return;
    }
    if (value is List<Object?>) {
      if (depth >= canonicalCommandDepthLimit) {
        throw const FormatException('Canonical command exceeds depth limit');
      }
      emit('[');
      for (var i = 0; i < value.length; i++) {
        if (i != 0) emit(',');
        write(value[i], depth + 1);
      }
      emit(']');
      return;
    }
    if (value is Map<String, Object?>) {
      if (depth >= canonicalCommandDepthLimit) {
        throw const FormatException('Canonical command exceeds depth limit');
      }
      final keys = value.keys.toList()..sort();
      if (keys.any((key) => key.codeUnits.any((unit) => unit > 127))) {
        throw const FormatException('Command keys must be ASCII');
      }
      emit('{');
      for (var i = 0; i < keys.length; i++) {
        if (i != 0) emit(',');
        string(keys[i]);
        emit(':');
        write(value[keys[i]], depth + 1);
      }
      emit('}');
      return;
    }
    throw const FormatException('Not a canonical command value');
  }
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

/// SHA-256 of an arbitrary canonical protocol value (rows, plans and effects).
String canonicalValueHash(Object? value) =>
    sha256.convert(utf8.encode(canonicalCommandJson(value))).toString();
