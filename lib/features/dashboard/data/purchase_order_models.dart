import 'package:flutter/material.dart';
import 'package:red5/core/network/api_int_parsing.dart';
import 'package:red5/features/dashboard/data/invoice_models.dart';
import 'package:red5/core/network/api_pagination.dart';

enum PurchaseOrderListStatus { paid, pending, overdue, open, draft }

enum PurchaseOrderDetailStatus { open, paid, pending, overdue, draft }

class PurchaseOrderListItem {
  const PurchaseOrderListItem({
    required this.id,
    required this.purchaseOrderNumber,
    required this.amount,
    required this.vendorName,
    required this.category,
    required this.date,
    required this.status,
    this.vendorAvatarUrl,
  });

  /// API primary key (used for navigation).
  final String id;
  final String purchaseOrderNumber;
  final double amount;
  final String vendorName;
  final String category;
  final DateTime date;
  final PurchaseOrderListStatus status;
  final String? vendorAvatarUrl;

  factory PurchaseOrderListItem.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final number = _readString(json, const [
          'purchase_order_number',
          'purchaseOrderNumber',
        ]) ??
        (id.isEmpty ? '—' : id);
    final vendorName = _readRelationName(
      json['vendor'],
      json: json,
      flatNameKeys: const ['vendor_name'],
      nestedNameKeys: const ['name'],
      label: 'Vendor',
    );
    final projectRaw = json['project'];
    final project = readApiMap(projectRaw);
    final category = _readString(json, const [
          'category_name',
          'category',
        ]) ??
        _readString(project, const ['name']) ??
        _readString(json, const ['project_name']) ??
        '—';
    final amount = _readAmount(json['total']) > 0
        ? _readAmount(json['total'])
        : _readAmount(json['total_balance'] ?? json['sub_total']);
    final date = _readDate(json['issue_date']) ??
        _readDate(json['created_at']) ??
        DateTime.now();
    return PurchaseOrderListItem(
      id: id.isEmpty ? number : id,
      purchaseOrderNumber: number,
      amount: amount,
      vendorName: vendorName,
      category: category,
      date: date,
      status: _parseListStatus(json['status']),
    );
  }
}

String purchaseOrderListStatusLabel(PurchaseOrderListStatus status) {
  return switch (status) {
    PurchaseOrderListStatus.paid => 'Paid',
    PurchaseOrderListStatus.pending => 'Pending',
    PurchaseOrderListStatus.overdue => 'Overdue',
    PurchaseOrderListStatus.open => 'Open',
    PurchaseOrderListStatus.draft => 'Draft',
  };
}

Color purchaseOrderListStatusColor(PurchaseOrderListStatus status) {
  return switch (status) {
    PurchaseOrderListStatus.paid => const Color(0xFF22C55E),
    PurchaseOrderListStatus.open => const Color(0xFF22C55E),
    PurchaseOrderListStatus.draft => const Color(0xFF6B7280),
    PurchaseOrderListStatus.pending => const Color(0xFFF59E0B),
    PurchaseOrderListStatus.overdue => const Color(0xFFEF4444),
  };
}

class PurchaseOrderAddress {
  const PurchaseOrderAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
}

class PurchaseOrderLineItem {
  const PurchaseOrderLineItem({
    required this.productName,
    required this.qty,
    required this.listPrice,
    required this.amount,
    required this.discount,
    required this.tax,
    required this.total,
    this.compositeItemId,
    this.groupId,
  });

  final String productName;
  final double qty;
  final double listPrice;
  final double amount;
  final double discount;
  final double tax;
  final double total;
  final int? compositeItemId;
  final int? groupId;
}

class PurchaseOrderDetail {
  const PurchaseOrderDetail({
    required this.id,
    required this.purchaseOrderNumber,
    required this.status,
    required this.vendorName,
    required this.contactPerson,
    required this.projectName,
    required this.categoryName,
    required this.issueDate,
    required this.dueDate,
    required this.paymentTerms,
    required this.billingAddress,
    required this.shippingAddress,
    required this.notes,
    required this.lineItems,
    this.vendorId,
    this.projectId,
    this.contactId,
    this.statusKey,
    this.internalNotes = '',
    this.adjustment = 0,
    this.orderDiscount = 0,
    this.orderTax = 0,
    this.grandTotalAmount = 0,
  });

