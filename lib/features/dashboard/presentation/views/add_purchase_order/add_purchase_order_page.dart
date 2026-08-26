part of 'add_purchase_order.dart';

/// Create or edit purchase order form.
class AddPurchaseOrderPage extends ConsumerStatefulWidget {
  const AddPurchaseOrderPage({
    super.key,
    this.editPurchaseOrderId,
    this.existing,
  });

  /// When set, submits `PATCH /purchase-orders/{id}`.
  final String? editPurchaseOrderId;

  /// Optional prefill from detail (skips fetch when [editPurchaseOrderId] is set).
  final PurchaseOrderDetail? existing;

  static const pathPrefix = '/purchase-orders';
  static const name = 'add-purchase-order';
  static const editName = 'edit-purchase-order';
  static String get path => '$pathPrefix/add';

  static String pathForEdit(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}/edit';

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

  final _billLine1 = TextEditingController();
  final _billLine2 = TextEditingController();
  final _billCity = TextEditingController();
  final _billZip = TextEditingController();
  final _billCountry = TextEditingController();
  final _billState = TextEditingController();

  final _shipLine1 = TextEditingController();
  final _shipLine2 = TextEditingController();
  final _shipCity = TextEditingController();
  final _shipZip = TextEditingController();
  final _shipCountry = TextEditingController();
  final _shipState = TextEditingController();

  final _categoryName = TextEditingController();
  final _issueDate = TextEditingController();
  final _dueDate = TextEditingController();
  final _clientNotes = TextEditingController();
  final _internalNotes = TextEditingController();

  DateTime? _issueDateValue;
  DateTime? _dueDateValue;
  double _adjustment = 0;

  VendorModel? _vendor;
  ContactModel? _contact;
  ProjectOption? _project;
  String? _paymentTerms;

  List<VendorModel> _vendors = const [];
  List<ContactModel> _contacts = const [];
  List<ProjectOption> _projects = const [];
  List<GroupItemOption> _groups = const [];
  GroupItemOption? _selectedGroup;
  List<CompositeItemOption> _compositeCatalog = const [];
  final List<_PurchaseLineDraft> _lineItems = [_PurchaseLineDraft()];
  bool _loadingOptions = false;
  bool _loadingCompositeItems = false;
  bool _loadingEdit = false;
  bool _applyingEdit = false;
  String? _loadEditError;
  PurchaseOrderDetail? _resolvedEdit;
  bool _submitting = false;

  bool get _isEditMode {
    final ex = widget.existing;
    if (ex != null && ex.id.trim().isNotEmpty) return true;
    final eid = widget.editPurchaseOrderId?.trim();
    return eid != null && eid.isNotEmpty;
  }

  String? get _editTargetId {
    final ex = widget.existing;
    if (ex != null && ex.id.trim().isNotEmpty) return ex.id.trim();
    final resolved = _resolvedEdit;
    if (resolved != null && resolved.id.trim().isNotEmpty) {
      return resolved.id.trim();
    }
    final eid = widget.editPurchaseOrderId?.trim();
    return eid != null && eid.isNotEmpty ? eid : null;
  }

  List<String> get _paymentTermChoices {
    final current = _paymentTerms?.trim();
    if (current != null &&
        current.isNotEmpty &&
        !_paymentTermOptions.contains(current)) {
      return [current, ..._paymentTermOptions];
    }
    return _paymentTermOptions;
  }

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
    final hasPrefill = widget.existing != null;
    final hasEditId = (widget.editPurchaseOrderId ?? '').trim().isNotEmpty;
    if (_isEditMode) {
      _loadingEdit = true;
    } else if (!hasPrefill && !hasEditId) {
      _resetForm();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadOptions();
    if (!mounted) return;

    final editId = _editTargetId ?? widget.editPurchaseOrderId?.trim();
    if (editId != null && editId.isNotEmpty) {
      await _loadForEdit(editId);
      return;
    }

    final existing = widget.existing;
    if (existing != null) {
      await _applyFromDetail(existing);
    }
  }

