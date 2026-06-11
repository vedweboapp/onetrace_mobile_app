import 'package:red5/features/dashboard/data/report_models.dart';

enum ReportFieldType {
  all,
  text,
  status,
  number,
  date,
  relation,
}

extension ReportFieldTypeX on ReportFieldType {
  String get label => switch (this) {
        ReportFieldType.all => 'All Types',
        ReportFieldType.text => 'Text',
        ReportFieldType.status => 'Status',
        ReportFieldType.number => 'Number',
        ReportFieldType.date => 'Date',
        ReportFieldType.relation => 'Relation',
      };

  static List<ReportFieldType> get filterOptions => ReportFieldType.values;
}

final class ReportFieldDefinition {
  const ReportFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.tableKind = ReportTableCellKind.text,
    this.flex = 2,
    this.minWidth = 120,
    this.showInList = true,
  });

  final String key;
  final String label;
  final ReportFieldType type;
  final ReportTableCellKind tableKind;
  final int flex;
  final double minWidth;
  final bool showInList;
}

abstract final class ReportColumnCatalog {
  ReportColumnCatalog._();

  static const defaultSelectedKeys = [
    'project_name',
    'client',
    'status',
    'progress',
    'due_date',
  ];

  static const fields = [
    ReportFieldDefinition(
      key: 'project_name',
      label: 'Project Name',
      type: ReportFieldType.text,
      tableKind: ReportTableCellKind.stackedText,
      flex: 3,
      minWidth: 180,
    ),
    ReportFieldDefinition(
      key: 'client',
      label: 'Client',
      type: ReportFieldType.relation,
      tableKind: ReportTableCellKind.avatar,
      flex: 1,
      minWidth: 72,
    ),
    ReportFieldDefinition(
      key: 'status',
      label: 'Status',
      type: ReportFieldType.status,
      flex: 2,
      minWidth: 100,
    ),
    ReportFieldDefinition(
      key: 'progress',
      label: 'Progress',
      type: ReportFieldType.number,
      flex: 1,
      minWidth: 90,
    ),
    ReportFieldDefinition(
      key: 'due_date',
      label: 'Due Date',
      type: ReportFieldType.date,
      flex: 2,
      minWidth: 110,
    ),
    ReportFieldDefinition(key: 'address', label: 'Address', type: ReportFieldType.text),
    ReportFieldDefinition(
      key: 'address_city',
      label: 'Address - City',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'address_state',
      label: 'Address - State / Province',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'address_zip',
      label: 'Address - Zip / Postal Code',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'address_country',
      label: 'Address - Country / Region',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'address_latitude',
      label: 'Address - Latitude',
      type: ReportFieldType.number,
    ),
    ReportFieldDefinition(
      key: 'address_longitude',
      label: 'Address - Longitude',
      type: ReportFieldType.number,
    ),
    ReportFieldDefinition(
      key: 'description',
      label: 'Description',
      type: ReportFieldType.text,
      flex: 3,
      minWidth: 200,
    ),
    ReportFieldDefinition(
      key: 'created_by',
      label: 'Created By',
      type: ReportFieldType.relation,
    ),
    ReportFieldDefinition(
      key: 'phone_number',
      label: 'Phone Number',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(key: 'email', label: 'Email', type: ReportFieldType.text),
    ReportFieldDefinition(
      key: 'site_name',
      label: 'Site Name',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'what3words',
      label: 'What3words',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'quote_name',
      label: 'Quote name',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'order_number',
      label: 'Order number',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'salesperson',
      label: 'Salesperson',
      type: ReportFieldType.relation,
    ),
    ReportFieldDefinition(
      key: 'project_manager',
      label: 'Project manager',
      type: ReportFieldType.relation,
    ),
    ReportFieldDefinition(key: 'tags', label: 'Tags', type: ReportFieldType.text),
    ReportFieldDefinition(
      key: 'technicians',
      label: 'Technicians',
      type: ReportFieldType.relation,
    ),
    ReportFieldDefinition(
      key: 'customer_id',
      label: 'Customer ID',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'job_title',
      label: 'Job Title',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'assigned_worker',
      label: 'Assigned worker',
      type: ReportFieldType.relation,
    ),
    ReportFieldDefinition(
      key: 'project_type',
      label: 'Project type',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'group_name',
      label: 'Group name',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'composite_item',
      label: 'Composite item',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(
      key: 'item_name',
      label: 'Item name',
      type: ReportFieldType.text,
    ),
    ReportFieldDefinition(key: 'sku', label: 'SKU', type: ReportFieldType.text),
    ReportFieldDefinition(
      key: 'quantity',
      label: 'Quantity',
      type: ReportFieldType.number,
    ),
    ReportFieldDefinition(
      key: 'cost_price',
      label: 'Cost price',
      type: ReportFieldType.number,
    ),
    ReportFieldDefinition(
      key: 'selling_price',
      label: 'Selling price',
      type: ReportFieldType.number,
    ),
    ReportFieldDefinition(
      key: 'composite_items',
      label: 'Composite Items',
      type: ReportFieldType.text,
    ),
  ];

  static int get totalCount => fields.length;

  static ReportFieldDefinition? fieldByKey(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  static List<ReportFieldDefinition> resolveSelected(List<String> keys) {
    return [
      for (final key in keys)
        if (fieldByKey(key) != null) fieldByKey(key)!,
    ];
  }

  static List<ReportTableColumn> tableColumnsFor(List<String> keys) {
    return [
      for (final field in resolveSelected(keys))
        ReportTableColumn(
          key: field.key,
          label: field.label.toUpperCase(),
          flex: field.flex,
          kind: field.tableKind,
          minWidth: field.minWidth,
        ),
    ];
  }
}
