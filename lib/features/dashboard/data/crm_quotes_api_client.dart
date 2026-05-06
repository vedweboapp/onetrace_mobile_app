import 'package:dio/dio.dart';

import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/quote_list_page_result.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';

/// Dio-backed dashboard quotes API.
final class CrmQuotesApiClient implements CrmQuotesApi {
  CrmQuotesApiClient({Dio? dio}) : _dio = dio ?? _createDefaultDio();

  final Dio _dio;

  static Dio _createDefaultDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    dio.interceptors.add(ApiDioLogInterceptor());
    return dio;
  }

  @override
  Future<QuoteListPageResult> fetchQuotesPage(int page) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.projects,
      queryParameters: {'page': page},
    );
    final root = response.data ?? const <String, dynamic>{};
    final summaries = _extractSummaries(root);
    final listInfo = QuoteListInfo.fromJson(root['list_info']);

    final perPage = _readInt(root, const ['per_page', 'page_size', 'limit']);
    final totalCount = _readInt(root, const ['count', 'total', 'total_count']);
    final totalPages = _resolveTotalPages(
      page: page,
      totalPagesRaw: _readInt(root, const ['total_pages', 'pages']),
      totalCount: totalCount ?? listInfo.count,
      pageSize: perPage,
      hasMore: listInfo.moreRecords,
    );

    return QuoteListPageResult(
      summaries: summaries,
      page: page,
      totalPages: totalPages,
      hasMoreRecords: listInfo.moreRecords,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchQuoteAppPayload(String quoteId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.projectById(quoteId),
    );
    final root = response.data ?? const <String, dynamic>{};
    return _normalizeQuotePayload(root);
  }

  List<QuoteSummary> _extractSummaries(Map<String, dynamic> root) {
    final rows = _extractRows(root);
    final result = <QuoteSummary>[];
    for (final row in rows) {
      final mapped = _normalizeSummaryRow(row);
      final summary = QuoteSummary.fromJson(mapped);
      if (summary != null) result.add(summary);
    }
    return result;
  }

  List<Map<String, dynamic>> _extractRows(Map<String, dynamic> root) {
    final dynamic candidates = root['data'] ??
        root['results'] ??
        root['items'] ??
        root['projects'] ??
        root['quotes'];
    if (candidates is List) {
      return candidates
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeSummaryRow(Map<String, dynamic> row) {
    String read(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = row[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    return <String, dynamic>{
      'id': read(const ['id', 'ID', 'project_id', 'quote_id']),
      'Subject': read(const [
        'Subject',
        'quote_name',
        'project_name',
        'name',
        'title',
      ], fallback: 'Untitled Quote'),
      'Quote_Number': read(const [
        'Quote_Number',
        'quote_number',
        'project_number',
        'reference',
        'number',
      ], fallback: '—'),
      'client_name': read(const [
        'client_name',
        'client',
        'client_title',
        'organization',
        'company_name',
      ]),
      'description': read(const ['description', 'details', 'summary']),
      'start_date': read(const ['start_date', 'project_start', 'created_at']),
      'end_date': read(const ['end_date', 'project_end', 'valid_till']),
    };
  }

  Map<String, dynamic> _normalizeQuotePayload(Map<String, dynamic> root) {
    final quoteNode = _readMap(
      root,
      const ['quote', 'data', 'project', 'result'],
    );
    final quoteMap = quoteNode.isNotEmpty ? quoteNode : root;
    final createdByText = _readActor(quoteMap['created_by']) ??
        _readActor(quoteMap['owner']) ??
        _readString(quoteMap, const ['created_by', 'owner']);
    final modifiedByText = _readActor(quoteMap['modified_by']) ??
        _readString(quoteMap, const ['modified_by']);

    final productsRaw = root['products'] ??
        root['line_items'] ??
        quoteMap['products'] ??
        quoteMap['line_items'] ??
        const <dynamic>[];
    final products = _asMapList(productsRaw);

    final compositeRaw = root['composite_groups'] ??
        quoteMap['composite_groups'] ??
        root['composite_item_groups'] ??
        quoteMap['composite_item_groups'];

    return <String, dynamic>{
      'quote': <String, dynamic>{
        'quote_name': _readString(quoteMap, const [
          'quote_name',
          'Subject',
          'project_name',
          'name',
          'title',
        ], fallback: 'Untitled Quote'),
        'quote_number': _readString(quoteMap, const [
          'quote_number',
          'Quote_Number',
          'project_number',
          'reference',
          'number',
        ], fallback: '—'),
        'quote_stage': _readString(quoteMap, const ['quote_stage', 'stage']),
        'valid_till': _readString(
          quoteMap,
          const ['valid_till', 'valid_until', 'expiry_date'],
        ),
        'property': _readString(quoteMap, const ['property', 'site', 'address']),
        'door_survey': _readString(quoteMap, const ['door_survey']),
        'deal_name': _readString(quoteMap, const ['deal_name', 'deal']),
        'wardrive_pdf_link': _readString(quoteMap, const [
          'wardrive_pdf_link',
          'workdrive_pdf_link',
          'pdf_link',
          'pdf_url',
          'pdf',
        ]),
        'workdrive_pdf_download': _readString(quoteMap, const [
          'workdrive_pdf_download',
          'download_link',
          'pdf_download_url',
        ]),
        'contact_name': _readString(
          quoteMap,
          const ['contact_name', 'customer_name', 'client_name'],
        ),
        'created_by': createdByText,
        'modified_by': modifiedByText,
        'layout': _readString(quoteMap, const ['layout']),
        'id': _readString(quoteMap, const ['id', 'project_id']),
        'project_status': _readString(quoteMap, const ['project_status', 'status']),
        'description': _readString(quoteMap, const ['description']),
        'start_date': _readString(quoteMap, const ['start_date']),
        'end_date': _readString(quoteMap, const ['end_date']),
        'organization': _readString(quoteMap, const ['organization']),
        'client': _readString(quoteMap, const ['client']),
        'created_at': _readString(quoteMap, const ['created_at']),
        'modified_at': _readString(quoteMap, const ['modified_at']),
        'deleted_at': _readString(quoteMap, const ['deleted_at']),
        'deleted_by': _readString(quoteMap, const ['deleted_by']),
        'is_deleted': _readString(quoteMap, const ['is_deleted']),
      },
      'products': products,
      'composite_groups': compositeRaw,
    };
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String? _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    String? fallback,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String? _readActor(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final username = map['username']?.toString().trim();
    final email = map['email']?.toString().trim();
    final id = map['id']?.toString().trim();
    if (username != null && username.isNotEmpty) return username;
    if (email != null && email.isNotEmpty) return email;
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int _resolveTotalPages({
    required int page,
    required int? totalPagesRaw,
    required int totalCount,
    required int? pageSize,
    required bool hasMore,
  }) {
    if (totalPagesRaw != null && totalPagesRaw > 0) return totalPagesRaw;
    if (pageSize != null && pageSize > 0 && totalCount > 0) {
      return (totalCount / pageSize).ceil().clamp(1, 999999);
    }
    if (hasMore) return page + 1;
    return page > 0 ? page : 1;
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return const <String, dynamic>{};
  }
}
