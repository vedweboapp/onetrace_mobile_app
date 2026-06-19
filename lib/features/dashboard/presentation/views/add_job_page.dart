import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';
import 'package:red5/features/dashboard/presentation/jobs_list_refresh.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/features/forms/data/form_picker_utils.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/dashboard/presentation/widgets/forms_multi_picker_sheet.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// Form to create a job (Job Details, Schedule, Materials, Forms, QR).
class AddJobPage extends ConsumerStatefulWidget {
  const AddJobPage({
    super.key,
    this.projectId = '',
    this.initialProjectName = '',
    this.initialClientName = '',
    this.standalone = false,
    this.editJobId,
  });

  static const name = 'add-job';
  static const standaloneName = 'create-job';
  static const editJobName = 'edit-job';
  static const standalonePath = '/jobs/create';

  final String projectId;
  final String initialProjectName;
  final String initialClientName;

  /// When true, navigates back to the jobs list after create instead of project details.
  final bool standalone;

  /// When set, loads the job and saves via `PUT /jobs/{id}/` instead of create.
  final String? editJobId;

  static String pathFor(String projectId) =>
      '${ProjectDetailsPage.pathPrefix}/$projectId/add-job';

  static String pathForEdit(String projectId, String jobId) =>
      '${ProjectDetailsPage.pathPrefix}/$projectId/jobs/$jobId/edit';

  bool get isEditing => (editJobId ?? '').trim().isNotEmpty;

  @override
  ConsumerState<AddJobPage> createState() => _AddJobPageState();
}

class _AddJobPageState extends ConsumerState<AddJobPage> {
  static const _pageBg = Color(0xFFF7F7F8);
  static const _labelColor = AppColors.inkStrong;
  static const _sectionGrey = Color(0xFF9CA3AF);

  final _formKey = GlobalKey<FormState>();
  final _jobTitleController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _plotNameController = TextEditingController(text: 'Plot');

  List<ProjectOption> _projects = const [];
  List<ClientOption> _clients = const [];
  List<SiteModel> _sites = const [];
  List<UserProfileModel> _workers = const [];
  List<NamedIdOption> _jobStatuses = const [];
  List<NamedIdOption> _formOptions = const [];
  List<NamedIdOption> _qrCodeOptions = const [];
  List<GroupItemOption> _groups = const [];
  List<CompositeItemOption> _compositeItems = const [];

  ProjectOption? _selectedProject;
  ClientOption? _selectedClient;
  SiteModel? _selectedSite;
  UserProfileModel? _selectedWorker;
  NamedIdOption? _selectedJobStatus;
  List<NamedIdOption> _selectedForms = const [];
  NamedIdOption? _selectedQrCode;
  GroupItemOption? _selectedGroup;

  bool _isLoadingProjects = false;
  bool _isLoadingClients = false;
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;
  bool _isLoadingJobStatuses = false;
  bool _isLoadingForms = false;
  bool _isLoadingQrCodes = false;
  bool _isLoadingGroups = false;
  String? _projectsLoadError;
  String? _clientsLoadError;
  String? _sitesLoadError;
  final _startDateController = TextEditingController();
  final _scheduleDateController = TextEditingController();

  DateTime? _startDate;
  DateTime? _scheduleDate;
  bool _attemptedSubmit = false;
  bool _isSubmitting = false;
  bool _isLoadingEditJob = false;

  bool get _isEditing => widget.isEditing;

  String? _scannedQrValue;

  final List<_MaterialLine> _materialLines = [];

  static TextStyle get _dropdownValueStyle => AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  static TextStyle get _dropdownHintStyle => AppFonts.bodyMedium(
        color: AppColors.textFieldHint,
      ).copyWith(fontSize: 15, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _materialLines.add(_MaterialLine());
    for (final c in [
      _jobTitleController,
      _projectNameController,
      _clientNameController,
      _descriptionController,
      _plotNameController,
    ]) {
      c.addListener(_onChanged);
    }
    _refreshMaterialListeners();
    unawaited(_loadDropdownData());
  }

