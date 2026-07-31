/// Builds `POST/PUT /jobs/` bodies matching the backend contract.
import 'package:red5/features/dashboard/data/job_models.dart';

/// Which template-id key the job forms link model expects.
///
/// - [projectFormId] — project-based jobs (`project_form_id`)
/// - [dynamicFormId] — service jobs (`dynamic_form_id`)
enum JobLinkedFormIdKey { projectFormId, dynamicFormId }

abstract final class JobWritePayload {
  const JobWritePayload._();

  static Map<String, dynamic> build({
    required String title,
    String? description,
    int? assignedWorker,
    int? salesperson,
    DateTime? startDate,
    DateTime? endDate,
    String? comments,
    int? jobStatus,
    int? client,
    int? project,
    int? site,
    int? form,
    List<int>? formIds,
    int? qrCode,
    String? jobSource,
    Map<String, dynamic>? jobMeta,
    Map<String, dynamic>? jobMetaOverride,
    Map<String, dynamic>? existingJobRaw,
    JobLinkedFormIdKey? formIdKey,
  }) {
    final meta = jobMetaOverride ?? jobMeta ?? const <String, dynamic>{};
    final linkedFormIds = _normalizeFormIds(formIds: formIds, form: form);
    final resolvedFormKey = formIdKey ??
        resolveLinkedFormIdKey(
          jobRaw: existingJobRaw,
          projectId: project,
        );
    return <String, dynamic>{
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (assignedWorker != null) 'assigned_worker': assignedWorker,
      if (salesperson != null) 'salesperson': salesperson,
      if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
      if (comments != null && comments.trim().isNotEmpty)
        'comments': comments.trim(),
      if (jobStatus != null) 'job_status': jobStatus,
      if (client != null) 'client': client,
      if (project != null) 'project': project,
      if (site != null) 'site': site,
      if (linkedFormIds.isNotEmpty)
        'forms': buildLinkedFormsWriteList(
          formIds: linkedFormIds,
          key: resolvedFormKey,
          jobRaw: existingJobRaw,
        ),
      if (qrCode != null) 'qr_code': qrCode,
      if (jobSource != null && jobSource.trim().isNotEmpty)
        'job_source': jobSource.trim(),
      'job_meta': meta,
    };
  }

  /// Full job update body from a [JobRead] (admin + operative PUT flows).
  static Map<String, dynamic> buildFromJobRead(
    JobRead job, {
    Map<String, dynamic>? jobMetaOverride,
    List<Map<String, dynamic>>? checklists,
    DateTime? completedAt,
    int? jobStatusOverride,
    int? qrCodeOverride,
    bool includeExistingChecklists = true,
  }) {
    final linkedFormIds = job.formIds.isNotEmpty
        ? job.formIds
        : (job.form != null ? <int>[job.form!] : const <int>[]);

    final payload = build(
      title: job.title,
      description: job.description,
      assignedWorker: job.assignedWorker,
      startDate: job.startDate,
      endDate: job.endDate,
      comments: job.comments,
      jobStatus: jobStatusOverride ?? job.jobStatus,
      client: job.client,
      project: job.project,
      site: job.site,
      formIds: linkedFormIds,
      qrCode: qrCodeOverride ?? job.qrCode,
      jobMeta: job.jobMeta,
      jobMetaOverride: jobMetaOverride,
      existingJobRaw: job.raw,
    );

    if (checklists != null) {
      payload['checklists'] = checklists;
    } else if (includeExistingChecklists &&
        job.checklists != null &&
        job.checklists!.items.isNotEmpty) {
      payload['checklists'] = job.checklists!.toWriteList();
    }
    if (completedAt != null) {
      payload['completed_at'] = completedAt.toUtc().toIso8601String();
    }
    return payload;
  }

  /// Checklist-only PUT — omits [job_status] so the server does not treat the
  /// request as a job completion transition.
  static Map<String, dynamic> buildChecklistOnlyUpdate({
    required String title,
    required List<Map<String, dynamic>> checklists,
  }) {
    return <String, dynamic>{'title': title.trim(), 'checklists': checklists};
  }

  /// Operative "Start Job" — saves checklist rows and moves status to in progress.
  static Map<String, dynamic> buildOperativeJobStart({
    required String title,
    required List<Map<String, dynamic>> checklists,
    int? inProgressJobStatusId,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'checklists': checklists,
      if (inProgressJobStatusId != null) 'job_status': inProgressJobStatusId,
    };
  }

  /// Status-only PUT for operative start when checklist was already saved.
  static Map<String, dynamic> buildStatusOnlyUpdate({
    required String title,
    required int jobStatusId,
  }) {
    return <String, dynamic>{'title': title.trim(), 'job_status': jobStatusId};
  }

