import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// [RequestOptions.extra] keys — set on a request to show [tryShowSuccessTopPopup]
/// after a successful (2xx) response.
const String kDioExtraShowSuccessToast = 'showSuccessToast';
const String kDioExtraSuccessToastTitle = 'successToastTitle';
const String kDioExtraSuccessToastSubtitle = 'successToastSubtitle';

/// When [kDioExtraShowSuccessToast] is `true`, shows the success popup using
/// title/subtitle from extras or a short message parsed from JSON [data].
final class SuccessToastInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final ro = response.requestOptions;
    if (ro.extra[kDioExtraShowSuccessToast] != true) {
      handler.next(response);
      return;
    }

    final titleOpt = (ro.extra[kDioExtraSuccessToastTitle] as String?)?.trim();
    final subtitleOpt = (ro.extra[kDioExtraSuccessToastSubtitle] as String?)?.trim();

    var title = titleOpt ?? '';
    if (title.isEmpty) {
      title = _messageFromData(response.data) ?? 'Success';
    }
    final subtitle = subtitleOpt ?? _loginSubtitleFromRequest(ro);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      tryShowSuccessTopPopup(title: title, subtitle: subtitle);
    });
    handler.next(response);
  }

  static String? _messageFromData(dynamic data) {
    if (data is Map) {
      for (final key in const ['message', 'detail', 'msg']) {
        final v = data[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  static String? _loginSubtitleFromRequest(RequestOptions ro) {
    final d = ro.data;
    if (d is Map) {
      final e = d['email']?.toString().trim();
      if (e != null && e.isNotEmpty) {
        return 'You\'re signed in as $e';
      }
    }
    return null;
  }
}
