import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/places/place_address.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/contacts/presentation/views/add_contact_page.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';

class _SiteContactDraft {
  _SiteContactDraft({this.title, this.contactId});

  String? title;
  String? contactId;
}

class AddSitePage extends ConsumerStatefulWidget {
  const AddSitePage({super.key, this.existing});

  /// When non-null the form opens in edit mode pre-filled with [existing] and
  /// submits a `PATCH /site/{id}/` instead of a `POST /site/`.
  final SiteModel? existing;

  static const path = '/sites/add';
  static const name = 'add-site';

  @override
  ConsumerState<AddSitePage> createState() => _AddSitePageState();
}

class _AddSitePageState extends ConsumerState<AddSitePage> {
  final _formKey = GlobalKey<FormState>();

  final _siteName = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _what3Words = TextEditingController();

  String _country = 'United States';
  bool _isSubmitting = false;

  final List<ClientModel> _clients = <ClientModel>[];
  bool _clientsLoading = true;
  String? _clientsError;
  String? _selectedClientId;

  final List<ContactModel> _clientContacts = <ContactModel>[];
  bool _contactsLoading = false;
  String? _contactsError;
  final List<_SiteContactDraft> _contactRows = <_SiteContactDraft>[];

  bool get _isEditing => widget.existing != null;

  static final _countries = <String>[
    'United States',
    'India',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  static const _contactTitles = <String>[
    'Primary',
    'Site Manager',
    'Technical',
    'Billing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _siteName.text = existing.siteName;
      if (existing.clientId != null) {
        _selectedClientId = existing.clientId!.toString();
      }
      _address1.text = existing.addressLine1;
      _address2.text = existing.addressLine2;
      _city.text = existing.city;
      _state.text = existing.state;
      _postalCode.text = existing.postalCode;
      _what3Words.text = existing.what3Words;
      final country = existing.country.trim();
      if (country.isNotEmpty) {
        _country = _countries.contains(country) ? country : _countries.first;
      }
      for (final person in existing.contactPersons) {
        _contactRows.add(
          _SiteContactDraft(
            title: person.title.trim().isEmpty ? null : person.title.trim(),
            contactId:
                person.contactId.trim().isEmpty ? null : person.contactId.trim(),
          ),
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadClients();
      final clientId = _selectedClientId?.trim();
      if (clientId != null && clientId.isNotEmpty) {
        await _loadClientContacts(clientId);
      }
    });
  }

  Future<void> _loadClients() async {
    setState(() {
      _clientsLoading = true;
      _clientsError = null;
    });
    try {
      final api = ref.read(clientsApiClientProvider);
      final all = <ClientModel>[];
      var page = 1;
      var totalPages = 1;
      do {
        final result = await api.fetchClientsPage(page: page);
        all.addAll(result.items);
        totalPages = result.totalPages;
        page++;
      } while (page <= totalPages && page <= 50);

      if (!mounted) return;
      setState(() {
        _clients
          ..clear()
          ..addAll(all);
        _clientsLoading = false;
        _clientsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _clientsLoading = false;
        _clientsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load clients',
        );
      });
    }
  }

