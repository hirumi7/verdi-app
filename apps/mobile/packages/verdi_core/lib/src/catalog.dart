import 'calendar.dart';
import 'collection.dart';
import 'command_encoding.dart';
import 'catalog_unicode.dart';

String normalizeCatalogName(String input) {
  final output = <int>[];
  var space = false;
  for (final scalar in input.runes) {
    if (catalogWhitespace.contains(scalar)) {
      space = output.isNotEmpty;
    } else {
      if (space) output.add(32);
      space = false;
      output.addAll(catalogCaseFold[scalar] ?? [scalar]);
    }
  }
  return String.fromCharCodes(output);
}

int catalogScalarCompare(String a, String b) {
  final left = a.runes.iterator, right = b.runes.iterator;
  while (true) {
    final l = left.moveNext(), r = right.moveNext();
    if (!l || !r)
      return l
          ? 1
          : r
          ? -1
          : 0;
    if (left.current != right.current)
      return left.current.compareTo(right.current);
  }
}

Map<String, Object?> _object(Object? v) => (v as Map).cast<String, Object?>();

final class CatalogSuggestion {
  final StandardCareKind careKind;
  final CareInterval interval;
  final String context, sourceLabel;
  const CatalogSuggestion(
    this.careKind,
    this.interval,
    this.context,
    this.sourceLabel,
  );
  factory CatalogSuggestion.fromJson(Object? value) {
    final m = _object(value), i = _object(m['interval']);
    return CatalogSuggestion(
      StandardCareKind.values.byName(m['careKind'] as String),
      CareInterval(
        i['count'] as int,
        IntervalUnit.values.byName(i['unit'] as String),
      ),
      m['context'] as String,
      m['sourceLabel'] as String,
    );
  }
  Map<String, Object?> toJson() => {
    'careKind': careKind.name,
    'interval': {'count': interval.count, 'unit': interval.unit.name},
    'context': context,
    'sourceLabel': sourceLabel,
  };
}

final class CatalogSelection {
  final String speciesId, catalogVersion, speciesNameSnapshot;
  final List<CatalogSuggestion> suggestions;
  CatalogSelection({
    required this.speciesId,
    required this.catalogVersion,
    required this.speciesNameSnapshot,
    Iterable<CatalogSuggestion> suggestions = const [],
  }) : suggestions = List.unmodifiable(suggestions);
  factory CatalogSelection.fromJson(String id, Object? value) {
    final m = _object(value);
    return CatalogSelection(
      speciesId: id,
      catalogVersion: m['catalogVersion'] as String,
      speciesNameSnapshot: m['speciesNameSnapshot'] as String,
      suggestions: (m['suggestions'] as List).map(CatalogSuggestion.fromJson),
    );
  }
  CatalogSuggestion? suggestion(StandardCareKind kind) =>
      suggestions.where((s) => s.careKind == kind).firstOrNull;
  Map<String, Object?> toJson() => {
    'catalogVersion': catalogVersion,
    'speciesNameSnapshot': speciesNameSnapshot,
    'suggestions': suggestions.map((s) => s.toJson()).toList(),
  };
  bool same(CatalogSelection? other) =>
      other != null &&
      speciesId == other.speciesId &&
      canonicalCommandJson(toJson()) == canonicalCommandJson(other.toJson());
}

final class SuggestionSnapshot {
  final String id, routineId, plantId, speciesId, catalogVersion;
  final CatalogSuggestion suggestion;
  final DateTime capturedAt;
  const SuggestionSnapshot(
    this.id,
    this.routineId,
    this.plantId,
    this.speciesId,
    this.catalogVersion,
    this.suggestion,
    this.capturedAt,
  );
}

final class CatalogEntry {
  final Map<String, Object?> data;
  final String version;
  CatalogEntry(this.version, Map<String, Object?> data)
    : data = Map.unmodifiable(data);
  String get id => data['id'] as String;
  String get commonName => data['commonName'] as String;
  String get scientificName => data['scientificName'] as String;
  List<String> get altNames => (data['altNames'] as List).cast<String>();
  String get difficulty => data['difficulty'] as String;
  String get light => data['light'] as String;
  String get careNotes => data['careNotes'] as String;
  bool get active => data['lifecycle'] == 'active';
  Map<String, Object?> get toxicity => _object(data['toxicity']);
  List<Map<String, Object?>> get sources =>
      (data['sources'] as List).map(_object).toList();
  String get toxicityLabel => switch (toxicity['value']) {
    'toxic' => 'Listed as toxic',
    'non-toxic' => 'Listed as non-toxic',
    _ => 'Unknown',
  };
  CatalogSelection get selection => CatalogSelection(
    speciesId: id,
    catalogVersion: version,
    speciesNameSnapshot: scientificName.trim(),
    suggestions: (data['suggestions'] as List).map(CatalogSuggestion.fromJson),
  );
}

final class CatalogState {
  final String? version;
  final List<CatalogEntry> entries;
  final List<String> popularIds;
  final String? limitation;
  final Map<String, Object?>? manifest;
  CatalogState({
    this.version,
    Iterable<CatalogEntry> entries = const [],
    Iterable<String> popularIds = const [],
    this.limitation,
    this.manifest,
  }) : entries = List.unmodifiable(entries),
       popularIds = List.unmodifiable(popularIds);
  bool get popularComplete =>
      popularIds.isNotEmpty &&
      popularIds.toSet().length == popularIds.length &&
      popularIds.every((id) => entry(id)?.active == true);
  bool get available => version != null;
  CatalogEntry? entry(String id) =>
      entries.where((e) => e.id == id).firstOrNull;
  List<CatalogEntry> search(String raw) {
    final q = normalizeCatalogName(raw);
    if (q.isEmpty)
      return !popularComplete
          ? []
          : [
              for (final id in popularIds)
                if (entry(id)?.active == true) entry(id)!,
            ];
    final ranks = <String, int>{};
    for (final e in entries.where((e) => e.active)) {
      for (final rawName in [e.commonName, e.scientificName, ...e.altNames]) {
        final name = normalizeCatalogName(rawName);
        for (
          var start = name.indexOf(q);
          start >= 0;
          start = name.indexOf(q, start + 1)
        ) {
          final rank = start == 0
              ? 0
              : name.codeUnitAt(start - 1) == 32
              ? 1
              : 2;
          if (rank < (ranks[e.id] ?? 3)) ranks[e.id] = rank;
        }
      }
    }
    return entries.where((e) => ranks.containsKey(e.id)).toList()..sort((a, b) {
      var c = ranks[a.id]!.compareTo(ranks[b.id]!);
      if (c == 0)
        c = catalogScalarCompare(
          normalizeCatalogName(a.commonName),
          normalizeCatalogName(b.commonName),
        );
      if (c == 0)
        c = catalogScalarCompare(
          normalizeCatalogName(a.scientificName),
          normalizeCatalogName(b.scientificName),
        );
      return c == 0 ? a.id.compareTo(b.id) : c;
    });
  }
}
