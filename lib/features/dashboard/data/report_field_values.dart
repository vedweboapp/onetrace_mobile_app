import 'package:intl/intl.dart';
import 'package:red5/features/dashboard/data/report_column_fields.dart';
import 'package:red5/features/dashboard/data/report_models.dart';

extension ReportListCardItemFields on ReportListCardItem {
  static final _dateFormat = DateFormat('MMM d, yyyy');

  Map<String, String> get allTextValues => {
        'project_name': title,
        'client': assigneeName,
        'status': status.label,
        'progress': '$progressPercent%',
        'due_date': _dateFormat.format(dueDate),
        'address': extraFields['address'] ?? '—',
        'address_city': extraFields['address_city'] ?? '—',
        'address_state': extraFields['address_state'] ?? '—',
        'address_zip': extraFields['address_zip'] ?? '—',
        'address_country': extraFields['address_country'] ?? '—',
        'address_latitude': extraFields['address_latitude'] ?? '—',
        'address_longitude': extraFields['address_longitude'] ?? '—',
        'description': extraFields['description'] ?? subtitle,
        'created_by': extraFields['created_by'] ?? assigneeName,
        'phone_number': extraFields['phone_number'] ?? '—',
        'email': extraFields['email'] ?? '—',
        'site_name': extraFields['site_name'] ?? '—',
        'what3words': extraFields['what3words'] ?? '—',
        'quote_name': extraFields['quote_name'] ?? '—',
        'order_number': extraFields['order_number'] ?? '—',
        'salesperson': extraFields['salesperson'] ?? '—',
        'project_manager': extraFields['project_manager'] ?? assigneeName,
        'tags': extraFields['tags'] ?? subtitle,
        'technicians': extraFields['technicians'] ?? '—',
        'customer_id': extraFields['customer_id'] ?? '—',
        'job_title': extraFields['job_title'] ?? '—',
        'assigned_worker': extraFields['assigned_worker'] ?? assigneeName,
        'project_type': extraFields['project_type'] ?? subtitle,
        'group_name': extraFields['group_name'] ?? '—',
        'composite_item': extraFields['composite_item'] ?? '—',
        'item_name': extraFields['item_name'] ?? '—',
        'sku': extraFields['sku'] ?? '—',
        'quantity': extraFields['quantity'] ?? '—',
        'cost_price': extraFields['cost_price'] ?? '—',
        'selling_price': extraFields['selling_price'] ?? '—',
        'composite_items': extraFields['composite_items'] ?? '—',
      };

  ReportTableCell tableCellFor(String key) {
    final field = ReportColumnCatalog.fieldByKey(key);
    if (field == null) return const ReportTableCell.text('—');

    return switch (field.tableKind) {
      ReportTableCellKind.stackedText => ReportTableCell.stacked(
          primary: title,
          secondary: subtitle,
        ),
      ReportTableCellKind.avatar => ReportTableCell.avatar(
          primary: assigneeName,
          avatarUrl: assigneeAvatarUrl,
        ),
      ReportTableCellKind.text => ReportTableCell.text(
          allTextValues[key] ?? '—',
        ),
    };
  }

  ReportTableRow toTableRow(List<String> columnKeys) {
    return ReportTableRow(
      id: id,
      cells: {
        for (final key in columnKeys) key: tableCellFor(key),
      },
    );
  }

  bool matchesQueryWithFields(String query, List<String> columnKeys) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    for (final key in columnKeys) {
      final value = allTextValues[key]?.toLowerCase() ?? '';
      if (value.contains(q)) return true;
    }
    return matchesQuery(query);
  }
}