  Future<void> _loadClientContacts(String clientId) async {
    final id = clientId.trim();
    if (id.isEmpty) {
      setState(() {
        _clientContacts.clear();
        _contactsLoading = false;
        _contactsError = null;
      });
      return;
    }

    setState(() {
      _contactsLoading = true;
      _contactsError = null;
    });
    try {
      final contacts = await ref
          .read(contactsApiClientProvider)
          .fetchClientContacts(clientId: id);
      if (!mounted) return;
      setState(() {
        _clientContacts
          ..clear()
          ..addAll(contacts);
        _contactsLoading = false;
        _contactsError = null;
        _pruneInvalidContactSelections();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
        _contactsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load contacts',
        );
      });
    }
  }

  void _pruneInvalidContactSelections() {
    final allowed = _clientContacts.map((c) => c.id.trim()).toSet();
    for (final row in _contactRows) {
      final selected = row.contactId?.trim();
      if (selected != null && selected.isNotEmpty && !allowed.contains(selected)) {
        row.contactId = null;
      }
    }
  }

  Future<void> _onClientChanged(String? value) async {
    setState(() {
      _selectedClientId = value;
      _contactRows.clear();
      _clientContacts.clear();
      _contactsError = null;
    });
    final id = value?.trim();
    if (id != null && id.isNotEmpty) {
      await _loadClientContacts(id);
    }
  }

  void _addContactRow() {
    setState(() => _contactRows.add(_SiteContactDraft()));
  }

  void _removeContactRow(int index) {
    if (index < 0 || index >= _contactRows.length) return;
    setState(() => _contactRows.removeAt(index));
  }

  Future<void> _openAddContactPerson() async {
    final clientId = _selectedClientId?.trim();
    if (clientId == null || clientId.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Select a client first')),
      );
      return;
    }

    final created = await context.push<ContactModel>(
      AddContactPage.path,
      extra: <String, dynamic>{'presetClientId': clientId},
    );
    if (!mounted) return;
    await _loadClientContacts(clientId);
    if (!mounted) return;
    if (created != null && created.id.trim().isNotEmpty) {
      setState(() {
        _contactRows.add(
          _SiteContactDraft(
            title: _contactTitles.first,
            contactId: created.id.trim(),
          ),
        );
      });
    }
  }

  List<DropdownMenuItem<String>> _clientDropdownItems() {
    final existing = widget.existing;
    final items = <DropdownMenuItem<String>>[];
    final seen = <String>{};

    if (existing != null) {
      final id = existing.clientId?.toString().trim() ?? '';
      if (id.isNotEmpty && !_clients.any((c) => c.id == id)) {
        items.add(
          DropdownMenuItem<String>(
            value: id,
            child: Text(
              existing.clientName.trim().isEmpty
                  ? 'Client #$id'
                  : existing.clientName,
            ),
          ),
        );
        seen.add(id);
      }
    }

    for (final c in _clients) {
      if (seen.contains(c.id)) continue;
      items.add(
        DropdownMenuItem<String>(
          value: c.id,
          child: Text(c.name.trim().isEmpty ? 'Client #${c.id}' : c.name),
        ),
      );
      seen.add(c.id);
    }
    return items;
  }

  String? _clientDropdownValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Select a client';
    return null;
  }

  String? _effectiveClientDropdownValue() {
    final id = _selectedClientId?.trim();
    if (id == null || id.isEmpty) return null;
    final allowed = _clientDropdownItems()
        .map((e) => e.value)
        .whereType<String>()
        .toSet();
    return allowed.contains(id) ? id : null;
  }

  List<SiteContactPerson> _buildContactPersonsPayload() {
    final byId = {
      for (final c in _clientContacts) c.id.trim(): c,
    };
    final out = <SiteContactPerson>[];
    for (final row in _contactRows) {
      final contactId = row.contactId?.trim() ?? '';
      if (contactId.isEmpty) continue;
      final title = (row.title ?? '').trim();
      out.add(
        SiteContactPerson(
          title: title.isEmpty ? _contactTitles.first : title,
          contactId: contactId,
          contactName: byId[contactId]?.contactName ?? '',
        ),
      );
    }
    return out;
  }

  @override
  void dispose() {
    _siteName.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    _what3Words.dispose();
    super.dispose();
  }

  String? Function(String?) _requiredField(String fieldName) {
    return (value) {
      if ((value ?? '').trim().isEmpty) return '$fieldName is required';
      return null;
    };
  }

  String? _postalCodeValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Postal / ZIP code is required';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final clientId = _selectedClientId?.trim();
    if (clientId == null || clientId.isEmpty) return;

    for (var i = 0; i < _contactRows.length; i++) {
      final row = _contactRows[i];
      final hasTitle = (row.title ?? '').trim().isNotEmpty;
      final hasContact = (row.contactId ?? '').trim().isNotEmpty;
      if (hasTitle != hasContact) {
        context.showTopSnackBar(
          SnackBar(
            content: Text(
              hasTitle
                  ? 'Select a contact person for row ${i + 1}'
                  : 'Select a title for row ${i + 1}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(sitesApiClientProvider);
      final existing = widget.existing;
      final contactPersons = _buildContactPersonsPayload();
      final saved = existing == null
          ? await api.createSite(
              siteName: _siteName.text.trim(),
              clientId: clientId,
              addressLine1: _address1.text.trim(),
              addressLine2: _address2.text.trim(),
              country: _country.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              postalCode: _postalCode.text.trim(),
              what3Words: _what3Words.text.trim(),
              contactPersons: contactPersons,
            )
          : await api.updateSite(
              id: existing.id,
              siteName: _siteName.text.trim(),
              clientId: clientId,
              addressLine1: _address1.text.trim(),
              addressLine2: _address2.text.trim(),
              country: _country.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              postalCode: _postalCode.text.trim(),
              what3Words: _what3Words.text.trim(),
              contactPersons: contactPersons,
            );
      if (!mounted) return;
      context.pop<SiteModel>(saved);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: _isEditing
                  ? 'Failed to update site'
                  : 'Failed to create site',
            ),
          ),
        ),
      );
      setState(() => _isSubmitting = false);
    }
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

  InputDecoration _dropdownDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Widget _buildClientField() {
    if (_clientsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_clientsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _clientsError!,
            style: AppFonts.bodySmall(color: const Color(0xFFE53935)),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _loadClients,
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (_clientDropdownItems().isEmpty) {
      return Text(
        'No clients found. Create a client first.',
        style: AppFonts.bodySmall(color: const Color(0xFF8A8A8A)),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey<String>('${_selectedClientId ?? ''}|${_clients.length}'),
      initialValue: _effectiveClientDropdownValue(),
      items: _clientDropdownItems(),
      onChanged: _isSubmitting ? null : _onClientChanged,
      validator: _clientDropdownValidator,
      decoration: _dropdownDecoration(hintText: 'Select client'),
      hint: const Text('Select client'),
    );
  }

  Widget _buildContactPersonsSection() {
    final clientId = _selectedClientId?.trim();
    final hasClient = clientId != null && clientId.isNotEmpty;
    final hasContacts = _clientContacts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Contact persons',
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            if (hasClient && hasContacts)
              TextButton.icon(
                onPressed: _isSubmitting ? null : _addContactRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add contact person'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkStrong,
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!hasClient)
          Text(
            'Select a client to manage contact persons.',
            style: AppFonts.bodySmall(color: AppColors.muted),
          )
        else if (_contactsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (_contactsError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _contactsError!,
                style: AppFonts.bodySmall(color: const Color(0xFFE53935)),
              ),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _loadClientContacts(clientId),
                child: const Text('Retry'),
              ),
            ],
          )
        else if (!hasContacts)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This client has no contacts yet.',
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a contact person for this client, then assign them here.',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _openAddContactPerson,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add person'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkStrong,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
              ],
            ),
          )
        else if (_contactRows.isEmpty)
          Text(
            'No contact persons added. Tap “Add contact person” to assign one.',
            style: AppFonts.bodySmall(color: AppColors.muted),
          )
        else
          ...List.generate(_contactRows.length, (index) {
            final row = _contactRows[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _contactRows.length - 1 ? 0 : 12,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Title'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey('title-$index-${row.title}'),
                            initialValue: row.title != null &&
                                    _contactTitles.contains(row.title)
                                ? row.title
                                : null,
                            items: _contactTitles
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) => setState(() => row.title = value),
                            decoration: _dropdownDecoration(
                              hintText: 'Select title',
                            ),
                            hint: const Text('Select title'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Contact person'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'contact-$index-${row.contactId}|${_clientContacts.length}',
                            ),
                            initialValue: () {
                              final id = row.contactId?.trim();
                              if (id == null || id.isEmpty) return null;
                              return _clientContacts.any((c) => c.id == id)
                                  ? id
                                  : null;
                            }(),
                            items: _clientContacts
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.contactName.trim().isEmpty
                                          ? 'Contact #${c.id}'
                                          : c.contactName,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) =>
                                    setState(() => row.contactId = value),
                            decoration: _dropdownDecoration(
                              hintText: 'Select contact',
                            ),
                            hint: const Text('Select contact'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _removeContactRow(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFF8A8A8A),
                      ),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            );
          }),
        if (hasClient && hasContacts) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : _openAddContactPerson,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Create new contact'),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkStrong),
            ),
          ),
        ],
      ],
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
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          _isEditing ? 'Edit Site' : 'Add Site',
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
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    _label('Site name', required: true),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _siteName,
                      hintText: 'e.g. Apex Structural Group',
                      validator: _requiredField('Site name'),
                    ),
                    const SizedBox(height: 14),
                    _label('Client', required: true),
                    const SizedBox(height: 8),
                    _buildClientField(),
                    const SizedBox(height: 14),
                    AppAddressFields(
                      line1: _address1,
                      line2: _address2,
                      city: _city,
                      state: _state,
                      postalCode: _postalCode,
                      enabled: !_isSubmitting,
                      layout: AppAddressLayout.lineCountryPostal,
                      line1Hint: 'Search address...',
                      line2Hint: 'Suite, unit, etc. (optional)',
                      postalCodeHint: 'ZIP or Postal Code',
                      postalCodeLabel: 'Postal / ZIP code',
                      line1Validator: _requiredField('Address line 1'),
                      postalCodeValidator: _postalCodeValidator,
                      countryDropdownValue: _countries.contains(_country)
                          ? _country
                          : _countries.first,
                      countryDropdownOptions: _countries,
                      onCountryDropdownChanged: (value) =>
                          setState(() => _country = value),
                      dropdownDecoration: _dropdownDecoration(
                        hintText: 'Select country',
                      ),
                      labelBuilder: (text, {required = false}) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(text, required: required),
                          const SizedBox(height: 8),
                        ],
                      ),
                      onCountryResolved: (country) {
                        final matched =
                            matchCountryOption(country, _countries) ?? country;
                        setState(() {
                          if (!_countries.contains(matched)) {
                            _countries.insert(0, matched);
                          }
                          _country = matched;
                        });
                      },
                    ),
                    _label('What3words'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _what3Words,
                      hintText: 'e.g. filled.count.soap',
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 22),
                    _buildContactPersonsSection(),
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
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: const Color(
                        0xFF111111,
                      ).withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save' : 'Create',
                            style: AppFonts.titleMedium(color: AppColors.white)
                                .copyWith(
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
}
