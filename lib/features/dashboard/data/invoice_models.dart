import 'package:flutter/material.dart';
import 'package:red5/core/network/api_int_parsing.dart';

double? readApiDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim().replaceAll(',', '');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String _readString(Map<String, dynamic> json, List<String> keys,
    {String fallback = ''}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    return text;
  }
  return fallback;
}

Map<String, dynamic> _readMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

/// Maps UI payment-term labels to API slugs (`net_30`, `net_45`, …).
String invoicePaymentTermsToApi(String display) {
  return switch (display.trim().toLowerCase()) {
    'net 15 days' => 'net_15',
    'net 45 days' => 'net_45',
    'net 60 days' => 'net_60',
    'due on receipt' => 'due_on_receipt',
    _ => 'net_30',
  };
}

String invoicePaymentTermsFromApi(String? raw) {
  final key = (raw ?? '').trim().toLowerCase().replaceAll(' ', '_');
  return switch (key) {
    'net_15' => 'Net 15 Days',
    'net_45' => 'Net 45 Days',
    'net_60' => 'Net 60 Days',
    'due_on_receipt' => 'Due on receipt',
    'net_30' => 'Net 30 Days',
    _ when raw != null && raw.trim().isNotEmpty => raw.trim(),
    _ => 'Net 30 Days',
  };
}

/// Row for `POST /api/v1/invoice/` composite_items[].
class InvoiceCompositeItemPayload {
  const InvoiceCompositeItemPayload({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
    this.groupId,
    this.groupName,
  });

  final int id;
  final String name;
  final double quantity;
  final double amount;
  final int? groupId;
  final String? groupName;

  Map<String, dynamic> toJson() {
    final group = <String, dynamic>{};
    if (groupId != null) group['id'] = groupId;
    if (groupName != null && groupName!.trim().isNotEmpty) {
      group['name'] = groupName!.trim();
    }
    return <String, dynamic>{
      'id': id,
      'name': name.trim(),
      if (group.isNotEmpty) 'group': group,
      'quantity': quantity,
      'amount': amount,
    };
  }
}

class InvoiceAddressPayload {
  const InvoiceAddressPayload({
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    this.pincode,
    required this.country,
  });

  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String? pincode;
  final String country;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'address_line_1': addressLine1.trim(),
        'address_line_2': addressLine2?.trim().isEmpty ?? true
            ? null
            : addressLine2!.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'pincode': pincode?.trim().isEmpty ?? true ? null : pincode!.trim(),
        'country': country.trim(),
      };
}

class InvoiceCreatePayload {
  const InvoiceCreatePayload({
    required this.clientId,
    required this.contactId,
    required this.projectId,
    required this.total,
    required this.dueDate,
    required this.paymentTerms,
    required this.billTo,
    required this.shipTo,
    required this.compositeItems,
    this.clientNotes,
    this.internalNotes,
  });

  final int clientId;
  final int contactId;
  final int projectId;
  final double total;
  final String dueDate;
  final String paymentTerms;
  final InvoiceAddressPayload billTo;
  final InvoiceAddressPayload shipTo;
  final List<InvoiceCompositeItemPayload> compositeItems;
  final String? clientNotes;
  final String? internalNotes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'client': clientId,
        'contact': contactId,
        'project': projectId,
        'total': total,
        'due_date': dueDate,
        'payment_terms': paymentTerms,
        'bill_to': billTo.toJson(),
        'ship_to': shipTo.toJson(),
        'composite_items':
            compositeItems.map((e) => e.toJson()).toList(growable: false),
        if (clientNotes != null && clientNotes!.trim().isNotEmpty)
          'client_notes': clientNotes!.trim(),
        if (internalNotes != null && internalNotes!.trim().isNotEmpty)
          'internal_notes': internalNotes!.trim(),
      };
}

/// `GET /api/v1/invoice/` list row.
class InvoiceListItem {
  const InvoiceListItem({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.projectName,
    required this.issueDate,
    required this.dueDate,
    required this.paymentTerms,
    required this.subTotal,
    required this.adjustmentAmount,
    required this.totalBalance,
    required this.status,
    this.clientAvatarUrl,
  });

  final String id;
  final String invoiceNumber;
  final String clientName;
  final String projectName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String paymentTerms;
  final double subTotal;
  final double adjustmentAmount;
  final double totalBalance;
  final String status;
  final String? clientAvatarUrl;

  /// Display amount for list tiles.
  double get amount => totalBalance;

  DateTime get date => issueDate ?? dueDate ?? DateTime.now();

  InvoiceStatus get listStatus => invoiceStatusFromApi(status);

