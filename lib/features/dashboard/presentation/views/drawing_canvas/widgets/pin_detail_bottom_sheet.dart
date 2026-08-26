part of '../drawing_canvas.dart';

class _PinDetailBottomSheet extends ConsumerStatefulWidget {
  const _PinDetailBottomSheet({
    required this.pinNumber,
    required this.pin,
    required this.pinStatuses,
    required this.onCreatePinStatus,
    required this.onEditPinStatus,
    required this.onDeletePinStatus,
    this.installationTypeId,
    this.projectId,
    this.levelId,
    this.levelLabel,
    this.groupLabel = '',
    this.productOptionLabel = '',
  });

  final int pinNumber;
  final _CanvasPin pin;
  final int? installationTypeId;
  final String? projectId;
  final List<PinStatusItem> pinStatuses;
  final Future<PinStatusItem?> Function() onCreatePinStatus;
  final Future<PinStatusItem?> Function(PinStatusItem) onEditPinStatus;
  final Future<bool> Function(PinStatusItem) onDeletePinStatus;
  final String? levelId;
  final String? levelLabel;
  final String groupLabel;
  final String productOptionLabel;

  @override
  ConsumerState<_PinDetailBottomSheet> createState() =>
      _PinDetailBottomSheetState();
}

class _PinDetailBottomSheetState extends ConsumerState<_PinDetailBottomSheet> {
  late final TextEditingController _productController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _qtyController;
  late final TextEditingController _blockController;
  late final TextEditingController _levelController;
  late final TextEditingController _zoneController;
  late String _status;
  late String _variation;
  bool _isEditing = false;
  late List<_PinAttachment> _attachments;
  int? _linkedFormId;
  String _linkedFormName = '';
  List<NamedIdOption> _formOptions = const [];
  List<FormSummary> _matchedProjectForms = const [];
  bool _isLoadingForms = false;
  int? _installationTypeId;
  late List<PinStatusItem> _pinStatusCatalog;

  static const List<String> _fallbackStatuses = <String>[
    'To Do',
    'In Progress',
    'Inactive',
    'Installed',
    'Action Required',
  ];
  static const List<String> _variationOptions = <String>['No', 'Yes'];
  late List<String> _statusOptions;

