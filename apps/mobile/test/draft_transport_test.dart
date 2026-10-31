import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/core/native/draft_repository_service.dart';

void main() {
  test(
    'a missing reply terminates transport, settles queued work, permits close',
    () async {
      final receiver = ReceivePort();
      addTearDown(receiver.close);
      // The receiver remains alive, consumes messages, and deliberately never
      // replies. This is different from discarding an already completed result.
      receiver.listen((_) {});
      final service = DraftRepositoryService.forTransportTest(
        receiver.sendPort,
        responseTimeout: const Duration(milliseconds: 25),
      );
      final commit = expectLater(
        service.commit('original-command', 'original-hash'),
        throwsA(
          isA<DraftStorageFailure>().having(
            (e) => e.outcomeUnknown,
            'unknown mutation',
            true,
          ),
        ),
      );
      final read = expectLater(
        service.read(),
        throwsA(
          isA<DraftStorageFailure>().having(
            (e) => e.outcomeUnknown,
            'failed read',
            false,
          ),
        ),
      );
      await Future.wait([commit, read]).timeout(const Duration(seconds: 2));
      await service.close().timeout(const Duration(seconds: 1));
      await expectLater(service.read(), throwsA(isA<DraftStorageFailure>()));
    },
  );
}
