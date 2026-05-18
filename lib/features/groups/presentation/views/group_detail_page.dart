import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/groups/data/group_date_format.dart';
import 'package:red5/features/groups/data/group_models.dart';
import 'package:red5/features/groups/data/groups_api_client.dart';
import 'package:red5/features/groups/presentation/views/add_group_page.dart';

/// Read-only details view for a single group. Loads via `GET /group/{id}/`.
class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});

  static const pathPrefix = '/groups';
  static const name = 'group-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String groupId;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  GroupModel? _group;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.groupId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid group id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(groupsApiClientProvider);
      final data = await api.fetchGroupDetail(id);
      if (!mounted) return;
      setState(() {
        _group = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load group details',
        );
      });
    }
  }

  Future<void> _openEdit() async {
    final current = _group;
    if (current == null) return;
    final updated = await Navigator.of(context).push<GroupModel>(
      MaterialPageRoute(
        settings: const RouteSettings(name: AddGroupPage.name),
        builder: (_) => AddGroupPage(existing: current),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _group = updated);
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

  Widget _statusPill(bool isActive) {
    final color = isActive ? const Color(0xFF12A150) : const Color(0xFF6B7280);
    final bg = isActive ? const Color(0xFFE6F7EE) : const Color(0xFFEDEEF0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'IN ACTIVE',
        style: AppFonts.labelMedium(color: color).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _createdBy(GroupModel g) {
    final name = g.createdByName.trim();
    final email = g.createdByEmail.trim();
    if (name.isEmpty && email.isEmpty) return const Text('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        if (email.isNotEmpty)
          Text(
            email,
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 14),
          ),
      ],
    );
  }

  Widget _modifiedBy(GroupModel g) {
    final name = g.modifiedByName.trim();
    final email = g.modifiedByEmail.trim();
    if (name.isEmpty && email.isEmpty) {
      return Text(
        '—',
        style: AppFonts.bodyMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        if (email.isNotEmpty)
          Text(
            email,
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 14),
          ),
      ],
    );
  }

  Widget _compositeItemBlock(GroupItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelValue('Composite Item', item.compositeItem.name),
          const SizedBox(height: 10),
          _labelValue('Abbreviation', item.abbreviation),
        ],
      ),
    );
  }

  Widget _buildContent(GroupModel g) {
    final compositeBlocks = <Widget>[];
    for (var i = 0; i < g.items.length; i++) {
      compositeBlocks.add(_compositeItemBlock(g.items[i]));
      if (i != g.items.length - 1) {
        compositeBlocks.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: Color(0xFFE2E2E4)),
          ),
        );
      }
    }
    if (compositeBlocks.isEmpty) {
      compositeBlocks.add(
        Text(
          'No composite items',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name.isEmpty ? 'Group Name' : g.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.headlineSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Composite items',
                      style: AppFonts.bodyMedium(
                        color: AppColors.muted,
                      ).copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _statusPill(g.isActive),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E2E4)),
          _sectionHeader('Basic Info'),
          _labelValue('Group Name', g.name),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E2E4)),
          _sectionHeader('Composite items'),
          ...compositeBlocks,
          const SizedBox(height: 4),
          const Divider(height: 1, color: Color(0xFFE2E2E4)),
          _sectionHeader('Record'),
          _labelValue('Created At', formatGroupDate(g.createdAt)),
          const SizedBox(height: 14),
          _labelValue('Updated At', formatGroupDate(g.updatedAt)),
          const SizedBox(height: 14),
          Text(
            'CREATED BY',
            style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          _createdBy(g),
          const SizedBox(height: 14),
          Text(
            'MODIFIED BY',
            style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          _modifiedBy(g),
        ],
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
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Group Detail Page',
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
                onTap: _isLoading || _group == null ? null : _openEdit,
                child: Padding(
                  padding: EdgeInsets.all(8),
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
          ? Center(
              child: const AppSkeletonScreenBody(
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
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(_group!),
    );
  }
}
