/// Formats a [DateTime] as `MMM d, yyyy, h:mm a` (e.g. `May 6, 2026, 5:14 PM`).
///
/// Kept dependency-free to avoid pulling in `intl` for one date string.
String formatGroupDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final month = _months[local.month - 1];
  final day = local.day;
  final year = local.year;
  final hour24 = local.hour;
  final hour12Raw = hour24 % 12;
  final hour12 = hour12Raw == 0 ? 12 : hour12Raw;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  return '$month $day, $year, $hour12:$minute $period';
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
