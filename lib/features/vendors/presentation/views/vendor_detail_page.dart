import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/presentation/views/add_vendor_page.dart';

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({super.key, required this.vendorId});

  static const pathPrefix = '/vendors';
  static const name = 'vendor-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String vendorId;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage>
    with SingleTickerProviderStateMixin {
  static const _labelGrey = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFE5E7EB);
  static const _searchBg = Color(0xFFEFEEF0);
  static const _metaMuted = Color(0xFF8B8B8B);

  late final TabController _tabController;
  late final VendorDetail _detail;
  final _contactSearchController = TextEditingController();
  final _projectSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detail = VendorMockData.detailForId(widget.vendorId);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _contactSearchController.addListener(() => setState(() {}));
    _projectSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contactSearchController.dispose();
    _projectSearchController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          height: 1.2,
        ),
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
      style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.35,
      ),
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

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFF1F1F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: AppFonts.labelMedium(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFF6B6B70),
        ).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.65,
        ),
      ),
    );
  }

  Widget _overviewTab(VendorDetail detail) {
    final addr = detail.address;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionTitle('Basic Info'),
        _statusBadge(detail.isActive),
        const SizedBox(height: 14),
        _fullRow('Client name', detail.name),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Primary Contact'),
        _fullRow('Contact person', detail.contactPerson),
        _fullRow('Email', detail.email),
        _fullRow('Phone', detail.phone),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Address'),
        _fullRow('Street address', addr.street),
        _halfRow('City', addr.city, 'State / Province', addr.state),
        _halfRow('Postal code', addr.postalCode, 'Country', addr.country),
      ],
    );
  }

  Widget _searchBar(TextEditingController controller, String hint) {
    final hasQuery = controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => controller.clear(),
                  icon: const Icon(Icons.cancel, color: Color(0xFF9CA3AF)),
                )
              : null,
        ),
      ),
    );
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

  List<VendorContactEntry> _filteredContacts(VendorDetail detail) {
    final q = _contactSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return detail.contacts;
    return detail.contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q) ||
              c.addressLine.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _contactTile(VendorContactEntry contact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.showAppTopToast(
            title: 'Contact detail coming soon',
            type: AppTopToastType.info,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    _contactMeta(Icons.email_outlined, contact.email),
                    _contactMeta(Icons.phone_outlined, contact.phone),
                    _contactMeta(Icons.location_on_outlined, contact.addressLine),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsTab(VendorDetail detail) {
    final contacts = _filteredContacts(detail);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('Contacts')),
                IconButton(
                  onPressed: () {
                    context.showAppTopToast(
                      title: 'Add contact coming soon',
                      type: AppTopToastType.info,
                    );
                  },
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.add, size: 18),
                  ),
                ),
              ],
            ),
            _searchBar(_contactSearchController, 'Search contacts...'),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No contacts found',
                    style: AppFonts.bodyMedium(color: _labelGrey),
                  ),
                ),
              )
            else
              for (final c in contacts) _contactTile(c),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'vendor_contacts_fab_${detail.id}',
            onPressed: () {
              context.showAppTopToast(
                title: 'Add contact coming soon',
                type: AppTopToastType.info,
              );
            },
            backgroundColor: const Color(0xFF121212),
            foregroundColor: AppColors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  List<VendorProjectEntry> _filteredProjects(VendorDetail detail) {
    final q = _projectSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return detail.projects;
    return detail.projects
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.siteName.toLowerCase().contains(q) ||
              p.status.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _projectTile(VendorProjectEntry project) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.showAppTopToast(
            title: 'Project detail coming soon',
            type: AppTopToastType.info,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.siteName,
                      style: AppFonts.bodyMedium(color: _metaMuted).copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.status,
                      style: AppFonts.bodyMedium(
                        color: const Color(0xFF2563EB),
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectsTab(VendorDetail detail) {
    final projects = _filteredProjects(detail);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionTitle('Projects'),
        _searchBar(_projectSearchController, 'Search projects...'),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No projects found',
                style: AppFonts.bodyMedium(color: _labelGrey),
              ),
            ),
          )
        else
          for (final p in projects) _projectTile(p),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          detail.name,
          style: AppFonts.titleLarge(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AddVendorPage.path),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.inkStrong,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.inkStrong,
                unselectedLabelColor: _labelGrey,
                indicatorColor: AppColors.inkStrong,
                indicatorWeight: 2.5,
                labelStyle: AppFonts.labelMedium(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: AppFonts.labelMedium(color: _labelGrey)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Contacts'),
                  Tab(text: 'Projects'),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: _divider),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _overviewTab(detail),
          _contactsTab(detail),
          _projectsTab(detail),
        ],
      ),
    );
  }
}
