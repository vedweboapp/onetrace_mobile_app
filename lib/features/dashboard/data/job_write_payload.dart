/// Builds `POST/PUT /jobs/` bodies matching the backend contract.
abstract final class JobWritePayload {
  const JobWritePayload._();

  static Map<String, dynamic> build({
    required String title,
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
    int? qrCode,
    String? jobSource,
    Map<String, dynamic>? jobMeta,
    Map<String, dynamic>? jobMetaOverride,
  }) {
    final meta = jobMetaOverride ?? jobMeta ?? const <String, dynamic>{};
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
      if (form != null) 'form': form,
      if (qrCode != null) 'qr_code': qrCode,
      if (jobSource != null && jobSource.trim().isNotEmpty)
        'job_source': jobSource.trim(),
      'job_meta': meta,
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
