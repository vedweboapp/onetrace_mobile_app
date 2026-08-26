part of '../quotation_detail.dart';

double _scopeParseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(RegExp(r'[£€,\s]'), '').trim();
  return double.tryParse(s) ?? 0;
}

Map<String, dynamic> _scopeAsMap(dynamic raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return const {};
}