  Future<void> _loadDropdownData() async {
    setState(() {
      _isLoadingProjects = true;
      _isLoadingClients = true;
      _isLoadingWorkers = true;
      _isLoadingJobStatuses = true;
      _isLoadingForms = true;
      _isLoadingQrCodes = true;
      _isLoadingGroups = true;
      _projectsLoadError = null;
      _clientsLoadError = null;
    });
    final api = ref.read(quoteProjectApiClientProvider);
    final userApi = ref.read(userProfileApiClientProvider);

    var projects = const <ProjectOption>[];
    var clients = const <ClientOption>[];
    var workers = const <UserProfileModel>[];
    var jobStatuses = const <NamedIdOption>[];
    var qrCodes = const <NamedIdOption>[];
    var groups = const <GroupItemOption>[];
    String? projectsError;
    String? clientsError;

    try {
      projects = await api.fetchProjects();
    } catch (e) {
      projectsError = ApiResponseMessage.fromAnyError(
        e,
        genericFallback: 'Could not load projects',
      );
    }

    try {
      clients = await api.fetchClients();
    } catch (e) {
      clientsError = ApiResponseMessage.fromAnyError(
        e,
        genericFallback: 'Could not load clients',
      );
    }

    try {
      workers = await userApi.fetchAllUserProfiles();
    } catch (_) {
      workers = const [];
    }

    jobStatuses = await api.fetchJobStatusOptions();
    qrCodes = await api.fetchQrCodeOptions();

    try {
      groups = await api.fetchGroups();
    } catch (_) {
      groups = const [];
    }

    if (!mounted) return;
    setState(() {
      _projects = projects;
      _clients = clients;
      _workers = workers;
      _jobStatuses = jobStatuses;
      _qrCodeOptions = qrCodes;
      _groups = groups;
      _isLoadingProjects = false;
      _isLoadingClients = false;
      _isLoadingWorkers = false;
      _isLoadingJobStatuses = false;
      _isLoadingQrCodes = false;
      _isLoadingGroups = false;
      _projectsLoadError = projectsError;
      _clientsLoadError = clientsError;
      if (_selectedJobStatus == null && jobStatuses.isNotEmpty) {
        _selectedJobStatus = _defaultToDoStatus(jobStatuses);
      }
      if (_selectedGroup == null && groups.isNotEmpty) {
        _selectedGroup = groups.first;
      }
      _applyInitialSelections();
    });
    final projectId = int.tryParse(_effectiveProjectId);
    if (projectId != null) {
      await _loadProjectForms(projectId: projectId);
    } else if (mounted) {
      setState(() => _isLoadingForms = false);
    }
    if (_isEditing) {
      await _loadJobForEdit();
    }
    if (_selectedGroup != null) {
      unawaited(_loadCompositeItemsForGroup(_selectedGroup!.id));
    }
    if (_selectedClient != null) {
      unawaited(_loadSitesForClient(_selectedClient!.id));
    }
  }

  NamedIdOption? _defaultToDoStatus(List<NamedIdOption> statuses) {
    for (final status in statuses) {
      final name = status.name.trim().toLowerCase();
      if (name == 'to do' || name == 'todo' || name.contains('to do')) {
        return status;
      }
    }
    return statuses.isNotEmpty ? statuses.first : null;
  }

