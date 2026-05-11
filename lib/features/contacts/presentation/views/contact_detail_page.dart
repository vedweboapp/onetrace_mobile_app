import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/contacts/presentation/views/add_contact_page.dart';

/// Read-only details view for a single contact. Loads via `GET /contact/{id}/`.
class ContactDetailPage extends ConsumerStatefulWidget {
  const ContactDetailPage({super.key, required this.contactId});

  static const pathPrefix = '/contacts';
  static const name = 'contact-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String contactId;

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  ContactModel? _contact;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.contactId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid contact id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(contactsApiClientProvider);
      final data = await api.fetchContactDetail(id);
      if (!mounted) return;
      setState(() {
        _contact = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load contact details',
        );
      });
    }
  }

  Future<void> _openEdit() async {
    final current = _contact;
    if (current == null) return;
    final updated = await Navigator.of(context).push<ContactModel>(
      MaterialPageRoute(
        settings: const RouteSettings(name: AddContactPage.name),
        builder: (_) => AddContactPage(existing: current),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _contact = updated);
    }
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.trim().isEmpty ? '—' : value.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
        ),
      ],
    );
  }

  Widget _streetAddress(ContactModel c) {
    final hasLine2 = c.addressLine2.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STREET ADDRESS',
          style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          c.addressLine1.trim().isEmpty ? '—' : c.addressLine1.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        if (hasLine2) ...[
          const SizedBox(height: 2),
          Text(
            c.addressLine2.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 15),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(ContactModel c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Text(
          c.contactName.isEmpty ? 'Contact Name' : c.contactName,
          style: AppFonts.headlineSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          c.clientName.isEmpty ? 'Client Name' : c.clientName,
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Basic Info'),
        _labelValue('Contact Name', c.contactName),
        const SizedBox(height: 14),
        _labelValue('Client Name', c.clientName),
        if (c.client.contactPerson.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _labelValue('Client Contact Person', c.client.contactPerson),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Primary Contact'),
        _labelValue('Email', c.email),
        const SizedBox(height: 14),
        _labelValue('Phone', c.phone),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Address'),
        _streetAddress(c),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('City', c.city)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('State / Province', c.state)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('Postal Code', c.postalCode)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('Country', c.country)),
          ],
        ),
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
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Contact Detail Page',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: const Color(0xFFF1F1F2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLoading || _contact == null ? null : _openEdit,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    "assets/images/edit_icon.png",
                    color: AppColors.inkStrong,
                    height: 15,
                    width: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(_contact!),
    );
  }
}
