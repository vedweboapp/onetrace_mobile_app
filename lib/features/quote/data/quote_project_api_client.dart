import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/auth_bearer_interceptor.dart';
import 'package:red5/core/providers/local_storage_provider.dart';

final class LevelSyncResult {
  const LevelSyncResult({this.levelId, this.rawResponse});

  final String? levelId;
  final Map<String, dynamic>? rawResponse;
}

final class ProjectLevelItem {
  const ProjectLevelItem({
    required this.id,
    required this.name,
    required this.drawingFile,
    required this.plots,
  });

  final String id;
  final String name;
  final String drawingFile;
  final List<Map<String, dynamic>> plots;
}

final class ClientOption {
  const ClientOption({required this.id, required this.name});

  final int id;
  final String name;
}

final class PinStatusItem {
  const PinStatusItem({
    required this.id,
    required this.statusName,
    required this.bgColour,
    required this.textColour,
    required this.isActive,
  });

  final String id;
  final String statusName;
  final String bgColour;
  final String textColour;
  final bool isActive;
}

/// API client for project and level (drawing) operations.
final class QuoteProjectApiClient {
  QuoteProjectApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    dio.interceptors.add(ApiDioLogInterceptor());
    return dio;
  }

  Future<String> createProject({
    required String name,
    int? organizationId,
    int? clientId,
    String? description,
    String? startDate,
    String? endDate,
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (organizationId != null) payload['organization'] = organizationId;
    if (clientId != null) payload['client'] = clientId;
    if (description != null) payload['description'] = description;
    if (startDate != null) payload['start_date'] = startDate;
    if (endDate != null) payload['end_date'] = endDate;
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.projects,
      data: payload,
    );
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    final id = _readString(body, const ['id', 'project_id']) ??
        _readString(root, const ['id', 'project_id']);
    if (id == null || id.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Project created but no project id returned by backend.',
      );
    }
    return id;
  }

  Future<void> updateProject({
    required String projectId,
    required String name,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      AppApiUrls.projectById(projectId),
      data: <String, dynamic>{'name': name},
    );
  }

  Future<List<ClientOption>> fetchClients() async {
    final response = await _dio.get<dynamic>(AppApiUrls.clients);
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = root['data'] is List
        ? (root['data'] as List<dynamic>)
        : (root['results'] is List ? (root['results'] as List<dynamic>) : const <dynamic>[]);

    final clients = <ClientOption>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final idRaw = map['id'] ?? map['client_id'];
      final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      if (id == null) continue;
      final name = _readString(
            map,
            const ['name', 'client_name', 'title', 'company_name'],
          ) ??
          'Client $id';
      clients.add(ClientOption(id: id, name: name));
    }
    return clients;
  }

  Future<LevelSyncResult> upsertLevel({
    required String projectId,
    String? levelId,
    required String levelName,
    required String drawingFilePath,
  }) async {
    final payload = FormData.fromMap(<String, dynamic>{
      'name': levelName,
      'drawing_file': await MultipartFile.fromFile(drawingFilePath),
    });

    final isCreate = levelId == null || levelId.trim().isEmpty;
    final String path = !isCreate
        ? AppApiUrls.projectLevelById(projectId, levelId.trim())
        : AppApiUrls.projectLevels(projectId);
    final response = !isCreate
        ? await _dio.put<dynamic>(path, data: payload)
        : await _dio.post<dynamic>(path, data: payload);

    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    var resolvedLevelId = _readString(body, const ['id', 'level_id']) ??
        _readString(root, const ['id', 'level_id']);
    if (!isCreate) {
      resolvedLevelId ??= levelId.trim();
    } else if (resolvedLevelId == null || resolvedLevelId.isEmpty) {
      resolvedLevelId = await _resolveLevelIdByName(
        projectId: projectId,
        levelName: levelName,
      );
    }
    return LevelSyncResult(
      levelId: resolvedLevelId,
      rawResponse: body.isNotEmpty ? body : (root.isEmpty ? null : root),
    );
  }

  /// `PUT` [project_level_update] — JSON body per API: `{ "plots": [...] }`.
  Future<void> updateLevelPlots({
    required String projectId,
    required String levelId,
    required List<Map<String, dynamic>> plots,
  }) async {
    await _dio.put<dynamic>(
      AppApiUrls.projectLevelById(projectId, levelId),
      data: <String, dynamic>{'plots': plots},
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  Future<String?> _resolveLevelIdByName({
    required String projectId,
    required String levelName,
  }) async {
    final name = levelName.trim();
    if (name.isEmpty) return null;
    try {
      final levels = await fetchProjectLevels(projectId: projectId);
      final matches =
          levels.where((e) => e.name.trim() == name).toList(growable: false);
      if (matches.isEmpty) return null;
      int sortKey(ProjectLevelItem e) => int.tryParse(e.id) ?? 0;
      matches.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
      return matches.first.id;
    } catch (_) {
      return null;
    }
  }

  /// GET drawing bytes (relative path or full URL) with auth; writes a temp file.
  Future<String> downloadDrawingForLocalEdit(String pathOrUrl) async {
    final uri = _resolveDrawingMediaUri(pathOrUrl);
    final response = await _dio.get<List<int>>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Drawing download failed with status $code.',
      );
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Drawing download returned an empty body.',
      );
    }
    final rawName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'drawing.pdf';
    final safe = rawName.replaceAll(RegExp(r'[/\\]+'), '_');
    final tempPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '${DateTime.now().millisecondsSinceEpoch}_$safe';
    await File(tempPath).writeAsBytes(bytes, flush: true);
    return tempPath;
  }

  static Uri _resolveDrawingMediaUri(String pathOrUrl) {
    final t = pathOrUrl.trim();
    if (t.isEmpty) {
      throw ArgumentError('Drawing path/url is empty');
    }
    final parsed = Uri.tryParse(t);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return parsed;
    }
    final base = Uri.parse(AppApiUrls.baseUrl);
    return base.resolve(t.startsWith('/') ? t : '/$t');
  }

  Future<List<ProjectLevelItem>> fetchProjectLevels({
    required String projectId,
  }) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectLevels(projectId));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final data = root['data'];
    final rows = data is List ? data : const <dynamic>[];
    final out = <ProjectLevelItem>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final id = _readString(map, const ['id', 'level_id']);
      final drawingFile = _readString(map, const ['drawing_file']);
      if (id == null || id.isEmpty || drawingFile == null || drawingFile.isEmpty) {
        continue;
      }
      final name = _readString(map, const ['name']) ?? 'Level';
      final rawPlots = map['plots'];
      final parsedPlots = <Map<String, dynamic>>[];
      if (rawPlots is List) {
        for (final p in rawPlots) {
          final plot = _coerceMap(p);
          if (plot.isNotEmpty) {
            parsedPlots.add(plot);
          }
        }
      }
      out.add(
        ProjectLevelItem(
          id: id,
          name: name,
          drawingFile: drawingFile,
          plots: parsedPlots,
        ),
      );
    }
    return out;
  }

  Future<List<PinStatusItem>> fetchPinStatuses({
    int page = 1,
    int pageSize = 20,
  }) async {
    final out = <PinStatusItem>[];
    var nextPage = page < 1 ? 1 : page;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.pinStatuses,
        queryParameters: <String, dynamic>{
          'page': nextPage,
          'page_size': pageSize,
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = root['data'] is List ? (root['data'] as List<dynamic>) : const <dynamic>[];
      for (final row in rows) {
        final map = _coerceMap(row);
        final id = _readString(map, const ['id']) ?? '';
        final statusName = _readString(map, const ['status_name']) ?? '';
        if (id.isEmpty || statusName.isEmpty) continue;
        final bg = _readString(map, const ['bg_colour']) ?? '#E5E7EB';
        final text = _readString(map, const ['text_colour']) ?? '#374151';
        final isActiveRaw = map['is_active'];
        final isActive = isActiveRaw is bool
            ? isActiveRaw
            : '${isActiveRaw ?? ''}'.toLowerCase() == 'true';
        out.add(
          PinStatusItem(
            id: id,
            statusName: statusName,
            bgColour: bg,
            textColour: text,
            isActive: isActive,
          ),
        );
      }
      final pagination = _coerceMap(root['pagination']);
      final hasNext = pagination['next'] != null;
      if (!hasNext) break;
      nextPage += 1;
    }
    return out;
  }

  Future<PinStatusItem> createPinStatus({
    required String statusName,
    required String bgColour,
    required String textColour,
    bool? isActive,
  }) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.pinStatuses,
      data: <String, dynamic>{
        'status_name': statusName,
        'bg_colour': bgColour,
        'text_colour': textColour,
        if (isActive != null) 'is_active': isActive,
      },
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final id = _readString(body, const ['id']);
    final name = _readString(body, const ['status_name']);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Pin status created but payload is invalid.',
      );
    }
    return PinStatusItem(
      id: id,
      statusName: name,
      bgColour: _readString(body, const ['bg_colour']) ?? '#E5E7EB',
      textColour: _readString(body, const ['text_colour']) ?? '#374151',
      isActive: body['is_active'] is bool ? body['is_active'] as bool : true,
    );
  }

  Future<PinStatusItem> updatePinStatus({
    required String statusId,
    required String statusName,
    required String bgColour,
    required String textColour,
    required bool isActive,
  }) async {
    final response = await _dio.put<dynamic>(
      AppApiUrls.pinStatusById(statusId),
      data: <String, dynamic>{
        'status_name': statusName,
        'bg_colour': bgColour,
        'text_colour': textColour,
        'is_active': isActive,
      },
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final id = _readString(body, const ['id']) ?? statusId;
    final name = _readString(body, const ['status_name']) ?? statusName;
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Pin status updated but payload is invalid.',
      );
    }
    return PinStatusItem(
      id: id,
      statusName: name,
      bgColour: _readString(body, const ['bg_colour']) ?? bgColour,
      textColour: _readString(body, const ['text_colour']) ?? textColour,
      isActive: body['is_active'] is bool ? body['is_active'] as bool : isActive,
    );
  }

  static dynamic _normalizeResponseData(dynamic data) {
    if (data is List<int>) {
      final asText = utf8.decode(data, allowMalformed: true).trim();
      if (asText.isEmpty) return null;
      try {
        return jsonDecode(asText);
      } catch (_) {
        return asText;
      }
    }
    return data;
  }

  static Map<String, dynamic> _coerceMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, dynamic>{};
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Map<String, dynamic> _entityBody(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    final result = root['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(
        result.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return root;
  }
}

final quoteProjectApiClientProvider = Provider<QuoteProjectApiClient>((ref) {
  final storage = ref.read(localStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppApiUrls.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  dio.interceptors.addAll([
    AuthBearerInterceptor(storage),
    ApiDioLogInterceptor(),
  ]);
  return QuoteProjectApiClient(dio: dio);
});