  void _rebuildStatusOptions() {
    _statusOptions = _pinStatusCatalog
        .where((e) => e.isActive)
        .map((e) => e.statusName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (_statusOptions.isEmpty) {
      _statusOptions = List<String>.from(_fallbackStatuses);
    }
  }

  @override
  void initState() {
    super.initState();
    _pinStatusCatalog = widget.pinStatuses
        .where((e) => e.isActive)
        .toList(growable: true);
    _productController = TextEditingController(text: widget.pin.productName);
    _descriptionController = TextEditingController(
      text: widget.pin.description,
    );
    _qtyController = TextEditingController(text: '${widget.pin.quantity}');
    _blockController = TextEditingController(text: widget.pin.blockName);
    _levelController = TextEditingController(text: widget.pin.levelName);
    _zoneController = TextEditingController(text: widget.pin.zoneName);
    _rebuildStatusOptions();
    _status = _statusOptions.contains(widget.pin.status)
        ? widget.pin.status
        : _statusOptions.first;
    _variation = _variationOptions.contains(widget.pin.variation)
        ? widget.pin.variation
        : _variationOptions.first;
    _attachments = List<_PinAttachment>.from(widget.pin.attachments);
    _linkedFormId = widget.pin.formId;
    _linkedFormName = widget.pin.formName.trim();
    _installationTypeId =
        widget.installationTypeId ?? widget.pin.installationTypeId;
    unawaited(_bootstrapForms());
  }

  Future<void> _bootstrapForms() async {
    await _resolveInstallationTypeId();
    await _loadProjectForms();
  }

  Future<void> _resolveInstallationTypeId() async {
    if (_installationTypeId != null) return;

    final pin = widget.pin;
    final itemId = pin.compositeItemId;
    if (itemId == null) return;

    final api = ref.read(quoteProjectApiClientProvider);
    final groupId = pin.groupId;
    if (groupId != null) {
      try {
        final items = await api.fetchCompositeItems(groupId: groupId);
        for (final item in items) {
          if (item.id == itemId && item.installationTypeId != null) {
            if (!mounted) return;
            setState(() => _installationTypeId = item.installationTypeId);
            return;
          }
        }
      } catch (_) {
        // Fall through to single-item lookup.
      }
    }

    try {
      final id = await api.fetchItemInstallationTypeId(itemId);
      if (!mounted || id == null) return;
      setState(() => _installationTypeId = id);
    } catch (_) {
      // Form filter stays empty when type cannot be resolved.
    }
  }

  int? get _effectiveInstallationTypeId =>
      _installationTypeId ?? widget.installationTypeId;

  Future<void> _loadProjectForms() async {
    final projectId = int.tryParse((widget.projectId ?? '').trim());
    if (projectId == null) {
      return;
    }
    setState(() {
      _isLoadingForms = true;
    });
    try {
      final rows = await ref
          .read(formsApiClientProvider)
          .fetchProjectForms(projectId: projectId);
      if (!mounted) return;
      final installationTypeId = _effectiveInstallationTypeId;
      final filtered = rows.matchingInstallationType(installationTypeId);
      setState(() {
        _applyFilteredFormOptions(filtered);
        _isLoadingForms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matchedProjectForms = const [];
        _formOptions = const [];
        _isLoadingForms = false;
      });
    }
  }

  FormSummary? _findProjectFormForId(int? formId) {
    if (formId == null) return null;
    for (final form in _matchedProjectForms) {
      if (form.id == formId || form.templateFormId == formId) {
        return form;
      }
    }
    return null;
  }

  void _linkProjectForm(FormSummary form) {
    _linkedFormId = form.id;
    _linkedFormName = form.name;
  }

  void _syncLinkedFormFromMatches() {
    final existingId = _linkedFormId ?? widget.pin.formId;
    final matched = _findProjectFormForId(existingId);
    if (matched != null) {
      _linkProjectForm(matched);
      return;
    }

    _linkedFormId = null;
    _linkedFormName = '';

    if (_matchedProjectForms.length == 1) {
      _linkProjectForm(_matchedProjectForms.first);
    }
  }

  void _applyFilteredFormOptions(List<FormSummary> filtered) {
    _matchedProjectForms = filtered;
    _formOptions = filtered.toActivePickerOptions();
    _syncLinkedFormFromMatches();
    _ensureLinkedFormOption();

    if (_linkedFormId != null &&
        !_formOptions.any((option) => option.id == _linkedFormId)) {
      _linkedFormId = null;
      _linkedFormName = '';
      _syncLinkedFormFromMatches();
      _ensureLinkedFormOption();
    }
  }

  void _ensureLinkedFormOption() {
    final linkedId = _linkedFormId;
    if (linkedId == null) return;
    if (_formOptions.any((option) => option.id == linkedId)) return;

    final matched = _findProjectFormForId(linkedId);
    if (matched == null) {
      _linkedFormId = null;
      _linkedFormName = '';
      return;
    }

    _formOptions = [
      ..._formOptions,
      matched.toPickerOption,
    ];
  }

  @override
  void didUpdateWidget(covariant _PinDetailBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinStatuses != oldWidget.pinStatuses) {
      _pinStatusCatalog = widget.pinStatuses
          .where((e) => e.isActive)
          .toList(growable: true);
      _rebuildStatusOptions();
      if (!_statusOptions.contains(_status)) {
        _status = _statusOptions.isNotEmpty
            ? _statusOptions.first
            : widget.pin.status;
      }
    }
    if (widget.installationTypeId != oldWidget.installationTypeId) {
      _installationTypeId =
          widget.installationTypeId ?? widget.pin.installationTypeId;
      unawaited(_bootstrapForms());
    }
  }

