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
import 'package:red5/features/dashboard/data/invoice_models.dart';
import 'package:red5/features/dashboard/data/invoices_api_client.dart';
import 'package:red5/features/dashboard/presentation/invoice_list_refresh.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class _CompositeLineDraft {
  _CompositeLineDraft();

  CompositeItemOption? product;
  final qtyController = TextEditingController(text: '1');
  final amountController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    amountController.dispose();
  }
}

/// Create invoice — `POST /api/v1/invoice/`.
class AddInvoicePage extends ConsumerStatefulWidget {
  const AddInvoicePage({super.key});

  static const pathPrefix = '/invoices';
  static const name = 'add-invoice';
  static String get path => '$pathPrefix/add';

  @override
  ConsumerState<AddInvoicePage> createState() => _AddInvoicePageState();
}

class _AddInvoicePageState extends ConsumerState<AddInvoicePage> {
  static const _pageBg = Color(0xFFF7F7F8);
  static const _cardBg = AppColors.white;
  static const _labelGrey = Color(0xFF6B7280);
  static const _totalBoxBg = Color(0xFFE8F0FE);

  final _formKey = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(symbol: r'$');
  final _isoDate = DateFormat('yyyy-MM-dd');

  // Bill To
  final _billLine1 = TextEditingController(text: 'Acme Corporation');
  final _billLine2 = TextEditingController(text: 'Acme Corporation');
  final _billCity = TextEditingController();
  final _billZip = TextEditingController();
  final _billCountry = TextEditingController();
  final _billState = TextEditingController();

  // Ship To
  final _shipLine1 = TextEditingController(text: 'Acme Corporation');
  final _shipLine2 = TextEditingController(text: 'Acme Corporation');
  final _shipCity = TextEditingController();
  final _shipZip = TextEditingController();
  final _shipCountry = TextEditingController();
  final _shipState = TextEditingController();

  final _issueDate = TextEditingController();
  final _dueDate = TextEditingController();
  final _clientNotes = TextEditingController(
    text:
        'Payment is due within 30 days of invoice date. Late payments may incur additional charges.',
  );
  final _internalNotes = TextEditingController(
    text:
        'Payment is due within 30 days of invoice date. Late payments may incur additional charges.',
  );

  DateTime? _issueDateValue;
  DateTime? _dueDateValue;
  double _adjustment = 0;

  ClientModel? _client;
  ContactModel? _contact;
  ProjectOption? _project;
  String _paymentTerms = 'Net 30 Days';

  List<ClientModel> _clients = const [];
  List<ContactModel> _contacts = const [];
  List<ProjectOption> _projects = const [];
  List<GroupItemOption> _groups = const [];
  GroupItemOption? _selectedGroup;
  List<CompositeItemOption> _compositeCatalog = const [];
  final List<_CompositeLineDraft> _lineItems = [_CompositeLineDraft()];
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

