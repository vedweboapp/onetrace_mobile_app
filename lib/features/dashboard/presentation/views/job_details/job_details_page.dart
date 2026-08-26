part of 'job_details.dart';

String? _absoluteJobDrawingUrl(String drawingFileFromApi) {
  final raw = drawingFileFromApi.trim();
  if (raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return raw;
  }
  return Uri.parse(
    AppApiUrls.baseUrl,
  ).resolve(raw.startsWith('/') ? raw : '/$raw').toString();
}

class JobDetailsPage extends ConsumerStatefulWidget {
  const JobDetailsPage({
    super.key,
    required this.projectId,
    required this.jobId,
    required this.jobTitle,
    required this.projectName,
    required this.clientName,
    required this.workerName,
    required this.startDate,
    required this.scheduleDate,
    required this.status,
    this.latitude,
    this.longitude,
  });

  static const name = 'job-details';
  static const standaloneName = 'service-job-details';
  static const standalonePath = '/jobs/:jobId';

  final String projectId;
  final String jobId;
  final String jobTitle;
  final String projectName;
  final String clientName;
  final String workerName;
  final DateTime? startDate;
  final DateTime? scheduleDate;
  final String status;
  final double? latitude;
  final double? longitude;

  static String pathFor(String projectId, String jobId) {
    return '${ProjectDetailsPage.pathPrefix}/$projectId/jobs/$jobId';
  }

  static String standalonePathFor(String jobId) =>
      '/jobs/${Uri.encodeComponent(jobId)}';

  factory JobDetailsPage.fromRoute({
    required String projectId,
    required String routeJobId,
    Object? extra,
  }) {
    var jobId = Uri.decodeComponent(routeJobId);
    var jobTitle = 'Job';
    var projectName = 'Project';
    var clientName = '--';
    var workerName = 'Assigned Worker';
    DateTime? startDate;
    DateTime? scheduleDate;
    var status = 'Active';
    double? latitude;
    double? longitude;
    if (extra is Map) {
      final m = Map<String, dynamic>.from(extra);
      final rawJobId = m['jobId'];
      final rawJobTitle = m['jobTitle'];
      final rawProjectName = m['projectName'];
      final rawClientName = m['clientName'];
      final rawWorkerName = m['workerName'];
      final rawStartDate = m['startDate'];
      final rawScheduleDate = m['scheduleDate'];
      final rawStatus = m['status'];
      final rawLatitude = m['latitude'];
      final rawLongitude = m['longitude'];
      if (rawJobId is String && rawJobId.trim().isNotEmpty) {
        jobId = rawJobId.trim();
      } else if (rawJobId is num) {
        jobId = rawJobId.toInt().toString();
      }
      if (rawJobTitle is String && rawJobTitle.trim().isNotEmpty) {
        jobTitle = rawJobTitle.trim();
      }
      if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
        projectName = rawProjectName.trim();
      }
      if (rawClientName is String && rawClientName.trim().isNotEmpty) {
        clientName = rawClientName.trim();
      }
      if (rawWorkerName is String && rawWorkerName.trim().isNotEmpty) {
        workerName = rawWorkerName.trim();
      }
      if (rawStartDate is String && rawStartDate.trim().isNotEmpty) {
        startDate = DateTime.tryParse(rawStartDate.trim());
      }
      if (rawScheduleDate is String && rawScheduleDate.trim().isNotEmpty) {
        scheduleDate = DateTime.tryParse(rawScheduleDate.trim());
      }
      if (rawStatus is String && rawStatus.trim().isNotEmpty) {
        status = rawStatus.trim();
      }
      if (rawLatitude is num) {
        latitude = rawLatitude.toDouble();
      } else if (rawLatitude is String) {
        latitude = double.tryParse(rawLatitude.trim());
      }
      if (rawLongitude is num) {
        longitude = rawLongitude.toDouble();
      } else if (rawLongitude is String) {
        longitude = double.tryParse(rawLongitude.trim());
      }
    }
    return JobDetailsPage(
      projectId: projectId,
      jobId: jobId,
      jobTitle: jobTitle,
      projectName: projectName,
      clientName: clientName,
      workerName: workerName,
      startDate: startDate,
      scheduleDate: scheduleDate,
      status: status,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  ConsumerState<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends ConsumerState<JobDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  JobRead? _job;
  bool _isLoadingJob = false;
  bool _isUpdatingJob = false;
  String? _jobLoadError;
  String? _scannedQrValue;
  final TextEditingController _commentsController = TextEditingController();
  bool _ppeConfirmed = true;
  bool _powerIsolated = true;
  bool _groundingVerified = false;
  bool _panelDelivered = true;
  bool _materialInspected = false;
  bool _isLoadingDrawings = false;
  String? _drawingsError;
  final List<_JobDrawingItem> _drawings = <_JobDrawingItem>[];
  String? _beforePhotoUrl;
  String? _afterPhotoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(_loadJobDetails);
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return DateFormat('MMM d, yyyy · h:mm a').format(value.toLocal());
  }

