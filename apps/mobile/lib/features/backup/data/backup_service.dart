import 'dart:convert';

import '../../../core/native/draft_bridge.g.dart';

abstract interface class BackupService {
  Future<Map<String, Object?>?> call(String method, Map<String, Object?> args);
  Future<String?> choose();
  Future<String> share(Map<String, Object?> args);
}

final class NativeBackupService implements BackupService {
  final BackupPlatformHostApi _api;
  NativeBackupService({BackupPlatformHostApi? api})
    : _api = api ?? BackupPlatformHostApi();
  @override
  Future<Map<String, Object?>?> call(
    String method,
    Map<String, Object?> args,
  ) async {
    final request = jsonEncode(args);
    final encoded = await switch (method) {
      'startExport' => _api.startExport(request),
      'startImport' => _api.startImport(request),
      'backupStatus' => _api.backupStatus(request),
      'latestBackupOperation' => _api.latestBackupOperation(request),
      'confirmImport' => _api.confirmImport(request),
      'cancelBackup' => _api.cancelBackup(request),
      'retryImport' => _api.retryImport(request),
      'renewExportHandle' => _api.renewExportHandle(request),
      _ => throw ArgumentError.value(method),
    };
    if (encoded.length > 65536) throw const FormatException('BACKUP_LIMIT');
    final value = jsonDecode(encoded);
    return value == null ? null : (value as Map).cast<String, Object?>();
  }

  @override
  Future<String?> choose() => _api.chooseBackup();
  @override
  Future<String> share(Map<String, Object?> args) =>
      _api.shareBackup(jsonEncode(args));
}
