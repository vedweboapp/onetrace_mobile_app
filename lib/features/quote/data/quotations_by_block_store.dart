import 'dart:convert';

import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

/// JSON object: block name → `{ documents, selectedIndex }`.
typedef QuotationsByBlock = Map<String, Map<String, dynamic>>;

abstract final class QuotationsByBlockStore {
  const QuotationsByBlockStore._();

  static QuotationsByBlock decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(
          k.toString(),
          v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static String encode(QuotationsByBlock data) => jsonEncode(data);

  static QuotationsByBlock read(LocalStorage storage) {
    return decode(storage.getString(LocalStorageKeys.quotationsByBlock));
  }

  static Future<void> write(LocalStorage storage, QuotationsByBlock data) async {
    if (data.isEmpty) {
      await storage.remove(LocalStorageKeys.quotationsByBlock);
      return;
    }
    await storage.setString(LocalStorageKeys.quotationsByBlock, encode(data));
  }

  /// Migrates legacy single-session storage into the first block bucket.
  static Future<QuotationsByBlock> readWithLegacyMigration(LocalStorage storage) async {
    var map = read(storage);
    if (map.isNotEmpty) return map;

    final legacy = storage.getString(LocalStorageKeys.quoteSession);
    if (legacy == null || legacy.isEmpty) return map;

    try {
      final decoded = jsonDecode(legacy) as Map<String, dynamic>;
      final docs = decoded['documents'];
      if (docs is! List || docs.isEmpty) return map;

      map = {
        'Imported': Map<String, dynamic>.from(decoded),
      };
      await write(storage, map);
      await storage.remove(LocalStorageKeys.quoteSession);
    } catch (_) {
      // ignore corrupt legacy
    }
    return map;
  }
}
