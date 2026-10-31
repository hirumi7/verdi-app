import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:verdi_core/src/command_encoding.dart';

void main() {
  test('Dart matches the exact independent vectors also executed in Swift', () {
    final file =
        jsonDecode(
              File(
                '../verdi_native/Tests/VerdiNativeTests/Fixtures/canonical-command-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(file['version'], 1);
    final vectors = file['vectors'] as List<Object?>;
    expect(vectors, hasLength(20));
    for (final item in vectors) {
      final vector = item as Map<String, Object?>;
      final name = vector['name'] as String;
      Object? input = vector['input'];
      Map<String, Object?>? rawPayload;
      if (vector['utf16_units'] case final List<Object?> units) {
        final raw = String.fromCharCodes(units.cast<int>());
        input = raw;
        if (vector['raw_payload_field'] case final String field) {
          rawPayload = {field: raw};
          input = {
            'commandType': vector['command_type'],
            'normalisedPayload': rawPayload,
          };
        }
      }
      final text = canonicalCommandJson(input);
      final bytes = utf8.encode(text);
      expect(text, vector['canonical'], reason: name);
      expect(
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        vector['utf8_hex'],
        reason: name,
      );
      expect(sha256.convert(bytes).toString(), vector['sha256'], reason: name);
      if (vector['command_type'] case final String type) {
        expect(
          commandHash(
            type,
            rawPayload ?? vector['payload'] as Map<String, Object?>,
          ),
          vector['sha256'],
          reason: name,
        );
      }
    }
  });

  test('reject floats, unsupported objects and keys', () {
    for (final value in [
      double.nan,
      double.infinity,
      1.0,
      DateTime.utc(2026),
      {'é': 1},
      {1: 'non-string key'},
    ]) {
      expect(() => canonicalCommandJson(value), throwsFormatException);
    }
  });

  test('depth boundary counts every container and command wrapper', () {
    Object? nested(int count) {
      Object? value;
      for (var i = 0; i < count; i++) {
        value = [value];
      }
      return value;
    }

    expect(() => canonicalCommandJson(nested(64)), returnsNormally);
    expect(() => canonicalCommandJson(nested(65)), throwsFormatException);
    expect(() => commandHash('Test', {'nested': nested(62)}), returnsNormally);
    expect(
      () => commandHash('Test', {'nested': nested(63)}),
      throwsFormatException,
    );
    final cycle = <Object?>[];
    cycle.add(cycle);
    expect(() => canonicalCommandJson(cycle), throwsFormatException);
  });

  test(
    'exact byte boundary distinguishes ASCII, emoji and escaped controls',
    () {
      const available = canonicalCommandByteLimit - 2;
      for (final (unit, size) in [
        ('a', 1),
        ('🌿', 4),
        ('\u0000', 6),
        (String.fromCharCode(0xd800), 6),
      ]) {
        final text = unit * (available ~/ size) + 'a' * (available % size);
        expect(
          utf8.encode(canonicalCommandJson(text)),
          hasLength(canonicalCommandByteLimit),
        );
        expect(() => canonicalCommandJson('${text}a'), throwsFormatException);
      }
    },
  );

  test('byte boundary includes the whole command wrapper', () {
    final overhead = utf8
        .encode(
          canonicalCommandJson({
            'commandType': 'Test',
            'normalisedPayload': {'text': ''},
          }),
        )
        .length;
    final text = 'x' * (canonicalCommandByteLimit - overhead);
    expect(() => commandHash('Test', {'text': text}), returnsNormally);
    expect(
      () => commandHash('Test', {'text': '${text}x'}),
      throwsFormatException,
    );
  });
}
