/// Generic `{ id, name }` row for admin dropdowns and pickers.
final class NamedIdOption {
  const NamedIdOption({required this.id, required this.name});

  final int id;
  final String name;
}

String formatNamedIdSelectionLabel(
  List<NamedIdOption> selected, {
  String emptyLabel = '',
  String multipleSuffix = 'forms selected',
}) {
  if (selected.isEmpty) return emptyLabel;
  if (selected.length == 1) return selected.first.name;
  return '${selected.length} $multipleSuffix';
}