  factory InvoiceListItem.fromJson(Map<String, dynamic> json) {
    final client = _readMap(json['client']);
    return InvoiceListItem(
      id: _readString(json, const ['id'], fallback: ''),
      invoiceNumber: _readString(
        json,
        const ['invoice_number', 'invoice_no', 'number'],
      ),
      clientName: _readString(client, const ['name', 'client_name']),
      projectName: json['project_name'] is String
          ? (json['project_name'] as String).trim()
          : _readString(
              _readMap(json['project']),
              const ['name', 'project_name', 'title'],
            ),
      issueDate: _parseDate(json['issue_date']),
      dueDate: _parseDate(json['due_date']),
      paymentTerms: invoicePaymentTermsFromApi(
        _readString(json, const ['payment_terms']),
      ),
      subTotal: readApiDouble(json['sub_total']) ?? 0,
      adjustmentAmount: readApiDouble(json['adjustment_amount']) ?? 0,
      totalBalance: readApiDouble(json['total_balance']) ??
          readApiDouble(json['total']) ??
          0,
      status: _readString(json, const ['status']),
    );
  }
}

class InvoiceNamedRef {
  const InvoiceNamedRef({required this.id, required this.name});

  final int? id;
  final String name;

  factory InvoiceNamedRef.fromJson(Map<String, dynamic> json) {
    return InvoiceNamedRef(
      id: readApiInt(json['id']),
      name: _readString(json, const ['name', 'title']),
    );
  }
}

class InvoiceAddress {
  const InvoiceAddress({
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  /// Legacy alias used by detail overview layout.
  String get street => addressLine1;

  factory InvoiceAddress.fromJson(Map<String, dynamic> json) {
    return InvoiceAddress(
      addressLine1: _readString(
        json,
        const ['address_line_1', 'address_line1', 'street'],
      ),
      addressLine2: _readString(
        json,
        const ['address_line_2', 'address_line2'],
      ),
      city: _readString(json, const ['city']),
      state: _readString(json, const ['state']),
      postalCode: _readString(
        json,
        const ['pincode', 'postal_code', 'zip', 'zip_code'],
      ),
      country: _readString(json, const ['country']),
    );
  }
}

class InvoiceProductItem {
  const InvoiceProductItem({
    required this.productName,
    required this.qty,
    required this.listPrice,
    required this.amount,
    required this.discount,
    required this.tax,
    required this.total,
    this.groupName,
  });

  final String productName;
  final double qty;
  final double listPrice;
  final double amount;
  final double discount;
  final double tax;
  final double total;
  final String? groupName;

  factory InvoiceProductItem.fromCompositeJson(Map<String, dynamic> json) {
    final group = _readMap(json['group']);
    final item = _readMap(json['item']);
    final qty = readApiDouble(json['quantity']) ?? 1;
    final safeQty = qty > 0 ? qty : 1.0;

    final topName = _readString(
      json,
      const ['name', 'item_name', 'title', 'product_name'],
    );
    final nestedName = _readString(
      item,
      const ['name', 'item_name', 'title', 'product_name'],
    );
    final productName =
        topName.isNotEmpty ? topName : (nestedName.isEmpty ? '—' : nestedName);

    final lineTotal = readApiDouble(json['line_total']);
    final rowAmount = readApiDouble(json['amount']);
    final selling = readApiDouble(item['selling_price']) ??
        readApiDouble(json['selling_price']) ??
        readApiDouble(json['unit_price']) ??
        0;

    var listPrice = selling;
    if (listPrice <= 0 && lineTotal != null && safeQty > 0) {
      listPrice = lineTotal / safeQty;
    } else if (listPrice <= 0 && rowAmount != null && safeQty > 0) {
      listPrice = rowAmount / safeQty;
    }

    final amount = rowAmount ?? (safeQty * listPrice);
    var total = lineTotal ?? amount.toDouble();
    if (listPrice <= 0 && safeQty > 0 && total > 0) {
      listPrice = total / safeQty;
    }
    if (total <= 0 && listPrice > 0) {
      total = safeQty * listPrice;
    }

    final groupName = _readString(group, const ['name', 'group_name']);
    return InvoiceProductItem(
      productName: productName,
      qty: safeQty,
      listPrice: listPrice,
      amount: amount,
      discount: readApiDouble(json['discount']) ?? 0,
      tax: readApiDouble(json['tax']) ?? 0,
      total: total,
      groupName: groupName.isEmpty ? null : groupName,
    );
  }
}

/// `GET /api/v1/invoice/{id}/` body.
class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.clientName,
    required this.contactPerson,
    required this.projectName,
    required this.issueDate,
    required this.dueDate,
    required this.paymentTerms,
    required this.billingAddress,
    required this.shippingAddress,
    required this.notes,
    required this.internalNotes,
    required this.productItems,
    this.adjustment = 0,
    this.invoiceDiscount = 0,
    this.invoiceTax = 0,
    this.total = 0,
  });

  final String id;
  final String invoiceNumber;
  final String status;
  final String clientName;
  final String contactPerson;
  final String projectName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String paymentTerms;
  final InvoiceAddress billingAddress;
  final InvoiceAddress shippingAddress;
  final String notes;
  final String internalNotes;
  final List<InvoiceProductItem> productItems;
  final double adjustment;
  final double invoiceDiscount;
  final double invoiceTax;
  final double total;

  double get subtotal => productItems.fold<double>(
        0,
        (sum, item) => sum + (item.total > 0 ? item.total : item.amount),
      );

  double get grandTotal {
    if (total > 0) return total;
    final computed = subtotal - invoiceDiscount + invoiceTax + adjustment;
    return computed > 0 ? computed : subtotal;
  }

  InvoiceDetailStatus get detailStatus => invoiceDetailStatusFromApi(status);

  String get statusLabel => status.isEmpty ? '—' : _capitalizeStatus(status);

  Color get statusColor => invoiceStatusColor(detailStatus);

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final client = _readMap(json['client']);
    final contact = _readMap(json['contact']);
    final project = _readMap(json['project']);
    final compositeRaw = json['composite_items'];
    final products = <InvoiceProductItem>[];
    if (compositeRaw is List) {
      for (final row in compositeRaw) {
        if (row is Map) {
          products.add(
            InvoiceProductItem.fromCompositeJson(
              Map<String, dynamic>.from(row),
            ),
          );
        }
      }
    }
    final bill = InvoiceAddress.fromJson(_readMap(json['bill_to']));
    final ship = InvoiceAddress.fromJson(_readMap(json['ship_to']));
    return InvoiceDetail(
      id: _readString(json, const ['id']),
      invoiceNumber: _readString(
        json,
        const ['invoice_number', 'invoice_no'],
      ),
      status: _readString(json, const ['status']),
      clientName: _readString(client, const ['name', 'client_name']),
      contactPerson: _readString(
        contact,
        const ['name', 'contact_name', 'contact_person'],
      ),
      projectName: _readString(
        project,
        const ['name', 'project_name'],
        fallback: _readString(json, const ['project_name']),
      ),
      issueDate: _parseDate(json['issue_date']),
      dueDate: _parseDate(json['due_date']),
      paymentTerms: invoicePaymentTermsFromApi(
        _readString(json, const ['payment_terms']),
      ),
      billingAddress: bill,
      shippingAddress: ship,
      notes: _readString(json, const ['client_notes']),
      internalNotes: _readString(json, const ['internal_notes']),
      productItems: products,
      adjustment: readApiDouble(json['adjustment_amount']) ?? 0,
      invoiceDiscount: readApiDouble(json['discount']) ??
          readApiDouble(json['discount_amount']) ??
          0,
      invoiceTax: readApiDouble(json['tax']) ?? readApiDouble(json['tax_amount']) ?? 0,
      total: readApiDouble(json['total']) ??
          readApiDouble(json['total_balance']) ??
          0,
    );
  }
}