  final String id;
  final String purchaseOrderNumber;
  final PurchaseOrderDetailStatus status;
  final String vendorName;
  final String contactPerson;
  final String projectName;
  final String categoryName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String paymentTerms;
  final PurchaseOrderAddress billingAddress;
  final PurchaseOrderAddress shippingAddress;
  final String notes;
  final List<PurchaseOrderLineItem> lineItems;
  final String? vendorId;
  final String? projectId;
  final String? contactId;
  final String? statusKey;
  final String internalNotes;
  final double adjustment;
  final double orderDiscount;
  final double orderTax;
  final double grandTotalAmount;

  double get subtotal =>
      lineItems.fold<double>(0, (sum, item) => sum + item.total);

  double get grandTotal => grandTotalAmount > 0
      ? grandTotalAmount
      : subtotal - orderDiscount + orderTax + adjustment;

  String get statusLabel => switch (status) {
        PurchaseOrderDetailStatus.open => 'Open',
        PurchaseOrderDetailStatus.paid => 'Paid',
        PurchaseOrderDetailStatus.pending => 'Pending',
        PurchaseOrderDetailStatus.overdue => 'Overdue',
        PurchaseOrderDetailStatus.draft => 'Draft',
      };

  Color get statusColor => switch (status) {
        PurchaseOrderDetailStatus.open => const Color(0xFF22C55E),
        PurchaseOrderDetailStatus.paid => const Color(0xFF22C55E),
        PurchaseOrderDetailStatus.draft => const Color(0xFF6B7280),
        PurchaseOrderDetailStatus.pending => const Color(0xFFF59E0B),
        PurchaseOrderDetailStatus.overdue => const Color(0xFFEF4444),
      };

  factory PurchaseOrderDetail.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final number = _readString(json, const ['purchase_order_number']) ??
        (id.isEmpty ? '—' : id);
    final vendorName = _readRelationName(
      json['vendor'],
      json: json,
      flatNameKeys: const ['vendor_name'],
      nestedNameKeys: const ['name'],
      label: 'Vendor',
    );
    final contactPerson = _readRelationName(
      json['contact'],
      json: json,
      flatNameKeys: const ['contact_person', 'contact_name'],
      nestedNameKeys: const ['name', 'contact_name'],
      label: 'Contact',
    );
    final projectName = _readString(json, const ['project_name']) ??
        _readRelationName(
          json['project'],
          json: json,
          flatNameKeys: const ['project_name'],
          nestedNameKeys: const ['name'],
          label: 'Project',
        );
    final categoryName = _readString(json, const [
          'category_name',
          'category',
        ]) ??
        '—';
    final billing = _parseAddress(
      _firstNonEmptyMap(json, const ['bill_to', 'billing_address']),
      fallbackName: vendorName,
      root: json,
      prefix: 'billing',
    );
    final shipping = _parseAddress(
      _firstNonEmptyMap(json, const ['ship_to', 'shipping_address']),
      fallbackName: vendorName,
      root: json,
      prefix: 'shipping',
    );
    final lineItems = _parseLineItems(json);
    final adjustment = _readAmount(json['adjustment_amount']);
    final grandTotal = _readAmount(json['total']) > 0
        ? _readAmount(json['total'])
        : _readAmount(json['total_balance']);
    final vendorIdRaw = _readRelationId(
      json['vendor'],
      legacyKey: 'vendor_id',
      json: json,
    );
    final projectIdRaw = _readRelationId(
      json['project'],
      legacyKey: 'project_id',
      json: json,
    );
    final contactIdRaw = _readRelationId(
      json['contact'],
      legacyKey: 'contact_id',
      json: json,
    );
    return PurchaseOrderDetail(
      id: id.isEmpty ? number : id,
      purchaseOrderNumber: number,
      status: _parseDetailStatus(json['status']),
      vendorName: vendorName,
      contactPerson: contactPerson,
      projectName: projectName,
      categoryName: categoryName,
      issueDate: _readDate(json['issue_date']),
      dueDate: _readDate(json['due_date']),
      paymentTerms: invoicePaymentTermsFromApi(
        _readString(json, const ['payment_terms']),
      ),
      billingAddress: billing,
      shippingAddress: shipping,
      notes: _readString(json, const [
            'vendor_notes',
            'notes',
            'client_notes',
          ]) ??
          '',
      lineItems: lineItems,
      vendorId: _readIdString(vendorIdRaw),
      projectId: _readIdString(projectIdRaw),
      contactId: _readIdString(contactIdRaw),
      statusKey: _readString(json, const ['status']),
      internalNotes: _readString(json, const ['internal_notes']) ?? '',
      adjustment: adjustment,
      grandTotalAmount: grandTotal,
    );
  }
}

