import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class _PurchaseLineDraft {
  _PurchaseLineDraft();

  CompositeItemOption? product;
  final qtyController = TextEditingController(text: '1');
  final unitPriceController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    unitPriceController.dispose();
  }
}

/// Create purchase order form (UI until PO API is available).
class AddPurchaseOrderPage extends ConsumerStatefulWidget {
  const AddPurchaseOrderPage({super.key});

  static const pathPrefix = '/purchase-orders';
  static const name = 'add-purchase-order';
  static String get path => '$pathPrefix/add';

  @override
  ConsumerState<AddPurchaseOrderPage> createState() =>
      _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends ConsumerState<AddPurchaseOrderPage> {
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

  final _poId = TextEditingController(text: 'PUR-2024-006');
  final _categoryName = TextEditingController(text: 'Raw Material');
  final _projectName = TextEditingController();
  final _issueDate = TextEditingController();
  final _dueDate = TextEditingController();
  final _clientNotes = TextEditingController(
    text:
        'Payment is due within 30 days of purchase order date. Late payments may incur additional charges.',
  );
  final _internalNotes = TextEditingController(
    text: 'Add internal notes for office use only.',
  );

  DateTime? _issueDateValue;
  DateTime? _dueDateValue;
  double _adjustment = 0;

  ClientModel? _vendor;
  ContactModel? _contact;
  ProjectOption? _project;
  String _paymentTerms = 'Net 30 Days';

  List<ClientModel> _vendors = const [];
  List<ContactModel> _contacts = const [];
  List<ProjectOption> _projects = const [];
  List<GroupItemOption> _groups = const [];
  GroupItemOption? _selectedGroup;
  List<CompositeItemOption> _compositeCatalog = const [];
  final List<_PurchaseLineDraft> _lineItems = [_PurchaseLineDraft()];
  bool _loadingOptions = false;
  bool _loadingCompositeItems = false;
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
    _dueDateValue = now.add(const Duration(days: 30));
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
      _poId,
      _categoryName,
      _projectName,
      _issueDate,
      _dueDate,
      _clientNotes,
      _internalNotes,
    ]) {
      c.dispose();
    }
    for (final line in _lineItems) {
      line.dispose();
    }
    super.dispose();
  }

  double _parseAmount(String raw) => double.tryParse(raw.trim()) ?? 0;

  double _lineTotal(_PurchaseLineDraft line) {
    if (line.product == null) return 0;
    return _parseAmount(line.qtyController.text) *
        _parseAmount(line.unitPriceController.text);
  }

  double get _subtotal =>
      _lineItems.fold<double>(0, (sum, line) => sum + _lineTotal(line));

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
        projectApi.fetchGroups(),
      ]);
      if (!mounted) return;
      final vendors = (results[0] as ClientsPageResult).items;
      final contacts = (results[1] as ContactsPageResult).items;
      final projects = results[2] as List<ProjectOption>;
      final groups = results[3] as List<GroupItemOption>;
      setState(() {
        _vendors = vendors;
        _contacts = contacts;
        _projects = projects;
        _groups = groups;
        _loadingOptions = false;
        if (_vendor == null && vendors.isNotEmpty) _vendor = vendors.first;
        if (_contact == null && contacts.isNotEmpty) {
          _contact = contacts.first;
        }
        if (_project == null && projects.isNotEmpty) {
          _project = projects.first;
          _projectName.text = projects.first.name;
        }
        if (_selectedGroup == null && groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
      });
      if (_selectedGroup != null) {
        unawaited(_loadCompositeItemsForGroup(_selectedGroup!.id));
      }
      if (_project != null) {
        unawaited(_loadCompositeCatalogForProject(_project!.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not load vendors or contacts',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadCompositeCatalogForProject(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return;
    try {
      final catalog = await ref
          .read(quoteProjectApiClientProvider)
          .fetchGroupCompositeCatalog(projectId: id);
      if (!mounted || _project?.id != id) return;
      setState(() {
        _groups = catalog.groups;
        if (catalog.groups.isNotEmpty) {
          final keepGroup = _selectedGroup != null &&
              catalog.groups.any((g) => g.id == _selectedGroup!.id);
          _selectedGroup =
              keepGroup ? _selectedGroup : catalog.groups.first;
        }
        if (catalog.items.isNotEmpty) {
          _compositeCatalog = catalog.items;
        }
      });
      if (_compositeCatalog.isEmpty && _selectedGroup != null) {
        unawaited(_loadCompositeItemsForGroup(_selectedGroup!.id));
      }
    } catch (_) {
      if (_selectedGroup != null) {
        unawaited(_loadCompositeItemsForGroup(_selectedGroup!.id));
      }
    }
  }

  Future<void> _loadCompositeItemsForGroup(int groupId) async {
    setState(() => _loadingCompositeItems = true);
    try {
      final items = await ref
          .read(quoteProjectApiClientProvider)
          .fetchCompositeItems(groupId: groupId);
      if (!mounted) return;
      setState(() {
        _compositeCatalog = items;
        _loadingCompositeItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _compositeCatalog = const [];
        _loadingCompositeItems = false;
      });
    }
  }

  void _onGroupSelected(GroupItemOption? group) {
    setState(() {
      _selectedGroup = group;
      _compositeCatalog = const [];
      for (final line in _lineItems) {
        line.product = null;
        line.unitPriceController.clear();
      }
    });
    if (group != null) {
      unawaited(_loadCompositeItemsForGroup(group.id));
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

  void _addLineItem() {
    setState(() => _lineItems.add(_PurchaseLineDraft()));
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  void _onProductSelected(int index, CompositeItemOption? product) {
    setState(() {
      _lineItems[index].product = product;
      if (product != null &&
          _lineItems[index].unitPriceController.text.trim().isEmpty) {
        _lineItems[index].unitPriceController.text = '0';
      }
    });
  }

  void _changeAdjustment(double delta) {
    setState(() => _adjustment += delta);
  }

  String _qtyLabel(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }

  Future<void> _save({required bool send}) async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_vendor == null) {
      context.showAppTopToast(
        title: 'Select a vendor',
        type: AppTopToastType.warning,
      );
      return;
    }

    final hasLine = _lineItems.any((line) {
      if (line.product == null) return false;
      final qty = _parseAmount(line.qtyController.text);
      return qty > 0;
    });
    if (!hasLine) {
      context.showAppTopToast(
        title: 'Add at least one line item',
        type: AppTopToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _submitting = false);

    context.showAppTopToast(
      title: send ? 'Purchase order sent' : 'Purchase order saved',
      subtitle: _poId.text.trim().isNotEmpty ? _poId.text.trim() : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Address Line 1'),
        _textField(line1, hint: 'Address line 1'),
        _fieldLabel('Address Line 2'),
        _textField(line2, hint: 'Address line 2'),
        _halfRow(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('City'),
              _textField(city, hint: 'City'),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Zip Code'),
              _textField(zip, hint: 'Zip'),
            ],
          ),
        ),
        _halfRow(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Country'),
              _textField(country, hint: 'Country'),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('State'),
              _textField(state, hint: 'State'),
            ],
          ),
        ),
      ],
    );
  }

  String _compositeItemHint() {
    if (_loadingCompositeItems) return 'Loading composite items...';
    if (_selectedGroup == null) return 'Select a group first';
    if (_compositeCatalog.isEmpty) {
      return 'No composite items in this group';
    }
    return 'Select composite item';
  }

  Widget _lineItemEditor(int index, _PurchaseLineDraft line) {
    final product = line.product;
    final canPickItem =
        _selectedGroup != null &&
        !_loadingCompositeItems &&
        _compositeCatalog.isNotEmpty;

    if (product == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Composite Item'),
            _dropdownField<CompositeItemOption>(
              value: line.product,
              hint: _compositeItemHint(),
              enabled: canPickItem,
              items: _compositeCatalog
                  .map(
                    (p) => DropdownMenuItem<CompositeItemOption>(
                      value: p,
                      child: Text(
                        p.abbreviation.trim().isEmpty
                            ? p.name
                            : '${p.name} (${p.abbreviation})',
                        style: _dropdownValueStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _onProductSelected(index, v),
            ),
          ],
        ),
      );
    }

    final qty = _parseAmount(line.qtyController.text);
    final unit = _parseAmount(line.unitPriceController.text);
    final total = _lineTotal(line);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppFonts.bodyLarge(color: AppColors.inkStrong)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_qtyLabel(qty)} Unit @ ${_currency.format(unit)}',
                      style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _currency.format(total),
                style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (_lineItems.length > 1)
                IconButton(
                  onPressed: () => _removeLineItem(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _halfRow(
            left: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Quantity'),
                _textField(
                  line.qtyController,
                  hint: '1',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            right: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Unit Price'),
                _textField(
                  line.unitPriceController,
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
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
              label: const Text('Save Purchase Order'),
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
          'New Purchase Order',
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
                _fieldLabel('Vendor Name'),
                _dropdownField<ClientModel>(
                  value: _vendor,
                  hint: 'Select vendor',
                  items: _vendors
                      .map(
                        (v) => DropdownMenuItem<ClientModel>(
                          value: v,
                          child: Text(
                            v.name.trim().isEmpty ? 'Vendor' : v.name,
                            style: _dropdownValueStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _vendor = v),
                  validator: (v) => v == null ? 'Vendor is required' : null,
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
                _fieldLabel('Purchase Order ID'),
                _textField(_poId, hint: 'PUR-2024-001'),
                _dateField(
                  controller: _issueDate,
                  label: 'Issue Date',
                  onTap: () => _pickDate(isIssueDate: true),
                ),
                _dateField(
                  controller: _dueDate,
                  label: 'Due Date',
                  onTap: () => _pickDate(isIssueDate: false),
                ),
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
                _fieldLabel('Project Name'),
                _dropdownField<ProjectOption>(
                  value: _project,
                  hint: 'Select project',
                  items: _projects
                      .map(
                        (p) => DropdownMenuItem<ProjectOption>(
                          value: p,
                          child: Text(p.name, style: _dropdownValueStyle),
                        ),
                      )
                      .toList(),
                  onChanged: (p) {
                    setState(() {
                      _project = p;
                      _projectName.text = p?.name ?? '';
                    });
                    if (p != null) {
                      unawaited(_loadCompositeCatalogForProject(p.id));
                    }
                  },
                ),
                _fieldLabel('Category Name'),
                _textField(_categoryName, hint: 'Raw Material'),
              ],
            ),
            _sectionCard(
              title: 'Line Items',
              children: [
                _fieldLabel('Group'),
                _dropdownField<GroupItemOption>(
                  value: _selectedGroup,
                  hint: _groups.isEmpty
                      ? 'No groups available'
                      : 'Select group',
                  enabled: _groups.isNotEmpty,
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem<GroupItemOption>(
                          value: g,
                          child: Text(g.name, style: _dropdownValueStyle),
                        ),
                      )
                      .toList(),
                  onChanged: _onGroupSelected,
                  validator: (v) => v == null ? 'Group is required' : null,
                ),
                for (var i = 0; i < _lineItems.length; i++)
                  _lineItemEditor(i, _lineItems[i]),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _addLineItem,
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
                  hint: 'Notes visible to vendor',
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
