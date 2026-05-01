/// Minimal HTTP result for API layers (status + raw body string).
class HttpTextResult {
  const HttpTextResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Abstract HTTP transport — implemented by [DioAppHttpClient] or tests/mocks.
abstract class AppHttpClient {
  Future<HttpTextResult> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// `application/x-www-form-urlencoded` body.
  Future<HttpTextResult> postFormUrlEncoded(
    String url, {
    required String body,
    Map<String, String>? headers,
  });
}