  double get _subtotal => _lineItems.fold<double>(
        0,
        (sum, line) => sum + _parseAmount(line.amountController.text),
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
        projectApi.fetchGroups(),
      ]);
      if (!mounted) return;
      final clients = (results[0] as ClientsPageResult).items;
      final contacts = (results[1] as ContactsPageResult).items;
      final projects = results[2] as List<ProjectOption>;
      final groups = results[3] as List<GroupItemOption>;
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _contacts = contacts;
        _projects = projects;
        _groups = groups;
        _loadingOptions = false;
        if (_client == null && clients.isNotEmpty) _client = clients.first;
        if (_contact == null && contacts.isNotEmpty) {
          _contact = contacts.first;
        }
        if (_project == null && projects.isNotEmpty) {
          _project = projects.first;
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
              genericFallback: 'Could not load clients or contacts',
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
        line.amountController.clear();
      }
    });
    if (group != null) {
      unawaited(_loadCompositeItemsForGroup(group.id));
    }
  }

  Future<void> _pickDate({
    required bool isIssueDate,
  }) async {
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
    setState(() => _lineItems.add(_CompositeLineDraft()));
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
          _lineItems[index].amountController.text.trim().isEmpty) {
        _lineItems[index].amountController.text = '0';
      }
    });
  }

  GroupItemOption? _groupForProduct(CompositeItemOption? product) {
    if (product?.groupId == null) return null;
    for (final g in _groups) {
      if (g.id == product!.groupId) return g;
    }
    return null;
  }

  void _changeAdjustment(double delta) {
    setState(() => _adjustment += delta);
  }

  Future<void> _save({required bool send}) async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final clientId = int.tryParse(_client?.id.trim() ?? '');
    final contactId = int.tryParse(_contact?.id.trim() ?? '');
    final projectId = int.tryParse(_project?.id.trim() ?? '');
    if (clientId == null) {
      context.showAppTopToast(
        title: 'Select a client',
        type: AppTopToastType.warning,
      );
      return;
    }
    if (contactId == null) {
      context.showAppTopToast(
        title: 'Select a contact',
        type: AppTopToastType.warning,
      );
      return;
    }
    if (projectId == null) {
      context.showAppTopToast(
        title: 'Select a project',
        type: AppTopToastType.warning,
      );
      return;
    }
    if (_dueDateValue == null) {
      context.showAppTopToast(
        title: 'Due date is required',
        type: AppTopToastType.warning,
      );
      return;
    }

    final compositePayload = <InvoiceCompositeItemPayload>[];
    for (final line in _lineItems) {
      final product = line.product;
      if (product == null) continue;
      final qty = _parseAmount(line.qtyController.text);
      final amount = _parseAmount(line.amountController.text);
      if (qty <= 0) continue;
      final group = _groupForProduct(product);
      compositePayload.add(
        InvoiceCompositeItemPayload(
          id: product.id,
          name: product.name,
          quantity: qty,
          amount: amount,
          groupId: group?.id ?? product.groupId,
          groupName: group?.name,
        ),
      );
    }
    if (compositePayload.isEmpty) {
      context.showAppTopToast(
        title: 'Add at least one line item',
        type: AppTopToastType.warning,
      );
      return;
    }

    final payload = InvoiceCreatePayload(
      clientId: clientId,
      contactId: contactId,
      projectId: projectId,
      total: _subtotal,
      dueDate: _isoDate.format(_dueDateValue!),
      paymentTerms: invoicePaymentTermsToApi(_paymentTerms),
      billTo: InvoiceAddressPayload(
        addressLine1: _billLine1.text,
        addressLine2: _billLine2.text,
        city: _billCity.text,
        state: _billState.text,
        pincode: _billZip.text,
        country: _billCountry.text,
      ),
      shipTo: InvoiceAddressPayload(
        addressLine1: _shipLine1.text,
        addressLine2: _shipLine2.text,
        city: _shipCity.text,
        state: _shipState.text,
        pincode: _shipZip.text,
        country: _shipCountry.text,
      ),
      compositeItems: compositePayload,
      clientNotes: _clientNotes.text,
      internalNotes: _internalNotes.text,
    );

    setState(() => _submitting = true);
    try {
      final created =
          await ref.read(invoicesApiClientProvider).createInvoice(payload);
      if (!mounted) return;
      ref.read(invoiceListRefreshTickProvider.notifier).state++;
      context.showAppTopToast(
        title: send ? 'Invoice created' : 'Invoice saved',
        subtitle: created.invoiceNumber.isNotEmpty
            ? created.invoiceNumber
            : null,
        type: AppTopToastType.success,
      );
      context.pop(created.id);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to save invoice',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
        GestureDetector(
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

  String _compositeItemHint() {
    if (_loadingCompositeItems) return 'Loading composite items...';
    if (_selectedGroup == null) return 'Select a group first';
    if (_compositeCatalog.isEmpty) {
      return 'No composite items in this group';
    }
    return 'Select composite item';
  }

  Widget _compositeLineTile(int index, _CompositeLineDraft line) {
    final canPickItem =
        _selectedGroup != null &&
        !_loadingCompositeItems &&
        _compositeCatalog.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Line ${index + 1}',
                style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                      validator: index == 0 && _lineItems.length == 1
                          ? (v) => v == null ? 'Select a composite item' : null
                          : null,
                    ),
                  ],
                ),
              ),
              if (_lineItems.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: IconButton(
                    onPressed: () => _removeLineItem(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          _halfRow(
            left: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Quantity'),
                _textField(line.qtyController, hint: '1', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            right: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Amount'),
                _textField(line.amountController, hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
              label: const Text('Save Invoice'),
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
          'New Invoice',
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
                _fieldLabel('Client Name'),
                _dropdownField<ClientModel>(
                  value: _client,
                  hint: 'Select client',
                  items: _clients
                      .map(
                        (c) => DropdownMenuItem<ClientModel>(
                          value: c,
                          child: Text(
                            c.name.trim().isEmpty ? 'Client' : c.name,
                            style: _dropdownValueStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _client = c),
                  validator: (v) =>
                      v == null ? 'Client is required' : null,
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
                _fieldLabel('Project'),
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
                    setState(() => _project = p);
                    if (p != null) unawaited(_loadCompositeCatalogForProject(p.id));
                  },
                  validator: (v) => v == null ? 'Project is required' : null,
                ),
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
                  _compositeLineTile(i, _lineItems[i]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addLineItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add line item'),
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

  String _contactLabel(ContactModel c) {
    final name = c.contactName.trim();
    return name.isEmpty ? 'Contact' : name;
  }
}
