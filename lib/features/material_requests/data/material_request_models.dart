enum MaterialRequestStatus {
  pending,
  partiallyDispatched,
  dispatched,
}

extension MaterialRequestStatusX on MaterialRequestStatus {
  String get label => switch (this) {
        MaterialRequestStatus.pending => 'PENDING',
        MaterialRequestStatus.partiallyDispatched => 'PARTIALLY DISPATCHED',
        MaterialRequestStatus.dispatched => 'DISPATCHED',
      };
}

final class MaterialRequestListItem {
  const MaterialRequestListItem({
    required this.id,
    required this.requestCode,
    required this.jobCode,
    required this.requesterName,
    required this.itemCount,
    required this.status,
  });

  final String id;
  final String requestCode;
  final String jobCode;
  final String requesterName;
  final int itemCount;
  final MaterialRequestStatus status;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return requestCode.toLowerCase().contains(q) ||
        jobCode.toLowerCase().contains(q) ||
        requesterName.toLowerCase().contains(q) ||
        status.label.toLowerCase().contains(q);
  }
}

final class MaterialRequestJobLine {
  const MaterialRequestJobLine({
    required this.id,
    required this.jobCode,
    required this.projectName,
  });

  final String id;
  final String jobCode;
  final String projectName;
}

final class MaterialRequestItemLine {
  const MaterialRequestItemLine({
    required this.id,
    required this.itemName,
    required this.requestedLabel,
    required this.dispatchedLabel,
    required this.pendingLabel,
    this.jobName,
    this.quantity,
    this.highlightPending = false,
  });

  final String id;
  final String itemName;
  final String requestedLabel;
  final String dispatchedLabel;
  final String pendingLabel;
  final String? jobName;
  final String? quantity;
  final bool highlightPending;
}

final class MaterialRequestTimelineEvent {
  const MaterialRequestTimelineEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.trackingNumber,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? trackingNumber;
}

final class MaterialRequestDetail {
  const MaterialRequestDetail({
    required this.id,
    required this.requestCode,
    required this.workerName,
    required this.status,
    required this.jobs,
    required this.items,
    required this.dispatchItems,
    required this.timeline,
  });

  final String id;
  final String requestCode;
  final String workerName;
  final MaterialRequestStatus status;
  final List<MaterialRequestJobLine> jobs;
  final List<MaterialRequestItemLine> items;
  final List<MaterialRequestItemLine> dispatchItems;
  final List<MaterialRequestTimelineEvent> timeline;
}

abstract final class MaterialRequestMockData {
  MaterialRequestMockData._();

  static const jobOptions = [
  'Skyline Apartments Phase II',
  'Harbor Logistics Hub',
  'Downtown Office Fit-Out',
  'Riverside Retail Park',
  ];

  static const workerOptions = [
    'Johnathan Miller',
    'Rajesh Kumar',
    'Sarah Jenkins',
    'Chris Hall',
    'Jamie Fox',
  ];

  static const itemCatalog = [
    'Structural Steel Beams (HEB 200)',
    'Copper Wiring 2.5mm',
    'Fire-Rated Drywall Sheets',
    'HVAC Ducting Kit',
    'Concrete Mix — Grade M30',
  ];

  static final listItems = [
    const MaterialRequestListItem(
      id: 'req-8829',
      requestCode: 'REQ-8829',
      jobCode: 'JOB-1024',
      requesterName: 'Johnathan Miller',
      itemCount: 5,
      status: MaterialRequestStatus.pending,
    ),
    const MaterialRequestListItem(
      id: 'req-8830',
      requestCode: 'REQ-8830',
      jobCode: 'JOB-1041',
      requesterName: 'Rajesh Kumar',
      itemCount: 3,
      status: MaterialRequestStatus.partiallyDispatched,
    ),
    const MaterialRequestListItem(
      id: 'req-8831',
      requestCode: 'REQ-8831',
      jobCode: 'JOB-0998',
      requesterName: 'Sarah Jenkins',
      itemCount: 8,
      status: MaterialRequestStatus.dispatched,
    ),
    const MaterialRequestListItem(
      id: 'req-8832',
      requestCode: 'REQ-8832',
      jobCode: 'JOB-1102',
      requesterName: 'Chris Hall',
      itemCount: 2,
      status: MaterialRequestStatus.pending,
    ),
    const MaterialRequestListItem(
      id: 'req-8833',
      requestCode: 'REQ-8833',
      jobCode: 'JOB-1088',
      requesterName: 'Jamie Fox',
      itemCount: 6,
      status: MaterialRequestStatus.partiallyDispatched,
    ),
  ];

  static MaterialRequestListItem? listItemById(String id) {
    for (final item in listItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  static MaterialRequestDetail detailForId(String id) {
    final listItem = listItemById(id);
  final code = listItem?.requestCode ?? '#MR-2023-0842';
  final worker = listItem?.requesterName ?? 'Rajesh Kumar';
  final status = listItem?.status ?? MaterialRequestStatus.dispatched;

    return MaterialRequestDetail(
      id: id,
      requestCode: code,
      workerName: worker,
      status: status,
      jobs: const [
        MaterialRequestJobLine(
          id: 'job-1',
          jobCode: 'JOB-1024',
          projectName: 'Skyline Apartments Phase II',
        ),
        MaterialRequestJobLine(
          id: 'job-2',
          jobCode: 'JOB-1041',
          projectName: 'Harbor Logistics Hub',
        ),
      ],
      items: const [
        MaterialRequestItemLine(
          id: 'item-1',
          itemName: 'Structural Steel Beams (HEB 200)',
          requestedLabel: '12 Units',
          dispatchedLabel: '12 Units',
          pendingLabel: '—',
        ),
        MaterialRequestItemLine(
          id: 'item-2',
          itemName: 'Copper Wiring 2.5mm',
          requestedLabel: '8 Rolls',
          dispatchedLabel: '8 Rolls',
          pendingLabel: '—',
        ),
        MaterialRequestItemLine(
          id: 'item-3',
          itemName: 'Fire-Rated Drywall Sheets',
          requestedLabel: '24 Sheets',
          dispatchedLabel: '9 Sheets',
          pendingLabel: '15 Rolls',
          highlightPending: true,
        ),
      ],
      dispatchItems: const [
        MaterialRequestItemLine(
          id: 'disp-1',
          itemName: 'Structural Steel Beams (HEB 200)',
          requestedLabel: '15 Rolls',
          dispatchedLabel: '',
          pendingLabel: '',
          quantity: '15 Rolls',
        ),
        MaterialRequestItemLine(
          id: 'disp-2',
          itemName: 'Fire-Rated Drywall Sheets',
          requestedLabel: '15 Rolls',
          dispatchedLabel: '',
          pendingLabel: '',
          quantity: '15 Rolls',
        ),
      ],
      timeline: [
        MaterialRequestTimelineEvent(
          id: 'tl-1',
          title: '#DISP-098 Dispatch Created',
          subtitle:
              'Structural steel beams and drywall sheets dispatched to site.',
          timestamp: DateTime(2023, 10, 15, 9, 30),
          trackingNumber: 'LOG-4491-X',
        ),
        MaterialRequestTimelineEvent(
          id: 'tl-2',
          title: 'Initial Request Fulfilment',
          subtitle: 'First batch of copper wiring marked as fulfilled.',
          timestamp: DateTime(2023, 10, 14, 16, 15),
        ),
      ],
    );
  }
}
