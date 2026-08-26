import 'package:dio/dio.dart';
import 'package:red5/core/network/slow_network_toast.dart';

/// Watches in-flight Dio requests and shows a top toast when the network
/// appears slow / weak during loading.
final class SlowNetworkToastInterceptor extends Interceptor {
  SlowNetworkToastInterceptor();

  static const String _extraKey = 'slowNetworkWatchCancel';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final skip = options.extra[SlowNetworkToast.skipExtraKey] == true ||
        SlowNetworkToast.isSuppressed;
    if (skip) {
      handler.next(options);
      return;
    }

    final cancel = SlowNetworkToast.begin();
    options.extra[_extraKey] = cancel;
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _finish(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _finish(err.requestOptions);
    handler.next(err);
  }

  void _finish(RequestOptions options) {
    final cancel = options.extra.remove(_extraKey);
    if (cancel is void Function()) {
      cancel();
    }
  }
}
