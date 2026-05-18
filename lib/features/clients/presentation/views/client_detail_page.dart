import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/clients/presentation/views/add_client_page.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/contacts/presentation/views/add_contact_page.dart';
import 'package:red5/features/contacts/presentation/views/contact_detail_page.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  static const pathPrefix = '/clients';
  static const name = 'client-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage>
    with SingleTickerProviderStateMixin {
  ClientModel? _client;
  bool _isLoading = true;
  String? _error;

  late final TabController _tabController;

  List<QuoteSummary> _projects = const [];
  bool _projectsLoading = false;
  String? _projectsError;
  final TextEditingController _projectSearchController = TextEditingController();

  List<ContactModel> _contacts = const [];
  bool _contactsLoading = false;
  String? _contactsError;
  final TextEditingController _contactSearchController = TextEditingController();

  static const _labelGrey = Color(0xFF9CA3AF);
  static const _searchBg = Color(0xFFEFEEF0);
  static const _metaMuted = Color(0xFF8B8B8B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _projectSearchController.addListener(() => setState(() {}));
    _contactSearchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectSearchController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.clientId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid client id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(clientsApiClientProvider);
      final data = await api.fetchClientDetail(id);
      if (!mounted) return;
      setState(() {
        _client = data;
        _isLoading = false;
      });
      await Future.wait<void>([
        _loadProjectsForClient(data),
        _loadContactsForClient(data),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load client details',
        );
      });
    }
  }

  bool _contactBelongsToClient(ContactModel co, ClientModel cl) {
    final want = cl.id.trim();
    final got = co.clientId.trim();
    if (want.isEmpty) return false;
    if (got == want) return true;
    final wn = int.tryParse(want);
    final gn = int.tryParse(got);
    if (wn != null && gn != null && wn == gn) return true;
    return false;
  }

  Future<void> _loadContactsForClient(ClientModel client) async {
    setState(() {
      _contactsLoading = true;
      _contactsError = null;
    });
    try {
      final api = ref.read(contactsApiClientProvider);
      final merged = <String, ContactModel>{};
      var page = 1;
      var totalPages = 1;
      const maxPages = 40;
      do {
        final r = await api.fetchContactsPage(page: page);
        for (final c in r.items) {
          if (_contactBelongsToClient(c, client)) {
            merged[c.id] = c;
          }
        }
        totalPages = r.totalPages;
        page++;
      } while (page <= totalPages && page <= maxPages);

      if (!mounted) return;
      final list = merged.values.toList()
        ..sort(
          (a, b) =>
              a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase()),
        );
      setState(() {
        _contacts = list;
        _contactsLoading = false;
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

  Future<void> _loadProjectsForClient(ClientModel client) async {
    final nameKey = client.name.trim().toLowerCase();
    if (nameKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _projects = const [];
        _projectsLoading = false;
      });
      return;
    }
    setState(() {
      _projectsLoading = true;
      _projectsError = null;
    });
    try {
      final api = ref.read(crmQuotesApiProvider);
      final all = <QuoteSummary>[];
      var page = 1;
      var totalPages = 1;
      do {
        final r = await api.fetchQuotesPage(page);
        for (final p in r.summaries) {
          final cn = (p.clientName ?? '').trim().toLowerCase();
          if (cn.isNotEmpty && cn == nameKey) all.add(p);
        }
        totalPages = r.totalPages;
        page++;
      } while (page <= totalPages && page <= 50);

      if (!mounted) return;
      setState(() {
        _projects = all;
        _projectsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsLoading = false;
        _projectsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load projects',
        );
      });
    }
  }

  Future<void> _onEditClient() async {
    final c = _client;
    if (c == null) return;
    final updated = await context.push<ClientModel>(
      AddClientPage.pathForEdit(c.id),
      extra: c,
    );
    if (!mounted || updated == null) return;
    setState(() => _client = updated);
    await Future.wait<void>([
      _loadProjectsForClient(updated),
      _loadContactsForClient(updated),
    ]);
  }

  Future<void> _openCreateProject() async {
    final c = _client;
    if (c == null) return;
    await context.push(
      CreateProjectPage.path,
      extra: <String, dynamic>{
        'clientId': int.tryParse(c.id.trim()),
        'clientName': c.name,
      },
    );
    if (mounted) await _loadProjectsForClient(c);
  }

  Future<void> _openAddContact() async {
    final c = _client;
    if (c == null) return;
    await context.push(
      AddContactPage.path,
      extra: <String, dynamic>{'presetClientId': c.id.trim()},
    );
    if (mounted) await _loadContactsForClient(c);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 18, height: 1.2),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.labelMedium(color: _labelGrey).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        fontSize: 10,
      ),
    );
  }

  Widget _fieldValue(String text) {
    return Text(
      text.trim().isEmpty ? '—' : text.trim(),
      style: AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16, height: 1.35),
    );
  }

  Widget _fullRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 5),
          _fieldValue(value),
        ],
      ),
    );
  }

  Widget _halfRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(leftLabel),
                const SizedBox(height: 5),
                _fieldValue(leftValue),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(rightLabel),
                const SizedBox(height: 5),
                _fieldValue(rightValue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(ClientModel c) {
    final active = c.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: AppFonts.labelMedium(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        ).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.65,
        ),
      ),
    );
  }

  String _streetDisplay(ClientModel c) {
    final a = c.addressLine1.trim();
    final b = c.addressLine2.trim();
    if (a.isEmpty && b.isEmpty) return '—';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a, $b';
  }

  String _contactAddressLine(ContactModel c) {
    final line1 = [c.addressLine1, c.addressLine2]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final cityStateZip = [
      c.city.trim(),
      c.state.trim(),
      c.postalCode.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final parts = <String>[];
    if (line1.isNotEmpty) parts.add(line1);
    if (cityStateZip.isNotEmpty) parts.add(cityStateZip);
    if (c.country.trim().isNotEmpty) parts.add(c.country.trim());
    if (parts.isEmpty) return '—';
    return parts.join(', ');
  }

  Widget _overviewBody(ClientModel c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionTitle('Basic Info'),
        _statusBadge(c),
        const SizedBox(height: 14),
        _fullRow('Client name', c.name),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Primary Contact'),
        _fullRow('Contact person', c.contactPerson),
        _fullRow('Email', c.email),
        _fullRow('Phone', c.phone),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Address'),
        _fullRow('Street address', _streetDisplay(c)),
        _halfRow('City', c.city, 'State / Province', c.state),
        _halfRow('Postal code', c.pincode, 'Country', c.country),
      ],
    );
  }

  List<ContactModel> get _filteredContacts {
    final q = _contactSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) {
      return c.contactName.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          _contactAddressLine(c).toLowerCase().contains(q);
    }).toList();
  }

  List<QuoteSummary> get _filteredProjects {
    final q = _projectSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _projects;
    return _projects.where((p) {
      final name = p.quoteName.toLowerCase();
      final site = (p.projectName ?? '').toLowerCase();
      return name.contains(q) || site.contains(q);
    }).toList();
  }

  Widget _contactMeta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _metaMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.trim().isEmpty ? '—' : text.trim(),
              style: AppFonts.bodyMedium(color: _metaMuted).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(ContactModel co, ClientModel client) {
    final id = co.id.trim();
    final canOpen = id.isNotEmpty;
    return InkWell(
      onTap: !canOpen
          ? null
          : () async {
              await context.push(ContactDetailPage.pathFor(id));
              if (mounted) await _loadContactsForClient(client);
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    co.contactName.trim().isEmpty ? 'Contact' : co.contactName,
                    style: AppFonts.titleMedium(color: AppColors.inkStrong)
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.2,
                        ),
                  ),
                  _contactMeta(Icons.mail_outline_rounded, co.email),
                  _contactMeta(Icons.phone_outlined, co.phone),
                  _contactMeta(Icons.place_outlined, _contactAddressLine(co)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactsTabBody(ClientModel c) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Contacts',
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _openAddContact,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE9E9EA),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.inkStrong,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: TextField(
                controller: _contactSearchController,
                style: AppFonts.bodyLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: _searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF111111),
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF8A8A8A),
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadContactsForClient(c),
                color: const Color(0xFF121212),
                child: _contactsLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: AppSkeletonScreenBody(
                              style: AppSkeletonScreenBodyStyle.listRows,
                              listRowCount: 8,
                            ),
                          ),
                        ],
                      )
                    : _contactsError != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.35,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _contactsError!,
                              textAlign: TextAlign.center,
                              style: AppFonts.bodyMedium(color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: FilledButton(
                              onPressed: () => _loadContactsForClient(c),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      )
                    : _filteredContacts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: Center(
                              child: Text(
                                'No contacts for this client',
                                style: AppFonts.bodyMedium(color: AppColors.muted),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE3E3E4),
                        ),
                        itemBuilder: (context, index) {
                          return _contactRow(_filteredContacts[index], c);
                        },
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'client_contacts_fab',
            backgroundColor: const Color(0xFF111111),
            foregroundColor: AppColors.white,
            onPressed: _openAddContact,
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _projectRow(QuoteSummary p, ClientModel client) {
    final id = p.id.trim();
    final site = (p.projectName ?? '').trim();
    final subtitle = site.isNotEmpty ? site : '—';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id.isEmpty
            ? null
            : () async {
                await context.push(ProjectDetailsPage.pathFor(id), extra: p);
                if (mounted) await _loadProjectsForClient(client);
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.quoteName.trim().isEmpty ? 'Project' : p.quoteName,
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectsTabBody(ClientModel c) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Projects',
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _openCreateProject,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE9E9EA),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.inkStrong,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: TextField(
                controller: _projectSearchController,
                style: AppFonts.bodyLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search projects...',
                  hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: _searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF111111),
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF8A8A8A),
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadProjectsForClient(c),
                color: const Color(0xFF121212),
                child: _projectsLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : _projectsError != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.35,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _projectsError!,
                              textAlign: TextAlign.center,
                              style: AppFonts.bodyMedium(color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: FilledButton(
                              onPressed: () => _loadProjectsForClient(c),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      )
                    : _filteredProjects.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.4,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No projects linked to this client yet.',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.bodyMedium(
                                        color: AppColors.muted,
                                      ).copyWith(
                                        fontSize: 15,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: _openCreateProject,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF111111,
                                        ),
                                        foregroundColor: AppColors.white,
                                      ),
                                      child: const Text('Create project'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _filteredProjects.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE3E3E4),
                        ),
                        itemBuilder: (context, index) {
                          return _projectRow(_filteredProjects[index], c);
                        },
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'client_projects_fab',
            backgroundColor: const Color(0xFF111111),
            foregroundColor: AppColors.white,
            onPressed: _openCreateProject,
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _client?.name.isNotEmpty == true ? _client!.name : 'Client';
    final hasData = !_isLoading && _error == null && _client != null;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasData ? _onEditClient : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasData ? 50 : 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasData)
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: AppColors.inkStrong,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.inkStrong,
                  indicatorWeight: 2.2,
                  labelStyle: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Contacts'),
                    Tab(text: 'Projects'),
                  ],
                ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 4,
              ),
            )
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
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _client == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _overviewBody(_client!),
                _contactsTabBody(_client!),
                _projectsTabBody(_client!),
              ],
            ),
    );
  }
}
