import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter/services.dart';

import '../../../core/native/draft_bridge.g.dart';

bool validFeedbackText(String value) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit == 0) return false;
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i == units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
        return false;
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

class FeedbackMetadata {
  final String draftId;
  final String? appVersion, build, osVersion;
  const FeedbackMetadata(
    this.draftId,
    this.appVersion,
    this.build,
    this.osVersion,
  );
  factory FeedbackMetadata.parse(String value) {
    if (value.length > 8192) {
      throw const FormatException('Feedback metadata limit');
    }
    final raw = jsonDecode(value);
    if (raw is! Map ||
        raw.length != 5 ||
        !raw.keys.toSet().containsAll({
          'draftId',
          'destination',
          'appVersion',
          'build',
          'osVersion',
        }) ||
        raw['destination'] != null) {
      throw const FormatException('Feedback metadata shape');
    }
    final id = raw['draftId'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id)) {
      throw const FormatException('Feedback metadata ID');
    }
    String? version(String key, int max) {
      final v = raw[key];
      if (v == null) return null;
      if (v is! String ||
          v.isEmpty ||
          v.characters.length > max ||
          !validFeedbackText(v)) {
        throw const FormatException('Feedback metadata version');
      }
      return v;
    }

    return FeedbackMetadata(
      id,
      version('appVersion', 80),
      version('build', 40),
      version('osVersion', 40),
    );
  }
}

abstract interface class FeedbackService {
  Future<FeedbackMetadata> metadata();
  Future<void> copy(String text);
}

class NativeFeedbackService implements FeedbackService {
  final HelpPlatformHostApi host;
  NativeFeedbackService({HelpPlatformHostApi? host})
    : host = host ?? HelpPlatformHostApi();
  @override
  Future<FeedbackMetadata> metadata() async =>
      FeedbackMetadata.parse(await host.getFeedbackMetadata());
  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