enum InvoiceStatus { paid, pending, overdue, draft, open }

enum InvoiceDetailStatus { open, paid, pending, overdue, draft }

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _capitalizeStatus(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

InvoiceStatus invoiceStatusFromApi(String? raw) {
  return switch ((raw ?? '').trim().toLowerCase()) {
    'paid' => InvoiceStatus.paid,
    'pending' => InvoiceStatus.pending,
    'overdue' => InvoiceStatus.overdue,
    'draft' => InvoiceStatus.draft,
    'open' => InvoiceStatus.open,
    _ => InvoiceStatus.open,
  };
}

InvoiceDetailStatus invoiceDetailStatusFromApi(String? raw) {
  return switch ((raw ?? '').trim().toLowerCase()) {
    'paid' => InvoiceDetailStatus.paid,
    'pending' => InvoiceDetailStatus.pending,
    'overdue' => InvoiceDetailStatus.overdue,
    'draft' => InvoiceDetailStatus.draft,
    _ => InvoiceDetailStatus.open,
  };
}

Color invoiceStatusColor(InvoiceDetailStatus status) {
  return switch (status) {
    InvoiceDetailStatus.paid => const Color(0xFF137333),
    InvoiceDetailStatus.open => const Color(0xFF137333),
    InvoiceDetailStatus.pending => const Color(0xFFB45309),
    InvoiceDetailStatus.overdue => const Color(0xFFDC2626),
    InvoiceDetailStatus.draft => const Color(0xFF6B7280),
  };
}

Color invoiceListStatusColor(InvoiceStatus status) {
  return invoiceStatusColor(
    switch (status) {
      InvoiceStatus.paid => InvoiceDetailStatus.paid,
      InvoiceStatus.pending => InvoiceDetailStatus.pending,
      InvoiceStatus.overdue => InvoiceDetailStatus.overdue,
      InvoiceStatus.draft => InvoiceDetailStatus.draft,
      InvoiceStatus.open => InvoiceDetailStatus.open,
    },
  );
}

String invoiceListStatusLabel(InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.pending => 'Pending',
    InvoiceStatus.overdue => 'Overdue',
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.open => 'Open',
  };
}