  /// Picks `project_form_id` vs `dynamic_form_id` from existing job forms, or
  /// falls back to project presence for create flows.
  static JobLinkedFormIdKey resolveLinkedFormIdKey({
    Map<String, dynamic>? jobRaw,
    int? projectId,
  }) {
    final forms = jobRaw?['forms'] ?? jobRaw?['job_forms'];
    if (forms is List) {
      var sawDynamic = false;
      var sawProject = false;
      for (final row in forms) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(
          row.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (_readPositiveInt(map['dynamic_form_id']) != null) {
          sawDynamic = true;
        }
        if (_readPositiveInt(map['project_form_id']) != null) {
          sawProject = true;
        }
      }
      if (sawDynamic && !sawProject) return JobLinkedFormIdKey.dynamicFormId;
      if (sawProject && !sawDynamic) return JobLinkedFormIdKey.projectFormId;
      if (sawDynamic) return JobLinkedFormIdKey.dynamicFormId;
      if (sawProject) return JobLinkedFormIdKey.projectFormId;
    }

    if (projectId != null && projectId > 0) {
      return JobLinkedFormIdKey.projectFormId;
    }
    return JobLinkedFormIdKey.dynamicFormId;
  }

  /// Serializes linked forms as objects with the correct backend key.
  static List<Map<String, dynamic>> buildLinkedFormsWriteList({
    required List<int> formIds,
    required JobLinkedFormIdKey key,
    Map<String, dynamic>? jobRaw,
  }) {
    final writeKey = key == JobLinkedFormIdKey.projectFormId
        ? 'project_form_id'
        : 'dynamic_form_id';
    final jobFormIdsByTemplate = _jobFormIdsByTemplate(jobRaw);

    return [
      for (final id in formIds)
        if (id > 0)
          <String, dynamic>{
            writeKey: id,
            if (jobFormIdsByTemplate[id] != null)
              'job_form_id': jobFormIdsByTemplate[id],
          },
    ];
  }

  static Map<int, int> _jobFormIdsByTemplate(Map<String, dynamic>? jobRaw) {
    final forms = jobRaw?['forms'] ?? jobRaw?['job_forms'];
    if (forms is! List) return const {};

    final out = <int, int>{};
    for (final row in forms) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final templateId = _readPositiveInt(map['dynamic_form_id']) ??
          _readPositiveInt(map['project_form_id']) ??
          _readPositiveInt(map['form_id']) ??
          _readPositiveInt(map['form']);
      final jobFormId = _readPositiveInt(map['job_form_id']) ??
          _readPositiveInt(map['job_form']) ??
          _readPositiveInt(map['id']);
      if (templateId == null || jobFormId == null) continue;
      if (templateId == jobFormId &&
          !map.containsKey('job_form_id') &&
          !map.containsKey('job_form')) {
        continue;
      }
      out[templateId] = jobFormId;
    }
    return out;
  }

  static List<int> _normalizeFormIds({List<int>? formIds, int? form}) {
    final ids = <int>{
      if (formIds != null) ...formIds.where((id) => id > 0),
      if (form != null && form > 0) form,
    };
    return ids.toList(growable: false);
  }

  static int? _readPositiveInt(dynamic value) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static Map<String, dynamic> buildCompositeJobMeta({
    required List<Map<String, dynamic>> compositeItems,
    required double total,
  }) {
    return <String, dynamic>{
      'composite_items': compositeItems,
      'total': total.round(),
    };
  }

  static Map<String, dynamic> buildMaterialsMeta({
    required String sectionName,
    required String plotName,
    required double plotTotal,
    int? groupId,
    required List<({int id, int quantity})> compositeItems,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    final plot = <String, dynamic>{
      'name': plotName.trim().isEmpty ? 'Plot' : plotName.trim(),
      'plot_total': plotTotal.round(),
      if (groupId != null) 'group': groupId,
      'composite_items': compositeItems
          .map(
            (row) => <String, dynamic>{'id': row.id, 'quantity': row.quantity},
          )
          .toList(growable: false),
    };
    return <String, dynamic>{
      ...extra,
      'section': <String, dynamic>{
        'name': sectionName.trim().isEmpty ? 'Section' : sectionName.trim(),
      },
      'plot': plot,
    };
  }
}

extension JobReadWritePayload on JobRead {
  Map<String, dynamic> toWritePayload({
    Map<String, dynamic>? jobMetaOverride,
  }) =>
      JobWritePayload.buildFromJobRead(this, jobMetaOverride: jobMetaOverride);
}