String? _readIdString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// FK when API returns a nested object, plain id, or legacy `*_id` key.
String? _readRelationId(
  dynamic raw, {
  String? legacyKey,
  Map<String, dynamic>? json,
}) {
  if (raw is int || raw is num) return raw.toString();
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (int.tryParse(text) != null) return text;
  }
  if (raw is Map) return _readIdString(raw['id']);
  if (json != null && legacyKey != null) {
    return _readIdString(json[legacyKey]);
  }
  return null;
}

String _readRelationName(
  dynamic raw, {
  required Map<String, dynamic> json,
  required List<String> flatNameKeys,
  List<String> nestedNameKeys = const ['name'],
  required String label,
}) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final name = _readString(map, nestedNameKeys);
    if (name != null) return name;
  }
  final flat = _readString(json, flatNameKeys);
  if (flat != null) return flat;
  final id = _readRelationId(raw);
  if (id != null) return '$label $id';
  return '—';
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

double _readAmount(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

PurchaseOrderListStatus _parseListStatus(dynamic raw) {
  return switch ((raw ?? '').toString().trim().toLowerCase()) {
    'paid' => PurchaseOrderListStatus.paid,
    'overdue' => PurchaseOrderListStatus.overdue,
    'pending' => PurchaseOrderListStatus.pending,
    'open' => PurchaseOrderListStatus.open,
    'draft' => PurchaseOrderListStatus.draft,
    _ => PurchaseOrderListStatus.pending,
  };
}

PurchaseOrderDetailStatus _parseDetailStatus(dynamic raw) {
  return switch ((raw ?? '').toString().trim().toLowerCase()) {
    'paid' => PurchaseOrderDetailStatus.paid,
    'overdue' => PurchaseOrderDetailStatus.overdue,
    'pending' => PurchaseOrderDetailStatus.pending,
    'open' => PurchaseOrderDetailStatus.open,
    'draft' => PurchaseOrderDetailStatus.draft,
    _ => PurchaseOrderDetailStatus.pending,
  };
}

PurchaseOrderAddress _parseAddress(
  Map<String, dynamic> json, {
  required String fallbackName,
  Map<String, dynamic>? root,
  String? prefix,
}) {
  final merged = Map<String, dynamic>.from(json);
  if (root != null && prefix != null) {
    for (final key in const [
      'address_line_1',
      'address_line_2',
      'city',
      'state',
      'country',
      'postal_code',
      'pincode',
      'zip',
    ]) {
      if (_readString(merged, [key]) != null) continue;
      final flat = _readString(root, [
        '${prefix}_$key',
        '${prefix}_address_$key',
        'bill_to_$key',
        'ship_to_$key',
      ]);
      if (flat != null) merged[key] = flat;
    }
  }
  if (merged.isEmpty) {
    return PurchaseOrderAddress(
      street: fallbackName,
      city: '—',
      state: '—',
      postalCode: '—',
      country: '—',
    );
  }
  final line1 = _readString(merged, const ['address_line_1', 'line1']) ?? '';
  final line2 = _readString(merged, const ['address_line_2', 'line2']) ?? '';
  final street = [line1, line2].where((p) => p.isNotEmpty).join(', ');
  return PurchaseOrderAddress(
    street: street.isEmpty ? fallbackName : street,
    city: _readString(merged, const ['city']) ?? '—',
    state: _readString(merged, const ['state']) ?? '—',
    postalCode:
        _readString(merged, const ['postal_code', 'pincode', 'zip']) ?? '—',
    country: _readString(merged, const ['country']) ?? '—',
  );
}

List<PurchaseOrderLineItem> _parseLineItems(Map<String, dynamic> json) {
  final raw = json['composite_items'] ??
      json['line_items'] ??
      json['items'] ??
      json['purchase_order_items'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((row) {
    final map = Map<String, dynamic>.from(row);
    final compositeItem = readApiMap(map['composite_item']);
    final productName = _readString(map, const [
          'product_name',
          'name',
          'item_name',
        ]) ??
        _readString(compositeItem, const ['name']) ??
        'Item';
    final compositeItemId = readApiInt(map['id']) ??
        readApiInt(map['composite_item_id']) ??
        readApiInt(compositeItem['id']);
    final groupRaw = readApiMap(map['group']);
    final groupId = readApiInt(groupRaw['id']) ?? readApiInt(map['group_id']);
    final qty = _readAmount(map['qty'] ?? map['quantity']);
    final listPrice = _readAmount(map['list_price'] ?? map['unit_price']);
    final amount = _readAmount(map['amount']);
    final discount = _readAmount(map['discount']);
    final tax = _readAmount(map['tax']);
    final total = _readAmount(map['total']) > 0
        ? _readAmount(map['total'])
        : (amount > 0 ? amount : qty * listPrice);
    return PurchaseOrderLineItem(
      productName: productName,
      qty: qty,
      listPrice: listPrice,
      amount: amount > 0 ? amount : qty * listPrice,
      discount: discount,
      tax: tax,
      total: total,
      compositeItemId: compositeItemId,
      groupId: groupId,
    );
  }).toList(growable: false);
}

Map<String, dynamic> _firstNonEmptyMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final map = readApiMap(json[key]);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

/// Static preview data until purchase-order API exists.
abstract final class PurchaseOrderMockData {
  PurchaseOrderMockData._();

  static const _address = PurchaseOrderAddress(
    street: '4500 Industrial Parkway, Suite 200',
    city: 'Chicago',
    state: 'IL',
    postalCode: '60601',
    country: 'United States',
  );

  static const _notes =
      'Payment is due within 30 days of purchase order date. Late payments may incur additional charges.';

  static final PurchaseOrderDetail primary = PurchaseOrderDetail(
    id: 'pur-2024-001',
    purchaseOrderNumber: 'PUR-2024-001',
    status: PurchaseOrderDetailStatus.open,
    vendorName: 'BuildPro Construction LLC',
    contactPerson: 'Smith',
    projectName: 'PRJ-2024-001',
    categoryName: 'Raw Material',
    issueDate: DateTime(2024, 1, 15),
    dueDate: DateTime(2024, 2, 14),
    paymentTerms: 'Net 30 Days',
    billingAddress: _address,
    shippingAddress: _address,
    notes: _notes,
    lineItems: const [
      PurchaseOrderLineItem(
        productName: 'Product Name',
        qty: 1,
        listPrice: 0,
        amount: 0,
        discount: 0,
        tax: 0,
        total: 0,
      ),
    ],
    adjustment: 0,
    orderDiscount: 0,
    orderTax: 0,
    grandTotalAmount: 0,
  );

  static PurchaseOrderDetail detailForId(String rawId) {
    final id = rawId.trim();
    final key = id.toLowerCase();
    if (key == 'pur-2024-001' || key == '1') return primary;
    return PurchaseOrderDetail(
      id: id,
      purchaseOrderNumber: id.toUpperCase().startsWith('PUR') ? id : 'PUR-$id',
      status: PurchaseOrderDetailStatus.open,
      vendorName: 'Metropolis Urban Dev',
      contactPerson: 'Smith',
      projectName: 'PRJ-2024-001',
      categoryName: 'Raw Material',
      issueDate: DateTime(2024, 1, 15),
      dueDate: DateTime(2024, 2, 14),
      paymentTerms: 'Net 30 Days',
      billingAddress: _address,
      shippingAddress: _address,
      notes: _notes,
      lineItems: const [
        PurchaseOrderLineItem(
          productName: 'Product Name',
          qty: 1,
          listPrice: 0,
          amount: 0,
          discount: 0,
          tax: 0,
          total: 0,
        ),
      ],
    );
  }

  static final List<PurchaseOrderListItem> listItems = [
    PurchaseOrderListItem(
      id: 'PUR-2024-001',
      purchaseOrderNumber: 'PUR-2024-001',
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      category: 'Raw Material',
      date: DateTime(2024, 1, 15),
      status: PurchaseOrderListStatus.paid,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-002',
      purchaseOrderNumber: 'PUR-2024-002',
      amount: 12800,
      vendorName: 'BuildPro Supply Co',
      category: 'Equipment',
      date: DateTime(2024, 2, 3),
      status: PurchaseOrderListStatus.pending,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-003',
      purchaseOrderNumber: 'PUR-2024-003',
      amount: 9750,
      vendorName: 'Northwind Materials',
      category: 'Raw Material',
      date: DateTime(2024, 2, 18),
      status: PurchaseOrderListStatus.paid,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-004',
      purchaseOrderNumber: 'PUR-2024-004',
      amount: 22100,
      vendorName: 'Apex Structural Group',
      category: 'Steel & Fabrication',
      date: DateTime(2024, 3, 5),
      status: PurchaseOrderListStatus.overdue,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-005',
      purchaseOrderNumber: 'PUR-2024-005',
      amount: 6400,
      vendorName: 'Riverview Developments',
      category: 'Consumables',
      date: DateTime(2024, 3, 22),
      status: PurchaseOrderListStatus.pending,
    ),
  ];
}
