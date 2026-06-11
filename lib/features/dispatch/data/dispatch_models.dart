enum DispatchStatus {
  active,
  dispatched,
  pending,
}

extension DispatchStatusX on DispatchStatus {
  String get label => switch (this) {
        DispatchStatus.active => 'ACTIVE',
        DispatchStatus.dispatched => 'DISPATCHED',
        DispatchStatus.pending => 'PENDING',
      };
}

final class DispatchListItem {
  const DispatchListItem({
    required this.id,
    required this.dispatchCode,
    required this.recipientName,
    required this.projectName,
    required this.dispatchDate,
    required this.status,
  });

  final String id;
  final String dispatchCode;
  final String recipientName;
  final String projectName;
  final DateTime dispatchDate;
  final DispatchStatus status;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return dispatchCode.toLowerCase().contains(q) ||
        recipientName.toLowerCase().contains(q) ||
        projectName.toLowerCase().contains(q) ||
        status.label.toLowerCase().contains(q);
  }
}

final class DispatchItemLine {
  const DispatchItemLine({
    required this.id,
    required this.itemName,
    required this.quantityLabel,
    this.currentStock,
    this.dispatchQty,
  });

  final String id;
  final String itemName;
  final String quantityLabel;
  final int? currentStock;
  final int? dispatchQty;
}

final class DispatchDetail {
  const DispatchDetail({
    required this.id,
    required this.dispatchCode,
    required this.dispatchTo,
    required this.status,
    required this.dispatchDate,
    required this.materialRequestId,
    required this.items,
  });

  final String id;
  final String dispatchCode;
  final String dispatchTo;
  final DispatchStatus status;
  final DateTime dispatchDate;
  final String materialRequestId;
  final List<DispatchItemLine> items;
}

abstract final class DispatchMockData {
  DispatchMockData._();

  static const dispatchToOptions = [
    'Skyline Apartments Phase II',
    'Metropolis Heights Project',
    'Harbor Logistics Hub',
    'Downtown Office Fit-Out',
  ];

  static const materialRequestOptions = [
    'REQ-8829',
    'REQ-8830',
    'REQ-8831',
    'MR-2023-0842',
  ];

  static const itemCatalog = {
    'Industrial Steel Beam': 1240,
    'Structural Steel Beams (HEB 200)': 860,
    'Copper Wiring 2.5mm': 420,
    'Fire-Rated Drywall Sheets': 310,
    'HVAC Ducting Kit': 95,
  };

  static final listItems = [
    DispatchListItem(
      id: 'dsp-2024-001',
      dispatchCode: 'DSP-2024-001',
      recipientName: 'Smith',
      projectName: 'Metropolis Heights Project',
      dispatchDate: DateTime(2024, 1, 14),
      status: DispatchStatus.active,
    ),
    DispatchListItem(
      id: 'dsp-2024-002',
      dispatchCode: 'DSP-2024-002',
      recipientName: 'Rajesh Kumar',
      projectName: 'Skyline Apartments Phase II',
      dispatchDate: DateTime(2024, 1, 12),
      status: DispatchStatus.dispatched,
    ),
    DispatchListItem(
      id: 'dsp-2024-003',
      dispatchCode: 'DSP-2024-003',
      recipientName: 'Sarah Jenkins',
      projectName: 'Harbor Logistics Hub',
      dispatchDate: DateTime(2024, 1, 10),
      status: DispatchStatus.pending,
    ),
    DispatchListItem(
      id: 'dsp-2024-004',
      dispatchCode: 'DSP-2024-004',
      recipientName: 'Chris Hall',
      projectName: 'Downtown Office Fit-Out',
      dispatchDate: DateTime(2024, 1, 8),
      status: DispatchStatus.dispatched,
    ),
  ];

  static DispatchListItem? listItemById(String id) {
    for (final item in listItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  static DispatchDetail detailForId(String id) {
    final listItem = listItemById(id);
    return DispatchDetail(
      id: id,
      dispatchCode: listItem?.dispatchCode ?? 'DSP-2024-001',
      dispatchTo: listItem?.recipientName ?? 'Rajesh Kumar',
      status: listItem?.status ?? DispatchStatus.dispatched,
      dispatchDate: listItem?.dispatchDate ?? DateTime(2023, 10, 15),
      materialRequestId: 'MR-2023-0842',
      items: const [
        DispatchItemLine(
          id: 'item-1',
          itemName: 'Structural Steel Beams (HEB 200)',
          quantityLabel: '15 Rolls',
        ),
        DispatchItemLine(
          id: 'item-2',
          itemName: 'Fire-Rated Drywall Sheets',
          quantityLabel: '24 Sheets',
        ),
      ],
    );
  }
}
