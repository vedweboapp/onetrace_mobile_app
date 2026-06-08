import 'package:flutter/material.dart';

enum PurchaseOrderListStatus { paid, pending, overdue, open }

enum PurchaseOrderDetailStatus { open, paid, pending, overdue }

class PurchaseOrderListItem {
  const PurchaseOrderListItem({
    required this.id,
    required this.amount,
    required this.vendorName,
    required this.category,
    required this.date,
    required this.status,
    this.vendorAvatarUrl,
  });

  final String id;
  final double amount;
  final String vendorName;
  final String category;
  final DateTime date;
  final PurchaseOrderListStatus status;
  final String? vendorAvatarUrl;
}

String purchaseOrderListStatusLabel(PurchaseOrderListStatus status) {
  return switch (status) {
    PurchaseOrderListStatus.paid => 'Paid',
    PurchaseOrderListStatus.pending => 'Pending',
    PurchaseOrderListStatus.overdue => 'Overdue',
    PurchaseOrderListStatus.open => 'Open',
  };
}

Color purchaseOrderListStatusColor(PurchaseOrderListStatus status) {
  return switch (status) {
    PurchaseOrderListStatus.paid => const Color(0xFF22C55E),
    PurchaseOrderListStatus.open => const Color(0xFF22C55E),
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
  });

  final String productName;
  final double qty;
  final double listPrice;
  final double amount;
  final double discount;
  final double tax;
  final double total;
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
      };

  Color get statusColor => switch (status) {
        PurchaseOrderDetailStatus.open => const Color(0xFF22C55E),
        PurchaseOrderDetailStatus.paid => const Color(0xFF22C55E),
        PurchaseOrderDetailStatus.pending => const Color(0xFFF59E0B),
        PurchaseOrderDetailStatus.overdue => const Color(0xFFEF4444),
      };
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
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      category: 'Raw Material',
      date: DateTime(2024, 1, 15),
      status: PurchaseOrderListStatus.paid,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-002',
      amount: 12800,
      vendorName: 'BuildPro Supply Co',
      category: 'Equipment',
      date: DateTime(2024, 2, 3),
      status: PurchaseOrderListStatus.pending,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-003',
      amount: 9750,
      vendorName: 'Northwind Materials',
      category: 'Raw Material',
      date: DateTime(2024, 2, 18),
      status: PurchaseOrderListStatus.paid,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-004',
      amount: 22100,
      vendorName: 'Apex Structural Group',
      category: 'Steel & Fabrication',
      date: DateTime(2024, 3, 5),
      status: PurchaseOrderListStatus.overdue,
    ),
    PurchaseOrderListItem(
      id: 'PUR-2024-005',
      amount: 6400,
      vendorName: 'Riverview Developments',
      category: 'Consumables',
      date: DateTime(2024, 3, 22),
      status: PurchaseOrderListStatus.pending,
    ),
  ];
}
