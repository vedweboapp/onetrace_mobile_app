import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status + optional raw bytes (file download, multipart response body).
final class HttpBytesResult {
  const HttpBytesResult({required this.statusCode, this.bodyBytes});

  final int statusCode;
  final List<int>? bodyBytes;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Dio-backed transfer for binary GETs and `multipart/form-data` POSTs.
///
/// Separate from [DioAppHttpClient] so large payloads and upload progress stay isolated.
final class DioMultipartTransfer {
  DioMultipartTransfer({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 120),
    followRedirects: true,
    validateStatus: (_) => true,
  );

  final Dio _dio;

  /// GET [uri]; body as bytes (e.g. PDFs, binaries, HTML gateways).
  Future<HttpBytesResult> fetchBytes(
    Uri uri, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _dio.getUri<List<int>>(
      uri,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return HttpBytesResult(
      statusCode: response.statusCode ?? 0,
      bodyBytes: response.data,
    );
  }

  /// POST [url] as `multipart/form-data` using plain fields and uploaded parts.
  Future<HttpBytesResult> postMultipart(
    Uri url, {
    Map<String, String> fields = const {},
    Map<String, MultipartFile> files = const {},
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final map = <String, dynamic>{
      for (final e in fields.entries) e.key: e.value,
      ...files,
    };
    final formData = FormData.fromMap(map);
    final response = await _dio.post<List<int>>(
      url.toString(),
      data: formData,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return HttpBytesResult(
      statusCode: response.statusCode ?? 0,
      bodyBytes: response.data,
    );
  }

  /// [postMultipart] with [MultipartFile]s created from local file paths.
  Future<HttpBytesResult> postMultipartFromPaths(
    Uri url, {
    Map<String, String> fields = const {},
    required Map<String, String> fileFieldToPath,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final files = <String, MultipartFile>{};
    for (final e in fileFieldToPath.entries) {
      files[e.key] = await MultipartFile.fromFile(e.value);
    }
    return postMultipart(
      url,
      fields: fields,
      files: files,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Writes [bytes] to a uniquely named temp file and returns its path.
  Future<String> writeBytesToTempFile(List<int> bytes, String fileName) async {
    final safe = fileName.replaceAll(RegExp(r'[/\\]+'), '_');
    final tempPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safe';
    final file = File(tempPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

final dioMultipartTransferProvider = Provider<DioMultipartTransfer>((ref) {
  return DioMultipartTransfer();
});
