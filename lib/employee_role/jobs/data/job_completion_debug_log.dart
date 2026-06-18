import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug traces for operative form submit and job completion (debug builds only).
abstract final class JobCompletionDebugLog {
  static const _tag = 'JOB-COMPLETE';
  static const _formTag = 'FORM-SUBMIT';

  static void banner(String title) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════');
    debugPrint('║ $_tag | $title');
    debugPrint('╚══════════════════════════════════════════════════════════');
  }

  static void step(String message) {
    if (!kDebugMode) return;
    debugPrint('[$_tag] ▶ $message');
  }

  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint('[$_tag]   $message');
  }

  /// Logs form submit / update API with full request and response.
  static void formApi({
    required String label,
    required String method,
    required String url,
    Object? request,
    int? statusCode,
    Object? response,
    Object? error,
  }) {
    if (!kDebugMode) return;
    final status = statusCode == null ? '' : ' | HTTP $statusCode';
    debugPrint('');
    debugPrint('┌─[$_formTag] $label');
    debugPrint('│ $method $url$status');
    if (request != null) {
      debugPrint('│ REQUEST (payload):');
      for (final line in _pretty(request).split('\n')) {
        debugPrint('│   $line');
      }
    }
    if (response != null) {
      debugPrint('│ RESPONSE:');
      for (final line in _pretty(response).split('\n')) {
        debugPrint('│   $line');
      }
    }
    if (error != null) {
      debugPrint('│ ERROR: $error');
    }
    debugPrint('└─────────────────────────────────────────────────────────');
  }

  /// Logs SQLite-only draft / offline queue (no API call).
  static void localSave({
    required String label,
    required int jobId,
    required int projectFormId,
    required int jobFormId,
    required String status,
    required List<Map<String, dynamic>> values,
    String? remarks,
    int? submissionId,
  }) {
    if (!kDebugMode) return;
    if (kDebugMode && jobFormId <= 0) {
      debugPrint(
        '[FORM-LOCAL] WARNING: job_form_id unresolved for '
        'job_id=$jobId project_form_id=$projectFormId',
      );
    }
    final futurePayload = <String, dynamic>{
      'job_form_id': jobFormId > 0 ? jobFormId : null,
      'status': status,
      'values': values,
    };
    if (remarks != null && remarks.trim().isNotEmpty) {
      futurePayload['remarks'] = remarks.trim();
    }
    debugPrint('');
    debugPrint('┌─[FORM-LOCAL] $label');
    debugPrint('│ job_id=$jobId | project_form_id=$projectFormId | job_form_id=$jobFormId');
    debugPrint('│ NO API — saved to SQLite (sync on Submit Form tap)');
    debugPrint('│ DATA:');
    for (final line in _pretty(futurePayload).split('\n')) {
      debugPrint('│   $line');
    }
    debugPrint('└─────────────────────────────────────────────────────────');
  }

  static void api({
    required String label,
    required String method,
    required String url,
    Object? request,
    int? statusCode,
    Object? response,
    Object? error,
  }) {
    if (!kDebugMode) return;
    final status = statusCode == null ? '' : ' | HTTP $statusCode';
    debugPrint('');
    debugPrint('┌─[$_tag] $label');
    debugPrint('│ $method $url$status');
    if (request != null) {
      debugPrint('│ REQUEST:');
      for (final line in _pretty(request).split('\n')) {
        debugPrint('│   $line');
      }
    }
    if (response != null) {
      debugPrint('│ RESPONSE:');
      for (final line in _pretty(response).split('\n')) {
        debugPrint('│   $line');
      }
    }
    if (error != null) {
      debugPrint('│ ERROR: $error');
    }
    debugPrint('└─────────────────────────────────────────────────────────');
  }

  static String _pretty(Object? body) {
    if (body == null) return '<empty>';
    try {
      if (body is Map || body is List) {
        return const JsonEncoder.withIndent('  ').convert(body);
      }
      final raw = body.toString().trim();
      if (raw.startsWith('{') || raw.startsWith('[')) {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
      }
      return raw;
    } catch (_) {
      return body.toString();
    }
  }
}
