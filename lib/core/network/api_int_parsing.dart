/// Parses integer primary keys from heterogeneous API JSON values.
int? readApiInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// Reads the first non-null integer id from [map] using [keys] in order.
int? readApiIntFromMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final parsed = readApiInt(map[key]);
    if (parsed != null) return parsed;
  }
  return null;
}
