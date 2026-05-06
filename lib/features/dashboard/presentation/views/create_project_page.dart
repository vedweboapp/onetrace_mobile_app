import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/upload_drawing_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});

  static const path = '/create-project';
  static const name = 'create-project';

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

  @override
  void initState() {
    super.initState();
    _projectNameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _startDateController.addListener(_onFormChanged);
    _endDateController.addListener(_onFormChanged);
    _loadClients();
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

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
      _clientsError = null;
    });
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final clients = await api.fetchClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _clientsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load clients',
        );
        _isLoadingClients = false;
      });
    }
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

  Future<void> _chooseClient() async {
    if (_isLoadingClients || _clients.isEmpty) return;
    final selected = await showModalBottomSheet<ClientOption>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _clients.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final client = _clients[index];
              final selected = _selectedClient?.id == client.id;
              return ListTile(
                title: Text(
                  client.name,
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: AppColors.inkStrong)
                    : null,
                onTap: () => Navigator.of(ctx).pop(client),
              );
            },
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedClient = selected);
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
        description: _descriptionController.text.trim(),
        startDate: _formatForApi(_startDate!),
        endDate: _formatForApi(_endDate!),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created successfully')),
      );
      final uploadResult = await context.push<dynamic>(
        UploadDrawingPage.path,
        extra: <String, dynamic>{'projectId': projectId},
      );
      if (!mounted || uploadResult is! Map) {
        context.pop();
        return;
      }

      final map = Map<String, dynamic>.from(uploadResult);
      final fileName = (map['fileName'] ?? '').toString().trim();
      final pdfName = (map['pdfName'] ?? '').toString().trim();
      final filePath = (map['filePath'] ?? '').toString().trim();
      final levelName = (map['levelName'] ?? '').toString().trim();
      final uploadedProjectId = (map['projectId'] ?? '').toString().trim();
      final levelId = (map['levelId'] ?? '').toString().trim();
      final title = (pdfName.isNotEmpty ? pdfName : fileName).trim();

      if (title.isNotEmpty && filePath.isNotEmpty) {
        await context.push<bool>(
          DrawingCanvasPage.path,
          extra: <String, dynamic>{
            'title': title,
            'filePath': filePath,
            'levelName': levelName,
            'projectName': _projectNameController.text.trim(),
            'projectId': uploadedProjectId.isEmpty ? projectId : uploadedProjectId,
            'levelId': levelId,
          },
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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

  bool get _isDescriptionValid => _descriptionController.text.trim().length >= 20;

  bool get _areDatesValid {
    if (_startDate == null || _endDate == null) return false;
    return !_endDate!.isBefore(_startDate!);
  }

  bool get _isClientValid => _selectedClient != null;

  bool get _isFormValid =>
      _isProjectNameValid &&
      _isDescriptionValid &&
      _isClientValid &&
      _areDatesValid &&
      !_isLoadingClients;

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: AppColors.inkStrong),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppFonts.labelLarge(color: AppColors.muted).copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
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
          style: AppFonts.titleSmall(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
          ),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppFonts.titleSmall(color: AppColors.accentRed).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  Widget _clientField() {
    final text = _selectedClient?.name ?? 'Select a client';
    final showClientError = _attemptedSubmit && !_isClientValid;
    return InkWell(
      onTap: _chooseClient,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showClientError ? AppColors.error : AppColors.textFieldBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppFonts.bodyMedium(
                  color: _selectedClient == null
                      ? AppColors.textFieldHint
                      : AppColors.textFieldForeground,
                ).copyWith(
                  fontSize: 15,
                  fontWeight: _selectedClient == null
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            ),
            if (_isLoadingClients)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          ],
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
              Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.inkStrong),
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
          style: AppFonts.titleLarge(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
          ),
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
                            style: AppFonts.titleSmall(color: AppColors.error).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please correct the errors highlighted below to continue.',
                            style: AppFonts.bodySmall(color: AppColors.error).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
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
                      child: Icon(Icons.error_rounded, color: AppColors.error, size: 18),
                    )
                  : null,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Project name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Client'),
            _clientField(),
            if (_attemptedSubmit && !_isClientValid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Client is required',
                  style: AppFonts.bodySmall(color: AppColors.error).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_clientsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _clientsError!,
                  style: AppFonts.bodySmall(color: AppColors.danger),
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
                  style: AppFonts.labelSmall(color: descriptionCounterColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                if ((value ?? '').trim().isEmpty) return 'Start date is required';
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
                  style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
