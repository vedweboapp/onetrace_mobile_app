import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/quotation_description_rich_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:red5/features/quotations/presentation/widgets/quotation_block_sections_panel.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';

/// `POST /api/v1/quotations/` — create quotation (field names aligned with common REST payloads).
class AddQuotationPage extends ConsumerStatefulWidget {
  const AddQuotationPage({super.key});

  static const pathPrefix = '/quotations';
  static const name = 'add-quotation';
  static String get path => '$pathPrefix/add';

  @override
  ConsumerState<AddQuotationPage> createState() => _AddQuotationPageState();
}

class _AddQuotationPageState extends ConsumerState<AddQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  final _quoteName = TextEditingController();
  final _costCentre = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _siteContact = TextEditingController();
  final _tags = TextEditingController();
  final _orderNo = TextEditingController();
  final _dueDate = TextEditingController();
  final _projectManager = TextEditingController();
  final _technicians = TextEditingController();
  final _salesPerson = TextEditingController();
  final _blockName = TextEditingController();
  final _sectionName = TextEditingController();

  List<QuotationPlotGroup> _plotGroups = [
    const QuotationPlotGroup(
      name: 'No Plot',
      lines: [
        QuotationPlotLine(label: 'Quotation Map', quantityMultiplier: 4, amount: 0),
        QuotationPlotLine(label: 'Quotation Map', amount: 0),
        QuotationPlotLine(label: 'Quotation Map', amount: 0),
      ],
    ),
  ];
  bool _blockExpanded = true;

  late final QuillController _descriptionQuill = QuillController.basic();
  final _descriptionFocus = FocusNode();
  final _descriptionScroll = ScrollController();

  ClientModel? _client;
  SiteModel? _site;
  QuoteSummary? _project;

  List<ClientModel> _clients = const [];
  List<SiteModel> _sites = const [];
  List<QuoteSummary> _projects = const [];

  bool _loadingOptions = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDropdowns());
  }

  @override
  void dispose() {
    _quoteName.dispose();
    _costCentre.dispose();
    _primary.dispose();
    _secondary.dispose();
    _siteContact.dispose();
    _tags.dispose();
    _orderNo.dispose();
    _dueDate.dispose();
    _projectManager.dispose();
    _technicians.dispose();
    _salesPerson.dispose();
    _descriptionQuill.dispose();
    _descriptionFocus.dispose();
    _descriptionScroll.dispose();
    _blockName.dispose();
    _sectionName.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _loadingOptions = true);
    try {
      final clientsApi = ref.read(clientsApiClientProvider);
      final sitesApi = ref.read(sitesApiClientProvider);
      final quotesApi = ref.read(crmQuotesApiProvider);
      final clients = await clientsApi.fetchClientsPage(page: 1);
      final sites = await sitesApi.fetchSitesPage(page: 1);
      final quotes = await quotesApi.fetchQuotesPage(1);
      if (!mounted) return;
      setState(() {
        _clients = clients.items;
        _sites = sites.items;
        _projects = quotes.summaries;
        _loadingOptions = false;
      });
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

  Map<String, dynamic> _plotGroupToJson(QuotationPlotGroup g) {
    double sub = 0;
    for (final l in g.lines) {
      if (l.selected) sub += l.amount;
    }
    return <String, dynamic>{
      'name': g.name,
      'line_items': g.lines.map((l) => _plotLineToJson(l)).toList(),
      'subtotal': sub,
      'tax': 0.0,
      'total': sub,
    };
  }

  Map<String, dynamic> _plotLineToJson(QuotationPlotLine l) {
    final desc = (l.quantityMultiplier != null && l.quantityMultiplier! > 0)
        ? '${l.label} (x${l.quantityMultiplier})'
        : l.label;
    return <String, dynamic>{
      'description': desc,
      'amount': l.amount,
      'selected': l.selected,
    };
  }

  void _addPlotSection() {
    if (_submitting) return;
    final name = _sectionName.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _plotGroups = [
        ..._plotGroups,
        QuotationBlockSectionsPanel.emptyGroupFromSectionName(name),
      ];
      _sectionName.clear();
    });
  }

  void _removePlotGroup(int index) {
    if (_submitting) return;
    if (_plotGroups.length <= 1) return;
    setState(() {
      _plotGroups = [
        for (var i = 0; i < _plotGroups.length; i++)
          if (i != index) _plotGroups[i],
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

  Map<String, dynamic> _buildPayload() {
    final body = <String, dynamic>{
      'quote_name': _quoteName.text.trim(),
      'cost_centre': _costCentre.text.trim(),
      'primary_customer_contact': _primary.text.trim(),
      'secondary_customer_contact': _secondary.text.trim(),
      'site_contact': _siteContact.text.trim(),
      'tags': _tags.text.trim(),
      'order_no': _orderNo.text.trim(),
      'due_date': _dueDate.text.trim(),
      'project_manager': _projectManager.text.trim(),
      'technicians': _technicians.text.trim(),
      'sales_person': _salesPerson.text.trim(),
      'description': _descriptionQuill.document.toPlainText().trim(),
    };
    if (_client != null) body['client'] = _client!.id;
    if (_site != null) body['site'] = _site!.id;
    if (_project != null) body['project'] = _project!.id;
    final block = _blockName.text.trim();
    body['blocks'] = block.isEmpty
        ? <dynamic>[]
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'name': block,
              'sections': _plotGroups.map((g) => _plotGroupToJson(g)).toList(),
            },
          ];
    body.removeWhere((key, value) {
      if (key == 'blocks') return false;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });
    return body;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_project == null) {
      context.showTopSnackBar(const SnackBar(content: Text('Select a project')));
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
      style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
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
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: [
                          _sectionLabel('Basic info'),
                          _label('Quote Name', required: true),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _quoteName,
                            hintText: 'e.g. Apex Structural Group',
                            validator: _required('Quote name'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Project Name', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<QuoteSummary>(
                            key: ValueKey(_project?.id ?? 'none'),
                            initialValue: _project,
                            isExpanded: true,
                            hint: const Text('e.g. John Doe'),
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
                                : (v) => setState(() => _project = v),
                          ),
                          const SizedBox(height: 14),
                          _label('Client Name', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ClientModel>(
                            key: ValueKey(_client?.id ?? 'none'),
                            initialValue: _client,
                            isExpanded: true,
                            hint: const Text('e.g. Apex Structural Group'),
                            decoration: _dropdownDecoration(),
                            items: _clients
                                .map(
                                  (c) => DropdownMenuItem<ClientModel>(
                                    value: c,
                                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _client = v),
                          ),
                          const SizedBox(height: 14),
                          _label('Site', required: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<SiteModel>(
                            key: ValueKey(_site?.id ?? 'none'),
                            initialValue: _site,
                            isExpanded: true,
                            hint: const Text('e.g. Apex Structural Group'),
                            decoration: _dropdownDecoration(),
                            items: _sites
                                .map(
                                  (s) => DropdownMenuItem<SiteModel>(
                                    value: s,
                                    child: Text(s.siteName, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _site = v),
                          ),
                          const SizedBox(height: 14),
                          _label('Cost Centre', required: true),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _costCentre,
                            hintText: 'e.g. Apex Structural Group',
                            validator: _required('Cost centre'),
                            textInputAction: TextInputAction.next,
                          ),
                          _sectionLabel('Contact'),
                          _label('Primary Customer Contact'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _primary,
                            hintText: '+1 (555) 000-0000',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Secondary Customer Contact'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _secondary,
                            hintText: '+1 (555) 000-0000',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Site Contact'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _siteContact,
                            hintText: '+1 (555) 000-0000',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          _sectionLabel('Additional information'),
                          _label('Tags'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _tags,
                            hintText: 'Tags',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Order No.'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _orderNo,
                            hintText: 'Order number',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Due Date'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _dueDate,
                            hintText: 'YYYY-MM-DD',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Project Manager'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _projectManager,
                            hintText: 'Suite, unit, etc. (optional)',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Technicians'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _technicians,
                            hintText: 'Technicians',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Sales Person'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _salesPerson,
                            hintText: 'Sales Person',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Description'),
                          const SizedBox(height: 8),
                          IgnorePointer(
                            ignoring: _submitting,
                            child: buildQuotationDescriptionRichField(
                              quillController: _descriptionQuill,
                              editorFocusNode: _descriptionFocus,
                              editorScrollController: _descriptionScroll,
                            ),
                          ),
                          _sectionLabel('Project'),
                          _label('Block name'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _blockName,
                            hintText: 'Optional block label',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          QuotationBlockSectionsPanel(
                            blockNameController: _blockName,
                            sectionNameController: _sectionName,
                            plotGroups: _plotGroups,
                            blockExpanded: _blockExpanded,
                            onBlockExpandedChanged: (v) {
                              if (_submitting) return;
                              setState(() => _blockExpanded = v);
                            },
                            onAddSection: _addPlotSection,
                            onLineSelectionChanged: _setLineSelected,
                            onRemovePlotGroup: _removePlotGroup,
                            submitting: _submitting,
                          ),
                        ],
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
                                  style: AppFonts.titleMedium(color: AppColors.white)
                                      .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
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
