import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/form_metadata_detail_page.dart';
import 'package:red5/features/dashboard/presentation/widgets/assign_project_forms_sheet.dart';
import 'package:red5/features/forms/data/form_models.dart';
import 'package:red5/features/forms/data/form_picker_utils.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

enum ProjectFormsStatusFilter { active, inactive, all }

extension on ProjectFormsStatusFilter {
  String get label {
    switch (this) {
      case ProjectFormsStatusFilter.active:
        return 'Active';
      case ProjectFormsStatusFilter.inactive:
        return 'Inactive';
      case ProjectFormsStatusFilter.all:
        return 'All';
    }
  }

  bool? get apiIsActive {
    switch (this) {
      case ProjectFormsStatusFilter.active:
        return true;
      case ProjectFormsStatusFilter.inactive:
        return false;
      case ProjectFormsStatusFilter.all:
        return null;
    }
  }
}

/// Forms tab on [ProjectDetailsPage] — lists project forms and assign flow.
class ProjectFormsTab extends ConsumerStatefulWidget {
  const ProjectFormsTab({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  ConsumerState<ProjectFormsTab> createState() => _ProjectFormsTabState();
}

class _ProjectFormsTabState extends ConsumerState<ProjectFormsTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _isAssigning = false;
  String? _errorMessage;
  List<FormSummary> _forms = const [];
  ProjectFormsStatusFilter _statusFilter = ProjectFormsStatusFilter.active;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadForms();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  int? get _parsedProjectId => int.tryParse(widget.projectId.trim());

  Future<void> _loadForms() async {
    final projectId = _parsedProjectId;
    if (projectId == null) {
      setState(() {
        _forms = const [];
        _errorMessage = 'Invalid project id.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await ref.read(formsApiClientProvider).fetchProjectForms(
            projectId: projectId,
            isActive: _statusFilter.apiIsActive,
            pageSize: 100,
          );
      if (!mounted) return;
      setState(() {
        _forms = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load project forms',
        );
      });
    }
  }

  List<FormSummary> get _filteredForms {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _forms;
    return _forms
        .where(
          (form) =>
              form.name.toLowerCase().contains(q) ||
              (form.projectTypeLabel ?? '').toLowerCase().contains(q) ||
              (form.installationTypeLabel ?? '').toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<int> get _assignedTemplateIds => _forms
      .map((form) => form.templateFormId ?? form.id)
      .where((id) => id > 0)
      .toSet()
      .toList(growable: false);

  Future<void> _openAssignSheet() async {
    final projectId = _parsedProjectId;
    if (projectId == null) return;

    try {
      final catalog = await ref.read(formsApiClientProvider).fetchForms();
      if (!mounted) return;
      final options = catalog.toActivePickerOptions();
      if (options.isEmpty) {
        context.showTopSnackBar(
          const SnackBar(content: Text('No forms available to assign.')),
        );
        return;
      }

      final picked = await showAssignProjectFormsSheet(
        context: context,
        catalogForms: options,
        initiallySelectedTemplateIds: _assignedTemplateIds,
      );
      if (!mounted || picked == null) return;
      await _saveAssignedForms(picked);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not open assign forms',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveAssignedForms(List<int> templateFormIds) async {
    final projectId = widget.projectId.trim();
    if (projectId.isEmpty) return;

    setState(() => _isAssigning = true);
    try {
      await ref.read(quoteProjectApiClientProvider).patchProjectFormIds(
            projectId: projectId,
            formIds: templateFormIds,
          );
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            templateFormIds.isEmpty
                ? 'Project forms updated.'
                : 'Assigned ${templateFormIds.length} form${templateFormIds.length == 1 ? '' : 's'}.',
          ),
        ),
      );
      await _loadForms();
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not assign forms',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  void _onFormMenu(FormSummary form) {
    final templateId = form.templateFormId ?? form.id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          listTileTheme: const ListTileThemeData(
            iconColor: AppColors.inkStrong,
            textColor: AppColors.inkStrong,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  form.name,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.inkStrong,
                ),
                title: Text(
                  'View form metadata',
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                iconColor: AppColors.inkStrong,
                textColor: AppColors.inkStrong,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(FormMetadataDetailPage.pathFor(templateId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final visible = _filteredForms;

    return ColoredBox(
      color: AppColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Forms',
                      style: AppFonts.headlineSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
                    ),
                    const Spacer(),
                    Material(
                      color: const Color(0xFFECECEE),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _isAssigning ? null : _openAssignSheet,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: _isAssigning
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add,
                                  size: 22,
                                  color: AppColors.inkStrong,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search Forms...',
                    hintStyle: AppFonts.bodyMedium(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProjectFormsStatusFilter>(
                      value: _statusFilter,
                      borderRadius: BorderRadius.circular(12),
                      items: ProjectFormsStatusFilter.values
                          .map(
                            (filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _statusFilter = value);
                        unawaited(_loadForms());
                      },
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(visible)),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 20 + bottomPad,
            child: FloatingActionButton(
              onPressed: _isAssigning ? null : _openAssignSheet,
              backgroundColor: const Color(0xFF111111),
              foregroundColor: AppColors.white,
              child: _isAssigning
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.add, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<FormSummary> visible) {
    if (_isLoading && _forms.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMessage != null && _forms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadForms,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchController.text.trim().isEmpty
                ? 'No forms assigned to this project yet.'
                : 'No forms match your search.',
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadForms,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _ProjectFormCard(
            form: visible[index],
            onMenu: () => _onFormMenu(visible[index]),
          );
        },
      ),
    );
  }
}

class _ProjectFormCard extends StatelessWidget {
  const _ProjectFormCard({
    required this.form,
    required this.onMenu,
  });

  final FormSummary form;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final created = form.createdAt;
    final createdLabel = created == null
        ? null
        : 'Created ${DateFormat('MMM d, yyyy').format(created.toLocal())}';
    final projectType = form.projectTypeLabel?.trim();
    final installationType = form.installationTypeLabel?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    form.name,
                    style: AppFonts.titleMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.more_vert_rounded),
                  color: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            if (projectType != null && projectType.isNotEmpty) ...[
              const SizedBox(height: 8),
              _metaLine('Project Type', projectType),
            ],
            if (installationType != null && installationType.isNotEmpty) ...[
              const SizedBox(height: 4),
              _metaLine('Installation Type', installationType),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusDot(active: form.isActive),
                const SizedBox(width: 6),
                Text(
                  form.isActive ? 'Active' : 'Inactive',
                  style: AppFonts.labelMedium(
                    color: form.isActive
                        ? const Color(0xFF16A34A)
                        : AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (createdLabel != null)
                  Text(
                    createdLabel,
                    style: AppFonts.labelSmall(
                      color: const Color(0xFF9CA3AF),
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _metaLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
          fontSize: 13,
          height: 1.35,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.inkStrong.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
        shape: BoxShape.circle,
      ),
    );
  }
}