  String _formatMoney(double value) {
    return NumberFormat.currency(symbol: r'$ ', decimalDigits: 2).format(value);
  }

  String get _jobIdText => _job?.id.toString() ?? widget.jobId;

  String get _jobTitle =>
      _job?.jobSerialNumber?.trim().isNotEmpty == true
      ? _job!.jobSerialNumber!.trim()
      : (_job?.title ?? widget.jobTitle);

  bool get _isServiceJob {
    final job = _job;
    if (job != null) return job.isServiceJob;
    return widget.projectId.trim().isEmpty;
  }

  String get _description {
    final fromJob = _job?.description?.trim();
    if (fromJob != null && fromJob.isNotEmpty) return fromJob;
    return 'No description provided.';
  }

  String get _workerName => _job?.displayWorker ?? widget.workerName;

  String get _statusText => _job?.displayStatus ?? widget.status;

  DateTime? get _startDate => _job?.startDate ?? widget.startDate;

  DateTime? get _endDate => _job?.endDate ?? widget.scheduleDate;

  String get _sourceText {
    final fromJob = _job?.jobSource?.trim();
    if (fromJob != null && fromJob.isNotEmpty) return fromJob;
    if (_job?.isProjectJob == true) return 'Project';
    if (_isServiceJob) return 'Service';
    return 'Manual';
  }

  String get _projectName {
    final fromJob = _job?.projectName?.trim();
    if (fromJob != null && fromJob.isNotEmpty) return fromJob;
    return widget.projectName;
  }

  String get _clientName {
    final fromJob = _job?.clientName?.trim();
    if (fromJob != null && fromJob.isNotEmpty) return fromJob;
    return widget.clientName;
  }

  String get _itemName => _job?.itemName ?? 'Main Electrical Panel';

  String get _sectionName => _job?.sectionName ?? 'Main Electrical Panel';

  int get _quantity => _job?.quantity ?? 10;

  double get _unitPrice => _job?.sellingPrice ?? 1500;

  double get _total => _job?.total ?? (_quantity * _unitPrice);

