import 'package:dio/dio.dart';
import 'package:red5/core/network/app_http_client.dart';

/// [AppHttpClient] backed by Dio (shared timeouts, single instance).
///
/// Binary downloads and `multipart/form-data` uploads: [DioMultipartTransfer].
class DioAppHttpClient implements AppHttpClient {
  DioAppHttpClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (_) => true,
  );

  final Dio _dio;

  @override
  Future<HttpTextResult> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get<String>(
      url,
      queryParameters: queryParameters,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    final text = response.data ?? '';
    return HttpTextResult(statusCode: response.statusCode ?? 0, body: text);
  }

  @override
  Future<HttpTextResult> postFormUrlEncoded(
    String url, {
    required String body,
    Map<String, String>? headers,
  }) async {
    final merged = <String, String>{
      Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
      if (headers != null) ...headers,
    };
    final response = await _dio.post<String>(
      url,
      data: body,
      options: Options(headers: merged, responseType: ResponseType.plain),
    );
    final text = response.data ?? '';
    return HttpTextResult(statusCode: response.statusCode ?? 0, body: text);
  }
}
