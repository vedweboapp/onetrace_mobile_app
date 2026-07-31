import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

/// Copies form attachment files into app storage so they survive temp cleanup
/// and are still available when the job is completed and forms sync.
final class JobFormAttachmentStorage {
  const JobFormAttachmentStorage._();

  static Future<List<JobFormFieldValue>> persistValues({
    required int jobId,
    required int formId,
    required List<JobFormFieldValue> values,
    int? jobPinId,
  }) async {
    if (values.isEmpty) return values;

    final scopedDir = await _scopedDirectory(
      jobId: jobId,
      formId: formId,
      jobPinId: jobPinId,
    );

    final out = <JobFormFieldValue>[];
    for (final row in values) {
      out.add(await _persistRow(row, scopedDir));
    }
    return out;
  }

  static Future<Directory> _scopedDirectory({
    required int jobId,
    required int formId,
    int? jobPinId,
  }) async {
    final base = await getApplicationSupportDirectory();
    final scope = jobPinId != null && jobPinId > 0
        ? 'job_${jobId}_pin_$jobPinId'
        : 'job_${jobId}_form_$formId';
    final dir = Directory(p.join(base.path, 'job_form_attachments', scope));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<JobFormFieldValue> _persistRow(
    JobFormFieldValue row,
    Directory scopedDir,
  ) async {
    final srcPath = row.localFilePath?.trim();
    if (srcPath == null || srcPath.isEmpty) return row;

    final src = File(srcPath);
    if (!await src.exists()) return row;

    final filename = _safeFilename(row);
    final destPath = p.join(scopedDir.path, 'f${row.fieldId}_$filename');
    final normalizedSrc = p.normalize(srcPath);
    final normalizedDest = p.normalize(destPath);

    if (normalizedSrc != normalizedDest) {
      await File(destPath).writeAsBytes(await src.readAsBytes(), flush: true);
    }

    final apiValue = row.value.trim().isNotEmpty ? row.value.trim() : filename;
    return JobFormFieldValue(
      fieldId: row.fieldId,
      value: apiValue,
      localFilePath: destPath,
      fieldType: row.fieldType,
    );
  }

  static String _safeFilename(JobFormFieldValue row) {
    final fromValue = p.basename(row.value.trim());
    if (fromValue.isNotEmpty && fromValue != '.' && fromValue != '..') {
      return fromValue;
    }
    final fromPath = row.localFilePath?.trim();
    if (fromPath != null && fromPath.isNotEmpty) {
      final base = p.basename(fromPath);
      if (base.isNotEmpty && base != '.' && base != '..') return base;
    }
    return 'attachment_f${row.fieldId}';
  }
}