  Future<void> _loadJobDetails() async {
    final id = int.tryParse(widget.jobId.trim());
    if (id == null) return;
    setState(() {
      _isLoadingJob = true;
      _jobLoadError = null;
    });
    try {
      final job = await ref
          .read(quoteProjectApiClientProvider)
          .fetchJobById(id.toString());
      if (!mounted) return;
      setState(() {
        _job = job;
        _isLoadingJob = false;
        if (job.qrCode != null) {
          _scannedQrValue = job.qrCode.toString();
        }
        _commentsController.text = (job.comments ?? '').trim();
        _hydrateProgressFromJob(job);
        _readPhotoUrls(job);
      });
      unawaited(_loadLinkedDrawings(job));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingJob = false;
        _jobLoadError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load job details',
        );
      });
    }
  }

  Color get _statusColor {
    switch (_statusText.toLowerCase()) {
      case 'active':
      case 'in progress':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  void _hydrateProgressFromJob(JobRead job) {
    final formProgress = job.jobMeta['form_progress'];
    if (formProgress is Map) {
      final map = Map<String, dynamic>.from(
        formProgress.map((k, v) => MapEntry(k.toString(), v)),
      );
      _ppeConfirmed = map['ppe_confirmed'] == true;
      _powerIsolated = map['power_isolated'] == true;
      _groundingVerified = map['grounding_verified'] == true;
    }
    final materialProgress = job.jobMeta['material_progress'];
    if (materialProgress is Map) {
      final map = Map<String, dynamic>.from(
        materialProgress.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (map.containsKey('panel_delivered')) {
        _panelDelivered = map['panel_delivered'] == true;
      }
      _materialInspected = map['material_inspected'] == true;
    }
  }

  void _readPhotoUrls(JobRead job) {
    String? readUrl(dynamic value) {
      if (value is! String) return null;
      final text = value.trim();
      return text.isEmpty ? null : text;
    }

    final meta = job.jobMeta;
    final raw = job.raw;
    _beforePhotoUrl =
        readUrl(meta['before_photo']) ??
        readUrl(meta['before_photo_url']) ??
        readUrl(raw['before_photo']) ??
        readUrl(raw['before_photo_url']);
    _afterPhotoUrl =
        readUrl(meta['after_photo']) ??
        readUrl(meta['after_photo_url']) ??
        readUrl(raw['after_photo']) ??
        readUrl(raw['after_photo_url']);

    final photos = meta['photos'] ?? raw['photos'];
    if (photos is Map) {
      final map = Map<String, dynamic>.from(
        photos.map((k, v) => MapEntry(k.toString(), v)),
      );
      _beforePhotoUrl ??=
          readUrl(map['before']) ??
          readUrl(map['before_photo']) ??
          readUrl(map['before_url']);
      _afterPhotoUrl ??=
          readUrl(map['after']) ??
          readUrl(map['after_photo']) ??
          readUrl(map['after_url']);
    }
  }

  String get _resolvedProjectId {
    final fromWidget = widget.projectId.trim();
    if (fromWidget.isNotEmpty) return fromWidget;
    final fromJob = _job?.project?.toString().trim();
    if (fromJob != null && fromJob.isNotEmpty) return fromJob;
    return '';
  }

  Future<void> _loadLinkedDrawings(JobRead job) async {
    final fromJob = _drawingsFromJobLevels(job);
    if (fromJob.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _drawings
          ..clear()
          ..addAll(fromJob);
        _isLoadingDrawings = false;
        _drawingsError = null;
      });
      return;
    }

    final projectId = _resolvedProjectId;
    if (projectId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingDrawings = false;
        _drawingsError = null;
      });
      return;
    }
    setState(() {
      _isLoadingDrawings = true;
      _drawingsError = null;
    });
    try {
      final levels = await ref
          .read(quoteProjectApiClientProvider)
          .fetchProjectLevels(projectId: projectId);
      if (!mounted) return;
      final pinLabel = (job.pinName ?? job.plotName ?? '').trim().toLowerCase();
      final next = levels.asMap().entries.map((entry) {
        final index = entry.key;
        final level = entry.value;
        final title = level.name.trim().isEmpty
            ? 'Drawing ${index + 1}'
            : level.name.trim();
        final code = level.id.trim().isEmpty
            ? 'L${(index + 1).toString().padLeft(3, '0')}'
            : level.id.trim();
        final pinCount = _pinCountInPlots(level.plots);
        final linkedToJob = pinLabel.isNotEmpty &&
            level.plots.any((plot) {
              final plotMap = Map<String, dynamic>.from(
                plot.map((k, v) => MapEntry(k.toString(), v)),
              );
              for (final key in const ['name', 'pin_name', 'label', 'title']) {
                final value = plotMap[key]?.toString().trim().toLowerCase();
                if (value != null && value.isNotEmpty && value == pinLabel) {
                  return true;
                }
              }
              return false;
            });
        return _JobDrawingItem(
          code: code,
          title: title,
          subtitle: pinCount > 0
              ? '$pinCount pin${pinCount == 1 ? '' : 's'} on drawing'
              : 'Project drawing',
          updatedLabel:
              linkedToJob ? 'Linked to this job' : 'Available on project',
          remoteDrawingUrl: _absoluteJobDrawingUrl(level.drawingFile),
          levelName: title,
          projectId: projectId,
          levelId: level.id.trim().isEmpty ? null : level.id.trim(),
          isLinked: linkedToJob,
        );
      }).toList();
      setState(() {
        _drawings
          ..clear()
          ..addAll(next);
        _isLoadingDrawings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDrawings = false;
        _drawingsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load linked drawings',
        );
      });
    }
  }

  List<_JobDrawingItem> _drawingsFromJobLevels(JobRead job) {
    final raw = job.raw['levels'];
    if (raw is! List || raw.isEmpty) return const [];
    final projectId = _resolvedProjectId;
    final items = <_JobDrawingItem>[];
    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = (map['name']?.toString() ?? '').trim();
      final id = (map['id']?.toString() ?? '').trim();
      final drawingFile = (map['drawing_file']?.toString() ?? '').trim();
      final plots = map['plots'];
      final plotMaps = <Map<String, dynamic>>[];
      if (plots is List) {
        for (final plot in plots) {
          if (plot is! Map) continue;
          plotMaps.add(
            Map<String, dynamic>.from(
              plot.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
      final pinCount = _pinCountInPlots(plotMaps);
      final title = name.isEmpty ? 'Drawing ${index + 1}' : name;
      items.add(
        _JobDrawingItem(
          code: id.isEmpty
              ? 'L${(index + 1).toString().padLeft(3, '0')}'
              : id,
          title: title,
          subtitle: pinCount > 0
              ? '$pinCount pin${pinCount == 1 ? '' : 's'} on drawing'
              : 'Project drawing',
          updatedLabel: 'Linked to this job',
          remoteDrawingUrl: _absoluteJobDrawingUrl(drawingFile),
          levelName: title,
          projectId: projectId.isEmpty ? null : projectId,
          levelId: id.isEmpty ? null : id,
          isLinked: true,
        ),
      );
    }
    return items;
  }

  static int _pinCountInPlots(List<Map<String, dynamic>> plots) {
    var count = 0;
    for (final plot in plots) {
      final pins = plot['pins'];
      if (pins is List) count += pins.length;
    }
    return count;
  }

  Future<void> _openDrawing(_JobDrawingItem item) async {
    await DrawingCanvasPage.push(
      context,
      DrawingCanvasArgs(
        title: item.title,
        remoteDrawingUrl: item.remoteDrawingUrl,
        levelName: item.levelName,
        projectName: widget.projectName,
        projectId: item.projectId,
        levelId: item.levelId,
      ),
    );
  }

  Future<void> _scanQrCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _JobQrScannerPage()),
    );
    final value = code?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _scannedQrValue = value);
    if (_job != null) {
      final qrId = int.tryParse(value);
      if (qrId != null) {
        unawaited(_persistQrCode(qrId));
      }
    }
    context.showTopSnackBar(
      const SnackBar(content: Text('QR code scanned successfully.')),
    );
  }

  Future<void> _persistQrCode(int qrId) async {
    final job = _job;
    if (job == null || _isUpdatingJob) return;
    setState(() => _isUpdatingJob = true);
    try {
      final payload = JobWritePayload.buildFromJobRead(
        job,
        qrCodeOverride: qrId,
      );
      final updated = await ref
          .read(quoteProjectApiClientProvider)
          .updateJob(jobId: job.id.toString(), payload: payload);
      if (!mounted) return;
      setState(() {
        _job = updated;
        _isUpdatingJob = false;
        _readPhotoUrls(updated);
      });
    } catch (_) {
      if (mounted) setState(() => _isUpdatingJob = false);
    }
  }

  String get _mapQuery {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) return '$lat,$lng';

    final fallback = [
      widget.projectName,
      widget.clientName,
    ].where((part) => part.trim().isNotEmpty && part.trim() != '--').join(', ');
    return fallback.isEmpty ? _jobTitle : fallback;
  }

  double get _mapLatitude => widget.latitude ?? 40.712776;

  double get _mapLongitude => widget.longitude ?? -74.005974;

  Future<void> _openEditJob() async {
    final job = _job;
    if (job == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Job details are still loading.')),
      );
      return;
    }
    final projectId = widget.projectId.trim().isNotEmpty
        ? widget.projectId.trim()
        : (job.project?.toString() ?? '');
    if (projectId.isEmpty) {
      final updated = await context.push<bool>(
        AddJobPage.standaloneEditPathFor(job.id.toString()),
      );
      if (updated == true && mounted) {
        await _loadJobDetails();
      }
      return;
    }
    final updated = await context.push<bool>(
      AddJobPage.pathForEdit(projectId, job.id.toString()),
    );
    if (updated == true && mounted) {
      await _loadJobDetails();
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    if (widget.projectId.trim().isEmpty) {
      context.go('/dashboard');
      return;
    }
    final fallbackSummary = QuoteSummary(
      id: widget.projectId.trim(),
      quoteName: widget.projectName.trim().isEmpty
          ? 'Project'
          : widget.projectName.trim(),
      quoteNumber: 'â€”',
      clientName: widget.clientName,
      projectName: widget.projectName,
    );
    context.go(
      ProjectDetailsPage.pathFor(widget.projectId),
      extra: <String, dynamic>{
        ...fallbackSummary.toJson(),
        'initialTabIndex': 2, // Jobs tab
      },
    );
  }

  Future<void> _openMap() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': _mapQuery,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    context.showTopSnackBar(
      const SnackBar(content: Text('Could not open map for this job.')),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: AppFonts.labelLarge(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '--' : value,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w500, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _mapCard() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openMap,
        child: SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VisibleMapTiles(
                latitude: _mapLatitude,
                longitude: _mapLongitude,
              ),
              Container(color: Colors.black.withValues(alpha: 0.08)),
              Center(
                child: Icon(
                  Icons.location_on,
                  color: AppColors.accentRed,
                  size: 82,
                  shadows: const [
                    Shadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowCard,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 15,
                        color: AppColors.inkStrong,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Open in Maps',
                        style: AppFonts.labelSmall(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleRow() {
    return Row(
      children: [
        Expanded(
          child: _dateTile(label: 'Start Date', value: _formatDate(_startDate)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dateTile(
            label: 'Schedule Date',
            value: _formatDate(_endDate),
          ),
        ),
      ],
    );
  }

  Widget _dateTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: AppColors.inkStrong,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: AppFonts.bodySmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formsCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 20,
              color: AppColors.inkStrong,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Checklist',
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Site-level safety form',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _linkedDrawingCard(_JobDrawingItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.remoteDrawingUrl == null ? null : () => _openDrawing(item),
        child: _card(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.isLinked
                      ? const Color(0xFFE8F5EE)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: item.isLinked
                      ? const Color(0xFF10B981)
                      : AppColors.inkStrong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppFonts.titleSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.updatedLabel,
                      style: AppFonts.labelSmall(
                        color: item.isLinked
                            ? const Color(0xFF10B981)
                            : AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobPhotoCard({
    required String label,
    required String? photoUrl,
    required IconData placeholderIcon,
  }) {
    final url = photoUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: url == null || url.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(placeholderIcon, color: AppColors.muted, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'No photo uploaded',
                          style: AppFonts.bodySmall(color: AppColors.muted),
                        ),
                      ],
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    errorBuilder: (_, _, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(placeholderIcon, color: AppColors.muted, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Could not load photo',
                            style: AppFonts.bodySmall(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _commentsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest comments from response',
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _commentsController,
            hintText: 'Add a comment...',
            minLines: 2,
            maxLines: 4,
            borderRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _qrRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'QR Code',
            style: AppFonts.labelSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: _scanQrCode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _scannedQrValue ?? 'Scan QR Code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.inkStrong,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _overviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'JOB #${_jobIdText.toUpperCase()}',
                style: AppFonts.labelSmall(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _statusText.toUpperCase(),
              style: AppFonts.labelSmall(
                color: _statusColor,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingJob)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.inkStrong,
            ),
          ),
        if (_jobLoadError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEDEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF2D3D6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _jobLoadError!,
                    style: AppFonts.bodySmall(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: _loadJobDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        _mapCard(),
        _sectionTitle('JOB DETAILS'),
        _detailLine('Job Title', _jobTitle),
        if (!_isServiceJob) _detailLine('Project Name', _projectName),
        _detailLine('Client Name', _clientName),
        if ((_job?.siteName ?? '').trim().isNotEmpty)
          _detailLine('Site', _job!.siteName!.trim()),
        const Divider(height: 22, color: AppColors.borderLight),
        _detailLine('Description', _description),
        _detailLine('Source', _sourceText),
        _sectionTitle('SCHEDULE'),
        _card(
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFD4E4F7),
                child: Text(
                  _initials(_workerName),
                  style: AppFonts.labelSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Worker',
                      style: AppFonts.labelSmall(color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _workerName,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _scheduleRow(),
        _sectionTitle('MATERIALS'),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemName,
                            style: AppFonts.titleSmall(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: $_quantity units',
                            style: AppFonts.bodySmall(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_formatMoney(_unitPrice)} / unit',
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      'Subtotal',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                    const Spacer(),
                    Text(
                      _formatMoney(_total),
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _materialStatusCard(
          title: _itemName,
          section: _sectionName,
          quantity: '$_quantity units',
          unitPrice: _formatMoney(_unitPrice),
          total: _formatMoney(_total),
          delivered: _panelDelivered,
          onChanged: (value) => setState(() => _panelDelivered = value),
        ),
        const SizedBox(height: 12),
        _materialStatusCard(
          title: 'Copper Wire 12 AWG',
          section: 'Electrical wiring',
          quantity: '4 rolls',
          unitPrice: r'$ 240.00',
          total: r'$ 960.00',
          delivered: _materialInspected,
          onChanged: (value) => setState(() => _materialInspected = value),
        ),
        _sectionTitle('COMMENTS'),
        _commentsCard(),
        const SizedBox(height: 18),
        _qrRow(),
      ],
    );
  }

  Future<void> _saveJobProgressToApi() async {
    final job = _job;
    if (job == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Job must load before saving updates.')),
      );
      return;
    }
    if (_isUpdatingJob) return;
    setState(() => _isUpdatingJob = true);
    try {
      final nextMeta = Map<String, dynamic>.from(job.jobMeta)
        ..['form_progress'] = <String, dynamic>{
          'ppe_confirmed': _ppeConfirmed,
          'power_isolated': _powerIsolated,
          'grounding_verified': _groundingVerified,
        }
        ..['material_progress'] = <String, dynamic>{
          'panel_delivered': _panelDelivered,
          'material_inspected': _materialInspected,
        };
      final payload = job.toWritePayload(jobMetaOverride: nextMeta);
      payload['comments'] = _commentsController.text.trim();
      final scannedQrId = _scannedQrValue == null
          ? null
          : int.tryParse(_scannedQrValue!.trim());
      if (scannedQrId != null) {
        payload['qr_code'] = scannedQrId;
      }

      final updated = await ref
          .read(quoteProjectApiClientProvider)
          .updateJob(
            jobId: job.id.toString(),
            payload: payload,
          );
      if (!mounted) return;
      setState(() {
        _job = updated;
        _isUpdatingJob = false;
        _readPhotoUrls(updated);
      });
      context.showTopSnackBar(
        const SnackBar(content: Text('Job updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingJob = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not update job',
            ),
          ),
        ),
      );
    }
  }

  Widget _safetyChecklistTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text(
          'Safety Checklist',
          style: AppFonts.headlineSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete the required checklist before marking this job ready.',
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(height: 1.35),
        ),
        const SizedBox(height: 16),
        _sectionTitle('FORMS'),
        _formsCard(),
        const SizedBox(height: 6),
        _checklistTile(
          title: 'PPE and safety barricade confirmed',
          subtitle: 'Area is marked and assigned worker is equipped.',
          value: _ppeConfirmed,
          onChanged: (value) => setState(() => _ppeConfirmed = value),
        ),
        const SizedBox(height: 10),
        _checklistTile(
          title: 'Power isolation verified',
          subtitle: 'Lockout/tagout has been completed for the panel.',
          value: _powerIsolated,
          onChanged: (value) => setState(() => _powerIsolated = value),
        ),
        const SizedBox(height: 10),
        _checklistTile(
          title: 'Grounding wire size verified',
          subtitle: 'Pending confirmation from the site manager comment.',
          value: _groundingVerified,
          onChanged: (value) => setState(() => _groundingVerified = value),
        ),
        const SizedBox(height: 18),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor Notes',
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify the grounding wire size before proceeding with Section A. Upload final photos after installation.',
                style: AppFonts.bodyMedium(
                  color: AppColors.muted,
                ).copyWith(height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _isUpdatingJob ? null : _saveJobProgressToApi,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isUpdatingJob ? 'Saving...' : 'Save Form',
              style: AppFonts.titleMedium(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _drawingsTab() {
    final linked = _drawings.where((d) => d.isLinked).toList();
    final others = _drawings.where((d) => !d.isLinked).toList();
    final visible = linked.isNotEmpty ? [...linked, ...others] : _drawings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text(
          'Linked Drawings',
          style: AppFonts.headlineSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          'Project drawings associated with $_jobTitle.',
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(height: 1.35),
        ),
        if (_isLoadingDrawings)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.inkStrong,
            ),
          ),
        if (_drawingsError != null)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEDEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF2D3D6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _drawingsError!,
                    style: AppFonts.bodySmall(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final job = _job;
                    if (job != null) unawaited(_loadLinkedDrawings(job));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        if (!_isLoadingDrawings && visible.isEmpty && _drawingsError == null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _card(
              child: Column(
                children: [
                  const Icon(Icons.folder_off_outlined, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text(
                    'No drawings found for this project.',
                    textAlign: TextAlign.center,
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _linkedDrawingCard(item),
            ),
          ),
      ],
    );
  }

  Widget _photosTab() {
    final hasBefore = (_beforePhotoUrl ?? '').trim().isNotEmpty;
    final hasAfter = (_afterPhotoUrl ?? '').trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text(
          'Job Photos',
          style: AppFonts.headlineSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          'Before and after photos captured by the assigned worker.',
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(height: 1.35),
        ),
        const SizedBox(height: 18),
        _jobPhotoCard(
          label: 'BEFORE PHOTO',
          photoUrl: _beforePhotoUrl,
          placeholderIcon: Icons.photo_camera_outlined,
        ),
        const SizedBox(height: 18),
        _jobPhotoCard(
          label: 'AFTER PHOTO',
          photoUrl: _afterPhotoUrl,
          placeholderIcon: Icons.photo_outlined,
        ),
        if (!hasBefore && !hasAfter)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _card(
              child: Text(
                'Photos will appear here once the operative uploads before and after images from the job site.',
                style: AppFonts.bodySmall(
                  color: AppColors.muted,
                ).copyWith(height: 1.4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _checklistTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            activeColor: const Color(0xFF111111),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialStatusCard({
    required String title,
    required String section,
    required String quantity,
    required String unitPrice,
    required String total,
    required bool delivered,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.titleSmall(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section,
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: delivered,
                  onChanged: onChanged,
                  activeThumbColor: const Color(0xFF111111),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: _materialMetric('Qty', quantity)),
                Expanded(child: _materialMetric('Unit Price', unitPrice)),
                Expanded(
                  child: _materialMetric('Total', total, alignEnd: true),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              delivered ? 'Delivered / ready' : 'Pending confirmation',
              style: AppFonts.labelSmall(
                color: delivered ? const Color(0xFF10B981) : AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialMetric(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppFonts.bodySmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'W';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        centerTitle: true,
        title: Text(
          'Job Details',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.surface,
              child: IconButton(
                onPressed: _isLoadingJob ? null : _openEditJob,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: AppColors.inkStrong,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.inkStrong,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.inkStrong,
              indicatorWeight: 2,
              labelStyle: AppFonts.labelMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800),
              unselectedLabelStyle: AppFonts.labelMedium(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Safety Checklist'),
                Tab(text: 'Drawings'),
                Tab(text: 'Photos'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _overviewTab(),
              _safetyChecklistTab(),
              _drawingsTab(),
              _photosTab(),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottom,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  context.showTopSnackBar(
                    const SnackBar(content: Text('User manual coming soon.')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_rounded, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'User Manual',
                      style: AppFonts.titleMedium(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