  @override
  void dispose() {
    scheduleDisposeTextControllers([
      _productController,
      _descriptionController,
      _qtyController,
      _blockController,
      _levelController,
      _zoneController,
    ]);
    super.dispose();
  }

  void _resetForm() {
    final pin = widget.pin;
    _productController.text = pin.productName;
    _descriptionController.text = pin.description;
    _qtyController.text = '${pin.quantity}';
    _blockController.text = pin.blockName;
    _levelController.text = pin.levelName;
    _zoneController.text = pin.zoneName;
    _status = _statusOptions.contains(pin.status)
        ? pin.status
        : _statusOptions.first;
    _variation = _variationOptions.contains(pin.variation)
        ? pin.variation
        : _variationOptions.first;
    _attachments = List<_PinAttachment>.from(pin.attachments);
    _linkedFormId = pin.formId;
    _linkedFormName = pin.formName.trim();
    _ensureLinkedFormOption();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'doc',
        'docx',
      ],
    );
    if (!mounted || result == null) return;
    setState(() {
      for (final file in result.files) {
        final name = file.name.trim();
        if (name.isEmpty) continue;
        final duplicate = _attachments.any(
          (attachment) =>
              attachment.name == name &&
              attachment.localPath == file.path?.trim(),
        );
        if (duplicate) continue;
        _attachments.add(
          _PinAttachment(
            name: name,
            localPath: file.path?.trim(),
          ),
        );
      }
    });
  }

  void _onFormSelected(int? formId) {
    setState(() {
      _linkedFormId = formId;
      if (formId == null) {
        _linkedFormName = '';
        return;
      }
      for (final option in _formOptions) {
        if (option.id == formId) {
          _linkedFormName = option.name;
          return;
        }
      }
      _linkedFormName = 'Form #$formId';
    });
  }

  Widget _formDropdownField() {
    if (_isLoadingForms) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_formOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          _effectiveInstallationTypeId == null
              ? 'Item installation type required to link a form'
              : 'No project form matches this installation type',
          style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_formOptions.length == 1) {
      final label = _resolvedFormLabel().isNotEmpty
          ? _resolvedFormLabel()
          : _formOptions.first.name;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedId = _formOptions.any((option) => option.id == _linkedFormId)
        ? _linkedFormId
        : null;

    return DropdownButtonFormField<int?>(
      isExpanded: true,
      value: selectedId,
      hint: const Text('Select form'),
      iconEnabledColor: AppColors.inkStrong,
      borderRadius: BorderRadius.circular(12),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('None'),
        ),
        ..._formOptions.map(
          (option) => DropdownMenuItem<int?>(
            value: option.id,
            child: Text(
              option.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _onFormSelected,
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.textFieldFocusBorder),
        ),
      ),
    );
  }

  int? _statusIdByNameLocal(String statusName) {
    final normalized = statusName.trim().toLowerCase();
    for (final s in _pinStatusCatalog) {
      if (s.statusName.trim().toLowerCase() == normalized) {
        return int.tryParse(s.id);
      }
    }
    return null;
  }

  PinStatusItem? _statusItemByNameLocal(String statusName) {
    final normalized = statusName.trim().toLowerCase();
    for (final s in _pinStatusCatalog) {
      if (s.statusName.trim().toLowerCase() == normalized) {
        return s;
      }
    }
    return null;
  }

  String _fmt(DateTime d) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} $h:$m:$s';
  }

  Widget _sheetGrabHandle() {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9DA),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  TextStyle get _sheetCapsLabelStyle => AppFonts.labelMedium(
    color: AppColors.muted,
  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 11);

  Widget _sheetFieldLabel(String text) {
    return Text(text.toUpperCase(), style: _sheetCapsLabelStyle);
  }

  /// Status label color on light UI (dropdown / field): prefer readable
  /// `text_colour`, else the status `bg_colour` so the name itself is colored.
  Color _statusLabelColor(PinStatusItem? item) {
    final accent =
        parseHexColor(item?.bgColour ?? '') ?? const Color(0xFF6B7280);
    final textColour = parseHexColor(item?.textColour ?? '');
    if (textColour != null && textColour.computeLuminance() < 0.55) {
      return textColour;
    }
    return accent;
  }

  void _closePinSheet<T>([T? result]) {
    if (!mounted) return;
    popOverlaySafely<T>(context, result);
  }

  Future<void> _handleCreateStatus() async {
    unfocusPrimary();
    final created = await widget.onCreatePinStatus();
    if (!mounted || created == null) return;
    setState(() {
      _pinStatusCatalog.add(created);
      _rebuildStatusOptions();
      _status = created.statusName;
    });
  }

  Future<void> _handleEditStatus() async {
    unfocusPrimary();
    final current = _statusItemByNameLocal(_status);
    if (current == null) return;
    final updated = await widget.onEditPinStatus(current);
    if (!mounted || updated == null) return;
    setState(() {
      final idx = _pinStatusCatalog.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _pinStatusCatalog[idx] = updated;
      } else if (updated.isActive) {
        _pinStatusCatalog.add(updated);
      }
      _rebuildStatusOptions();
      _status = updated.statusName;
    });
  }

  Future<void> _handleDeleteStatus() async {
    unfocusPrimary();
    final current = _statusItemByNameLocal(_status);
    if (current == null) return;
    final deleted = await widget.onDeletePinStatus(current);
    if (!mounted || !deleted) return;
    setState(() {
      _pinStatusCatalog.removeWhere((e) => e.id == current.id);
      _rebuildStatusOptions();
      _status = _statusOptions.isNotEmpty
          ? _statusOptions.first
          : _fallbackStatuses.first;
    });
  }

  /// Dropdown row: status name in its status color (not only a dot).
  Widget _statusMenuRow(String name) {
    final item = _statusItemByNameLocal(name);
    final labelColor = _statusLabelColor(item);
    return Text(
      name,
      style: AppFonts.bodyMedium(
        color: labelColor,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Closed field: colored status text on light tint.
  Widget _statusSelectedChip(String name) {
    final item = _statusItemByNameLocal(name);
    final labelColor = _statusLabelColor(item);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: AppFonts.bodyMedium(
          color: labelColor,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusDropdown() {
    if (_statusOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          'No statuses — tap Add status',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      );
    }

    final value = _statusOptions.contains(_status)
        ? _status
        : _statusOptions.first;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      dropdownColor: AppColors.white,
      iconEnabledColor: AppColors.inkStrong,
      iconDisabledColor: AppColors.muted,
      borderRadius: BorderRadius.circular(12),
      style: AppFonts.bodyMedium(
        color: _statusLabelColor(_statusItemByNameLocal(value)),
      ).copyWith(fontWeight: FontWeight.w700),
      items: _statusOptions
          .map(
            (name) => DropdownMenuItem<String>(
              value: name,
              child: _statusMenuRow(name),
            ),
          )
          .toList(growable: false),
      selectedItemBuilder: (context) => _statusOptions
          .map((name) => _statusSelectedChip(name))
          .toList(growable: false),
      onChanged: (v) {
        unfocusPrimary();
        setState(() => _status = v ?? _status);
      },
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.textFieldFocusBorder),
        ),
      ),
    );
  }

  Widget _statusManageRow() {
    final canEdit = _statusItemByNameLocal(_status) != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: _handleCreateStatus,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add status'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (canEdit) ...[
            TextButton.icon(
              onPressed: _handleEditStatus,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              onPressed: _handleDeleteStatus,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _sheetCard = AppColors.surfaceHigh;
  static const _sheetMuted = AppColors.muted;
  static const _sheetDivider = AppColors.borderLight;
  static const _sheetInk = AppColors.inkStrong;

  TextStyle get _sheetValueStyle => AppFonts.bodySmall(
        color: _sheetInk,
      ).copyWith(fontSize: 13, fontWeight: FontWeight.w600);

  TextStyle get _sheetLabelStyle => AppFonts.bodySmall(
        color: _sheetMuted,
      ).copyWith(fontSize: 13, fontWeight: FontWeight.w500);

  String _displayOrDash(String value) =>
      value.trim().isEmpty ? '—' : value.trim();

  String _levelDisplayLabel() {
    final id = (widget.levelId ?? '').trim();
    final label = (widget.levelLabel ?? '').trim();
    if (id.isNotEmpty) return '$id (1)';
    if (label.isNotEmpty) return label;
    final fromPin = widget.pin.levelName.trim();
    return fromPin.isEmpty ? '—' : fromPin;
  }

  String _coordPercent(_CanvasPin pin, {required bool x}) {
    final norm = x ? pin.contentNormX : pin.contentNormY;
    if (norm != null) return '${(norm * 100).toStringAsFixed(2)}%';
    final pt = pin.pdfPoint;
    if (pt != null) {
      final v = x ? pt.fractionX : pt.fractionY;
      return '${(v * 100).toStringAsFixed(2)}%';
    }
    return '—';
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: _sheetMuted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: _sheetLabelStyle)),
              const SizedBox(width: 12),
              Flexible(child: trailing),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _sheetDivider),
      ],
    );
  }

  Widget _detailTextValue(String value, {TextAlign align = TextAlign.right}) {
    return Text(
      _displayOrDash(value),
      textAlign: align,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: _sheetValueStyle,
    );
  }

  String _resolvedFormLabel() {
    if (_isLoadingForms) return '';
    if (_matchedProjectForms.isEmpty) return '';

    final linked = _linkedFormName.trim();
    if (linked.isNotEmpty) return linked;

    final linkedId = _linkedFormId;
    if (linkedId != null) {
      final matched = _findProjectFormForId(linkedId);
      if (matched != null) return matched.name;
    }

    if (_matchedProjectForms.length == 1) {
      return _matchedProjectForms.first.name;
    }

    return '';
  }

  Widget _formViewTrailing() {
    if (_isLoadingForms) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final label = _resolvedFormLabel();
    if (label.isNotEmpty) {
      return _detailTextValue(label);
    }

    return _detailTextValue('—');
  }

  Widget _descriptionTrailing(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _detailTextValue('—');
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          trimmed,
          textAlign: TextAlign.left,
          style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _attachmentsTrailing({required bool editing}) {
    if (_attachments.isEmpty && !editing) {
      return _detailTextValue('No attachments');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_attachments.isNotEmpty && !editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_attachments.length} file${_attachments.length == 1 ? '' : 's'} attached',
                style: AppFonts.labelSmall(color: const Color(0xFF0B6E99))
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (_attachments.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              for (var i = 0; i < _attachments.length; i++)
                InputChip(
                  label: Text(
                    _attachments[i].name,
                    style: AppFonts.labelSmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  deleteIcon: editing
                      ? const Icon(Icons.close_rounded, size: 16)
                      : null,
                  onDeleted: editing
                      ? () => setState(() => _attachments.removeAt(i))
                      : null,
                  backgroundColor: const Color(0xFFF3F3F4),
                  side: const BorderSide(color: Color(0xFFE3E3E5)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        if (editing) ...[
          if (_attachments.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('Add file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              side: const BorderSide(color: Color(0xFFD9D9DC)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _coordinatesCard(_CanvasPin pin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _sheetCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sheetDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'X COORDINATE',
                  style: _sheetCapsLabelStyle.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _coordPercent(pin, x: true),
                  style: AppFonts.titleSmall(color: _sheetInk).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Y COORDINATE',
                  style: _sheetCapsLabelStyle.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _coordPercent(pin, x: false),
                  style: AppFonts.titleSmall(color: _sheetInk).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewStatusBadge() {
    final item = _statusItemByNameLocal(_status);
    final labelColor = _statusLabelColor(item);
    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: labelColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timelapse, size: 14, color: labelColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.labelMedium(color: labelColor).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildViewModeChildren(_CanvasPin pin) {
    final productTitle = widget.productOptionLabel.trim().isNotEmpty
        ? widget.productOptionLabel.trim()
        : (_productController.text.trim().isNotEmpty
            ? _productController.text.trim()
            : (pin.productName.trim().isNotEmpty
                ? pin.productName.trim()
                : 'Pin ${widget.pinNumber}'));
    final groupTitle = widget.groupLabel.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
    final plotName = _zoneController.text.trim();
    final descriptionText = _descriptionController.text.trim();

    return [
      _sheetGrabHandle(),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location #${widget.pinNumber}',
                  style: AppFonts.titleMedium(
                    color: _sheetInk,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  productTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyMedium(
                    color: _sheetMuted,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.inkStrong,
                  side: const BorderSide(color: Color(0xFFD9D9DC)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _closePinSheet(),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: _sheetMuted,
                splashRadius: 22,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (groupTitle.isNotEmpty)
        _detailRow(
          icon: Icons.folder_outlined,
          label: 'Group',
          trailing: _detailTextValue(groupTitle),
        ),
      _detailRow(
        icon: Icons.inventory_2_outlined,
        label: 'Product',
        trailing: _detailTextValue(productTitle),
      ),
      _detailRow(
        icon: Icons.add_box_outlined,
        label: 'Quantity',
        trailing: _detailTextValue('$qty'),
      ),
      _detailRow(
        icon: Icons.timelapse,
        label: 'Status',
        trailing: Align(
          alignment: Alignment.centerRight,
          child: _viewStatusBadge(),
        ),
      ),
      _detailRow(
        icon: Icons.location_on_outlined,
        label: 'Location',
        trailing: _detailTextValue('${widget.pinNumber}'),
      ),
      _detailRow(
        icon: Icons.layers_outlined,
        label: 'Plot',
        trailing: _detailTextValue(plotName),
      ),
      _detailRow(
        icon: Icons.grid_on_outlined,
        label: 'Level',
        trailing: _detailTextValue(_levelDisplayLabel()),
      ),
      _detailRow(
        icon: Icons.description_outlined,
        label: 'Description',
        trailing: _descriptionTrailing(descriptionText),
      ),
      _detailRow(
        icon: Icons.attach_file_rounded,
        label: 'Attachments',
        trailing: _attachmentsTrailing(editing: false),
      ),
      _detailRow(
        icon: Icons.apps_rounded,
        label: 'Form',
        trailing: _formViewTrailing(),
      ),
      _detailRow(
        icon: Icons.layers_outlined,
        label: 'Variation',
        trailing: Align(
          alignment: Alignment.centerRight,
          child: CupertinoSwitch(
            value: _variation == 'Yes',
            onChanged: null,
            activeTrackColor: const Color(0xFF3B82F6),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'LOCATION',
        style: _sheetCapsLabelStyle,
      ),
      const SizedBox(height: 10),
      _coordinatesCard(pin),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () =>
              _closePinSheet(const _PinSheetResult(removePin: true)),
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
          label: Text(
            'Delete Pin',
            style: AppFonts.titleMedium(
              color: const Color(0xFFEF4444),
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            backgroundColor: AppColors.white,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _editTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? minLines,
    int? maxLines,
  }) {
    return AppTextField(
      controller: controller,
      hintText: hint,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      fillColor: AppColors.white,
      borderRadius: 12,
    );
  }

  List<Widget> _buildEditModeChildren(_CanvasPin pin) {
    return [
      _sheetGrabHandle(),
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton(
            onPressed: () => _closePinSheet(),
            icon: const Icon(Icons.close, size: 22),
            color: AppColors.inkStrong,
            splashRadius: 22,
          ),
          Expanded(
            child: Text(
              'Edit Pin',
              textAlign: TextAlign.center,
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _resetForm();
                _isEditing = false;
              });
            },
            child: Text(
              'RESET',
              style: AppFonts.labelMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E5)),
      const SizedBox(height: 16),
      if (widget.groupLabel.trim().isNotEmpty) ...[
        _sheetFieldLabel('Group'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            widget.groupLabel.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (widget.productOptionLabel.trim().isNotEmpty) ...[
        _sheetFieldLabel('Selected product'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            widget.productOptionLabel.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 18),
      ],
      _sheetFieldLabel('Product name'),
      const SizedBox(height: 6),
      _editTextField(controller: _productController, hint: 'Product name'),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Quantity'),
                const SizedBox(height: 6),
                _editTextField(
                  controller: _qtyController,
                  hint: '1',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetFieldLabel('Status'),
                const SizedBox(height: 6),
                _statusDropdown(),
              ],
            ),
          ),
        ],
      ),
      _statusManageRow(),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Plot'),
                const SizedBox(height: 6),
                _editTextField(controller: _zoneController, hint: 'Plot name'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Location'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    '${widget.pinNumber}',
                    style: AppFonts.bodyMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Block'),
                const SizedBox(height: 6),
                _editTextField(controller: _blockController, hint: 'Block'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Level'),
                const SizedBox(height: 6),
                _editTextField(controller: _levelController, hint: 'Level'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Form'),
                const SizedBox(height: 6),
                _formDropdownField(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Variation'),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoSwitch(
                    value: _variation == 'Yes',
                    onChanged: (v) =>
                        setState(() => _variation = v ? 'Yes' : 'No'),
                    activeTrackColor: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _sheetFieldLabel('Dropped'),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          _fmt(pin.droppedAt),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      const SizedBox(height: 18),
      _sheetFieldLabel('Description'),
      const SizedBox(height: 6),
      _editTextField(
        controller: _descriptionController,
        hint: 'Description',
        minLines: 3,
        maxLines: 6,
      ),
      const SizedBox(height: 18),
      _sheetFieldLabel('Attachments'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: _attachmentsTrailing(editing: true),
      ),
      const SizedBox(height: 20),
      Text('LOCATION', style: _sheetCapsLabelStyle),
      const SizedBox(height: 10),
      _coordinatesCard(pin),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF070A0E),
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.disabledButton,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final qty =
                int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
            _closePinSheet(
              _PinSheetResult(
                updatedPin: pin.copyWith(
                  productName: _productController.text.trim(),
                  quantity: qty < 1 ? 1 : qty,
                  status: _status,
                  statusId: _statusIdByNameLocal(_status),
                  statusBgColor: parseHexColor(
                        _statusItemByNameLocal(_status)?.bgColour ?? '',
                      ) ??
                      pin.statusBgColor,
                  statusFgColor: parseHexColor(
                        _statusItemByNameLocal(_status)?.textColour ?? '',
                      ) ??
                      pin.statusFgColor,
                  blockName: _blockController.text.trim(),
                  levelName: _levelController.text.trim(),
                  zoneName: _zoneController.text.trim(),
                  variation: _variation,
                  description: _descriptionController.text.trim(),
                  formName: _linkedFormName.trim(),
                  formId: _linkedFormId,
                  attachments: List<_PinAttachment>.from(_attachments),
                ),
              ),
            );
          },
          child: Text(
            'SAVE CHANGES',
            style: AppFonts.titleSmall(
              color: AppColors.white,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _resetForm();
              _isEditing = false;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkStrong,
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'CANCEL',
            style: AppFonts.titleSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final lightTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      canvasColor: AppColors.white,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        surface: AppColors.white,
        onSurface: AppColors.inkStrong,
      ),
    );

    return Theme(
      data: lightTheme,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) unfocusPrimary();
        },
        child: Material(
          color: AppColors.white,
          surfaceTintColor: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return ColoredBox(
                    color: AppColors.white,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: _isEditing
                          ? _buildEditModeChildren(pin)
                          : _buildViewModeChildren(pin),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
