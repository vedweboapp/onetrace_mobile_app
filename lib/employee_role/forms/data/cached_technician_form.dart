import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:red5/features/forms/data/form_models.dart';

enum TechnicianFormSource { remote, cache }

@immutable
final class TechnicianFormBundle {
  const TechnicianFormBundle({
    required this.formId,
    required this.summary,
    required this.metadata,
    required this.rules,
    required this.fetchedAt,
    required this.source,
    this.contentHash,
  });

  final int formId;
  final FormSummary summary;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>> rules;
  final DateTime fetchedAt;
  final TechnicianFormSource source;
  final String? contentHash;

  TechnicianFormBundle copyWith({
    FormSummary? summary,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? rules,
    DateTime? fetchedAt,
    TechnicianFormSource? source,
    String? contentHash,
  }) {
    return TechnicianFormBundle(
      formId: formId,
      summary: summary ?? this.summary,
      metadata: metadata ?? this.metadata,
      rules: rules ?? this.rules,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      source: source ?? this.source,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  static String computeContentHash({
    required Map<String, dynamic> summaryRaw,
    required Map<String, dynamic> metadata,
    required List<Map<String, dynamic>> rules,
  }) {
    final payload = jsonEncode(<String, dynamic>{
      'summary': summaryRaw,
      'metadata': metadata,
      'rules': rules,
    });
    return payload.hashCode.toRadixString(16);
  }

  Map<String, dynamic> toDbRow() {
    return <String, dynamic>{
      'form_id': formId,
      'summary_json': jsonEncode(summary.raw),
      'metadata_json': jsonEncode(metadata),
      'rules_json': jsonEncode(rules),
      'fetched_at': fetchedAt.millisecondsSinceEpoch,
      'content_hash': contentHash,
    };
  }

  static TechnicianFormBundle fromDbRow(
    Map<String, dynamic> row, {
    TechnicianFormSource source = TechnicianFormSource.cache,
  }) {
    final formId = row['form_id'] as int;
    final summaryMap = _decodeMap(row['summary_json'] as String);
    final metadata = _decodeMap(row['metadata_json'] as String);
    final rulesRaw = jsonDecode(row['rules_json'] as String);
    final rules = rulesRaw is List
        ? rulesRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final fetchedAtMs = row['fetched_at'] as int;

    return TechnicianFormBundle(
      formId: formId,
      summary: FormSummary.fromJson(summaryMap),
      metadata: metadata,
      rules: rules,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      source: source,
      contentHash: row['content_hash'] as String?,
    );
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, dynamic>{};
  }
}