  Future<void> _loadProjectForms({
    required int projectId,
    bool preserveSelection = false,
  }) async {
    final previousSelection =
        preserveSelection ? List<NamedIdOption>.from(_selectedForms) : const <NamedIdOption>[];

    setState(() {
      _isLoadingForms = true;
      if (!preserveSelection) {
        _selectedForms = const [];
      }
    });

    try {
      final formRows = await ref
          .read(formsApiClientProvider)
          .fetchProjectForms(projectId: projectId);
      final options = formRows.toActivePickerOptions();
      if (!mounted) return;
      setState(() {
        _formOptions = options;
        _isLoadingForms = false;
        if (preserveSelection && previousSelection.isNotEmpty) {
          _selectedForms = previousSelection
              .where((picked) => options.any((option) => option.id == picked.id))
              .toList(growable: false);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formOptions = const [];
        _isLoadingForms = false;
        if (!preserveSelection) {
          _selectedForms = const [];
        }
      });
    }
  }

  Future<void> _loadSitesForClient(int? clientId) async {
    setState(() {
      _isLoadingSites = true;
      _sitesLoadError = null;
      _selectedSite = null;
    });
    try {
      final sitesApi = ref.read(sitesApiClientProvider);
      final sites = await sitesApi.fetchAllSites(clientId: clientId);
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _isLoadingSites = false;
        if (sites.isNotEmpty) {
          _selectedSite = sites.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sites = const [];
        _isLoadingSites = false;
        _sitesLoadError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load sites',
        );
      });
    }
  }

  static String _siteDropdownLabel(SiteModel site) {
    final location = [
      site.city.trim(),
      site.state.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    if (location.isEmpty) return site.siteName;
    return '${site.siteName} — $location';
  }

  Future<void> _loadCompositeItemsForGroup(int groupId) async {
    try {
      final items = await ref
          .read(quoteProjectApiClientProvider)
          .fetchCompositeItems(groupId: groupId);
      if (!mounted) return;
      setState(() => _compositeItems = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _compositeItems = const []);
    }
  }

  void _applyInitialSelections() {
    final routeProjectId = widget.projectId.trim();
    if (routeProjectId.isNotEmpty) {
      for (final p in _projects) {
        if (p.id == routeProjectId) {
          _selectedProject = p;
          break;
        }
      }
    }
    if (_selectedProject == null) {
      final initialName = widget.initialProjectName.trim();
      if (initialName.isNotEmpty) {
        for (final p in _projects) {
          if (p.name == initialName) {
            _selectedProject = p;
            break;
          }
        }
      }
    }
    if (_selectedProject != null) {
      _projectNameController.text = _selectedProject!.name;
      final linkedClientId = _selectedProject!.clientId;
      if (linkedClientId != null) {
        for (final c in _clients) {
          if (c.id == linkedClientId) {
            _selectedClient = c;
            break;
          }
        }
      }
    }
    if (_selectedClient == null) {
      final initialClient = widget.initialClientName.trim();
      if (initialClient.isNotEmpty) {
        for (final c in _clients) {
          if (c.name == initialClient) {
            _selectedClient = c;
            break;
          }
        }
      }
    }
    if (_selectedClient != null) {
      _clientNameController.text = _selectedClient!.name;
    }
    if (_selectedClient != null) {
      unawaited(_loadSitesForClient(_selectedClient!.id));
    }
  }

  Future<void> _loadJobForEdit() async {
    final jobId = widget.editJobId?.trim();
    if (jobId == null || jobId.isEmpty) return;
    setState(() => _isLoadingEditJob = true);
    try {
      final job = await ref.read(quoteProjectApiClientProvider).fetchJobById(jobId);
      if (!mounted) return;
      await _applyJobForEdit(job);
      if (!mounted) return;
      setState(() => _isLoadingEditJob = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingEditJob = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not load job for editing.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _applyJobForEdit(JobRead job) async {
    _jobTitleController.text = job.title;
    _descriptionController.text = (job.description ?? '').trim();
    if (job.startDate != null) {
      _startDate = job.startDate;
      _startDateController.text = _formatDate(job.startDate!);
    }
    if (job.endDate != null) {
      _scheduleDate = job.endDate;
      _scheduleDateController.text = _formatDate(job.endDate!);
    }
    if (job.plotName?.trim().isNotEmpty == true) {
      _plotNameController.text = job.plotName!.trim();
    }
    if (job.qrCode != null) {
      _scannedQrValue = job.qrCode.toString();
      for (final q in _qrCodeOptions) {
        if (q.id == job.qrCode) {
          _selectedQrCode = q;
          break;
        }
      }
    }

    if (job.project != null) {
      final projectId = job.project.toString();
      for (final p in _projects) {
        if (p.id == projectId) {
          _selectedProject = p;
          _projectNameController.text = p.name;
          break;
        }
      }
    } else if (job.projectName?.trim().isNotEmpty == true) {
      for (final p in _projects) {
        if (p.name == job.projectName!.trim()) {
          _selectedProject = p;
          _projectNameController.text = p.name;
          break;
        }
      }
    }

    if (job.client != null) {
      for (final c in _clients) {
        if (c.id == job.client) {
          _selectedClient = c;
          _clientNameController.text = c.name;
          break;
        }
      }
    } else if (job.clientName?.trim().isNotEmpty == true) {
      for (final c in _clients) {
        if (c.name == job.clientName!.trim()) {
          _selectedClient = c;
          _clientNameController.text = c.name;
          break;
        }
      }
    }

    if (_selectedClient != null) {
      await _loadSitesForClient(_selectedClient!.id);
    }
    if (job.site != null && mounted) {
      final siteId = job.site.toString();
      for (final s in _sites) {
        if (s.id == siteId) {
          setState(() => _selectedSite = s);
          break;
        }
      }
    }

    if (job.assignedWorker != null) {
      final workerId = job.assignedWorker.toString();
      for (final w in _workers) {
        if (w.id == workerId) {
          setState(() => _selectedWorker = w);
          break;
        }
      }
    }

    if (job.jobStatus != null) {
      for (final s in _jobStatuses) {
        if (s.id == job.jobStatus) {
          setState(() => _selectedJobStatus = s);
          break;
        }
      }
    }

    final linkedFormIds = JobRead.linkedFormTemplateIds(job.raw);
    if (linkedFormIds.isNotEmpty) {
      final picked = <NamedIdOption>[];
      for (final formId in linkedFormIds) {
        for (final f in _formOptions) {
          if (f.id == formId) {
            picked.add(f);
            break;
          }
        }
      }
      if (picked.isNotEmpty) {
        setState(() => _selectedForms = picked);
      }
    }

    final plotMeta = job.jobMeta['plot'];
    final sectionMeta = job.jobMeta['section'];
    if (sectionMeta is Map) {
      final sectionName = sectionMeta['name']?.toString().trim();
      if (sectionName != null &&
          sectionName.isNotEmpty &&
          _materialLines.isNotEmpty) {
        _materialLines.first.sectionController.text = sectionName;
      }
    } else if (job.sectionName?.trim().isNotEmpty == true &&
        _materialLines.isNotEmpty) {
      _materialLines.first.sectionController.text = job.sectionName!.trim();
    }

    int? groupId;
    final compositeRows = <({int id, int quantity})>[];
    if (plotMeta is Map) {
      final plotName = plotMeta['name']?.toString().trim();
      if (plotName != null && plotName.isNotEmpty) {
        _plotNameController.text = plotName;
      }
      groupId = plotMeta['group'] is int
          ? plotMeta['group'] as int
          : int.tryParse('${plotMeta['group'] ?? ''}');
      final rawItems = plotMeta['composite_items'];
      if (rawItems is List) {
        for (final row in rawItems) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(
            row.map((k, v) => MapEntry(k.toString(), v)),
          );
          final id = map['id'] is int
              ? map['id'] as int
              : int.tryParse('${map['id'] ?? map['composite_item'] ?? ''}');
          final qty = map['quantity'] is int
              ? map['quantity'] as int
              : int.tryParse('${map['quantity'] ?? ''}') ?? 1;
          if (id != null) compositeRows.add((id: id, quantity: qty));
        }
      }
    }

    if (compositeRows.isEmpty) {
      final rawItems = job.jobMeta['composite_items'];
      if (rawItems is List) {
        for (final row in rawItems) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(
            row.map((k, v) => MapEntry(k.toString(), v)),
          );
          final id = map['id'] is int
              ? map['id'] as int
              : int.tryParse('${map['id'] ?? map['composite_item'] ?? ''}');
          final qty = map['quantity'] is int
              ? map['quantity'] as int
              : int.tryParse('${map['quantity'] ?? ''}') ?? 1;
          if (id != null) compositeRows.add((id: id, quantity: qty));
          if (groupId == null && map['group'] is Map) {
            final groupMap = Map<String, dynamic>.from(
              (map['group'] as Map).map((k, v) => MapEntry(k.toString(), v)),
            );
            groupId = groupMap['id'] is int
                ? groupMap['id'] as int
                : int.tryParse('${groupMap['id'] ?? ''}');
          }
        }
      }
    }

    if (groupId != null) {
      for (final g in _groups) {
        if (g.id == groupId) {
          setState(() => _selectedGroup = g);
          break;
        }
      }
      await _loadCompositeItemsForGroup(groupId);
    }

    if (compositeRows.isNotEmpty && mounted) {
      setState(() {
        while (_materialLines.length < compositeRows.length) {
          _materialLines.add(_MaterialLine());
        }
        _refreshMaterialListeners();
        for (var i = 0; i < compositeRows.length; i++) {
          final row = compositeRows[i];
          CompositeItemOption? match;
          for (final item in _compositeItems) {
            if (item.id == row.id) {
              match = item;
              break;
            }
          }
          _materialLines[i].applyCompositeItem(match);
          _materialLines[i].qtyController.text = '${row.quantity}';
        }
      });
    } else if (_materialLines.isNotEmpty) {
      if (job.quantity != null) {
        _materialLines.first.qtyController.text = '${job.quantity}';
      }
      if (job.sellingPrice != null) {
        _materialLines.first.priceController.text =
            job.sellingPrice!.toStringAsFixed(2);
      }
    }

    if (mounted) setState(() {});
  }

  void _onProjectSelected(ProjectOption? project) {
    setState(() {
      _selectedProject = project;
      _projectNameController.text = project?.name ?? '';
      _selectedForms = const [];
      if (project?.clientId != null) {
        for (final c in _clients) {
          if (c.id == project!.clientId) {
            _selectedClient = c;
            _clientNameController.text = c.name;
            break;
          }
        }
      }
    });
    unawaited(_loadSitesForClient(_selectedClient?.id));
    final projectId = int.tryParse(project?.id ?? '');
    if (projectId != null) {
      unawaited(_loadProjectForms(projectId: projectId));
    } else {
      setState(() {
        _formOptions = const [];
        _isLoadingForms = false;
      });
    }
  }

  void _onGroupSelected(GroupItemOption? group) {
    setState(() {
      _selectedGroup = group;
      for (final line in _materialLines) {
        line.applyCompositeItem(null);
      }
    });
    if (group != null) {
      unawaited(_loadCompositeItemsForGroup(group.id));
    }
  }

  void _onCompositeItemSelected(_MaterialLine line, CompositeItemOption? item) {
    setState(() => line.applyCompositeItem(item));
    if (item != null && item.sellingPrice == null) {
      unawaited(_resolveCompositeItemSellingPrice(line, item));
    }
  }

  Future<void> _resolveCompositeItemSellingPrice(
    _MaterialLine line,
    CompositeItemOption item,
  ) async {
    try {
      final detail = await ref
          .read(itemsApiClientProvider)
          .fetchItemDetail(item.id.toString());
      if (!mounted || line.compositeItem?.id != item.id) return;
      setState(() {
        line.priceController.text = detail.sellPrice.toStringAsFixed(2);
      });
    } catch (_) {
      // Keep manual entry when detail lookup fails.
    }
  }

  static String _userLabel(UserProfileModel user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    if (name.isNotEmpty) return name;
    final email = user.email.trim();
    return email.isNotEmpty ? email : 'User #${user.id}';
  }

  static String _userInitials(UserProfileModel user) {
    final first = user.firstName.trim();
    final last = user.lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    return 'U';
  }

  void _onClientSelected(ClientOption? client) {
    setState(() {
      _selectedClient = client;
      _clientNameController.text = client?.name ?? '';
    });
    unawaited(_loadSitesForClient(client?.id));
  }

  String get _effectiveProjectId =>
      (_selectedProject?.id ?? widget.projectId).trim();

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _refreshMaterialListeners() {
    for (final line in _materialLines) {
      line.qtyController.removeListener(_onChanged);
      line.priceController.removeListener(_onChanged);
      line.qtyController.addListener(_onChanged);
      line.priceController.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _jobTitleController,
      _projectNameController,
      _clientNameController,
      _descriptionController,
      _plotNameController,
      _startDateController,
      _scheduleDateController,
    ]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    for (final line in _materialLines) {
      line.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$mm/$dd/$yyyy';
  }

  double get _materialsSubtotal {
    var total = 0.0;
    for (final line in _materialLines) {
      total += line.lineTotal;
    }
    return total;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(symbol: r'$ ', decimalDigits: 2).format(value);
  }

  Map<String, dynamic> _buildCreateJobPayload() {
    final compositeItems = <Map<String, dynamic>>[];
    for (final line in _materialLines) {
      final item = line.compositeItem;
      if (item == null) continue;
      final quantity = line.quantity.round();
      final amount = line.lineTotal.round();
      final groupId = item.groupId ?? _selectedGroup?.id;
      final groupName = _selectedGroup?.name;
      compositeItems.add(<String, dynamic>{
        'id': item.id,
        'quantity': quantity,
        'name': item.name,
        if (groupId != null)
          'group': <String, dynamic>{
            'id': groupId,
            if (groupName != null && groupName.trim().isNotEmpty)
              'name': groupName.trim(),
          },
        'amount': amount,
      });
    }
    final scannedQrId = _scannedQrValue == null
        ? null
        : int.tryParse(_scannedQrValue!.trim());

    return JobWritePayload.build(
      title: _jobTitleController.text,
      description: _descriptionController.text,
      assignedWorker: int.tryParse(_selectedWorker?.id ?? ''),
      startDate: _startDate,
      endDate: _scheduleDate,
      jobStatus: _selectedJobStatus?.id,
      client: _selectedClient?.id,
      project: int.tryParse(_effectiveProjectId),
      site: int.tryParse(_selectedSite?.id ?? ''),
      formIds: _selectedForms.map((form) => form.id).toList(growable: false),
      qrCode: _selectedQrCode?.id ?? scannedQrId,
      jobMeta: JobWritePayload.buildCompositeJobMeta(
        compositeItems: compositeItems,
        total: _materialsSubtotal,
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: (isStart ? _startDate : _scheduleDate) ?? DateTime.now(),
      helpText: isStart ? 'Start date' : 'Schedule date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateController.text = _formatDate(picked);
      } else {
        _scheduleDate = picked;
        _scheduleDateController.text = _formatDate(picked);
      }
    });
  }

  Future<void> _pickForms() async {
    if (_isLoadingForms) return;
    if (_effectiveProjectId.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Select a project first.')),
      );
      return;
    }
    if (_formOptions.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('No forms available for this project.')),
      );
      return;
    }

    final picked = await showFormsMultiPickerSheet(
      context: context,
      forms: _formOptions,
      selected: _selectedForms,
      description: 'Choose one or more forms to attach to this job.',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedForms = picked);
  }

  String get _selectedFormsLabel => formatNamedIdSelectionLabel(_selectedForms);

  Future<void> _pickWorker() async {
    if (_workers.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('No workers available to assign.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<UserProfileModel>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Assigned worker',
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ..._workers.map((w) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD4E4F7),
                    child: Text(
                      _userInitials(w),
                      style: AppFonts.labelSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    _userLabel(w),
                    style: _dropdownValueStyle,
                  ),
                  onTap: () => Navigator.pop(ctx, w),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => _selectedWorker = picked);
  }

  void _addMaterialLine() {
    setState(() {
      _materialLines.add(_MaterialLine());
      _refreshMaterialListeners();
    });
  }

  void _removeMaterialLine(int index) {
    if (_materialLines.length <= 1) return;
    setState(() {
      _materialLines[index].dispose();
      _materialLines.removeAt(index);
      _refreshMaterialListeners();
    });
  }

  Future<void> _submit() async {
    setState(() => _attemptedSubmit = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_selectedWorker == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please assign a worker.')),
      );
      return;
    }
    if (_selectedProject == null && _effectiveProjectId.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please select a project.')),
      );
      return;
    }
    if (_selectedJobStatus == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please select a job status.')),
      );
      return;
    }
    if (_selectedSite == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please select a site.')),
      );
      return;
    }
    final hasComposite = _materialLines.any((l) => l.compositeItem != null);
    if (!hasComposite) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Add at least one composite item in materials.'),
        ),
      );
      return;
    }
    if (_startDate == null || _scheduleDate == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Start and schedule dates are required.')),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      if (_isEditing) {
        final jobId = widget.editJobId!.trim();
        await api.updateJob(
          jobId: jobId,
          payload: _buildCreateJobPayload(),
        );
        if (!mounted) return;
        context.showTopSnackBar(
          const SnackBar(
            content: Text('Job updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
        return;
      }
      await api.createJob(_buildCreateJobPayload());
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Job created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.standalone) {
        ref.read(jobsListRefreshTickProvider.notifier).state++;
        context.pop(true);
        return;
      }
      context.go(
        ProjectDetailsPage.pathFor(_effectiveProjectId),
        extra: <String, Object?>{
          'id': _effectiveProjectId,
          'quoteName': _projectNameController.text.trim().isEmpty
              ? 'Project'
              : _projectNameController.text.trim(),
          'quoteNumber': '—',
          'projectName': _projectNameController.text.trim(),
          'clientName': _clientNameController.text.trim(),
          'initialTabIndex': 1,
          'jobsRefreshToken': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not create job',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _scanQrCode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScannerPage()));
    final value = code?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() {
      _scannedQrValue = value;
      final id = int.tryParse(value);
      if (id != null) {
        final match = _qrCodeOptions.where((q) => q.id == id).firstOrNull;
        _selectedQrCode = match ?? NamedIdOption(id: id, name: 'QR $id');
      }
    });
    context.showTopSnackBar(
      const SnackBar(content: Text('QR code scanned successfully.')),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: _sectionGrey),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppFonts.labelLarge(
              color: _sectionGrey,
            ).copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppFonts.titleSmall(
            color: _labelColor,
          ).copyWith(fontWeight: FontWeight.w600),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppFonts.titleSmall(
                      color: AppColors.accentRed,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  Widget _darkField(AppTextField field) {
    return field;
  }

  Widget _pickerField({
    required String value,
    required String placeholder,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: leading != null ? 56 : 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textFieldBorder),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                hasValue ? value : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hasValue
                    ? _dropdownValueStyle
                    : _dropdownHintStyle,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _apiDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    required String hint,
    String? Function(T?)? validator,
    bool isLoading = false,
    String? loadError,
  }) {
    final enabled = !isLoading && loadError == null && items.isNotEmpty;
    final effectiveValue =
        items.any((item) => item.value == value) ? value : null;

    return DropdownButtonFormField<T>(
      key: ValueKey('dropdown-$hint-${items.length}-$isLoading'),
      value: effectiveValue,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      style: _dropdownValueStyle,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
      dropdownColor: AppColors.white,
      decoration: InputDecoration(
        hintText: isLoading
            ? 'Loading...'
            : (loadError ?? hint),
        hintStyle: _dropdownHintStyle,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inkStrong, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
      ),
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: AppTextField(
          controller: controller,
          hintText: hint,
          readOnly: true,
          validator: validator,
          borderRadius: 12,
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: AppColors.inkStrong,
            ),
          ),
        ),
      ),
    );
  }

  Widget _halfRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _materialCard(int index) {
    final line = _materialLines[index];
    return Container(
      margin: EdgeInsets.only(
        bottom: index < _materialLines.length - 1 ? 12 : 0,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textFieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_materialLines.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeMaterialLine(index),
                icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
              ),
            ),
          if (index == 0) ...[
            _label('Plot Name'),
            _darkField(
              AppTextField(
                controller: _plotNameController,
                hintText: 'Plot name',
                borderRadius: 10,
              ),
            ),
            const SizedBox(height: 12),
            _label('Group'),
            _apiDropdownField<GroupItemOption>(
              value: _selectedGroup,
              isLoading: _isLoadingGroups,
              hint: 'Select group',
              items: _groups
                  .map(
                    (g) => DropdownMenuItem<GroupItemOption>(
                      value: g,
                      child: Text(g.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: _onGroupSelected,
            ),
            const SizedBox(height: 12),
          ],
          _label('Section Name'),
          _darkField(
            AppTextField(
              controller: line.sectionController,
              hintText: 'Section name',
              borderRadius: 10,
            ),
          ),
          const SizedBox(height: 12),
          _label('Composite Item'),
          _apiDropdownField<CompositeItemOption>(
            value: line.compositeItem,
            isLoading: false,
            hint: _compositeItems.isEmpty
                ? 'Select a group first'
                : 'Select item',
            items: _compositeItems
                .map(
                  (item) => DropdownMenuItem<CompositeItemOption>(
                    value: item,
                    child: Text(item.name, style: _dropdownValueStyle),
                  ),
                )
                .toList(),
            onChanged: (item) => _onCompositeItemSelected(line, item),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUANTITY',
                      style: AppFonts.labelSmall(color: AppColors.muted)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: line.qtyController,
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      borderRadius: 10,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNIT PRICE',
                      style: AppFonts.labelSmall(color: AppColors.muted)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: line.priceController,
                      hintText: r'$ 0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      borderRadius: 10,
                      dense: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final worker = _selectedWorker;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: AppColors.inkStrong,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          _isEditing ? 'Edit Job' : 'Create Job',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingEditJob
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        autovalidateMode: _attemptedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottom),
          children: [
            _sectionTitle('JOB DETAILS'),
            _label('Job Title', required: true),
            _darkField(
              AppTextField(
                controller: _jobTitleController,
                hintText: 'e.g. Electrical Panel Installation',
                borderRadius: 12,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Job title is required' : null,
              ),
            ),
            const SizedBox(height: 14),
            _label('Project Name', required: true),
            _apiDropdownField<ProjectOption>(
              value: _selectedProject,
              isLoading: _isLoadingProjects,
              loadError: _projectsLoadError,
              hint: 'Select project',
              items: _projects
                  .map(
                    (p) => DropdownMenuItem<ProjectOption>(
                      value: p,
                      child: Text(p.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: _onProjectSelected,
              validator: (v) => v == null ? 'Project is required' : null,
            ),
            const SizedBox(height: 14),
            _label('Client Name', required: true),
            _apiDropdownField<ClientOption>(
              value: _selectedClient,
              isLoading: _isLoadingClients,
              loadError: _clientsLoadError,
              hint: 'Select client',
              items: _clients
                  .map(
                    (c) => DropdownMenuItem<ClientOption>(
                      value: c,
                      child: Text(c.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: _onClientSelected,
              validator: (v) => v == null ? 'Client is required' : null,
            ),
            const SizedBox(height: 14),
            _label('Site', required: true),
            _apiDropdownField<SiteModel>(
              value: _selectedSite,
              isLoading: _isLoadingSites,
              loadError: _sitesLoadError,
              hint: _selectedClient == null
                  ? 'Select a client first'
                  : 'Select site',
              items: _sites
                  .map(
                    (s) => DropdownMenuItem<SiteModel>(
                      value: s,
                      child: Text(
                        _siteDropdownLabel(s),
                        style: _dropdownValueStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _selectedClient == null
                  ? null
                  : (site) => setState(() => _selectedSite = site),
              validator: (v) => v == null ? 'Site is required' : null,
            ),
            const SizedBox(height: 14),
            _label('Description'),
            _darkField(
              AppTextField(
                controller: _descriptionController,
                hintText:
                    'Install and configure electrical panel at site location.',
                minLines: 4,
                maxLines: 6,
                borderRadius: 12,
              ),
            ),
            const SizedBox(height: 14),
            _label('Job Status', required: true),
            _apiDropdownField<NamedIdOption>(
              value: _selectedJobStatus,
              isLoading: _isLoadingJobStatuses,
              hint: 'Select status',
              items: _jobStatuses
                  .map(
                    (s) => DropdownMenuItem<NamedIdOption>(
                      value: s,
                      child: Text(s.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() => _selectedJobStatus = s),
              validator: (v) => v == null ? 'Job status is required' : null,
            ),
            _sectionTitle('SCHEDULE'),
            _label('Assigned Worker', required: true),
            _pickerField(
              value: worker == null ? '' : _userLabel(worker),
              placeholder: _isLoadingWorkers ? 'Loading...' : 'Select worker',
              onTap: _isLoadingWorkers ? () {} : _pickWorker,
              leading: worker == null
                  ? null
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFD4E4F7),
                      child: Text(
                        _userInitials(worker),
                        style: AppFonts.labelSmall(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Start Date', required: true),
                  _dateField(
                    controller: _startDateController,
                    hint: 'mm/dd/yyyy',
                    onTap: () => _pickDate(isStart: true),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Schedule Date', required: true),
                  _dateField(
                    controller: _scheduleDateController,
                    hint: 'mm/dd/yyyy',
                    onTap: () => _pickDate(isStart: false),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            _sectionTitle('MATERIALS'),
            ...List.generate(_materialLines.length, _materialCard),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addMaterialLine,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.muted,
                side: const BorderSide(
                  color: AppColors.borderLight,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'Add Another Item',
                style: AppFonts.titleSmall(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Subtotal',
                    style: AppFonts.labelMedium(
                      color: _sectionGrey,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_materialsSubtotal),
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                ],
              ),
            ),
            _sectionTitle('FORMS'),
            _label('Select Forms'),
            _pickerField(
              value: _selectedFormsLabel,
              placeholder: _isLoadingForms
                  ? 'Loading forms...'
                  : _effectiveProjectId.isEmpty
                      ? 'Select a project first'
                      : 'Choose forms',
              onTap: _isLoadingForms || _effectiveProjectId.isEmpty
                  ? () {}
                  : _pickForms,
            ),
            _sectionTitle('IDENTIFICATION'),
            _label('QR Code'),
            _apiDropdownField<NamedIdOption>(
              value: _selectedQrCode,
              isLoading: _isLoadingQrCodes,
              hint: 'Select or scan QR code',
              items: _qrCodeOptions
                  .map(
                    (q) => DropdownMenuItem<NamedIdOption>(
                      value: q,
                      child: Text(q.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: (q) => setState(() {
                _selectedQrCode = q;
                _scannedQrValue = q?.id.toString();
              }),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: const Color(0xFF4B5563),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isSubmitting
                          ? (_isEditing ? 'Saving...' : 'Creating...')
                          : (_isEditing ? 'Save Changes' : 'Create Job'),
                      style: AppFonts.titleMedium(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (!_isSubmitting) ...[
                      const SizedBox(width: 10),
                      Icon(
                        _isEditing ? Icons.check_rounded : Icons.add,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  late final MobileScannerController _controller;
  bool _didReturn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didReturn) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        value = code;
        break;
      }
    }
    if (value == null) return;
    _didReturn = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        title: Text(
          'Scan QR Code',
          style: AppFonts.titleLarge(
            color: AppColors.white,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40 + MediaQuery.paddingOf(context).bottom,
            child: Text(
              'Place the QR code inside the frame',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialLine {
  _MaterialLine()
    : sectionController = TextEditingController(
        text: 'Main Electrical Panel',
      ),
      qtyController = TextEditingController(text: '1'),
      priceController = TextEditingController();

  final TextEditingController sectionController;
  CompositeItemOption? compositeItem;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  String get sectionName => sectionController.text.trim();

  double get quantity {
    return double.tryParse(qtyController.text.trim()) ?? 0;
  }

  double get unitPrice {
    final raw = priceController.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  double get lineTotal => quantity * unitPrice;

  void applyCompositeItem(CompositeItemOption? item) {
    compositeItem = item;
    if (item == null) {
      priceController.clear();
      return;
    }
    final price = item.sellingPrice;
    if (price != null) {
      priceController.text = price.toStringAsFixed(2);
    } else {
      priceController.clear();
    }
    final qty = item.quantity;
    qtyController.text =
        qty == qty.roundToDouble() ? qty.round().toString() : qty.toString();
  }

  void dispose() {
    sectionController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
