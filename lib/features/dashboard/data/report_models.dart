enum ReportCategory {
  projects,
  jobs,
  quotations,
  finance,
}

extension ReportCategoryX on ReportCategory {
  String get label => switch (this) {
        ReportCategory.projects => 'PROJECTS',
        ReportCategory.jobs => 'JOBS',
        ReportCategory.quotations => 'QUOTATIONS',
        ReportCategory.finance => 'FINANCE',
      };

  String get searchHint => switch (this) {
        ReportCategory.projects => 'Search projects...',
        ReportCategory.jobs => 'Search jobs...',
        ReportCategory.quotations => 'Search quotations...',
        ReportCategory.finance => 'Search items...',
      };
}

final class ReportListItem {
  const ReportListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final ReportCategory category;
  final DateTime lastGenerated;
}

/// How a column cell should be rendered in the summary table.
enum ReportTableCellKind {
  text,
  stackedText,
  avatar,
}

final class ReportTableColumn {
  const ReportTableColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.kind = ReportTableCellKind.text,
    this.minWidth,
  });

  final String key;
  final String label;
  final int flex;
  final ReportTableCellKind kind;
  final double? minWidth;
}

final class ReportTableCell {
  const ReportTableCell.text(this.primary)
      : secondary = null,
        avatarUrl = null,
        kind = ReportTableCellKind.text;

  const ReportTableCell.stacked({
    required this.primary,
    required this.secondary,
  })  : avatarUrl = null,
        kind = ReportTableCellKind.stackedText;

  const ReportTableCell.avatar({
    required this.primary,
    this.avatarUrl,
  })  : secondary = null,
        kind = ReportTableCellKind.avatar;

  final String primary;
  final String? secondary;
  final String? avatarUrl;
  final ReportTableCellKind kind;

  Iterable<String> get searchableValues sync* {
    yield primary;
    final sub = secondary;
    if (sub != null && sub.isNotEmpty) yield sub;
  }
}

final class ReportTableRow {
  const ReportTableRow({
    required this.id,
    required this.cells,
  });

  final String id;
  final Map<String, ReportTableCell> cells;

  ReportTableCell? cellFor(String columnKey) => cells[columnKey];

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    for (final cell in cells.values) {
      for (final value in cell.searchableValues) {
        if (value.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }
}

final class ReportTableData {
  const ReportTableData({
    required this.columns,
    required this.rows,
  });

  final List<ReportTableColumn> columns;
  final List<ReportTableRow> rows;
}

enum ReportSummaryLifecycleStatus {
  active,
  inactive,
}

extension ReportSummaryLifecycleStatusX on ReportSummaryLifecycleStatus {
  String get label => switch (this) {
        ReportSummaryLifecycleStatus.active => 'Active',
        ReportSummaryLifecycleStatus.inactive => 'Inactive',
      };
}

final class ReportListCardItem {
  const ReportListCardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.assigneeName,
    this.assigneeAvatarUrl,
    required this.progressPercent,
    required this.dueDate,
    this.progressLabel = 'PROGRESS',
    this.dueDateLabel = 'DUE DATE',
  });

  final String id;
  final String title;
  final String subtitle;
  final ReportSummaryLifecycleStatus status;
  final String assigneeName;
  final String? assigneeAvatarUrl;
  final int progressPercent;
  final DateTime dueDate;
  final String progressLabel;
  final String dueDateLabel;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        assigneeName.toLowerCase().contains(q) ||
        status.label.toLowerCase().contains(q);
  }
}

abstract final class ReportMockData {
  ReportMockData._();

  static final listItems = [
    ReportListItem(
      id: 'project-status-summary',
      title: 'Project Status Summary',
      description:
          'High-level overview of overall project health and completion status.',
      category: ReportCategory.projects,
      lastGenerated: DateTime(2024, 10, 12),
    ),
    ReportListItem(
      id: 'project-timeline',
      title: 'Project Timeline Report',
      description:
          'Detailed Gantt-style timeline view of all active job scheduling.',
      category: ReportCategory.projects,
      lastGenerated: DateTime(2024, 10, 15),
    ),
    ReportListItem(
      id: 'milestone-performance',
      title: 'Milestone Performance',
      description:
          'Detailed tracking of key project milestones and delivery timelines.',
      category: ReportCategory.projects,
      lastGenerated: DateTime(2024, 11, 2),
    ),
    ReportListItem(
      id: 'job-completion',
      title: 'Job Completion Overview',
      description:
          'Summary of completed, in-progress, and pending jobs across sites.',
      category: ReportCategory.jobs,
      lastGenerated: DateTime(2024, 9, 28),
    ),
    ReportListItem(
      id: 'quotation-pipeline',
      title: 'Quotation Pipeline',
      description:
          'Track open quotations, win rates, and conversion by client segment.',
      category: ReportCategory.quotations,
      lastGenerated: DateTime(2024, 10, 1),
    ),
  ];

