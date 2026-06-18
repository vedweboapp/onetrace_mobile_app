import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/employee_role/jobs/data/qr_code_details_models.dart';
import 'package:red5/features/dashboard/data/qr_code_models.dart';

final class QrCodesPageResult {
  const QrCodesPageResult({
    required this.items,
    required this.totalCount,
    required this.hasNext,
  });

  final List<QrCodeModel> items;
  final int totalCount;
  final bool hasNext;
}

final class QrCodesApiClient {
  QrCodesApiClient({
    required Dio dio,
    Dio? publicDio,
  })  : _dio = dio,
        _publicDio = publicDio ?? dio;

  final Dio _dio;
  final Dio _publicDio;

  /// `GET /qr-codes/` — paginated list.
  Future<QrCodesPageResult> fetchQrCodesPage({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.qrCodes,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = _coerceMap(response.data);
    final rows = _readRows(root);
    final items = rows
        .map((row) => QrCodeModel.fromJson(_coerceMap(row)))
        .where((item) => item.id > 0)
        .toList();
    final totalCount = _readInt(root['count']) ?? items.length;
    return QrCodesPageResult(
      items: items,
      totalCount: totalCount,
      hasNext: _hasNextPage(root, rows),
    );
  }

  /// Loads every page from `GET /qr-codes/`.
  Future<List<QrCodeModel>> fetchAllQrCodes({
    int pageSize = 50,
    String? search,
  }) async {
    final out = <QrCodeModel>[];
    final seen = <int>{};
    var page = 1;

    while (true) {
      final result = await fetchQrCodesPage(
        page: page,
        pageSize: pageSize,
        search: search,
      );
      for (final item in result.items) {
        if (!seen.add(item.id)) continue;
        out.add(item);
      }
      if (!result.hasNext || result.items.isEmpty) break;
      page += 1;
    }

    return out;
  }

  /// `GET /qr-codes/{id}/`
  Future<QrCodeModel> fetchQrCodeById(int id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.qrCodeById(id));
    final root = _coerceMap(response.data);
    return QrCodeModel.fromJson(_entityBody(root));
  }

  /// `GET /qr-codes/{qr_code}/details/` — public job lookup by QR value.
  Future<QrCodeJobDetails> fetchQrCodeDetails(String qrCode) async {
    final normalized = QrCodeUtils.normalizeScannedValue(qrCode);
    DioException? lastError;

    for (final client in <Dio>[_publicDio, _dio]) {
      try {
        final response = await client.get<dynamic>(
          AppApiUrls.qrCodeDetailsByCode(normalized),
        );
        final parsed = _parseQrCodeDetailsResponse(response, normalized);
        if (parsed != null) return parsed;
      } on DioException catch (error) {
        lastError = error;
        if (_isNotFound(error)) continue;
        rethrow;
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(
            path: AppApiUrls.qrCodeDetailsByCode(normalized),
          ),
          type: DioExceptionType.badResponse,
          message: 'QR code details response missing job_id.',
        );
  }

  QrCodeJobDetails? _parseQrCodeDetailsResponse(
    Response<dynamic> response,
    String normalized,
  ) {
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    return QrCodeJobDetails.tryFromMap(body, qrCode: normalized) ??
        QrCodeJobDetails.tryFromMap(root, qrCode: normalized);
  }

  static bool _isNotFound(DioException error) {
    final status = error.response?.statusCode;
    return status == 404;
  }

  /// `POST /qr-codes/generate/`
  Future<List<QrCodeModel>> generateQrCodes({required int count}) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.qrCodesGenerate,
      data: <String, dynamic>{'number_of_qr_codes': count},
      options: _jsonWriteOptions,
    );
    final root = _coerceMap(response.data);
    final rows = _readRows(root);
    return rows
        .map((row) => QrCodeModel.fromJson(_coerceMap(row)))
        .where((item) => item.id > 0)
        .toList();
  }

  static Options get _jsonWriteOptions => Options(
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      );

  static Map<String, dynamic> _coerceMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _entityBody(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) return _coerceMap(data);
    return root;
  }

  static List<dynamic> _readRows(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is List) return data;
    final results = root['results'];
    if (results is List) return results;
    return const [];
  }

  static bool _hasNextPage(Map<String, dynamic> root, List<dynamic> rows) {
    if (rows.isEmpty) return false;
    final next = root['next'];
    if (next != null && next.toString().trim().isNotEmpty) return true;
    final pagination = _coerceMap(root['pagination']);
    final pagNext = pagination['next'];
    return pagNext != null && pagNext.toString().trim().isNotEmpty;
  }
 
  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

final qrCodesApiClientProvider = Provider<QrCodesApiClient>(
  (ref) => sl<QrCodesApiClient>(),
);


