import 'package:test/test.dart';
import 'package:verdi_core/src/command_encoding.dart';

void main() {
  test(
    'SavePlant SHA-256 vector independently computed with Python hashlib',
    () {
      expect(
        commandHash('SavePlant', {
          'draftRevision': 1,
          'draftId': '00000000-0000-4000-8000-000000000001',
        }),
        'f4b5ad0f538859b25ec009f5f3ac31cf7591985bacb72002b8612177785bbc36',
      );
    },
  );
  test(
    'canonical keys recurse, arrays retain order, Unicode is not case-folded',
    () {
      expect(
        canonicalCommandJson({
          'z': [2, 1],
          'a': {'x': null, 'B': 'É\n/"'},
        }),
        '{"a":{"B":"É\\n/\\\"","x":null},"z":[2,1]}',
      );
      expect(
        commandHash('x', {'b': 2, 'a': 1}),
        commandHash('x', {'a': 1, 'b': 2}),
      );
      expect(commandHash('x', {'a': 'é'}), isNot(commandHash('x', {'a': 'É'})));
      expect(
        commandHash('x', {
          'a': [1, 2],
        }),
        isNot(
          commandHash('x', {
            'a': [2, 1],
          }),
        ),
      );
    },
  );
  test('reject floating values and non-ASCII schema keys', () {
    expect(() => canonicalCommandJson({'count': 1.0}), throwsFormatException);
    expect(() => canonicalCommandJson({'é': 1}), throwsFormatException);
    expect(
      () => canonicalCommandJson({'count': 9007199254740992}),
      throwsFormatException,
    );
    expect(
      () => canonicalCommandJson({'count': -9223372036854775808}),
      throwsFormatException,
    );
  });
}
