import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class _BillJobDraft {
  _BillJobDraft();

  JobRead? job;
}

/// Create bill order form (UI until bill API is available).
class AddBillPage extends ConsumerStatefulWidget {
  const AddBillPage({super.key});

  static const pathPrefix = '/bills';
  static const name = 'add-bill';
  static String get path => '$pathPrefix/add';

  @override
  ConsumerState<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends ConsumerState<AddBillPage> {
  static const _pageBg = Color(0xFFF7F7F8);
  static const _cardBg = AppColors.white;
  static const _labelGrey = Color(0xFF6B7280);
  static const _totalBoxBg = Color(0xFFE8F0FE);
  static const _addItemBlue = Color(0xFF2563EB);

  final _formKey = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(symbol: r'$');
  final _isoDate = DateFormat('yyyy-MM-dd');

  final _billLine1 = TextEditingController(text: 'Acme Corporation');
  final _billLine2 = TextEditingController(text: 'Acme Corporation');
  final _billCity = TextEditingController();
  final _billZip = TextEditingController();
  final _billCountry = TextEditingController();
  final _billState = TextEditingController();

  final _shipLine1 = TextEditingController(text: 'Acme Corporation');
  final _shipLine2 = TextEditingController(text: 'Acme Corporation');
  final _shipCity = TextEditingController();
  final _shipZip = TextEditingController();
  final _shipCountry = TextEditingController();
  final _shipState = TextEditingController();

  final _purchaseOrderId = TextEditingController(text: 'NW-2024-021');
  final _projectName = TextEditingController();
  final _issueDate = TextEditingController();
  final _dueDate = TextEditingController();
  final _clientNotes = TextEditingController(
    text:
        'Payment is due within 30 days of bill date. Late payments may incur additional charges.',
  );
  final _internalNotes = TextEditingController(
    text:
        'Payment is due within 30 days of bill date. Late payments may incur additional charges.',
  );

  DateTime? _issueDateValue;
  DateTime? _dueDateValue;
  double _adjustment = 0;

  ClientModel? _user;
  ContactModel? _contact;
  ProjectOption? _project;
  String _paymentTerms = 'Net 30 Days';

  List<ClientModel> _users = const [];
  List<ContactModel> _contacts = const [];
  List<JobRead> _jobsCatalog = const [];
  final List<_BillJobDraft> _jobLines = [_BillJobDraft()];
  bool _loadingOptions = false;
  bool _loadingJobs = false;
  bool _submitting = false;

  static const _paymentTermOptions = [
    'Net 30 Days',
    'Net 15 Days',
    'Net 45 Days',
    'Net 60 Days',
    'Due on receipt',
  ];

  static final _dropdownValueStyle = AppFonts.bodyMedium(
    color: AppColors.inkStrong,
  ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  static final _dropdownHintStyle = AppFonts.bodyMedium(
    color: AppColors.textFieldHint,
  ).copyWith(fontSize: 15, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _issueDateValue = now;
    _dueDateValue = now;
    _issueDate.text = _isoDate.format(_issueDateValue!);
    _dueDate.text = _isoDate.format(_dueDateValue!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    for (final c in [
      _billLine1,
      _billLine2,
      _billCity,
      _billZip,
      _billCountry,
      _billState,
      _shipLine1,
      _shipLine2,
      _shipCity,
      _shipZip,
      _shipCountry,
      _shipState,
      _purchaseOrderId,
      _projectName,
      _issueDate,
      _dueDate,
      _clientNotes,
      _internalNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _jobAmount(JobRead job) {
    final total = job.total;
    if (total != null && total > 0) return total;
    final price = job.sellingPrice;
    if (price != null && price > 0) return price;
    return 0;
  }

  double get _subtotal => _jobLines.fold<double>(
        0,
        (sum, line) => line.job == null ? sum : sum + _jobAmount(line.job!),
      );

  double get _total => _subtotal + _adjustment;

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      final clientsApi = ref.read(clientsApiClientProvider);
      final contactsApi = ref.read(contactsApiClientProvider);
      final projectApi = ref.read(quoteProjectApiClientProvider);
      final results = await Future.wait<dynamic>([
        clientsApi.fetchClientsPage(page: 1, pageSize: 100),
        contactsApi.fetchContactsPage(page: 1, pageSize: 100),
        projectApi.fetchProjects(),
      ]);
      if (!mounted) return;
      final users = (results[0] as ClientsPageResult).items;
      final contacts = (results[1] as ContactsPageResult).items;
      final projects = results[2] as List<ProjectOption>;
      setState(() {
        _users = users;
        _contacts = contacts;
        _loadingOptions = false;
        if (_user == null && users.isNotEmpty) _user = users.first;
        if (_contact == null && contacts.isNotEmpty) {
          _contact = contacts.first;
        }
        if (_project == null && projects.isNotEmpty) {
          _project = projects.first;
          _projectName.text = projects.first.name;
        }
      });
      unawaited(_loadJobs());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not load form options',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _loadingJobs = true);
    try {
      final jobs =
          await ref.read(quoteProjectApiClientProvider).fetchJobs(pageSize: 100);
      if (!mounted) return;
      setState(() {
        _jobsCatalog = jobs;
        _loadingJobs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobsCatalog = const [];
        _loadingJobs = false;
      });
    }
  }

  Future<void> _pickDate({required bool isIssueDate}) async {
    final initial = isIssueDate
        ? (_issueDateValue ?? DateTime.now())
        : (_dueDateValue ?? DateTime.now());
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: initial,
      helpText: isIssueDate ? 'Issue date' : 'Due date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final text = _isoDate.format(picked);
      if (isIssueDate) {
        _issueDateValue = picked;
        _issueDate.text = text;
      } else {
        _dueDateValue = picked;
        _dueDate.text = text;
      }
    });
  }

  void _addJobLine() {
    setState(() => _jobLines.add(_BillJobDraft()));
  }

  void _removeJobLine(int index) {
    if (_jobLines.length <= 1) return;
    setState(() => _jobLines.removeAt(index));
  }

  void _onJobSelected(int index, JobRead? job) {
    setState(() => _jobLines[index].job = job);
  }

  void _changeAdjustment(double delta) {
    setState(() => _adjustment += delta);
  }

  Future<void> _save({required bool send}) async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_user == null) {
      context.showAppTopToast(
        title: 'Select a user',
        type: AppTopToastType.warning,
      );
      return;
    }

    final hasLine = _jobLines.any((line) => line.job != null);
    if (!hasLine) {
      context.showAppTopToast(
        title: 'Add at least one job',
        type: AppTopToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _submitting = false);

    context.showAppTopToast(
      title: send ? 'Bill order sent' : 'Bill order saved',
      subtitle: _purchaseOrderId.text.trim().isNotEmpty
          ? _purchaseOrderId.text.trim()
          : null,
      type: AppTopToastType.success,
    );
    context.pop(true);
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(title),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.inkStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: _labelGrey).copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppTextField(
        controller: controller,
        hintText: hint,
        borderRadius: 8,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 4 : null,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: maxLines > 1 ? 12 : 14,
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String hint,
    String? Function(T?)? validator,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        value: items.any((i) => i.value == value) ? value : null,
        items: items,
        onChanged: (_loadingOptions || !enabled) ? null : onChanged,
        validator: validator,
        isExpanded: true,
        style: _dropdownValueStyle,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
        decoration: InputDecoration(
          hintText: _loadingOptions ? 'Loading...' : hint,
          hintStyle: _dropdownHintStyle,
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.textFieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.textFieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.inkStrong,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: onTap,
            child: AbsorbPointer(
              child: AppTextField(
                controller: controller,
                hintText: 'yyyy-mm-dd',
                readOnly: true,
                borderRadius: 8,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

  Widget _addressBlock({
    required TextEditingController line1,
    required TextEditingController line2,
    required TextEditingController city,
    required TextEditingController zip,
    required TextEditingController country,
    required TextEditingController state,
  }) {
    return AppAddressFields(
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: zip,
      countryController: country,
      layout: AppAddressLayout.billing,
      borderRadius: 8,
      postalCodeHint: 'Zip',
      line2Hint: 'Address line 2',
      labelBuilder: (text, {required = false}) => _fieldLabel(text),
      onPlaceSelected: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  String _jobHint() {
    if (_loadingJobs) return 'Loading jobs...';
    if (_jobsCatalog.isEmpty) return 'No jobs available';
    return 'Select job';
  }

  String _projectLabelForJob(JobRead job) {
    final fromField = _projectName.text.trim();
    if (fromField.isNotEmpty) return fromField;
    return _project?.name.trim().isNotEmpty == true
        ? _project!.name
        : 'Project NAME';
  }

  Widget _jobLineEditor(int index, _BillJobDraft line) {
    final job = line.job;
    final canPick = !_loadingJobs && _jobsCatalog.isNotEmpty;

    if (job == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Job'),
            _dropdownField<JobRead>(
              value: line.job,
              hint: _jobHint(),
              enabled: canPick,
              items: _jobsCatalog
                  .map(
                    (j) => DropdownMenuItem<JobRead>(
                      value: j,
                      child: Text(
                        j.title.trim().isEmpty ? j.displayId : j.title,
                        style: _dropdownValueStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _onJobSelected(index, v),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title.trim().isEmpty ? job.displayId : job.title,
                  style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _projectLabelForJob(job),
                  style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currency.format(_jobAmount(job)),
            style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (_jobLines.length > 1)
            IconButton(
              onPressed: () => _removeJobLine(index),
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFDC2626),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adjustmentRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Adjustment',
              style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          _stepButton(Icons.remove, () => _changeAdjustment(-1)),
          Container(
            width: 88,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.textFieldBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _currency.format(_adjustment),
              style: _dropdownValueStyle.copyWith(fontSize: 14),
            ),
          ),
          _stepButton(Icons.add, () => _changeAdjustment(1)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.textFieldBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.inkStrong),
        ),
      ),
    );
  }

  Widget _footerActions(double bottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : () => _save(send: true),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.inkStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _submitting ? null : () => _save(send: false),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Bill'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _contactLabel(ContactModel c) {
    final name = c.contactName.trim();
    return name.isEmpty ? 'Contact' : name;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

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
          'New Bill Order',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: _footerActions(bottom),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _sectionCard(
              title: 'Basic Information',
              children: [
                _fieldLabel('User Name'),
                _dropdownField<ClientModel>(
                  value: _user,
                  hint: 'Select user',
                  items: _users
                      .map(
                        (u) => DropdownMenuItem<ClientModel>(
                          value: u,
                          child: Text(
                            u.name.trim().isEmpty ? 'User' : u.name,
                            style: _dropdownValueStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _user = v),
                  validator: (v) => v == null ? 'User is required' : null,
                ),
                _fieldLabel('Contact Person'),
                _dropdownField<ContactModel>(
                  value: _contact,
                  hint: 'Select contact',
                  items: _contacts
                      .map(
                        (c) => DropdownMenuItem<ContactModel>(
                          value: c,
                          child: Text(
                            _contactLabel(c),
                            style: _dropdownValueStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _contact = c),
                ),
              ],
            ),
            _sectionCard(
              title: 'Bill To',
              children: [
                _addressBlock(
                  line1: _billLine1,
                  line2: _billLine2,
                  city: _billCity,
                  zip: _billZip,
                  country: _billCountry,
                  state: _billState,
                ),
              ],
            ),
            _sectionCard(
              title: 'Ship To',
              children: [
                _addressBlock(
                  line1: _shipLine1,
                  line2: _shipLine2,
                  city: _shipCity,
                  zip: _shipZip,
                  country: _shipCountry,
                  state: _shipState,
                ),
              ],
            ),
            _sectionCard(
              title: 'Additional Information',
              children: [
                _halfRow(
                  left: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Purchase Order ID'),
                      _textField(_purchaseOrderId, hint: 'NW-2024-021'),
                    ],
                  ),
                  right: _dateField(
                    controller: _issueDate,
                    label: 'Issue Date',
                    onTap: () => _pickDate(isIssueDate: true),
                  ),
                ),
                _halfRow(
                  left: _dateField(
                    controller: _dueDate,
                    label: 'Due Date',
                    onTap: () => _pickDate(isIssueDate: false),
                  ),
                  right: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Payment Terms'),
                      _dropdownField<String>(
                        value: _paymentTerms,
                        hint: 'Payment terms',
                        items: _paymentTermOptions
                            .map(
                              (t) => DropdownMenuItem<String>(
                                value: t,
                                child: Text(t, style: _dropdownValueStyle),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentTerms = v);
                        },
                      ),
                    ],
                  ),
                ),
                _fieldLabel('Project Name'),
                _textField(
                  _projectName,
                  hint: 'Project name',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            _sectionCard(
              title: 'Jobs',
              children: [
                for (var i = 0; i < _jobLines.length; i++)
                  _jobLineEditor(i, _jobLines[i]),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _addJobLine,
                    icon: const Icon(Icons.add, size: 18, color: _addItemBlue),
                    label: Text(
                      'Add Item',
                      style: AppFonts.bodyMedium(color: _addItemBlue).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 24, color: Color(0xFFE5E7EB)),
                _summaryRow('Sub Total', _currency.format(_subtotal)),
                _adjustmentRow(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _totalBoxBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Total',
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        _currency.format(_total),
                        style: AppFonts.titleLarge(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _sectionCard(
              title: 'Notes & Terms',
              children: [
                _fieldLabel('Client Notes'),
                _textField(
                  _clientNotes,
                  hint: 'Notes visible to client',
                  maxLines: 4,
                ),
                _fieldLabel('Internal Notes (Private)'),
                _textField(
                  _internalNotes,
                  hint: 'Internal notes',
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
