import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_drawing_card.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';

/// Scrollable drawing cards for operative job/site views.
class EmployeeJobDrawingsListBody extends ConsumerStatefulWidget {
  const EmployeeJobDrawingsListBody({
    super.key,
    required this.jobIds,
    this.initialItems,
    this.emptyMessage = 'No drawings linked to your jobs yet.',
    this.embedded = false,
  });

  final List<int> jobIds;
  final List<EmployeeJobDrawingListItem>? initialItems;
  final String emptyMessage;
  final bool embedded;

  @override
  ConsumerState<EmployeeJobDrawingsListBody> createState() =>
      _EmployeeJobDrawingsListBodyState();
}

class _EmployeeJobDrawingsListBodyState
    extends ConsumerState<EmployeeJobDrawingsListBody> {
  List<EmployeeJobDrawingListItem> _items = const [];
  var _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeJobDrawingsListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != null &&
        widget.initialItems != oldWidget.initialItems) {
      setState(() {
        _items = widget.initialItems!;
        _loading = false;
        _errorMessage = null;
      });
      return;
    }
    if (!_sameJobIds(oldWidget.jobIds, widget.jobIds)) {
      _load();
    }
  }

  bool _sameJobIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _load() async {
    final seeded = widget.initialItems;
    if (seeded != null) {
      setState(() {
        _items = seeded;
        _loading = false;
        _errorMessage = null;
      });
      return;
    }

    if (widget.jobIds.isEmpty) {
      setState(() {
        _items = const [];
        _loading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(employeeJobRepositoryProvider);
      final items = await repo.fetchDrawingItemsForJobs(widget.jobIds);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load drawings. Pull to retry.';
      });
    }
  }

  Future<void> _openDrawing(EmployeeJobDrawingListItem item) async {
    final level = item.level;
    final url = resolveEmployeeDrawingFileUrl(level.drawingFileUrl);
    if (url == null || url.isEmpty) return;

    await DrawingCanvasPage.push(
      context,
      DrawingCanvasArgs(
        title: level.name,
        remoteDrawingUrl: url,
        levelName: level.name,
        projectName: item.projectName,
        projectId: item.projectId?.toString(),
        levelId: level.id.toString(),
        embeddedLevelPlots: level.plotPayloads,
        viewOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.emptyMessage,
          textAlign: TextAlign.center,
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }

    final cards = [
      for (var i = 0; i < _items.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        _cardFor(_items[i]),
      ],
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _cardFor(_items[index]),
      ),
    );
  }

  Widget _cardFor(EmployeeJobDrawingListItem item) {
    final level = item.level;
    return EmployeeJobDrawingCard(
      title: level.name,
      subtitle: item.subtitle,
      updatedLabel: item.updatedLabel,
      drawingFileUrl: resolveEmployeeDrawingFileUrl(level.drawingFileUrl),
      cacheKey: 'job-${item.jobId}-level-${level.id}',
      onTap: () => _openDrawing(item),
    );
  }
}
