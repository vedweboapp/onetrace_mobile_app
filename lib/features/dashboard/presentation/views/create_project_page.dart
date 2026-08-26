import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/upload_drawing_page.dart';
import 'package:red5/features/dashboard/presentation/widgets/create_project_type_dialog.dart';
import 'package:red5/features/dashboard/presentation/widgets/forms_multi_picker_sheet.dart';
import 'package:red5/features/dashboard/presentation/widgets/project_type_picker_sheet.dart';
import 'package:red5/features/forms/data/form_picker_utils.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({
    super.key,
    this.preselectedClientId,
    this.preselectedClientName,
  });

  static const path = '/create-project';
  static const name = 'create-project';
  final int? preselectedClientId;
  final String? preselectedClientName;

  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  bool _attemptedSubmit = false;
  bool _isLoadingClients = false;
  String? _clientsError;
  List<ClientOption> _clients = const [];
  ClientOption? _selectedClient;

  bool _isLoadingProjectTypes = false;
  String? _projectTypesError;
  List<NamedIdOption> _projectTypes = const [];
  NamedIdOption? _selectedProjectType;

  bool _isLoadingForms = false;
  String? _formsError;
  List<NamedIdOption> _formOptions = const [];
  List<NamedIdOption> _selectedForms = const [];

  bool _isLoadingSites = false;
  String? _sitesError;
  List<SiteModel> _sites = const [];
  SiteModel? _selectedSite;

  static TextStyle get _dropdownValueStyle => AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  static TextStyle get _dropdownHintStyle => AppFonts.bodyMedium(
        color: AppColors.textFieldHint,
      ).copyWith(fontSize: 15, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _projectNameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _startDateController.addListener(_onFormChanged);
    _endDateController.addListener(_onFormChanged);
    _loadFormOptions();
  }

  Future<void> _loadFormOptions() async {
    setState(() {
      _isLoadingClients = true;
      _isLoadingProjectTypes = true;
      _isLoadingForms = true;
      _clientsError = null;
      _projectTypesError = null;
      _formsError = null;
    });

    final api = ref.read(quoteProjectApiClientProvider);
    final formsApi = ref.read(formsApiClientProvider);
    var clients = const <ClientOption>[];
    var projectTypes = const <NamedIdOption>[];
    var forms = const <NamedIdOption>[];
    String? clientsError;
    String? projectTypesError;
    String? formsError;

    try {
      clients = await api.fetchClients();
    } catch (e) {
      clientsError = ApiResponseMessage.fromAnyError(
        e,
        genericFallback: 'Failed to load clients',
      );
    }

    try {
      projectTypes = await api.fetchProjectTypeOptions();
    } catch (e) {
      projectTypesError = ApiResponseMessage.fromAnyError(
        e,
        genericFallback: 'Failed to load project types',
      );
    }

    try {
      final formRows = await formsApi.fetchForms();
      forms = formRows.toActivePickerOptions();
    } catch (e) {
      formsError = ApiResponseMessage.fromAnyError(
        e,
        genericFallback: 'Failed to load forms',
      );
    }

    if (!mounted) return;
    setState(() {
      _clients = clients;
      _projectTypes = projectTypes;
      _formOptions = forms;
      _clientsError = clientsError;
      _projectTypesError = projectTypesError;
      _formsError = formsError;
      _isLoadingClients = false;
      _isLoadingProjectTypes = false;
      _isLoadingForms = false;

      final incomingId = widget.preselectedClientId;
      if (_selectedClient == null && incomingId != null) {
        final match = clients.where((c) => c.id == incomingId).toList();
        if (match.isNotEmpty) {
          _selectedClient = match.first;
        } else {
          final fallbackName = (widget.preselectedClientName ?? '').trim();
          _selectedClient = ClientOption(
            id: incomingId,
            name: fallbackName.isEmpty ? 'Client #$incomingId' : fallbackName,
          );
        }
      }
    });

    if (_selectedClient != null) {
      await _loadSitesForClient(_selectedClient!.id);
    }
  }

  Future<void> _loadProjectTypes({NamedIdOption? select}) async {
    setState(() {
      _isLoadingProjectTypes = true;
      _projectTypesError = null;
    });
    try {
      final projectTypes =
          await ref.read(quoteProjectApiClientProvider).fetchProjectTypeOptions();
      if (!mounted) return;
      setState(() {
        _projectTypes = projectTypes;
        _isLoadingProjectTypes = false;
        if (select != null) {
          _selectedProjectType = select;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProjectTypes = false;
        _projectTypesError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load project types',
        );
      });
    }
  }

  Future<void> _pickProjectType() async {
    if (_isLoadingProjectTypes) return;
    final api = ref.read(quoteProjectApiClientProvider);
    final selected = await showProjectTypePickerSheet(
      context: context,
      projectTypes: _projectTypes,
      selected: _selectedProjectType,
      onAddProjectType: () => showCreateProjectTypeDialog(
        context: context,
        api: api,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedProjectType = selected;
      if (!_projectTypes.any((type) => type.id == selected.id)) {
        _projectTypes = [..._projectTypes, selected];
      }
    });
  }

  Future<void> _createProjectTypeFromPicker() async {
    final api = ref.read(quoteProjectApiClientProvider);
    final created = await showCreateProjectTypeDialog(context: context, api: api);
    if (created == null || !mounted) return;
    await _loadProjectTypes(select: created);
  }

  Future<void> _pickForms() async {
    if (_isLoadingForms) return;
    if (_formOptions.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('No forms available to select.')),
      );
      return;
    }

    final picked = await showFormsMultiPickerSheet(
      context: context,
      forms: _formOptions,
      selected: _selectedForms,
      description: 'Choose one or more forms to link with this project.',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedForms = picked);
  }

  String get _selectedFormsLabel => formatNamedIdSelectionLabel(_selectedForms);

  Future<void> _loadSitesForClient(int? clientId) async {
    setState(() {
      _isLoadingSites = true;
      _sitesError = null;
      _sites = const [];
      _selectedSite = null;
    });
    if (clientId == null) {
      setState(() => _isLoadingSites = false);
      return;
    }
    try {
      final sites =
          await ref.read(sitesApiClientProvider).fetchAllSites(clientId: clientId);
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _isLoadingSites = false;
        if (sites.length == 1) {
          _selectedSite = sites.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sites = const [];
        _isLoadingSites = false;
        _sitesError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load sites',
        );
      });
    }
  }

  void _onClientChanged(ClientOption? client) {
    setState(() => _selectedClient = client);
    _loadSitesForClient(client?.id);
  }

  static String _siteDropdownLabel(SiteModel site) {
    final location = [
      site.city.trim(),
      site.state.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    if (location.isEmpty) return site.siteName;
    return '${site.siteName} — $location';
  }

  @override
  void dispose() {
    _projectNameController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _startDateController.removeListener(_onFormChanged);
    _endDateController.removeListener(_onFormChanged);
    _projectNameController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _formatForInput(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    return '$mm/$dd/$yyyy';
  }

  String _formatForApi(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _pickStartDate() async {
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select start date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      _startDateController.text = _formatForInput(_startDate!);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
        _endDateController.text = _formatForInput(_endDate!);
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      _endDateController.text = _formatForInput(_endDate!);
    });
  }

  Future<void> _submit() async {
    setState(() => _attemptedSubmit = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (!_isFormValid) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final projectId = await api.createProject(
        name: _projectNameController.text.trim(),
        clientId: _selectedClient!.id,
        projectTypeId: _selectedProjectType!.id,
        siteId: int.tryParse(_selectedSite!.id),
        description: _descriptionController.text.trim(),
        startDate: _formatForApi(_startDate!),
        endDate: _formatForApi(_endDate!),
        forms: _selectedForms.map((form) => form.id).toList(growable: false),
      );
      if (!mounted) return;
      context.showSuccessTopPopup(
        title: 'Project created successfully',
        subtitle: 'You can upload drawings in the next step.',
      );
      final uploadResult = await context.push<dynamic>(
        UploadDrawingPage.path,
        extra: <String, dynamic>{'projectId': projectId},
      );
      if (!mounted) return;
      if (uploadResult is! Map) {
        context.pop();
        return;
      }

      final map = Map<String, dynamic>.from(uploadResult);
      final uploadCount = DrawingCanvasArgs.uploadCountFromResult(map);
      if (uploadCount == 1) {
        final args = DrawingCanvasArgs.fromUploadResult(
          map,
          projectName: _projectNameController.text.trim(),
          projectId: projectId,
        );
        if (args.title.trim().isNotEmpty &&
            (args.filePath ?? '').trim().isNotEmpty) {
          if (!mounted) return;
          await DrawingCanvasPage.push(context, args);
        }
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not create project',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _isProjectNameValid => _projectNameController.text.trim().isNotEmpty;

  bool get _isDescriptionValid =>
      _descriptionController.text.trim().length >= 20;

  bool get _areDatesValid {
    if (_startDate == null || _endDate == null) return false;
    return !_endDate!.isBefore(_startDate!);
  }

  bool get _isClientValid => _selectedClient != null;

  bool get _isProjectTypeValid => _selectedProjectType != null;

  bool get _isSiteValid => _selectedSite != null;

  bool get _isFormValid =>
      _isProjectNameValid &&
      _isProjectTypeValid &&
      _isDescriptionValid &&
      _isClientValid &&
      _isSiteValid &&
      _areDatesValid &&
      !_isLoadingClients &&
      !_isLoadingProjectTypes &&
      !_isLoadingSites;

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
        hintText: isLoading ? 'Loading...' : (loadError ?? hint),
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

  Widget _projectTypeField() {
    return FormField<void>(
      validator: (_) {
        if (!_isProjectTypeValid) return 'Project type is required';
        return null;
      },
      autovalidateMode: _attemptedSubmit
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      builder: (state) {
        final hasError = state.hasError;
        final text = _selectedProjectType?.name ?? 'Select a Type';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _isLoadingProjectTypes ? null : _pickProjectType,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? AppColors.error
                        : AppColors.textFieldBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoadingProjectTypes ? 'Loading...' : text,
                        style: _selectedProjectType == null
                            ? _dropdownHintStyle
                            : _dropdownValueStyle,
                      ),
                    ),
                    if (_isLoadingProjectTypes)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.muted,
                      ),
                  ],
                ),
              ),
            ),
            if (_projectTypesError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _projectTypesError!,
                  style: AppFonts.bodySmall(color: AppColors.danger),
                ),
              ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText ?? '',
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isLoadingProjectTypes
                    ? null
                    : _createProjectTypeFromPicker,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                child: Text(
                  'Add a project type',
                  style: AppFonts.bodySmall(
                    color: const Color(0xFF2563EB),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _formsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoadingForms ? null : _pickForms,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.textFieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isLoadingForms
                        ? 'Loading forms...'
                        : (_selectedFormsLabel.isEmpty
                            ? 'Choose forms'
                            : _selectedFormsLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _selectedFormsLabel.isEmpty
                        ? _dropdownHintStyle
                        : _dropdownValueStyle,
                  ),
                ),
                if (_isLoadingForms)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
        ),
        if (_formsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _formsError!,
              style: AppFonts.bodySmall(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: AppColors.inkStrong),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppFonts.labelLarge(
              color: AppColors.muted,
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
            color: AppColors.inkStrong,
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: AppColors.inkStrong,
              ),
              SizedBox(width: 8),
              Icon(Icons.date_range_outlined, size: 18, color: AppColors.muted),
              SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showErrorBanner = _attemptedSubmit && !_isFormValid;
    final descriptionLength = _descriptionController.text.trim().length;
    final descriptionCounterColor = descriptionLength >= 20
        ? AppColors.muted
        : AppColors.error;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Create Project',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _attemptedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
          children: [
            if (showErrorBanner)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEDEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF2D3D6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Form Submission Failed',
                            style: AppFonts.titleSmall(
                              color: AppColors.error,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please correct the errors highlighted below to continue.',
                            style: AppFonts.bodySmall(
                              color: AppColors.error,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _sectionTitle('BASIC INFO'),
            _label('Project Name', required: true),
            AppTextField(
              controller: _projectNameController,
              hintText: 'e.g. Skyline Apartments Phase II',
              suffixIcon: _attemptedSubmit && !_isProjectNameValid
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.error_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    )
                  : null,
              validator: (value) {
                if ((value ?? '').trim().isEmpty)
                  return 'Project name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Project Type', required: true),
            _projectTypeField(),
            const SizedBox(height: 14),
            _label('Forms'),
            _formsField(),
            const SizedBox(height: 14),
            _label('Client', required: true),
            _apiDropdownField<ClientOption>(
              value: _selectedClient,
              isLoading: _isLoadingClients,
              loadError: _clientsError,
              hint: 'Select a client',
              items: _clients
                  .map(
                    (c) => DropdownMenuItem<ClientOption>(
                      value: c,
                      child: Text(c.name, style: _dropdownValueStyle),
                    ),
                  )
                  .toList(),
              onChanged: _onClientChanged,
              validator: (value) => value == null ? 'Client is required' : null,
            ),
            const SizedBox(height: 14),
            _label('Sites', required: true),
            _apiDropdownField<SiteModel>(
              value: _selectedSite,
              isLoading: _isLoadingSites,
              loadError: _sitesError,
              hint: _selectedClient == null
                  ? 'Select a client first'
                  : 'Select a Site',
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
              onChanged: _selectedClient == null || _isLoadingSites
                  ? null
                  : (value) => setState(() => _selectedSite = value),
              validator: (value) {
                if (_selectedClient == null) return 'Select a client first';
                if (value == null) return 'Site is required';
                return null;
              },
            ),
            if (_selectedClient != null &&
                !_isLoadingSites &&
                _sites.isEmpty &&
                _sitesError == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No sites found for this client. Add a site first.',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 14),
            _label('Description', required: true),
            AppTextField(
              controller: _descriptionController,
              hintText: 'Provide a brief overview of the project scope...',
              minLines: 4,
              maxLines: 4,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Description is required';
                if (text.length < 20) {
                  return 'Description must be at least 20 characters';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$descriptionLength/20',
                  style: AppFonts.labelSmall(
                    color: descriptionCounterColor,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('TIMELINE'),
            _label('Start Date', required: true),
            _dateField(
              controller: _startDateController,
              hint: 'mm/dd/yyyy',
              onTap: _pickStartDate,
              validator: (value) {
                if ((value ?? '').trim().isEmpty)
                  return 'Start date is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('End Date', required: true),
            _dateField(
              controller: _endDateController,
              hint: 'mm/dd/yyyy',
              onTap: _pickEndDate,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'End date is required';
                if (_startDate != null &&
                    _endDate != null &&
                    _endDate!.isBefore(_startDate!)) {
                  return 'End date cannot be before start date';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : ((!_attemptedSubmit || _isFormValid) ? _submit : null),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF101114),
                  disabledBackgroundColor: const Color(0xFFAFAFB1),
                  foregroundColor: AppColors.white,
                  disabledForegroundColor: const Color(0xFFEDEDEE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isSubmitting ? 'Creating...' : 'Create',
                  style: AppFonts.titleMedium(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
