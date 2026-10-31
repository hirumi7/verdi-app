import 'package:verdi_core/verdi_core.dart';

/// These begin-operation rejections happen before a preparation is registered.
/// Transport, storage, session and busy errors have uncertain outcomes and must
/// keep the same ID until status recovery succeeds.
bool preparationRejected(Object error) =>
    error is CommandRejected &&
    const {
      'MEDIA_SELECTION_EXPIRED',
      'FUTURE_OBSERVATION_DATE',
      'STALE_TARGET',
      'FIELD_INVALID',
      'MEDIA_UNAVAILABLE',
    }.contains(error.code);