  static ReportListItem? reportById(String id) {
    for (final item in listItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ReportListItem detailForId(String id) =>
      reportById(id) ?? listItems.first;

  static ReportTableData tableFor(String reportId) {
    return _tablesByReportId[reportId] ?? _projectStatusTable;
  }

  static List<ReportListCardItem> listCardsFor(String reportId) {
    return _listCardsByReportId[reportId] ?? _projectStatusListCards;
  }

  static const _projectColumns = [
    ReportTableColumn(
      key: 'project',
      label: 'PROJECT NAME',
      flex: 3,
      kind: ReportTableCellKind.stackedText,
      minWidth: 200,
    ),
    ReportTableColumn(
      key: 'client',
      label: 'CLIENT',
      flex: 1,
      kind: ReportTableCellKind.avatar,
      minWidth: 72,
    ),
  ];

  static final _projectStatusTable = ReportTableData(
    columns: _projectColumns,
    rows: [
      _projectRow(
        'cloud-migration',
        'Cloud Migration',
        'Infrastructure',
        'Alex Morgan',
        'https://i.pravatar.cc/150?img=12',
      ),
      _projectRow(
        'mobile-app-v2',
        'Mobile App V2',
        'Product',
        'Jordan Lee',
        'https://i.pravatar.cc/150?img=32',
      ),
      _projectRow(
        'security-audit',
        'Security Audit',
        'Compliance',
        'Sam Rivera',
        'https://i.pravatar.cc/150?img=15',
      ),
      _projectRow(
        'data-analytics',
        'Data Analytics Dashboard',
        'Business Intelligence',
        'Taylor Brooks',
        'https://i.pravatar.cc/150?img=47',
      ),
      _projectRow(
        'website-redesign',
        'Website Redesign',
        'Design',
        'Casey Nguyen',
        'https://i.pravatar.cc/150?img=5',
      ),
      _projectRow(
        'ai-chatbot',
        'AI Chatbot Implementation',
        'Technology',
        'Morgan Patel',
        'https://i.pravatar.cc/150?img=21',
      ),
      _projectRow(
        'ecommerce-upgrade',
        'E-commerce Platform Upgrade',
        'Development',
        'Riley Chen',
        'https://i.pravatar.cc/150?img=38',
      ),
      _projectRow(
        'social-media',
        'Social Media Strategy',
        'Marketing',
        'Avery Kim',
        'https://i.pravatar.cc/150?img=9',
      ),
      _projectRow(
        'crm-overhaul',
        'CRM System Overhaul',
        'Sales',
        'Drew Martinez',
        'https://i.pravatar.cc/150?img=27',
      ),
    ],
  );

  static ReportTableRow _projectRow(
    String id,
    String name,
    String department,
    String client,
    String avatarUrl,
  ) {
    return ReportTableRow(
      id: id,
      cells: {
        'project': ReportTableCell.stacked(
          primary: name,
          secondary: department,
        ),
        'client': ReportTableCell.avatar(
          primary: client,
          avatarUrl: avatarUrl,
        ),
      },
    );
  }

  static final _jobCompletionTable = ReportTableData(
    columns: const [
      ReportTableColumn(
        key: 'job',
        label: 'JOB NAME',
        flex: 3,
        kind: ReportTableCellKind.stackedText,
        minWidth: 180,
      ),
      ReportTableColumn(
        key: 'status',
        label: 'STATUS',
        flex: 2,
        kind: ReportTableCellKind.text,
        minWidth: 110,
      ),
      ReportTableColumn(
        key: 'technician',
        label: 'TECHNICIAN',
        flex: 1,
        kind: ReportTableCellKind.avatar,
        minWidth: 72,
      ),
    ],
    rows: [
      _jobRow(
        'hvac-install',
        'HVAC Install — Block A',
        'Site A · Level 2',
        'In Progress',
        'Chris Hall',
        'https://i.pravatar.cc/150?img=11',
      ),
      _jobRow(
        'electrical-rough',
        'Electrical Rough-In',
        'Site B · Wing 1',
        'Completed',
        'Jamie Fox',
        'https://i.pravatar.cc/150?img=22',
      ),
      _jobRow(
        'plumbing-fit',
        'Plumbing Fit-Off',
        'Site C',
        'Pending',
        'Pat Ellis',
        'https://i.pravatar.cc/150?img=33',
      ),
      _jobRow(
        'fire-safety',
        'Fire Safety Inspection',
        'Site A · Roof',
        'Scheduled',
        'Quinn Adams',
        'https://i.pravatar.cc/150?img=44',
      ),
      _jobRow(
        'roof-waterproof',
        'Roof Waterproofing',
        'Site D',
        'In Progress',
        'Blake Turner',
        'https://i.pravatar.cc/150?img=55',
      ),
    ],
  );

  static ReportTableRow _jobRow(
    String id,
    String job,
    String location,
    String status,
    String technician,
    String avatarUrl,
  ) {
    return ReportTableRow(
      id: id,
      cells: {
        'job': ReportTableCell.stacked(primary: job, secondary: location),
        'status': ReportTableCell.text(status),
        'technician': ReportTableCell.avatar(
          primary: technician,
          avatarUrl: avatarUrl,
        ),
      },
    );
  }

  static final _quotationPipelineTable = ReportTableData(
    columns: const [
      ReportTableColumn(
        key: 'quotation',
        label: 'QUOTATION',
        flex: 3,
        kind: ReportTableCellKind.stackedText,
        minWidth: 180,
      ),
      ReportTableColumn(
        key: 'status',
        label: 'STATUS',
        flex: 2,
        kind: ReportTableCellKind.text,
        minWidth: 110,
      ),
      ReportTableColumn(
        key: 'client',
        label: 'CLIENT',
        flex: 1,
        kind: ReportTableCellKind.avatar,
        minWidth: 72,
      ),
    ],
    rows: [
      _quoteRow(
        'quote-1042',
        'Q-1042',
        'Tower Fit-Out',
        'Sent',
        'Northline Corp',
        'https://i.pravatar.cc/150?img=18',
      ),
      _quoteRow(
        'quote-1038',
        'Q-1038',
        'Site Services',
        'Under Review',
        'Harbor Industries',
        'https://i.pravatar.cc/150?img=28',
      ),
      _quoteRow(
        'quote-1031',
        'Q-1031',
        'Maintenance Plan',
        'Won',
        'Summit Holdings',
        'https://i.pravatar.cc/150?img=39',
      ),
      _quoteRow(
        'quote-1024',
        'Q-1024',
        'Equipment Lease',
        'Draft',
        'Blue Ridge LLC',
        'https://i.pravatar.cc/150?img=49',
      ),
    ],
  );

  static ReportTableRow _quoteRow(
    String id,
    String code,
    String title,
    String status,
    String client,
    String avatarUrl,
  ) {
    return ReportTableRow(
      id: id,
      cells: {
        'quotation': ReportTableCell.stacked(primary: code, secondary: title),
        'status': ReportTableCell.text(status),
        'client': ReportTableCell.avatar(
          primary: client,
          avatarUrl: avatarUrl,
        ),
      },
    );
  }

  static final _tablesByReportId = <String, ReportTableData>{
    'project-status-summary': _projectStatusTable,
    'project-timeline': _projectStatusTable,
    'milestone-performance': _projectStatusTable,
    'job-completion': _jobCompletionTable,
    'quotation-pipeline': _quotationPipelineTable,
  };

  static ReportListCardItem _listCard({
    required String id,
    required String title,
    required String subtitle,
    required ReportSummaryLifecycleStatus status,
    required String assigneeName,
    String? assigneeAvatarUrl,
    required int progressPercent,
    required DateTime dueDate,
    String progressLabel = 'PROGRESS',
    String dueDateLabel = 'DUE DATE',
  }) {
    return ReportListCardItem(
      id: id,
      title: title,
      subtitle: subtitle,
      status: status,
      assigneeName: assigneeName,
      assigneeAvatarUrl: assigneeAvatarUrl,
      progressPercent: progressPercent,
      dueDate: dueDate,
      progressLabel: progressLabel,
      dueDateLabel: dueDateLabel,
    );
  }

  static final _projectStatusListCards = [
    _listCard(
      id: 'cloud-migration',
      title: 'Cloud Migration',
      subtitle: 'Infrastructure',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Michael Chen',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=12',
      progressPercent: 75,
      dueDate: DateTime(2023, 12, 15),
    ),
    _listCard(
      id: 'mobile-app-v2',
      title: 'Mobile App V2',
      subtitle: 'Product',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Sarah Jenkins',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=32',
      progressPercent: 40,
      dueDate: DateTime(2023, 11, 30),
    ),
    _listCard(
      id: 'security-audit',
      title: 'Security Audit',
      subtitle: 'Compliance',
      status: ReportSummaryLifecycleStatus.inactive,
      assigneeName: 'Michael Chen',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=15',
      progressPercent: 15,
      dueDate: DateTime(2023, 10, 25),
    ),
    _listCard(
      id: 'data-analytics',
      title: 'Data Analytics Dashboard',
      subtitle: 'Business Intelligence',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Taylor Brooks',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=47',
      progressPercent: 62,
      dueDate: DateTime(2024, 1, 8),
    ),
    _listCard(
      id: 'website-redesign',
      title: 'Website Redesign',
      subtitle: 'Design',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Casey Nguyen',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=5',
      progressPercent: 88,
      dueDate: DateTime(2024, 2, 14),
    ),
    _listCard(
      id: 'ai-chatbot',
      title: 'AI Chatbot Implementation',
      subtitle: 'Technology',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Morgan Patel',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=21',
      progressPercent: 33,
      dueDate: DateTime(2024, 3, 20),
    ),
    _listCard(
      id: 'ecommerce-upgrade',
      title: 'E-commerce Platform Upgrade',
      subtitle: 'Development',
      status: ReportSummaryLifecycleStatus.inactive,
      assigneeName: 'Riley Chen',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=38',
      progressPercent: 10,
      dueDate: DateTime(2023, 9, 5),
    ),
    _listCard(
      id: 'social-media',
      title: 'Social Media Strategy',
      subtitle: 'Marketing',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Avery Kim',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=9',
      progressPercent: 55,
      dueDate: DateTime(2024, 4, 2),
    ),
    _listCard(
      id: 'crm-overhaul',
      title: 'CRM System Overhaul',
      subtitle: 'Sales',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Drew Martinez',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=27',
      progressPercent: 48,
      dueDate: DateTime(2024, 5, 18),
    ),
  ];

  static final _jobCompletionListCards = [
    _listCard(
      id: 'hvac-install',
      title: 'HVAC Install — Block A',
      subtitle: 'Site A · Level 2',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Chris Hall',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=11',
      progressPercent: 65,
      dueDate: DateTime(2024, 6, 12),
      progressLabel: 'COMPLETION',
    ),
    _listCard(
      id: 'electrical-rough',
      title: 'Electrical Rough-In',
      subtitle: 'Site B · Wing 1',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Jamie Fox',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=22',
      progressPercent: 100,
      dueDate: DateTime(2024, 5, 30),
      progressLabel: 'COMPLETION',
    ),
    _listCard(
      id: 'plumbing-fit',
      title: 'Plumbing Fit-Off',
      subtitle: 'Site C',
      status: ReportSummaryLifecycleStatus.inactive,
      assigneeName: 'Pat Ellis',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=33',
      progressPercent: 0,
      dueDate: DateTime(2024, 7, 1),
      progressLabel: 'COMPLETION',
    ),
    _listCard(
      id: 'fire-safety',
      title: 'Fire Safety Inspection',
      subtitle: 'Site A · Roof',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Quinn Adams',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=44',
      progressPercent: 20,
      dueDate: DateTime(2024, 6, 20),
      progressLabel: 'COMPLETION',
    ),
    _listCard(
      id: 'roof-waterproof',
      title: 'Roof Waterproofing',
      subtitle: 'Site D',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Blake Turner',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=55',
      progressPercent: 52,
      dueDate: DateTime(2024, 6, 28),
      progressLabel: 'COMPLETION',
    ),
  ];

  static final _quotationPipelineListCards = [
    _listCard(
      id: 'quote-1042',
      title: 'Q-1042',
      subtitle: 'Tower Fit-Out',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Northline Corp',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=18',
      progressPercent: 80,
      dueDate: DateTime(2024, 8, 15),
      progressLabel: 'WIN RATE',
      dueDateLabel: 'EXPIRES',
    ),
    _listCard(
      id: 'quote-1038',
      title: 'Q-1038',
      subtitle: 'Site Services',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Harbor Industries',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=28',
      progressPercent: 45,
      dueDate: DateTime(2024, 7, 22),
      progressLabel: 'WIN RATE',
      dueDateLabel: 'EXPIRES',
    ),
    _listCard(
      id: 'quote-1031',
      title: 'Q-1031',
      subtitle: 'Maintenance Plan',
      status: ReportSummaryLifecycleStatus.active,
      assigneeName: 'Summit Holdings',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=39',
      progressPercent: 100,
      dueDate: DateTime(2024, 6, 10),
      progressLabel: 'WIN RATE',
      dueDateLabel: 'EXPIRES',
    ),
    _listCard(
      id: 'quote-1024',
      title: 'Q-1024',
      subtitle: 'Equipment Lease',
      status: ReportSummaryLifecycleStatus.inactive,
      assigneeName: 'Blue Ridge LLC',
      assigneeAvatarUrl: 'https://i.pravatar.cc/150?img=49',
      progressPercent: 12,
      dueDate: DateTime(2024, 5, 5),
      progressLabel: 'WIN RATE',
      dueDateLabel: 'EXPIRES',
    ),
  ];

  static final _listCardsByReportId = <String, List<ReportListCardItem>>{
    'project-status-summary': _projectStatusListCards,
    'project-timeline': _projectStatusListCards,
    'milestone-performance': _projectStatusListCards,
    'job-completion': _jobCompletionListCards,
    'quotation-pipeline': _quotationPipelineListCards,
  };
}