  Future<void> _loadForEdit(String id) async {
    setState(() {
      _loadingEdit = true;
      _loadEditError = null;
    });
    try {
      final detail = await ref
          .read(purchaseOrdersApiClientProvider)
          .fetchPurchaseOrderDetail(id);
      if (!mounted) return;
      setState(() {
        _resolvedEdit = detail;
        _loadingEdit = false;
        _applyingEdit = true;
      });
      await _applyFromDetail(detail);
      if (!mounted) return;
      setState(() => _applyingEdit = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEdit = false;
        _applyingEdit = false;
        _loadEditError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load purchase order',
        );
      });
    }
  }

  Future<void> _applyFromDetail(PurchaseOrderDetail detail) async {
    _categoryName.text =
        detail.categoryName == 'â€”' ? '' : detail.categoryName;
    _clientNotes.text = detail.notes;
    _internalNotes.text = detail.internalNotes;
    _adjustment = detail.adjustment;

    _applyAddressToControllers(
      detail.billingAddress,
      line1: _billLine1,
      line2: _billLine2,
      city: _billCity,
      zip: _billZip,
      country: _billCountry,
      state: _billState,
    );
    _applyAddressToControllers(
      detail.shippingAddress,
      line1: _shipLine1,
      line2: _shipLine2,
      city: _shipCity,
      zip: _shipZip,
      country: _shipCountry,
      state: _shipState,
    );

    if (detail.issueDate != null) {
      _issueDateValue = detail.issueDate;
      _issueDate.text = _isoDate.format(detail.issueDate!);
    }
    if (detail.dueDate != null) {
      _dueDateValue = detail.dueDate;
      _dueDate.text = _isoDate.format(detail.dueDate!);
    }

    final terms = detail.paymentTerms.trim();
    if (terms.isNotEmpty && terms != 'â€”') {
      _paymentTerms = invoicePaymentTermsFromApi(terms);
    }

    _vendor = _matchVendor(detail);
    _contact = _matchContact(detail);
    _project = _matchProject(detail);
    _ensureVendorInList();
    _ensureContactInList();
    _ensureProjectInList();

    if (_project != null) {
      await _loadCompositeCatalogForProject(_project!.id);
      if (!mounted) return;
      _ensureProjectInList();
    }

    int? groupId;
    for (final item in detail.lineItems) {
      if (item.groupId != null) {
        groupId = item.groupId;
        break;
      }
    }
    if (groupId != null) {
      GroupItemOption? matched;
      for (final group in _groups) {
        if (group.id == groupId) {
          matched = group;
          break;
        }
      }
      matched ??= GroupItemOption(id: groupId, name: 'Group $groupId');
      _selectedGroup = matched;
      _ensureGroupInList();
      await _loadCompositeItemsForGroup(groupId);
    }

    _applyLineItemsFromDetail(detail);
    if (detail.vendorId != null) {
      await _loadContactsForVendor(detail.vendorId);
    }
    if (mounted) setState(() {});
  }

  void _ensureVendorInList() {
    final vendor = _vendor;
    if (vendor == null) return;
    final index = _vendors.indexWhere((v) => v.id == vendor.id);
    if (index >= 0) {
      _vendor = _vendors[index];
      return;
    }
    _vendors = [vendor, ..._vendors];
  }

  void _ensureContactInList() {
    final contact = _contact;
    if (contact == null) return;
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      _contact = _contacts[index];
      return;
    }
    _contacts = [contact, ..._contacts];
  }

  void _ensureProjectInList() {
    final project = _project;
    if (project == null) return;
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _project = _projects[index];
      return;
    }
    _projects = [project, ..._projects];
  }

  void _ensureGroupInList() {
    final group = _selectedGroup;
    if (group == null) return;
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index >= 0) {
      _selectedGroup = _groups[index];
      return;
    }
    _groups = [group, ..._groups];
  }

  void _applyAddressToControllers(
    PurchaseOrderAddress address, {
    required TextEditingController line1,
    required TextEditingController line2,
    required TextEditingController city,
    required TextEditingController zip,
    required TextEditingController country,
    required TextEditingController state,
  }) {
    final street = address.street.trim();
    if (street.isNotEmpty && street != 'â€”') {
      final parts = street.split(',').map((p) => p.trim()).toList();
      line1.text = parts.first;
      if (parts.length > 1) {
        line2.text = parts.sublist(1).join(', ');
      } else {
        line2.clear();
      }
    } else {
      line1.clear();
      line2.clear();
    }
    if (address.city.trim().isNotEmpty && address.city != 'â€”') {
      city.text = address.city;
    }
    if (address.postalCode.trim().isNotEmpty && address.postalCode != 'â€”') {
      zip.text = address.postalCode;
    }
    if (address.country.trim().isNotEmpty && address.country != 'â€”') {
      country.text = address.country;
    }
    if (address.state.trim().isNotEmpty && address.state != 'â€”') {
      state.text = address.state;
    }
  }

  VendorModel? _matchVendor(PurchaseOrderDetail detail) {
    final id = detail.vendorId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final vendor in _vendors) {
        if (vendor.id == id) return vendor;
      }
      return VendorModel(
        id: id,
        name: detail.vendorName == 'â€”' ? 'Vendor' : detail.vendorName,
        isActive: true,
      );
    }
    final name = detail.vendorName.trim().toLowerCase();
    if (name.isEmpty || name == 'â€”') return null;
    for (final vendor in _vendors) {
      if (vendor.name.trim().toLowerCase() == name) return vendor;
    }
    return null;
  }

  ContactModel? _matchContact(PurchaseOrderDetail detail) {
    final id = detail.contactId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final contact in _contacts) {
        if (contact.id == id) return contact;
      }
      final name = detail.contactPerson.trim();
      return ContactModel(
        id: id,
        contactName: name.isEmpty || name == 'â€”' ? 'Contact' : name,
        client: ContactClientRef.empty,
        email: '',
        phone: '',
        addressLine1: '',
        addressLine2: '',
        country: '',
        city: '',
        state: '',
        postalCode: '',
        isActive: true,
      );
    }
    final name = detail.contactPerson.trim().toLowerCase();
    if (name.isEmpty || name == 'â€”') return null;
    for (final contact in _contacts) {
      if (contact.contactName.trim().toLowerCase() == name) return contact;
    }
    return null;
  }

  ProjectOption? _matchProject(PurchaseOrderDetail detail) {
    final id = detail.projectId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final project in _projects) {
        if (project.id == id) return project;
      }
      final name = detail.projectName.trim();
      return ProjectOption(
        id: id,
        name: name.isEmpty || name == 'â€”' ? 'Project' : name,
      );
    }
    final name = detail.projectName.trim().toLowerCase();
    if (name.isEmpty || name == 'â€”') return null;
    for (final project in _projects) {
      if (project.name.trim().toLowerCase() == name) return project;
    }
    return null;
  }

  void _applyLineItemsFromDetail(PurchaseOrderDetail detail) {
    for (final line in _lineItems) {
      line.dispose();
    }
    _lineItems.clear();

    for (final item in detail.lineItems) {
      final draft = _PurchaseLineDraft();
      if (item.qty > 0) {
        draft.qtyController.text = _qtyLabel(item.qty);
      }
      if (item.listPrice > 0) {
        draft.unitPriceController.text = item.listPrice.toString();
      } else if (item.amount > 0 && item.qty > 0) {
        draft.unitPriceController.text = (item.amount / item.qty).toString();
      } else if (item.total > 0 && item.qty > 0) {
        draft.unitPriceController.text = (item.total / item.qty).toString();
      }

      final compositeId = item.compositeItemId;
      if (compositeId != null) {
        CompositeItemOption? product;
        for (final option in _compositeCatalog) {
          if (option.id == compositeId) {
            product = option;
            break;
          }
        }
        product ??= CompositeItemOption(
          id: compositeId,
          name: item.productName,
          groupId: item.groupId,
        );
        draft.product = product;
        if (!_compositeCatalog.any((option) => option.id == compositeId)) {
          _compositeCatalog = [..._compositeCatalog, product];
        } else {
          draft.product = _compositeCatalog.firstWhere(
            (option) => option.id == compositeId,
          );
        }
      }
      _lineItems.add(draft);
    }

    if (_lineItems.isEmpty) {
      _lineItems.add(_PurchaseLineDraft());
    }
  }

  void _resetForm() {
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
      _categoryName,
      _issueDate,
      _dueDate,
      _clientNotes,
      _internalNotes,
    ]) {
      c.clear();
    }
    _issueDateValue = null;
    _dueDateValue = null;
    _adjustment = 0;
    _vendor = null;
    _contact = null;
    _project = null;
    _paymentTerms = null;
    _selectedGroup = null;
    _groups = const [];
    _compositeCatalog = const [];
    _resolvedEdit = null;
    for (final line in _lineItems) {
      line.dispose();
    }
    _lineItems
      ..clear()
      ..add(_PurchaseLineDraft());
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
      _categoryName,
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

  double _lineTotal(_PurchaseLineDraft line) => line.lineTotal;

  double get _subtotal =>
      _lineItems.fold<double>(0, (sum, line) => sum + _lineTotal(line));

  double get _total => _subtotal + _adjustment;

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    final vendorsApi = ref.read(vendorsApiClientProvider);
    final projectApi = ref.read(quoteProjectApiClientProvider);

    List<VendorModel> vendors = const [];
    List<ProjectOption> projects = const [];
    List<GroupItemOption> groups = const [];
    Object? vendorsError;

    try {
      vendors = (await vendorsApi.fetchVendorsPage(
        page: 1,
        pageSize: 100,
        isActive: true,
      ))
          .items;
    } catch (e) {
      vendorsError = e;
    }

    try {
      projects = await projectApi.fetchProjects();
    } catch (_) {}

    try {
      groups = await projectApi.fetchGroups();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _vendors = vendors;
      _projects = projects;
      _groups = groups;
      _loadingOptions = false;
    });

    if (vendorsError != null && mounted) {
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              vendorsError,
              genericFallback: 'Could not load vendors',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadContactsForVendor(String? vendorId) async {
    final id = vendorId?.trim();
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _contacts = const []);
      return;
    }
    try {
      final contacts = await ref
          .read(contactsApiClientProvider)
          .fetchVendorContacts(vendorId: id);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _ensureContactInList();
        if (_contact != null &&
            !_contacts.any((c) => c.id == _contact!.id)) {
          _contact = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _contacts = const []);
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
        if (catalog.groups.isNotEmpty) {
          _groups = catalog.groups;
          if (_selectedGroup != null &&
              !catalog.groups.any((g) => g.id == _selectedGroup!.id)) {
            _selectedGroup = null;
          }
        }
        _compositeCatalog = const [];
      });
    } catch (_) {
      if (!mounted || _project?.id != id) return;
      setState(() {
        _selectedGroup = null;
        _compositeCatalog = const [];
      });
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
        line.applyProduct(null);
        line.qtyController.text = '1';
      }
    });
    if (group != null) {
      unawaited(_loadCompositeItemsForGroup(group.id));
    }
  }

  void _onVendorSelected(VendorModel? vendor) {
    setState(() {
      _vendor = vendor;
      _contact = null;
      _contacts = const [];
    });
    if (vendor != null) {
      _ensureVendorInList();
      unawaited(_loadContactsForVendor(vendor.id));
    }
  }

  Future<void> _pickVendor() async {
    final picked = await showVendorPickerSheet(
      context: context,
      selected: _vendor,
    );
    if (picked == null || !mounted) return;
    _onVendorSelected(picked);
  }

  InputDecoration _pickerDecoration({String? errorText}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.inkStrong, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      errorText: errorText,
    );
  }

  Widget _vendorPickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<VendorModel>(
        validator: (_) => _vendor == null ? 'Vendor is required' : null,
        builder: (field) {
          final vendor = _vendor;
          final hasValue = vendor != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _submitting ? null : _pickVendor,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: _pickerDecoration(errorText: field.errorText),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasValue
                              ? (vendor.name.trim().isEmpty
                                  ? 'Vendor'
                                  : vendor.name)
                              : 'Select vendor',
                          style: hasValue
                              ? _dropdownValueStyle
                              : _dropdownHintStyle,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onProjectSelected(ProjectOption? project) {
    setState(() {
      _project = project;
      _selectedGroup = null;
      _compositeCatalog = const [];
      for (final line in _lineItems) {
        line.applyProduct(null);
        line.qtyController.text = '1';
      }
    });
    if (project != null) {
      unawaited(_loadCompositeCatalogForProject(project.id));
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
    setState(() => _lineItems[index].applyProduct(product));
    if (product != null && product.sellingPrice == null) {
      unawaited(_resolveCompositeItemSellingPrice(index, product));
    }
  }

  Future<void> _resolveCompositeItemSellingPrice(
    int index,
    CompositeItemOption item,
  ) async {
    try {
      final detail = await ref
          .read(itemsApiClientProvider)
          .fetchItemDetail(item.id.toString());
      if (!mounted || _lineItems[index].product?.id != item.id) return;
      setState(() {
        _lineItems[index].unitPriceController.text =
            detail.sellPrice.toStringAsFixed(2);
      });
    } catch (_) {
      // Keep manual rate entry when detail lookup fails.
    }
  }

  GroupItemOption? _groupForProduct(CompositeItemOption? product) {
    if (_selectedGroup != null &&
        (product?.groupId == null || product!.groupId == _selectedGroup!.id)) {
      return _selectedGroup;
    }
    if (product?.groupId == null) return null;
    for (final g in _groups) {
      if (g.id == product!.groupId) return g;
    }
    return null;
  }

  void _changeAdjustment(double delta) {
    setState(() => _adjustment += delta);
  }

  String _qtyLabel(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }

  Map<String, dynamic> _buildPayload() {
    final vendorId = readApiInt(_vendor!.id)!;
    final projectId = readApiInt(_project!.id)!;
    final contactId = readApiInt(_contact!.id)!;
    final compositeItems = <InvoiceCompositeItemPayload>[];
    for (final line in _lineItems) {
      final product = line.product;
      if (product == null) continue;
      final qty = _parseAmount(line.qtyController.text);
      if (qty <= 0) continue;
      final amount = _lineTotal(line);
      final group = _groupForProduct(product);
      compositeItems.add(
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

    return <String, dynamic>{
      'vendor': vendorId,
      'contact': contactId,
      'project': projectId,
      'total': _subtotal,
      'due_date': _isoDate.format(_dueDateValue!),
      'payment_terms': invoicePaymentTermsToApi(_paymentTerms!),
      'bill_to': InvoiceAddressPayload(
        addressLine1: _billLine1.text,
        addressLine2: _billLine2.text,
        city: _billCity.text,
        state: _billState.text,
        pincode: _billZip.text,
        country: _billCountry.text,
      ).toJson(),
      'ship_to': InvoiceAddressPayload(
        addressLine1: _shipLine1.text,
        addressLine2: _shipLine2.text,
        city: _shipCity.text,
        state: _shipState.text,
        pincode: _shipZip.text,
        country: _shipCountry.text,
      ).toJson(),
      'composite_items':
          compositeItems.map((e) => e.toJson()).toList(growable: false),
      if (_clientNotes.text.trim().isNotEmpty)
        'vendor_notes': _clientNotes.text.trim(),
      if (_internalNotes.text.trim().isNotEmpty)
        'internal_notes': _internalNotes.text.trim(),
    };
  }

  Future<void> _save({required bool send}) async {
    if (_submitting || _loadingEdit) return;
    if (_isEditMode && _editTargetId == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_vendor == null) {
      context.showAppTopToast(
        title: 'Select a vendor',
        type: AppTopToastType.warning,
      );
      return;
    }

    if (_contact == null) {
      context.showAppTopToast(
        title: 'Select a contact',
        type: AppTopToastType.warning,
      );
      return;
    }

    if (_project == null) {
      context.showAppTopToast(
        title: 'Select a project',
        type: AppTopToastType.warning,
      );
      return;
    }

    if (_dueDateValue == null) {
      context.showAppTopToast(
        title: 'Select a due date',
        type: AppTopToastType.warning,
      );
      return;
    }

    if (_paymentTerms == null || _paymentTerms!.trim().isEmpty) {
      context.showAppTopToast(
        title: 'Select payment terms',
        type: AppTopToastType.warning,
      );
      return;
    }

    if (!_isEditMode && _selectedGroup == null) {
      context.showAppTopToast(
        title: 'Select a group',
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
    try {
      final api = ref.read(purchaseOrdersApiClientProvider);
      final payload = _buildPayload();
      final PurchaseOrderDetail result;
      if (_isEditMode) {
        result = await api.updatePurchaseOrder(_editTargetId!, payload);
      } else {
        result = await api.createPurchaseOrder(payload);
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      ref.read(purchaseOrderListRefreshTickProvider.notifier).state++;
      context.showAppTopToast(
        title: _isEditMode
            ? (send ? 'Purchase order sent' : 'Purchase order updated')
            : (send ? 'Purchase order sent' : 'Purchase order saved'),
        subtitle: result.purchaseOrderNumber,
        type: AppTopToastType.success,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: _isEditMode
                  ? 'Failed to update purchase order'
                  : 'Failed to save purchase order',
            ),
          ),
        ),
      );
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

  Widget _requiredFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text.toUpperCase(),
              style: AppFonts.labelSmall(color: _labelGrey).copyWith(
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: ' *',
              style: AppFonts.labelSmall(color: AppColors.error).copyWith(
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
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
    bool compact = false,
  }) {
    final resolvedValue = _resolveDropdownValue(items, value);
    final valueKey = switch (resolvedValue) {
      VendorModel v => v.id,
      ContactModel c => c.id,
      ProjectOption p => p.id,
      GroupItemOption g => '${g.id}',
      CompositeItemOption i => '${i.id}',
      _ => resolvedValue?.hashCode ?? 0,
    };
    return Padding(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        key: ValueKey('po-dropdown-$hint-$valueKey-${items.length}'),
        initialValue: resolvedValue,
        items: items,
        onChanged: (_loadingOptions || !enabled || items.isEmpty)
            ? null
            : onChanged,
        validator: validator,
        isExpanded: true,
        style: _dropdownValueStyle,
        dropdownColor: AppColors.white,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
        decoration: InputDecoration(
          hintText: _loadingOptions ? 'Loading...' : hint,
          hintStyle: _dropdownHintStyle,
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 12 : 14,
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

  T? _resolveDropdownValue<T>(List<DropdownMenuItem<T>> items, T? value) {
    if (value == null) return null;
    for (final item in items) {
      final candidate = item.value;
      if (candidate == null) continue;
      if (_dropdownValuesEqual(candidate, value)) return candidate;
    }
    return null;
  }

  bool _dropdownValuesEqual<T>(T a, T b) {
    if (identical(a, b)) return true;
    return switch ((a, b)) {
      (VendorModel left, VendorModel right) => left.id == right.id,
      (ContactModel left, ContactModel right) => left.id == right.id,
      (ProjectOption left, ProjectOption right) => left.id == right.id,
      (GroupItemOption left, GroupItemOption right) => left.id == right.id,
      (CompositeItemOption left, CompositeItemOption right) =>
        left.id == right.id,
      _ => a == b,
    };
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
    if (_loadingCompositeItems) return 'Loading...';
    if (_selectedGroup == null) return 'Select a group first';
    if (_compositeCatalog.isEmpty) {
      return 'No items in group';
    }
    return 'Select product...';
  }

  Widget _compactNumberField(
    TextEditingController controller, {
    required String hint,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      controller: controller,
      hintText: hint,
      borderRadius: 8,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    );
  }

  Widget _lineItemsTableHeader() {
    final showDelete = _lineItems.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(flex: 26, child: _fieldLabel('Groups')),
          const SizedBox(width: 8),
          Expanded(flex: 34, child: _requiredFieldLabel('Items')),
          const SizedBox(width: 8),
          SizedBox(width: 64, child: _fieldLabel('Qty')),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: _fieldLabel('Rate')),
          if (showDelete) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _inlineGroupDropdown({String? Function(GroupItemOption?)? validator}) {
    return _dropdownField<GroupItemOption>(
      value: _selectedGroup,
      hint: _loadingOptions
          ? 'Loading...'
          : _groups.isEmpty
          ? 'No groups'
          : 'Select group',
      enabled: !_loadingOptions && _groups.isNotEmpty,
      compact: true,
      items: _groups
          .map(
            (g) => DropdownMenuItem<GroupItemOption>(
              value: g,
              child: Text(g.name, style: _dropdownValueStyle),
            ),
          )
          .toList(),
      onChanged: _onGroupSelected,
      validator: validator,
    );
  }

  Widget _lineItemRow(int index, _PurchaseLineDraft line) {
    final canPickItem =
        _selectedGroup != null &&
        !_loadingCompositeItems &&
        _compositeCatalog.isNotEmpty;
    final showDelete = _lineItems.length > 1;

    return Padding(
      padding: EdgeInsets.only(bottom: index < _lineItems.length - 1 ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 26,
            child: index == 0
                ? _inlineGroupDropdown(
                    validator: (v) =>
                        !_isEditMode && v == null ? 'Required' : null,
                  )
                : _selectedGroup == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 14, left: 4, right: 4),
                    child: Text(
                      _selectedGroup!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 34,
            child: _dropdownField<CompositeItemOption>(
              value: line.product,
              hint: _compositeItemHint(),
              enabled: canPickItem,
              compact: true,
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
                  ? (v) => v == null ? 'Required' : null
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: _compactNumberField(
              line.qtyController,
              hint: '1',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: _compactNumberField(
              line.unitPriceController,
              hint: '0.00',
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (showDelete)
            SizedBox(
              width: 40,
              child: IconButton(
                onPressed: () => _removeLineItem(index),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
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
              _adjustment == 0 ? 'â€”' : _currency.format(_adjustment),
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
              label: Text(_isEditMode ? 'Update' : 'Save Purchase Order'),
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
    if (_loadingEdit || _applyingEdit) {
      return const Scaffold(
        backgroundColor: _pageBg,
        body: AppSkeletonScreenBody(
          style: AppSkeletonScreenBodyStyle.listRows,
        ),
      );
    }

    if (_loadEditError != null) {
      return Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: AppColors.inkStrong,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadEditError!,
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyMedium(color: _labelGrey),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final id = _editTargetId ?? widget.editPurchaseOrderId;
                    if (id != null && id.trim().isNotEmpty) {
                      _loadForEdit(id.trim());
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          _isEditMode ? 'Edit Purchase Order' : 'New Purchase Order',
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
                _vendorPickerField(),
                _fieldLabel('Contact Person'),
                _dropdownField<ContactModel>(
                  value: _contact,
                  hint: _vendor == null
                      ? 'Select a vendor first'
                      : _contacts.isEmpty
                      ? 'No contacts for this vendor'
                      : 'Select contact',
                  enabled: _vendor != null && _contacts.isNotEmpty,
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
                  hint: 'Select payment terms',
                  items: _paymentTermChoices
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(t, style: _dropdownValueStyle),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _paymentTerms = v),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
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
                  onChanged: _onProjectSelected,
                ),
                _fieldLabel('Category Name'),
                _textField(_categoryName, hint: 'Enter category'),
              ],
            ),
            _sectionCard(
              title: 'Line Items',
              children: [
                _lineItemsTableHeader(),
                for (var i = 0; i < _lineItems.length; i++)
                  _lineItemRow(i, _lineItems[i]),
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
                _summaryRow(
                  'Sub Total',
                  _subtotal == 0 ? 'â€”' : _currency.format(_subtotal),
                ),
                _adjustmentRow(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _totalBoxBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total amount',
                          style: AppFonts.bodyMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _currency.format(_total),
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _sectionCard(
              title: 'Notes & Terms',
              children: [
                _fieldLabel('Vendor Notes'),
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
