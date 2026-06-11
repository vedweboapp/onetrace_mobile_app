import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:red5/core/di/injection.dart';

import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

import 'package:red5/features/dashboard/data/job_models.dart';

import 'package:red5/features/quote/data/quote_project_api_client.dart';



final employeeJobRepositoryProvider = Provider<EmployeeJobRepository>((ref) {

  return EmployeeJobRepository(sl<QuoteProjectApiClient>());

});



final class EmployeeJobRepository {

  EmployeeJobRepository(this._jobsApi);



  final QuoteProjectApiClient _jobsApi;

  static final _timeFormat = DateFormat.jm();

  static final _dayFormat = DateFormat('MMM d');



  Future<List<EmployeeJobSummary>> fetchJobs() async {

    final rows = await _jobsApi.fetchAllJobs();

    return rows.map(_mapSummary).toList(growable: false);

  }



  Future<EmployeeJobDetail> fetchJobDetail({int? jobId}) async {

    if (jobId == null) {

      throw ArgumentError('jobId is required');

    }

    final job = await _jobsApi.fetchJobById(jobId.toString());

    return _mapJobRead(job);

  }



  EmployeeJobSummary _mapSummary(JobRead job) {

    final status = _mapStatus(job);

    return EmployeeJobSummary(

      id: job.id,

      title: job.title,

      status: status,

      earning: _formatEarning(job),

      location: _formatLocation(job),

      schedule: _formatSchedule(job),

      primaryActionLabel: _primaryActionLabel(status),

      startDate: job.startDate?.toLocal(),

    );

  }



  EmployeeJobDetail _mapJobRead(JobRead job) {

    final formProgress = job.jobMeta['form_progress'];

    final checklist = _checklistFromFormProgress(formProgress);

    final items = _itemsFromJob(job);

    return EmployeeJobDetail(

      id: job.id,

      title: job.title,

      currentStatus: job.displayStatus.toUpperCase(),

      project: job.projectName ??

          (job.project != null ? 'Project ${job.project}' : '—'),

      client: job.clientName ??

          (job.client != null ? 'Client ${job.client}' : 'Client'),

      siteContact: _readSiteContact(job),

      block: job.siteName ?? job.displayLocation,

      plot: job.siteName ?? job.displayLocation,

      description: job.description?.trim().isNotEmpty == true

          ? job.description!.trim()

          : 'No description provided.',

      items: items,

      safetyChecklist: checklist,

      formId: _primaryFormId(job),

      formIds: _formIdsFromJob(job),

      projectId: job.project,

    );

  }



  List<int> _formIdsFromJob(JobRead job) {
    final ids = <int>{...job.formIds};
    if (job.form != null) ids.add(job.form!);
    return ids.toList(growable: false);
  }

  int? _primaryFormId(JobRead job) {
    if (job.form != null) return job.form;
    if (job.formIds.isNotEmpty) return job.formIds.first;
    return null;
  }

  List<EmployeeJobItem> _itemsFromJob(JobRead job) {
    final parsed = <EmployeeJobItem>[];

    void collectFrom(dynamic raw) {
      if (raw is! List || raw.isEmpty) return;
      for (final entry in raw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        );
        parsed.add(_mapItemRow(map));
      }
    }

    collectFrom(job.jobMeta['composite_items']);
    final plot = job.jobMeta['plot'];
    if (plot is Map) {
      collectFrom(plot['composite_items']);
    }
    collectFrom(job.raw['composite_items']);
    collectFrom(job.raw['items']);

    if (parsed.isNotEmpty) {
      return parsed;
    }

    if (job.itemName?.trim().isNotEmpty == true || job.quantity != null) {
      final name = job.itemName?.trim().isNotEmpty == true
          ? job.itemName!.trim()
          : 'Assigned item';
      return [
        EmployeeJobItem(
          name: name,
          quantityLabel: _formatQuantityLabel(
            job.quantity,
            unit: _readUnitFromMeta(job.jobMeta) ?? 'units',
          ),
          iconName: _iconForItemName(name),
        ),
      ];
    }

