part of 'add_quotation.dart';

/// `POST /api/v1/quotations/` — create quotation (field names aligned with common REST payloads).
class AddQuotationPage extends ConsumerStatefulWidget {
  const AddQuotationPage({super.key, this.initialProjectId});

  /// When set (e.g. opened from project details), project dropdown is pre-filled.
  final String? initialProjectId;

  static const pathPrefix = '/quotations';
  static const name = 'add-quotation';
  static String get path => '$pathPrefix/add';

  @override
  ConsumerState<AddQuotationPage> createState() => _AddQuotationPageState();
}

class _AddQuotationPageState extends ConsumerState<AddQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  final _quoteName = TextEditingController();
  final _dueDate = TextEditingController();
  final _blockName = TextEditingController();
  final _sectionName = TextEditingController();

  List<QuotationPlotGroup> _plotGroups = [];

  /// Expanded state for each block card (same order as [_plotGroups]).
  List<bool> _blockExpandedList = [];

  /// Block names that have at least one plot with pins (for a short hint under Project).
  String? _loadedLevelSummary;

  late final QuillController _descriptionQuill = QuillController.basic();
  final _descriptionFocus = FocusNode();

  ClientModel? _client;
  SiteModel? _site;
  QuoteSummary? _project;

  List<ClientModel> _clients = const [];
  List<SiteModel> _sites = const [];
  List<QuoteSummary> _projects = const [];
  List<ContactModel> _contacts = const [];
  List<UserProfileModel> _userProfiles = const [];

  ContactModel? _primaryContact;
  List<ContactModel?> _additionalContacts = <ContactModel?>[null];

  UserProfileModel? _projectManagerUser;
  UserProfileModel? _salespersonUser;
  List<UserProfileModel> _selectedTechnicians = const [];

  /// Active tags from `fetchTags()` (dropdown source).
  List<TagItem> _tagCatalog = const [];

  /// Tags attached to this new quotation (chips + payload).
  List<TagItem> _selectedTags = const [];

  bool _loadingOptions = false;

  /// True while loading group / item / site / contact / level APIs for the selected project.
  bool _loadingProjectDeps = false;
  int _projectDepsSeq = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDropdowns());
  }

  @override
  void dispose() {
    _quoteName.dispose();
    _dueDate.dispose();
    _descriptionQuill.dispose();
    _descriptionFocus.dispose();
    _blockName.dispose();
    _sectionName.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _loadingOptions = true);
    try {
      final clientsApi = ref.read(clientsApiClientProvider);
      final quotesApi = ref.read(crmQuotesApiProvider);
      final quoteProjectApi = ref.read(quoteProjectApiClientProvider);
      final userProfileApi = ref.read(userProfileApiClientProvider);

      final results = await Future.wait<dynamic>([
        clientsApi.fetchClientsPage(page: 1),
        quotesApi.fetchQuotesPage(1),
        quoteProjectApi.fetchTags(),
        userProfileApi.fetchAllUserProfiles(),
      ]);
      if (!mounted) return;
      final clients = results[0] as ClientsPageResult;
      final quotes = results[1] as QuoteListPageResult;
      final tags = results[2] as List<TagItem>;
      final profiles = results[3] as List<UserProfileModel>;
      setState(() {
        _clients = clients.items;
        _projects = quotes.summaries;
        _tagCatalog =
            tags.where((t) => t.isActive).toList(growable: false);
        _userProfiles = profiles;
        _sites = const [];
        _site = null;
        _loadingOptions = false;
      });
      _applyInitialProjectIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to load form options',
            ),
          ),
        ),
      );
    }
  }

  void _applyInitialProjectIfNeeded() {
    final want = widget.initialProjectId?.trim();
    if (want == null || want.isEmpty) return;
    for (final p in _projects) {
      if (p.id.trim() == want) {
        setState(() => _project = p);
        _loadProjectDependencies(p.id);
        return;
      }
    }
  }

  /// After a project is chosen: project `sites[]`, `contact/`, `project/{id}/level/`.
  Future<void> _loadProjectDependencies(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return;
    final seq = ++_projectDepsSeq;
    setState(() => _loadingProjectDeps = true);
    try {
      final quoteProjectApi = ref.read(quoteProjectApiClientProvider);
      final contactsApi = ref.read(contactsApiClientProvider);

      final results = await Future.wait<dynamic>([
        quoteProjectApi.fetchProjectSites(projectId: id),
        contactsApi.fetchContactsPage(page: 1),
        quoteProjectApi.fetchProjectLevelsForQuotation(projectId: id),
      ]);
      if (!mounted || seq != _projectDepsSeq || _project?.id != id) return;
      final levels = results[2] as List<ProjectLevelItem>;
      final newGroups = _plotGroupsFromLevels(levels);
      final hasLevels = levels.isNotEmpty;
      final hasPinnedPlots = newGroups.any(
        (g) => g.lines.any((l) => (l.quantityMultiplier ?? 0) > 0),
      );
      final summary = hasLevels ? _levelSummaryFromLevels(levels) : null;
      final singleBlockName = hasLevels && levels.length == 1
          ? levels.first.name
          : null;
      setState(() {
        _sites = List<SiteModel>.from(results[0] as List<SiteModel>);
        _contacts = (results[1] as ContactsPageResult).items;
        _site = null;
        _primaryContact = null;
        _additionalContacts = <ContactModel?>[null];
        _plotGroups = newGroups;
        _blockExpandedList = hasLevels
            ? List<bool>.filled(newGroups.length, true)
            : <bool>[];
        _loadedLevelSummary = summary;
        if (singleBlockName != null) {
          _blockName.text = singleBlockName;
        } else if (!hasLevels) {
          _blockName.clear();
        }
      });
      if (!hasPinnedPlots && hasLevels && mounted) {
        context.showTopSnackBar(
          const SnackBar(
            content: Text(
              'Levels loaded but no pins found yet. Add pins on the project drawings, then re-select the project.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (seq == _projectDepsSeq && _project?.id == id) {
        setState(() {
          _sites = const [];
          _contacts = const [];
          _site = null;
          _primaryContact = null;
          _additionalContacts = <ContactModel?>[null];
          _plotGroups = [];
          _blockExpandedList = [];
          _loadedLevelSummary = null;
          _blockName.clear();
        });
      }
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to load project data',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && seq == _projectDepsSeq) {
        setState(() => _loadingProjectDeps = false);
      }
    }
  }

  static int _quotationPinCountFromPlot(Map<String, dynamic> plot) {
    final pins = plot['pins'];
    if (pins is! List) return 0;
    return pins.length;
  }

  static double _quotationPlotAmountFromPins(List<QuotationDesignPin> pins) {
    var sum = 0.0;
    for (final p in pins) {
      if (p.compositeItemId == null) continue;
      sum += p.lineTotal;
    }
    return sum;
  }

  static List<QuotationCompositeChildPin> _compositeChildrenFromRaw(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    final out = <QuotationCompositeChildPin>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(
        entry.map((k, v) => MapEntry(k.toString(), v)),
      );
      final nested = m['item'] ?? m['child_item'] ?? m['product'];
      var childId = m['child_item_id'] ?? m['item_id'] ?? m['product_id'];
      var childName = m['child_item_name'] ?? m['item_name'] ?? m['name'];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(
          nested.map((k, v) => MapEntry(k.toString(), v)),
        );
        childId ??= nestedMap['id'];
        final nestedName = nestedMap['name'] ?? nestedMap['item_name'];
        if (childName == null && nestedName != null) {
          childName = nestedName;
        }
      }
      final qtyRaw = m['quantity'] ?? m['qty'];
      final qty = qtyRaw is int
          ? qtyRaw
          : (qtyRaw is num ? qtyRaw.toInt() : int.tryParse('${qtyRaw ?? ''}'));
      final parsedId = childId is int
          ? childId
          : (childId is num
              ? childId.toInt()
              : int.tryParse('${childId ?? ''}'));
      final name = '${childName ?? ''}'.trim();
      out.add(
        QuotationCompositeChildPin(
          childItemId: parsedId,
          childItemName: name.isEmpty ? 'Component' : name,
          quantity: (qty ?? 1) < 1 ? 1 : (qty ?? 1),
        ),
      );
    }
    return out;
  }

  static List<QuotationCompositeChildPin> _compositeChildrenFromItem(
    Map<String, dynamic>? item,
  ) {
    if (item == null) return const [];
    for (final key in const [
      'composite_items',
      'components',
      'child_items',
      'items',
    ]) {
      final parsed = _compositeChildrenFromRaw(item[key]);
      if (parsed.isNotEmpty) return parsed;
    }
    return const [];
  }

  static List<QuotationDesignPin> _quotationDesignPinsFromPlot(
    Map<String, dynamic> plot,
  ) {
    final pins = plot['pins'];
    if (pins is! List) return const [];
    final out = <QuotationDesignPin>[];
    for (final raw in pins) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = '${m['id'] ?? m['pin_id'] ?? ''}'.trim();

      Map<String, dynamic>? item;
      for (final key in const ['item_detail', 'item', 'composite_item']) {
        final rawItem = m[key];
        if (rawItem is Map) {
          item = Map<String, dynamic>.from(
            rawItem.map((k, v) => MapEntry(k.toString(), v)),
          );
          break;
        }
      }

      Map<String, dynamic>? status;
      final sd = m['status_detail'] ?? m['status'];
      if (sd is Map) {
        status = Map<String, dynamic>.from(
          sd.map((k, v) => MapEntry(k.toString(), v)),
        );
      }

      var name = 'Item';
      if (item != null) {
        final n = item['name']?.toString().trim();
        if (n != null && n.isNotEmpty && n != 'null') name = n;
      }
      if (name == 'Item') {
        for (final key in const ['item_name', 'product_name', 'name']) {
          final v = m[key];
          if (v == null || v is Map || v is List) continue;
          final t = v.toString().trim();
          if (t.isNotEmpty && t != 'null') {
            name = t;
            break;
          }
        }
      }

      String? sku;
      if (item != null) {
        final s = item['sku']?.toString().trim();
        if (s != null && s.isNotEmpty && s != 'null') sku = s;
      }

      var qty = 1;
      final q = m['quantity'];
      if (q is int) {
        qty = q;
      } else if (q != null) {
        qty = int.tryParse('$q') ?? 1;
      }

      String? statusLabel;
      String? statusBg;
      String? statusFg;
      if (status != null) {
        final sl = status['status_name']?.toString().trim();
        if (sl != null && sl.isNotEmpty) statusLabel = sl;
        statusBg = status['bg_colour']?.toString();
        statusFg = status['text_colour']?.toString();
      }

      double? selling;
      if (item != null) {
        final sp = item['selling_price'];
        if (sp is num) {
          selling = sp.toDouble();
        } else if (sp != null) {
          selling = double.tryParse('$sp');
        }
      }
      if (selling == null) {
        final sp = m['selling_price'];
        if (sp is num) {
          selling = sp.toDouble();
        } else if (sp != null) {
          selling = double.tryParse('$sp');
        }
      }

      int? compositeItemId;
      if (item != null) {
        final rawComp = item['composite_item_id'] ??
            item['composite_item'] ??
            item['item_id'] ??
            item['id'];
        if (rawComp is int) {
          compositeItemId = rawComp;
        } else if (rawComp is Map) {
          final compMap = Map<String, dynamic>.from(
            rawComp.map((k, v) => MapEntry(k.toString(), v)),
          );
          final cid = compMap['id'];
          compositeItemId =
              cid is int ? cid : int.tryParse('${cid ?? ''}');
        } else {
          compositeItemId = int.tryParse('${rawComp ?? ''}');
        }
      }
      if (compositeItemId == null) {
        final top = m['composite_item_id'] ?? m['composite_item'];
        if (top is int) {
          compositeItemId = top;
        } else if (top is Map) {
          final topMap = Map<String, dynamic>.from(
            top.map((k, v) => MapEntry(k.toString(), v)),
          );
          compositeItemId = int.tryParse('${topMap['id'] ?? ''}');
        } else {
          compositeItemId = int.tryParse('${top ?? ''}');
        }
      }
      if (compositeItemId == null && item == null) {
        final itemFk = m['item'];
        if (itemFk is int) {
          compositeItemId = itemFk;
        } else if (itemFk is num) {
          compositeItemId = itemFk.toInt();
        }
      }

      final compositeFromPin = _compositeChildrenFromRaw(m['composite_items']);
      final compositeFromItem = _compositeChildrenFromItem(item);
      final compositeItems = compositeFromPin.isNotEmpty
          ? compositeFromPin
          : compositeFromItem;
      final isComposite =
          m['is_composite'] == true ||
          (item?['is_composite'] == true) ||
          compositeItems.isNotEmpty;

      out.add(
        QuotationDesignPin(
          id: id.isEmpty ? '${out.length + 1}' : id,
          itemName: name,
          sku: sku,
          quantity: qty,
          statusLabel: statusLabel,
          statusBgHex: statusBg,
          statusTextHex: statusFg,
          sellingPrice: selling,
          compositeItemId: compositeItemId,
          isComposite: isComposite,
          compositeItems: compositeItems,
        ),
      );
    }
    return out;
  }

  static int _quotationPlotSortKey(Map<String, dynamic> plot) {
    final id = plot['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
  }

  static String _quotationPlotLabelFrom(Map<String, dynamic> plot) {
    for (final key in ['name', 'plot_name', 'title', 'label']) {
      final v = plot[key];
      if (v == null || v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    final id = plot['id'];
    return id != null ? 'Plot $id' : 'Plot';
  }

  List<QuotationPlotGroup> _plotGroupsFromLevels(
    List<ProjectLevelItem> levels,
  ) {
    final sorted = [...levels]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = <QuotationPlotGroup>[];
    for (final level in sorted) {
      final lines = <QuotationPlotLine>[];
      final plotList = [...level.plots]
        ..sort(
          (a, b) =>
              _quotationPlotSortKey(a).compareTo(_quotationPlotSortKey(b)),
        );
      for (final plot in plotList) {
        final n = _quotationPinCountFromPlot(plot);
        final plotIdStr = '${plot['id'] ?? plot['plot_id'] ?? ''}'.trim();
        final designPins = _quotationDesignPinsFromPlot(plot);
        lines.add(
          QuotationPlotLine(
            label: _quotationPlotLabelFrom(plot),
            quantityMultiplier: n > 0 ? n : null,
            amount: _quotationPlotAmountFromPins(designPins),
            plotId: plotIdStr.isEmpty ? null : plotIdStr,
            designPins: designPins,
            selected: n > 0,
          ),
        );
      }
      groups.add(
        QuotationPlotGroup(
          name: level.name,
          levelId: level.id,
          lines: lines,
        ),
      );
    }
    return groups;
  }

  String? _levelSummaryFromLevels(List<ProjectLevelItem> levels) {
    final names = <String>[];
    for (final l in levels) {
      if (l.plots.any((p) => _quotationPinCountFromPlot(p) > 0)) {
        names.add(l.name);
      }
    }
    if (names.isEmpty) return null;
    return names.join(' · ');
  }

  Map<String, dynamic> _siteSnapshotMap() {
    final s = _site;
    if (s == null) return <String, dynamic>{};
    return <String, dynamic>{
      'id': _jsonPk(s.id),
      'site_name': s.siteName,
      'address_line_1': s.addressLine1,
      'address_line_2': s.addressLine2,
      'city': s.city,
      'state': s.state,
      'country': s.country,
      'pincode': s.postalCode,
    };
  }

  List<ContactModel> get _clientContactsList =>
      _contactsForPicker.toList(growable: false);

  void _addAdditionalContactRow() {
    if (_submitting) return;
    setState(() => _additionalContacts = [..._additionalContacts, null]);
  }

  void _removeAdditionalContactRow(int index) {
    if (_submitting) return;
    setState(() {
      if (_additionalContacts.length <= 1) {
        _additionalContacts = <ContactModel?>[null];
      } else {
        _additionalContacts = [
          for (var i = 0; i < _additionalContacts.length; i++)
            if (i != index) _additionalContacts[i],
        ];
      }
    });
  }

  Widget _buildAdditionalContactsSection() {
    final contacts = _clientContactsList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Additional contacts',
                style: AppFonts.titleSmall(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            TextButton.icon(
              onPressed: (_submitting || _client == null)
                  ? null
                  : _addAdditionalContactRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add additional contact'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_client == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text(
              'Select a client first to add additional contacts.',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
          )
        else if (contacts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text(
              'No contacts for this client yet.',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
          )
        else
          for (var i = 0; i < _additionalContacts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _contactDropdown(
                    fieldKey: 'add_$i',
                    hint: 'Optional',
                    value: _additionalContacts[i],
                    onChanged: (c) => setState(() {
                      final next = List<ContactModel?>.from(
                        _additionalContacts,
                      );
                      next[i] = c;
                      _additionalContacts = next;
                    }),
                  ),
                ),
                if (_additionalContacts.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => _removeAdditionalContactRow(i),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.muted,
                  ),
                ],
              ],
            ),
          ],
      ],
    );
  }

  List<Map<String, dynamic>> _buildQuoteSections() {
    final sections = <Map<String, dynamic>>[];
    var sectionOrder = 0;
    for (final g in _plotGroups) {
      final levelId = int.tryParse(g.levelId?.trim() ?? '');
      if (levelId == null) continue;

      final plots = <Map<String, dynamic>>[];
      var plotOrder = 0;
      var sectionTotal = 0;

      for (final line in g.lines) {
        if (!line.selected) continue;
        final plotId = int.tryParse(line.plotId?.trim() ?? '');
        if (plotId == null) continue;

        final pins = <Map<String, dynamic>>[];
        var pinsOrder = 0;
        var plotTotal = 0;

        for (final p in line.designPins) {
          final cid = p.compositeItemId;
          if (cid == null) continue;
          final qty = p.quantity < 1 ? 1 : p.quantity;
          final sp = (p.sellingPrice ?? 0).toDouble();
          final pinsTotal = (qty * sp).round();
          plotTotal += pinsTotal;
          final pinId = int.tryParse(p.id.trim());
          final pinPayload = <String, dynamic>{
            'pins_order': pinsOrder++,
            'pin_id': pinId,
            'composite_item_id': cid,
            'name': p.itemName,
            'quantity': qty,
            'selling_price': p.sellingPrice ?? 0,
            'pins_total': pinsTotal,
            'is_composite': p.isComposite,
          };
          if (p.isComposite && p.compositeItems.isNotEmpty) {
            pinPayload['composite_items'] = p.compositeItems
                .map((c) => c.toPayloadMap())
                .toList(growable: false);
          }
          pins.add(pinPayload);
        }
        if (pins.isEmpty) continue;

        plots.add(<String, dynamic>{
          'plot_order': plotOrder++,
          'plot_id': plotId,
          'name': line.label,
          'pins': pins,
          'plot_total': plotTotal,
        });
        sectionTotal += plotTotal;
      }

      if (plots.isEmpty) continue;

      sections.add(<String, dynamic>{
        'section_order': sectionOrder++,
        'level_id': levelId,
        'name': _quoteSectionNameForGroup(g),
        'plots': plots,
        'section_total': sectionTotal,
      });
    }
    return sections;
  }

  String _quoteSectionNameForGroup(QuotationPlotGroup group) {
    final block = _blockName.text.trim();
    if (block.isNotEmpty && _plotGroups.length == 1) return block;
    final levelName = group.name.trim();
    if (levelName.isNotEmpty) return levelName;
    return block.isEmpty ? 'Section' : block;
  }

  void _addPlotSection() {
    if (_submitting) return;
    if (_project == null) return;
    final name = _sectionName.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _plotGroups = [
        ..._plotGroups,
        QuotationBlockSectionsPanel.emptyGroupFromSectionName(name),
      ];
      _blockExpandedList = [..._blockExpandedList, true];
      _sectionName.clear();
    });
  }

  void _removePlotGroup(int index) {
    if (_submitting) return;
    if (index < 0 || index >= _plotGroups.length) return;
    setState(() {
      _plotGroups = [
        for (var i = 0; i < _plotGroups.length; i++)
          if (i != index) _plotGroups[i],
      ];
      _blockExpandedList = [
        for (var i = 0; i < _blockExpandedList.length; i++)
          if (i != index) _blockExpandedList[i],
      ];
    });
  }

  void _setBlockExpandedAt(int blockIndex, bool expanded) {
    if (_submitting) return;
    if (blockIndex < 0 || blockIndex >= _blockExpandedList.length) return;
    setState(() {
      _blockExpandedList = [
        for (var i = 0; i < _blockExpandedList.length; i++)
          i == blockIndex ? expanded : _blockExpandedList[i],
      ];
    });
  }

  void _setLineSelected(int groupIndex, int lineIndex, bool selected) {
    if (_submitting) return;
    setState(() {
      final groups = List<QuotationPlotGroup>.from(_plotGroups);
      final lines = List<QuotationPlotLine>.from(groups[groupIndex].lines);
      lines[lineIndex] = lines[lineIndex].copyWith(selected: selected);
      groups[groupIndex] = groups[groupIndex].copyWith(lines: lines);
      _plotGroups = groups;
    });
  }

  String? Function(String?) _required(String label) {
    return (v) {
      if ((v ?? '').trim().isEmpty) return '$label is required';
      return null;
    };
  }

  Iterable<ContactModel> get _contactsForPicker {
    return _contacts.where((c) {
      if (!c.isActive) return false;
      if (_client == null) return true;
      return c.clientId == _client!.id;
    });
  }

  static String _contactLabel(ContactModel c) {
    final phone = c.phone.trim();
    if (phone.isNotEmpty) return '${c.contactName} · $phone';
    return c.contactName;
  }

  static String _userLabel(UserProfileModel u) {
    final name = '${u.firstName} ${u.lastName}'.trim();
    if (name.isNotEmpty) return name;
    final e = u.email.trim();
    return e.isNotEmpty ? e : 'User #${u.id}';
  }

  /// DRF-friendly PK: integer when the id is numeric.
  static Object _jsonPk(String id) {
    final t = id.trim();
    final n = int.tryParse(t);
    return n ?? t;
  }

  Widget _contactDropdown({
    required Object fieldKey,
    required String hint,
    required ContactModel? value,
    required ValueChanged<ContactModel?> onChanged,
  }) {
    final rows = _contactsForPicker.toList();
    return DropdownButtonFormField<ContactModel?>(
      key: ValueKey<String>(
        'cq_${fieldKey}_${value?.id ?? 'none'}_${rows.length}',
      ),
      initialValue: value,
      isExpanded: true,
      hint: Text(hint, style: AppFonts.bodySmall(color: AppColors.muted)),
      decoration: _dropdownDecoration(),
      items: <DropdownMenuItem<ContactModel?>>[
        const DropdownMenuItem<ContactModel?>(
          value: null,
          child: Text('— None —'),
        ),
        ...rows.map(
          (c) => DropdownMenuItem<ContactModel?>(
            value: c,
            child: Text(
              _contactLabel(c),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _submitting ? null : onChanged,
    );
  }

  String _formatDueDateForDisplay(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    return '$dd-$mm-$yyyy';
  }

  String _formatDueDateForApi(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    return '$yyyy-$mm-$dd';
  }

  DateTime? _parseDueDateField(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final dash = t.split('-');
    if (dash.length == 3) {
      // dd-mm-yyyy (UI) or yyyy-mm-dd (API)
      if (dash[0].length == 4) {
        final y = int.tryParse(dash[0]);
        final m = int.tryParse(dash[1]);
        final d = int.tryParse(dash[2]);
        if (y != null && m != null && d != null) {
          try {
            return DateTime(y, m, d);
          } catch (_) {}
        }
      } else {
        final d = int.tryParse(dash[0]);
        final m = int.tryParse(dash[1]);
        final y = int.tryParse(dash[2]);
        if (y != null && m != null && d != null) {
          try {
            return DateTime(y, m, d);
          } catch (_) {}
        }
      }
    }
    final parts = t.split('/');
    if (parts.length == 3) {
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m != null && d != null && y != null) {
        try {
          return DateTime(y, m, d);
        } catch (_) {}
      }
    }
    final iso = DateTime.tryParse(t);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    return null;
  }

  String _dueDatePayloadValue() {
    final t = _dueDate.text.trim();
    if (t.isEmpty) return '';
    final dt = _parseDueDateField(t);
    if (dt != null) return _formatDueDateForApi(dt);
    return t;
  }

  Future<void> _pickDueDate() async {
    if (_submitting) return;
    final initial = _parseDueDateField(_dueDate.text) ?? DateTime.now();
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select due date',
    );
    if (picked == null || !mounted) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    setState(() => _dueDate.text = _formatDueDateForDisplay(normalized));
  }

  Widget _dateField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback? onTap,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: AppTextField(
          controller: controller,
          hintText: hint,
          readOnly: true,
          enabled: enabled,
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

  List<UserProfileModel> get _techniciansAvailableToAdd {
    final chosen = _selectedTechnicians.map((u) => u.id).toSet();
    return _userProfiles
        .where((u) => u.id.isNotEmpty && !chosen.contains(u.id))
        .toList();
  }

  void _addTechnician(UserProfileModel u) {
    if (_submitting) return;
    if (_selectedTechnicians.any((x) => x.id == u.id)) return;
    setState(() => _selectedTechnicians = [..._selectedTechnicians, u]);
  }

  void _removeTechnician(UserProfileModel u) {
    if (_submitting) return;
    setState(
      () => _selectedTechnicians = _selectedTechnicians
          .where((x) => x.id != u.id)
          .toList(growable: false),
    );
  }

  Widget _buildTechniciansField() {
    if (_loadingOptions && _userProfiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
        child: Text(
          'Loading team…',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      );
    }
    final available = _techniciansAvailableToAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedTechnicians.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in _selectedTechnicians)
                InputChip(
                  label: Text(
                    _userLabel(u),
                    style: AppFonts.bodySmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  backgroundColor: AppColors.surface,
                  deleteIconColor: AppColors.inkStrong,
                  onDeleted: _submitting ? null : () => _removeTechnician(u),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            'tech_add_${_selectedTechnicians.length}_${available.length}',
          ),
          isExpanded: true,
          hint: Text(
            available.isEmpty
                ? (_userProfiles.isEmpty ? 'No users loaded' : 'No more to add')
                : 'Add technician',
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
          decoration: _dropdownDecoration(),
          items: available
              .map(
                (u) => DropdownMenuItem<String>(
                  value: u.id,
                  child: Text(
                    _userLabel(u),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (_submitting || available.isEmpty)
              ? null
              : (id) {
                  if (id == null) return;
                  final u = _userProfiles.firstWhere((e) => e.id == id);
                  _addTechnician(u);
                },
        ),
      ],
    );
  }

  List<TagItem> get _tagsAvailableToAdd {
    final chosen = _selectedTags.map((t) => t.id).toSet();
    return _tagCatalog.where((t) => !chosen.contains(t.id)).toList();
  }

  void _addTag(TagItem tag) {
    if (_submitting) return;
    if (_selectedTags.any((t) => t.id == tag.id)) return;
    setState(() => _selectedTags = [..._selectedTags, tag]);
  }

  void _removeTag(TagItem tag) {
    if (_submitting) return;
    setState(
      () => _selectedTags =
          _selectedTags.where((t) => t.id != tag.id).toList(growable: false),
    );
  }

  static Color _tagChipBackground(TagItem t) {
    var s = t.colourHex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length == 8) {
      try {
        return Color(int.parse(s, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFE5E7EB);
  }

  Widget _buildTagsField() {
    if (_loadingOptions && _tagCatalog.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
        child: Text(
          'Loading tags…',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      );
    }
    final available = _tagsAvailableToAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedTags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _selectedTags)
                InputChip(
                  label: Text(
                    t.name,
                    style: AppFonts.bodySmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  backgroundColor:
                      _tagChipBackground(t).withValues(alpha: 0.28),
                  deleteIconColor: AppColors.inkStrong,
                  onDeleted:
                      _submitting ? null : () => _removeTag(t),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            'quotation_tag_add_${_selectedTags.length}_${available.length}',
          ),
          isExpanded: true,
          hint: Text(
            available.isEmpty
                ? (_tagCatalog.isEmpty ? 'No tags available' : 'No more tags')
                : 'Add tag',
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
          decoration: _dropdownDecoration(),
          items: available
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (_submitting || available.isEmpty)
              ? null
              : (id) {
                  if (id == null) return;
                  final tag = _tagCatalog.firstWhere((e) => e.id == id);
                  _addTag(tag);
                },
        ),
      ],
    );
  }

  Map<String, dynamic> _buildPayload() {
    final quoteSections = _buildQuoteSections();
    final levels = quoteSections
        .map((s) => s['level_id'])
        .whereType<int>()
        .toList();
    final grandTotal = quoteSections.fold<int>(
      0,
      (sum, sec) =>
          sum + ((sec['section_total'] as num?)?.round() ?? 0),
    );

    final additionalIds = _additionalContacts
        .whereType<ContactModel>()
        .map((c) => _jsonPk(c.id))
        .toList(growable: false);

    final body = <String, dynamic>{
      'customer': _jsonPk(_client!.id),
      'site': _jsonPk(_site!.id),
      'sites': <Object>[_jsonPk(_site!.id)],
      'quote_name': _quoteName.text.trim(),
      'tags': _selectedTags
          .map((t) => int.tryParse(t.id.trim()) ?? t.id.trim())
          .toList(),
      'due_date': _dueDatePayloadValue(),
      'description': _descriptionQuill.document.toPlainText().trim(),
      'project': _jsonPk(_project!.id),
      'levels': levels,
      'select_all_levels': true,
      'quote_sections': quoteSections,
      'grand_total': grandTotal,
      'site_snapshot': _siteSnapshotMap(),
      'additional_customer_contact': additionalIds,
    };

    if (_primaryContact != null) {
      body['primary_customer_contact'] = _jsonPk(_primaryContact!.id);
    }
    if (_salespersonUser != null) {
      body['salesperson'] = _jsonPk(_salespersonUser!.id);
    }
    if (_projectManagerUser != null) {
      body['project_manager'] = _jsonPk(_projectManagerUser!.id);
    }
    if (_selectedTechnicians.isNotEmpty) {
      final techIds =
          _selectedTechnicians.map((u) => _jsonPk(u.id)).toList();
      body['technicians'] = techIds;
      body['technician'] = techIds;
    }

    body.removeWhere((key, value) {
      if (key == 'quote_sections' ||
          key == 'levels' ||
          key == 'tags' ||
          key == 'sites' ||
          key == 'additional_customer_contact' ||
          key == 'site_snapshot') {
        return false;
      }
      if (value is String && value.trim().isEmpty) return true;
      if (value is List && value.isEmpty) return true;
      return false;
    });
    return body;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_project == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Select a project')),
      );
      return;
    }
    if (_client == null) {
      context.showTopSnackBar(const SnackBar(content: Text('Select a client')));
      return;
    }
    if (_site == null) {
      context.showTopSnackBar(const SnackBar(content: Text('Select a site')));
      return;
    }
    if (_sites.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text(
            'This project has no linked sites. Link sites on the project, then try again.',
          ),
        ),
      );
      return;
    }
    if (_buildQuoteSections().isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text(
            'No quotable sections: ensure each level has plots with pins and composite items. Deselect empty plots if needed.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(quotationsApiClientProvider);
      final created = await api.createQuotation(_buildPayload());
      if (!mounted) return;
      context.pop<QuotationListItem>(created);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to create quotation',
            ),
          ),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  Widget _buildProjectScopeSection() {
    if (_project == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Project'),
          const SizedBox(height: 6),
          Text(
            'Select a project to load drawing levels, plots, and pins for quotation.',
            style: AppFonts.bodySmall(
              color: AppColors.muted,
            ).copyWith(fontSize: 12, height: 1.35),
          ),
        ],
      );
    }
    if (_loadingProjectDeps) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Project'),
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Project'),
        if (_loadedLevelSummary != null && _loadedLevelSummary!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Levels: $_loadedLevelSummary',
            style: AppFonts.bodySmall(
              color: AppColors.muted,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
        QuotationBlockSectionsPanel(
          blockNameController: _blockName,
          sectionNameController: _sectionName,
          plotGroups: _plotGroups,
          blockExpandedList: _blockExpandedList.length == _plotGroups.length
              ? _blockExpandedList
              : List<bool>.filled(_plotGroups.length, true),
          onBlockExpandedAt: _setBlockExpandedAt,
          onAddSection: _addPlotSection,
          onLineSelectionChanged: _setLineSelected,
          onRemovePlotGroup: _removePlotGroup,
          submitting: _submitting,
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
        ],
      ),
      style: AppFonts.bodySmall(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _submitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Add Quotation',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.inkStrong.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: _loadingOptions && _clients.isEmpty && _sites.isEmpty
          ? Center(
              child: const AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 5,
              ),
            )
          : SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          _label('Quote name', required: true),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _quoteName,
                            hintText: 'Quote name',
                            validator: _required('Quote name'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Client', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ClientModel>(
                            key: ValueKey<String>(
                              'quotation_client_${_client?.id ?? 'none'}',
                            ),
                            initialValue: _client,
                            isExpanded: true,
                            hint: const Text('Select client'),
                            decoration: _dropdownDecoration(),
                            items: _clients
                                .map(
                                  (c) => DropdownMenuItem<ClientModel>(
                                    value: c,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() {
                                    _client = v;
                                    _primaryContact = null;
                                    _additionalContacts =
                                        <ContactModel?>[null];
                                  }),
                          ),
                          const SizedBox(height: 14),
                          _label('Project', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<QuoteSummary>(
                            key: ValueKey<String>(
                              'quotation_project_${_project?.id ?? 'none'}',
                            ),
                            initialValue: _project,
                            isExpanded: true,
                            hint: const Text('Select project'),
                            decoration: _dropdownDecoration(),
                            items: _projects
                                .map(
                                  (p) => DropdownMenuItem<QuoteSummary>(
                                    value: p,
                                    child: Text(
                                      p.quoteName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) {
                                    setState(() {
                                      _project = v;
                                      _site = null;
                                      _sites = const [];
                                      _contacts = const [];
                                      _primaryContact = null;
                                      _additionalContacts =
                                          <ContactModel?>[null];
                                      _loadedLevelSummary = null;
                                      _plotGroups = [];
                                      _blockExpandedList = [];
                                      _blockName.clear();
                                    });
                                    if (v != null) {
                                      _loadProjectDependencies(v.id);
                                    }
                                  },
                          ),
                          if (_loadingProjectDeps) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Loading sites and project data…',
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ).copyWith(fontSize: 12),
                            ),
                          ],
                          if (!_loadingProjectDeps &&
                              _loadedLevelSummary != null &&
                              _loadedLevelSummary!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Levels: $_loadedLevelSummary',
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ).copyWith(fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _label('Sites', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<SiteModel>(
                            key: ValueKey<String>(
                              'quotation_site_${_site?.id ?? 'none'}',
                            ),
                            initialValue: _site,
                            isExpanded: true,
                            hint: Text(
                              _project == null
                                  ? 'Select a project first'
                                  : 'Select site',
                            ),
                            decoration: _dropdownDecoration(),
                            items: _sites
                                .map(
                                  (s) => DropdownMenuItem<SiteModel>(
                                    value: s,
                                    child: Text(
                                      s.siteName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged:
                                (_submitting ||
                                    _project == null ||
                                    _loadingProjectDeps)
                                ? null
                                : (v) => setState(() => _site = v),
                          ),
                          if (_project != null &&
                              !_loadingProjectDeps &&
                              _sites.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'This project has no linked sites. Add or link sites on the project in the CRM, then reopen this form.',
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ).copyWith(fontSize: 12, height: 1.35),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _buildProjectScopeSection(),
                          const SizedBox(height: 14),
                          _label('Primary contact'),
                          const SizedBox(height: 8),
                          _contactDropdown(
                            fieldKey: 'primary_customer',
                            hint: 'Optional',
                            value: _primaryContact,
                            onChanged: (c) =>
                                setState(() => _primaryContact = c),
                          ),
                          const SizedBox(height: 14),
                          _label('Due date'),
                          const SizedBox(height: 8),
                          _dateField(
                            controller: _dueDate,
                            hint: 'dd-mm-yyyy',
                            onTap: _submitting ? null : _pickDueDate,
                            enabled: !_submitting,
                          ),
                          const SizedBox(height: 18),
                          _buildAdditionalContactsSection(),
                          const SizedBox(height: 18),
                          _label('Salesperson'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<UserProfileModel?>(
                            key: ValueKey<String>(
                              'sp_${_salespersonUser?.id ?? 'none'}',
                            ),
                            initialValue: _salespersonUser,
                            isExpanded: true,
                            hint: Text(
                              'Optional',
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ),
                            ),
                            decoration: _dropdownDecoration(),
                            items: <DropdownMenuItem<UserProfileModel?>>[
                              const DropdownMenuItem<UserProfileModel?>(
                                value: null,
                                child: Text('— None —'),
                              ),
                              ..._userProfiles.map(
                                (u) => DropdownMenuItem<UserProfileModel?>(
                                  value: u,
                                  child: Text(
                                    _userLabel(u),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (u) => setState(() => _salespersonUser = u),
                          ),
                          const SizedBox(height: 14),
                          _label('Project manager'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<UserProfileModel?>(
                            key: ValueKey<String>(
                              'pm_${_projectManagerUser?.id ?? 'none'}',
                            ),
                            initialValue: _projectManagerUser,
                            isExpanded: true,
                            hint: Text(
                              'Optional',
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ),
                            ),
                            decoration: _dropdownDecoration(),
                            items: <DropdownMenuItem<UserProfileModel?>>[
                              const DropdownMenuItem<UserProfileModel?>(
                                value: null,
                                child: Text('— None —'),
                              ),
                              ..._userProfiles.map(
                                (u) => DropdownMenuItem<UserProfileModel?>(
                                  value: u,
                                  child: Text(
                                    _userLabel(u),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (u) =>
                                    setState(() => _projectManagerUser = u),
                          ),
                          const SizedBox(height: 14),
                          _label('Tags'),
                          const SizedBox(height: 8),
                          _buildTagsField(),
                          const SizedBox(height: 14),
                          _label('Technicians'),
                          const SizedBox(height: 8),
                          _buildTechniciansField(),
                          const SizedBox(height: 14),
                          _label('Description'),
                          const SizedBox(height: 8),
                          IgnorePointer(
                            ignoring: _submitting,
                            child: buildQuotationDescriptionRichField(
                              key: const ValueKey<Object>(
                                'add_quotation_description_editor',
                              ),
                              quillController: _descriptionQuill,
                              editorFocusNode: _descriptionFocus,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  'Create',
                                  style:
                                      AppFonts.titleMedium(
                                        color: AppColors.white,
                                      ).copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF111111), width: 1.4),
      ),
    );
  }
}
