/// Builds `POST/PUT /jobs/` bodies matching the backend contract.
import 'package:red5/features/dashboard/data/job_models.dart';

abstract final class JobWritePayload {
  const JobWritePayload._();

  static Map<String, dynamic> build({    required String title,
    String? description,
    int? assignedWorker,
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
  }) {
    final meta = jobMetaOverride ?? jobMeta ?? const <String, dynamic>{};
    final linkedFormIds = _normalizeFormIds(formIds: formIds, form: form);
    return <String, dynamic>{
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (assignedWorker != null) 'assigned_worker': assignedWorker,
      if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
      if (comments != null && comments.trim().isNotEmpty)
        'comments': comments.trim(),
      if (jobStatus != null) 'job_status': jobStatus,
      if (client != null) 'client': client,
      if (project != null) 'project': project,
      if (site != null) 'site': site,
      if (linkedFormIds.isNotEmpty) 'forms': linkedFormIds,
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
    );

    if (checklists != null) {
      payload['checklists'] = checklists;
    } else if (job.checklists != null && job.checklists!.items.isNotEmpty) {
      payload['checklists'] = job.checklists!.toWriteList();
    }
    if (completedAt != null) {
      payload['completed_at'] = completedAt.toUtc().toIso8601String();
    }
    return payload;
  }

  static List<int> _normalizeFormIds({
    List<int>? formIds,
    int? form,
  }) {
    final ids = <int>{
      if (formIds != null) ...formIds.where((id) => id > 0),
      if (form != null && form > 0) form,
    };
    return ids.toList(growable: false);
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
            (row) => <String, dynamic>{
              'id': row.id,
              'quantity': row.quantity,
            },
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
  Map<String, dynamic> toWritePayload({Map<String, dynamic>? jobMetaOverride}) =>
      JobWritePayload.buildFromJobRead(this, jobMetaOverride: jobMetaOverride);
}
