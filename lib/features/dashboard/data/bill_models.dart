import 'package:flutter/material.dart';

enum BillListStatus { paid, pending, overdue, open }

class BillListItem {
  const BillListItem({
    required this.id,
    required this.amount,
    required this.vendorName,
    required this.date,
    required this.status,
    this.vendorAvatarUrl,
  });

  final String id;
  final double amount;
  final String vendorName;
  final DateTime date;
  final BillListStatus status;
  final String? vendorAvatarUrl;
}

String billListStatusLabel(BillListStatus status) {
  return switch (status) {
    BillListStatus.paid => 'Paid',
    BillListStatus.pending => 'Pending',
    BillListStatus.overdue => 'Overdue',
    BillListStatus.open => 'Open',
  };
}

Color billListStatusColor(BillListStatus status) {
  return switch (status) {
    BillListStatus.paid => const Color(0xFF22C55E),
    BillListStatus.open => const Color(0xFF22C55E),
    BillListStatus.pending => const Color(0xFFF59E0B),
    BillListStatus.overdue => const Color(0xFFEF4444),
  };
}

enum BillDetailStatus { open, paid, pending, overdue }

class BillAddress {
  const BillAddress({
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

enum BillJobStatus { inProgress, completed, pending }

String billJobStatusLabel(BillJobStatus status) {
  return switch (status) {
    BillJobStatus.inProgress => 'In Progress',
    BillJobStatus.completed => 'Completed',
    BillJobStatus.pending => 'Pending',
  };
}

Color billJobStatusColor(BillJobStatus status) {
  return switch (status) {
    BillJobStatus.inProgress => const Color(0xFF22C55E),
    BillJobStatus.completed => const Color(0xFF2563EB),
    BillJobStatus.pending => const Color(0xFF6B7280),
  };
}

class BillJobLineItem {
  const BillJobLineItem({
    required this.jobName,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.projectName,
    required this.amount,
    this.qty = 1,
    this.rate = 0,
    this.total = 0,
  });

  final String jobName;
  final String location;
  final DateTime? startDate;
  final DateTime? endDate;
  final BillJobStatus status;
  final String projectName;
  final double amount;
  final double qty;
  final double rate;
  final double total;

  double get lineTotal => total > 0 ? total : amount;
}

class BillDetail {
  const BillDetail({
    required this.id,
    required this.billNumber,
    required this.status,
    required this.userName,
    required this.contactPerson,
    required this.projectName,
    required this.issueDate,
    required this.dueDate,
    required this.paymentTerms,
    required this.billingAddress,
    required this.shippingAddress,
    required this.notes,
    required this.jobItems,
    this.adjustment = 0,
    this.billDiscount = 0,
    this.billTax = 0,
    this.grandTotalAmount = 0,
  });

  final String id;
  final String billNumber;
  final BillDetailStatus status;
  final String userName;
  final String contactPerson;
  final String projectName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String paymentTerms;
  final BillAddress billingAddress;
  final BillAddress shippingAddress;
  final String notes;
  final List<BillJobLineItem> jobItems;
  final double adjustment;
  final double billDiscount;
  final double billTax;
  final double grandTotalAmount;

  double get subtotal =>
      jobItems.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get grandTotal => grandTotalAmount > 0
      ? grandTotalAmount
      : subtotal - billDiscount + billTax + adjustment;

  String get statusLabel => switch (status) {
        BillDetailStatus.open => 'Open',
        BillDetailStatus.paid => 'Paid',
        BillDetailStatus.pending => 'Pending',
        BillDetailStatus.overdue => 'Overdue',
      };

  Color get statusColor => switch (status) {
        BillDetailStatus.open => const Color(0xFF22C55E),
        BillDetailStatus.paid => const Color(0xFF22C55E),
        BillDetailStatus.pending => const Color(0xFFF59E0B),
        BillDetailStatus.overdue => const Color(0xFFEF4444),
      };
}

/// Static preview data until bill-order API exists.
abstract final class BillMockData {
  BillMockData._();

  static const _address = BillAddress(
    street: '4500 Industrial Parkway, Suite 200',
    city: 'Chicago',
    state: 'IL',
    postalCode: '60601',
    country: 'United States',
  );

  static const _notes =
      'Payment is due within 30 days of invoice date. Late payments may incur additional charges. Please include the invoice number on all correspondence.';

  static final BillDetail primary = BillDetail(
    id: 'pur-2024-001',
    billNumber: 'PUR-2024-001',
    status: BillDetailStatus.open,
    userName: 'BuildPro Construction LLC',
    contactPerson: 'Smith',
    projectName: 'PRJ-2024-001',
    issueDate: DateTime(2024, 1, 15),
    dueDate: DateTime(2024, 2, 14),
    paymentTerms: 'Net 30 Days',
    billingAddress: _address,
    shippingAddress: _address,
    notes: _notes,
    jobItems: [
      BillJobLineItem(
        jobName: 'Electrical Wiring Work',
        location: 'Block A, L02',
        startDate: DateTime(2024, 10, 24),
        endDate: DateTime(2024, 10, 28),
        status: BillJobStatus.inProgress,
        projectName: 'PRJ-2024-001',
        amount: 3975,
        qty: 1,
        rate: 3975,
        total: 3975,
      ),
      BillJobLineItem(
        jobName: 'Electrical Wiring Work',
        location: 'Block B, L05',
        startDate: DateTime(2024, 10, 22),
        endDate: DateTime(2024, 10, 25),
        status: BillJobStatus.completed,
        projectName: 'PRJ-2024-001',
        amount: 3975,
        qty: 1,
        rate: 3975,
        total: 3975,
      ),
      BillJobLineItem(
        jobName: 'Electrical Wiring Work',
        location: 'Block C, L01',
        startDate: DateTime(2024, 10, 29),
        endDate: DateTime(2024, 11, 4),
        status: BillJobStatus.pending,
        projectName: 'PRJ-2024-001',
        amount: 3975,
        qty: 1,
        rate: 3975,
        total: 3975,
      ),
    ],
    adjustment: 0,
    billDiscount: 0,
    billTax: 0,
    grandTotalAmount: 7950,
  );

  static BillDetail detailForId(String rawId) {
    final id = rawId.trim();
    final key = id.toLowerCase();
    if (key == 'pur-2024-001' || key == '1') return primary;
    BillListItem? listMatch;
    for (final item in listItems) {
      if (item.id.toLowerCase() == key) {
        listMatch = item;
        break;
      }
    }
    return BillDetail(
      id: id,
      billNumber: id.toUpperCase().startsWith('PUR') ? id : 'PUR-$id',
      status: switch (listMatch?.status) {
        BillListStatus.paid => BillDetailStatus.paid,
        BillListStatus.pending => BillDetailStatus.pending,
        BillListStatus.overdue => BillDetailStatus.overdue,
        _ => BillDetailStatus.open,
      },
      userName: listMatch?.vendorName ?? 'BuildPro Construction LLC',
      contactPerson: 'Smith',
      projectName: 'PRJ-2024-001',
      issueDate: listMatch?.date ?? DateTime(2024, 1, 15),
      dueDate: (listMatch?.date ?? DateTime(2024, 1, 15))
          .add(const Duration(days: 30)),
      paymentTerms: 'Net 30 Days',
      billingAddress: _address,
      shippingAddress: _address,
      notes: _notes,
      jobItems: primary.jobItems,
      grandTotalAmount: listMatch?.amount ?? 7950,
    );
  }

  static final List<BillListItem> listItems = [
    BillListItem(
      id: 'PUR-2024-001',
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      date: DateTime(2024, 1, 15),
      status: BillListStatus.paid,
    ),
    BillListItem(
      id: 'PUR-2024-002',
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      date: DateTime(2024, 1, 15),
      status: BillListStatus.paid,
    ),
    BillListItem(
      id: 'PUR-2024-003',
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      date: DateTime(2024, 1, 15),
      status: BillListStatus.paid,
    ),
    BillListItem(
      id: 'PUR-2024-004',
      amount: 45200,
      vendorName: 'Metropolis Urban Dev',
      date: DateTime(2024, 1, 15),
      status: BillListStatus.paid,
    ),
    BillListItem(
      id: 'PUR-2024-005',
      amount: 12800,
      vendorName: 'BuildPro Supply Co',
      date: DateTime(2024, 2, 3),
      status: BillListStatus.pending,
    ),
    BillListItem(
      id: 'PUR-2024-006',
      amount: 22100,
      vendorName: 'Apex Structural Group',
      date: DateTime(2024, 3, 5),
      status: BillListStatus.overdue,
    ),
  ];
}