    return const [
      EmployeeJobItem(
        name: 'No items assigned',
        quantityLabel: '—',
        iconName: 'default',
      ),
    ];
  }

  EmployeeJobItem _mapItemRow(Map<String, dynamic> map) {
    final name = _readItemName(map);
    final qty = map['quantity'] ?? map['qty'] ?? map['amount'];
    final unit = _readUnit(map);
    return EmployeeJobItem(
      name: name,
      quantityLabel: _formatQuantityLabel(qty, unit: unit),
      iconName: _iconForItemName(name),
    );
  }

  String _readItemName(Map<String, dynamic> map) {
    for (final nestedKey in const ['item', 'composite_item', 'product']) {
      final nested = map[nestedKey];
      if (nested is! Map) continue;
      final nestedMap = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final key in const ['name', 'item_name', 'title']) {
        final value = nestedMap[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    for (final key in const ['name', 'item_name', 'title', 'label']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return 'Item';
  }

  String? _readUnit(Map<String, dynamic> map) {
    for (final key in const [
      'unit',
      'uom',
      'unit_of_measure',
      'measurement_unit',
    ]) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _readUnitFromMeta(Map<String, dynamic> meta) {
    for (final key in const ['unit', 'uom', 'unit_of_measure']) {
      final value = meta[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _formatQuantityLabel(dynamic quantity, {String? unit}) {
    if (quantity == null) return '—';
    final qtyText = quantity is num
        ? quantity % 1 == 0
            ? quantity.toInt().toString()
            : quantity.toString()
        : quantity.toString().trim();
    if (qtyText.isEmpty) return '—';

    final unitLabel = unit?.trim();
    if (unitLabel != null && unitLabel.isNotEmpty) {
      return '$qtyText $unitLabel';
    }
    return '$qtyText units';
  }

  String _iconForItemName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wire') ||
        lower.contains('cable') ||
        lower.contains('wiring')) {
      return 'wire';
    }
    if (lower.contains('smoke') ||
        lower.contains('detector') ||
        lower.contains('sensor')) {
      return 'sensor';
    }
    return 'default';
  }



  String _readSiteContact(JobRead job) {

    final siteRaw = job.raw['site'];

    if (siteRaw is Map) {

      final contacts = siteRaw['contacts'];

      if (contacts is List && contacts.isNotEmpty) {

        final first = contacts.first;

        if (first is Map) {

          final phone = first['phone']?.toString().trim();

          if (phone != null && phone.isNotEmpty) return phone;

        }

      }

    }

    final clientRaw = job.raw['client'];

    if (clientRaw is Map) {

      final phone = clientRaw['phone']?.toString().trim();

      if (phone != null && phone.isNotEmpty) return phone;

    }

    return '—';

  }



  EmployeeJobStatus _mapStatus(JobRead job) {

    if (job.completedAt != null) return EmployeeJobStatus.completed;

    final status = job.displayStatus.toUpperCase();

    if (status.contains('PROGRESS')) return EmployeeJobStatus.inProgress;

    if (status.contains('TODO') || status.contains('TO DO')) {

      return EmployeeJobStatus.upcoming;

    }

    if (status.contains('COMPLETE')) return EmployeeJobStatus.completed;

    return EmployeeJobStatus.pending;

  }



  String _formatEarning(JobRead job) {

    final total = job.total;

    if (total == null) return '—';

    return '£ ${total.toStringAsFixed(2)}';

  }



  String _formatLocation(JobRead job) {

    final site = job.siteName ?? job.displayLocation;

    final project = job.projectName?.trim();

    if (project != null && project.isNotEmpty) return '$site · $project';

    return site;

  }



  String _formatSchedule(JobRead job) {

    final start = job.startDate?.toLocal();

    if (start == null) return 'Schedule TBD';

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final day = DateTime(start.year, start.month, start.day);

    final time = _timeFormat.format(start);

    if (day == today) return 'Today · $time';

    if (day == today.add(const Duration(days: 1))) return 'Tomorrow · $time';

    return '${_dayFormat.format(start)} · $time';

  }



  List<EmployeeSafetyChecklistItem> _checklistFromFormProgress(

    dynamic formProgress,

  ) {

    if (formProgress is! Map) {

      return _defaultChecklist;

    }

    final map = Map<String, dynamic>.from(

      formProgress.map((k, v) => MapEntry(k.toString(), v)),

    );

    if (map.isEmpty) return _defaultChecklist;

    return map.entries

        .map(

          (entry) => EmployeeSafetyChecklistItem(

            id: entry.key,

            title: _humanizeKey(entry.key),

            isChecked: entry.value == true ||

                entry.value.toString().toLowerCase() == 'true',

          ),

        )

        .toList(growable: false);

  }



  static String _humanizeKey(String key) {

    return key

        .replaceAll('_', ' ')

        .split(' ')

        .where((part) => part.isNotEmpty)

        .map(

          (part) =>

              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',

        )

        .join(' ');

  }



  static const _defaultChecklist = EmployeeJobPreStartSafetyChecklist.items;

  static String _primaryActionLabel(EmployeeJobStatus status) {
    return switch (status) {
      EmployeeJobStatus.inProgress => 'Continue Job',
      EmployeeJobStatus.upcoming => 'Start Job',
      EmployeeJobStatus.pending => 'Start Job',
      EmployeeJobStatus.completed => 'View Details',
    };
  }

}


