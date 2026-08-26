import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_int_parsing.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/project_jobs_tree_models.dart';
import 'package:red5/features/forms/data/form_models.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/features/quote/data/project_read.dart';
import 'package:red5/features/sites/data/site_models.dart';

export 'package:red5/core/models/named_id_option.dart';

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
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String drawingFile;
  final List<Map<String, dynamic>> plots;

  /// API `order` field for stable display ordering (lower first).
  final int sortOrder;
}

final class ClientOption {
  const ClientOption({required this.id, required this.name});

  final int id;
  final String name;
}

final class ProjectOption {
  const ProjectOption({
    required this.id,
    required this.name,
    this.clientId,
    this.clientName,
  });

  final String id;
  final String name;
  final int? clientId;
  final String? clientName;
}

final class PinStatusItem {
  const PinStatusItem({
    required this.id,
    required this.statusName,
    required this.bgColour,
    required this.textColour,
    required this.isActive,
    this.pinCount = 0,
  });

  final String id;
  final String statusName;
  final String bgColour;
  final String textColour;
  final bool isActive;

  /// Pins using this status (when returned by the API).
  final int pinCount;

  static PinStatusItem? tryFromMap(Map<String, dynamic> map) {
    final id = QuoteProjectApiClient._readString(map, const ['id']) ?? '';
    final statusName =
        QuoteProjectApiClient._readString(map, const ['status_name']) ?? '';
    if (id.isEmpty || statusName.isEmpty) return null;
    final bg =
        QuoteProjectApiClient._readString(map, const ['bg_colour']) ??
        '#E5E7EB';
    final text =
        QuoteProjectApiClient._readString(map, const ['text_colour']) ??
        '#374151';
    final isActiveRaw = map['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : '${isActiveRaw ?? 'true'}'.toLowerCase() != 'false';
    final pinCount =
        readApiIntFromMap(map, const [
          'pin_count',
          'pins_count',
          'pins_affected',
          'affected_pins',
        ]) ??
        0;
    return PinStatusItem(
      id: id,
      statusName: statusName,
      bgColour: bg,
      textColour: text,
      isActive: isActive,
      pinCount: pinCount,
    );
  }
}

final class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.colourHex,
    this.textColourHex,
    required this.isActive,
  });

  final String id;
  final String name;

  /// Primary colour for chips (API: `colour` / `color` / `bg_colour`).
  final String colourHex;
  final String? textColourHex;
  final bool isActive;
}

/// Project type or installation type row from metadata APIs.
final class MetadataColourItem {
  const MetadataColourItem({
    required this.id,
    required this.name,
    required this.bgColour,
    required this.textColour,
    required this.isActive,
  });

  final String id;
  final String name;
  final String bgColour;
  final String textColour;
  final bool isActive;

  static MetadataColourItem? tryFromMap(
    Map<String, dynamic> map, {
    required List<String> nameKeys,
  }) {
    final id = QuoteProjectApiClient._readString(map, const ['id']) ?? '';
    final name = QuoteProjectApiClient._readString(map, nameKeys) ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    final bg =
        QuoteProjectApiClient._readString(map, const [
          'bg_color',
          'bg_colour',
          'background_color',
        ]) ??
        '#E5E7EB';
    final text =
        QuoteProjectApiClient._readString(map, const [
          'text_color',
          'text_colour',
        ]) ??
        '#374151';
    final isActiveRaw = map['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : '${isActiveRaw ?? 'true'}'.toLowerCase() != 'false';
    return MetadataColourItem(
      id: id,
      name: name,
      bgColour: bg,
      textColour: text,
      isActive: isActive,
    );
  }
}

final class GroupItemOption {
  const GroupItemOption({required this.id, required this.name});

  final int id;
  final String name;
}

final class CompositeItemOption {
  const CompositeItemOption({
    required this.id,
    required this.name,
    this.groupId,
    this.abbreviation = '',
    this.sellingPrice,
    this.quantity = 1,
    this.installationTypeId,
  });

  final int id;
  final String name;
  final int? groupId;

  /// Short code shown on map pins (e.g. "SRK").
  final String abbreviation;

  /// Item sell price from `/items/` or nested item payload.
  final double? sellingPrice;

  /// Default quantity from the group line (falls back to 1).
  final int quantity;

  /// Installation type linked to this item key (used to match project forms).
  final int? installationTypeId;
}

final class GroupCompositeCatalog {
  const GroupCompositeCatalog({required this.groups, required this.items});

  final List<GroupItemOption> groups;
  final List<CompositeItemOption> items;
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
    int? projectTypeId,
    int? siteId,
    String? description,
    String? startDate,
    String? endDate,
    List<int>? forms,
  }) async {
    final payload = <String, dynamic>{'name': name, 'quote_name': name};
    if (organizationId != null) payload['organization'] = organizationId;
    if (clientId != null) payload['client'] = clientId;
    if (projectTypeId != null) payload['project_type'] = projectTypeId;
    if (siteId != null) payload['sites'] = [siteId];
    if (description != null) payload['description'] = description;
    if (startDate != null) payload['start_date'] = startDate;
    if (endDate != null) payload['end_date'] = endDate;
    final linkedFormIds =
        forms?.where((id) => id > 0).toList(growable: false) ?? const <int>[];
    if (linkedFormIds.isNotEmpty) {
      payload['form_ids'] = linkedFormIds;
      payload['forms'] = linkedFormIds;
    }
    _logOutgoingPayload(
      methodName: 'createProject',
      endpoint: AppApiUrls.projects,
      payload: payload,
    );
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.projects,
      data: payload,
    );
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    final id =
        _readString(body, const ['id', 'project_id']) ??
        _readString(root, const ['id', 'project_id']);
    if (id == null || id.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Project created but no project id returned by backend.',
      );
    }
    if (linkedFormIds.isNotEmpty) {
      await patchProjectFormIds(projectId: id, formIds: linkedFormIds);
    }
    return id;
  }

  /// `GET /project/{id}/` — project_read
  Future<ProjectRead> fetchProjectById(String projectId) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectById(projectId));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final project = ProjectRead.tryFromMap(body.isNotEmpty ? body : root);
    if (project == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Project response did not include a valid id.',
      );
    }
    return project;
  }

  /// Fetches all pages from `GET /project/`.
  Future<List<ProjectRead>> fetchAllProjects({int pageSize = 50}) async {
    final projects = <ProjectRead>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.projects,
        queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = root['results'] is List
          ? (root['results'] as List<dynamic>)
          : (root['data'] is List
                ? (root['data'] as List<dynamic>)
                : const <dynamic>[]);
      for (final row in rows) {
        if (row is! Map) continue;
        final project = ProjectRead.tryFromMap(Map<String, dynamic>.from(row));
        if (project != null) projects.add(project);
      }
      final hasNext = root['next'] != null && rows.isNotEmpty;
      final pagination = _coerceMap(root['pagination']);
      final pagNext = pagination['next'];
      if (hasNext ||
          (pagNext != null && pagNext.toString().trim().isNotEmpty)) {
        page += 1;
        continue;
      }
      if (rows.isEmpty) break;
      page += 1;
      if (rows.length < pageSize) break;
    }
    return projects;
  }

  Future<void> updateProject({
    required String projectId,
    required String name,
    List<int>? forms,
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (forms != null) payload['forms'] = forms;
    _logOutgoingPayload(
      methodName: 'updateProject',
      endpoint: AppApiUrls.projectById(projectId),
      payload: payload,
    );
    await _dio.put<Map<String, dynamic>>(
      AppApiUrls.projectById(projectId),
      data: payload,
    );
  }

  /// `PATCH /project/{id}/` — assign form templates via `form_ids`.
  Future<void> patchProjectFormIds({
    required String projectId,
    required List<int> formIds,
  }) async {
    final payload = <String, dynamic>{
      'form_ids': formIds.where((id) => id > 0).toList(growable: false),
    };
    _logOutgoingPayload(
      methodName: 'patchProjectFormIds',
      endpoint: AppApiUrls.projectById(projectId),
      payload: payload,
    );
    await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.projectById(projectId),
      data: payload,
    );
  }

  Future<List<ClientOption>> fetchClients() async {
    final response = await _dio.get<dynamic>(AppApiUrls.clients);
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = root['data'] is List
        ? (root['data'] as List<dynamic>)
        : (root['results'] is List
              ? (root['results'] as List<dynamic>)
              : const <dynamic>[]);

    final clients = <ClientOption>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final idRaw = map['id'] ?? map['client_id'];
      final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      if (id == null) continue;
      final name =
          _readString(map, const [
            'name',
            'client_name',
            'title',
            'company_name',
          ]) ??
          'Client $id';
      clients.add(ClientOption(id: id, name: name));
    }
    return clients;
  }

  /// Projects list for admin dropdowns (create job, etc.).
  Future<List<ProjectOption>> fetchProjects({int pageSize = 100}) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.projects,
      queryParameters: <String, dynamic>{'page': 1, 'page_size': pageSize},
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = root['data'] is List
        ? (root['data'] as List<dynamic>)
        : (root['results'] is List
              ? (root['results'] as List<dynamic>)
              : const <dynamic>[]);

    final projects = <ProjectOption>[];
    final seenIds = <String>{};
    for (final row in rows) {
      final map = _coerceMap(row);
      final id = _readString(map, const ['id', 'project_id', 'quote_id']) ?? '';
      if (id.isEmpty || !seenIds.add(id)) continue;
      final name =
          _readString(map, const [
            'name',
            'Subject',
            'project_name',
            'title',
            'quote_name',
          ]) ??
          'Project $id';
      final clientRaw = map['client'] ?? map['client_id'];
      int? clientId;
      String? clientName;
      if (clientRaw is Map) {
        final clientMap = _coerceMap(clientRaw);
        final cid = clientMap['id'] ?? clientMap['client_id'];
        clientId = cid is int ? cid : int.tryParse('${cid ?? ''}');
        clientName = _readString(clientMap, const [
          'name',
          'client_name',
          'company_name',
          'title',
        ]);
      } else {
        clientId = clientRaw is int
            ? clientRaw
            : int.tryParse('${clientRaw ?? ''}');
      }
      if (clientName == null || clientName.isEmpty) {
        clientName = _readString(map, const [
          'client_name',
          'customer_name',
          'account_name',
        ]);
      }
      projects.add(
        ProjectOption(
          id: id,
          name: name,
          clientId: clientId,
          clientName: clientName,
        ),
      );
    }
    return projects;
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
    _logOutgoingPayload(
      methodName: 'upsertLevel',
      endpoint: path,
      payload: <String, dynamic>{
        'name': levelName,
        'drawing_file': drawingFilePath,
        'operation': isCreate ? 'create' : 'update',
      },
    );
    final response = !isCreate
        ? await _dio.put<dynamic>(path, data: payload)
        : await _dio.post<dynamic>(path, data: payload);

    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    var resolvedLevelId =
        _readString(body, const ['id', 'level_id']) ??
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

  /// `PUT` [project_level_update] — JSON body: `{ "payload": "<json string>" }`
  /// where the string decodes to `{ "plots": [...] }`.
  /// To clear markup, send each plot id with `coordinates` / `pins` set to null.
  /// Per-plot pin removal: omit deleted pins from `pins` and/or send `deleted_pin_ids`.
  /// Returns normalized response `data` (when present) for pin/plot id sync.
  Future<Map<String, dynamic>?> updateLevelPlots({
    required String projectId,
    required String levelId,
    required List<Map<String, dynamic>> plots,
  }) async {
    final payloadJson = jsonEncode(<String, dynamic>{'plots': plots});
    final requestBody = <String, dynamic>{'payload': payloadJson};
    final endpoint = AppApiUrls.projectLevelById(projectId, levelId);
    _logOutgoingPayload(
      methodName: 'updateLevelPlots',
      endpoint: endpoint,
      payload: <String, dynamic>{'payload': plots},
    );
    final response = await _dio.put<dynamic>(
      endpoint,
      data: requestBody,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: const <String, dynamic>{
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _levelUpdateResponseBody(root);
    if (kDebugMode) {
      final plotsRaw = body['plots'];
      final plotCount = plotsRaw is List ? plotsRaw.length : 0;
      debugPrint(
        '[API RESPONSE] updateLevelPlots $endpoint status=${response.statusCode} plots=$plotCount',
      );
    }
    return body.isNotEmpty ? body : (root.isEmpty ? null : root);
  }

  static Map<String, dynamic> _levelUpdateResponseBody(
    Map<String, dynamic> root,
  ) {
    final body = _entityBody(root);
    final payload = body['payload'];
    if (payload is Map) {
      return Map<String, dynamic>.from(
        payload.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      } catch (_) {
        // Fall through to body below.
      }
    }
    return body;
  }

  /// Plot entries returned after level update (for debugging / id sync).
  static List<Map<String, dynamic>> plotsFromLevelResponse(
    Map<String, dynamic>? body,
  ) {
    if (body == null || body.isEmpty) return const <Map<String, dynamic>>[];
    final raw = body['plots'];
    return _asMapList(raw);
  }

  /// Pin ids listed under a plot payload (`deleted_pin_ids` / `deleted_pins`).
  static List<int> deletedPinIdsFromPlotPayload(Map<String, dynamic> plot) {
    final out = <int>{};
    for (final key in ['deleted_pin_ids', 'deleted_pins', 'pins_delete']) {
      final raw = plot[key];
      if (raw is! List) continue;
      for (final entry in raw) {
        final id = readApiInt(entry);
        if (id != null) out.add(id);
      }
    }
    return out.toList(growable: false);
  }

  Future<String?> _resolveLevelIdByName({
    required String projectId,
    required String levelName,
  }) async {
    final name = levelName.trim();
    if (name.isEmpty) return null;
    try {
      final levels = await fetchProjectLevels(projectId: projectId);
      final matches = levels
          .where((e) => e.name.trim() == name)
          .toList(growable: false);
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
        // Media files are often public; still send auth when present.
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
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
    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Drawing download returned an empty body.',
      );
    }
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);

    // Reject HTML/error pages that were saved with a .pdf name.
    if (bytes.length >= 15) {
      final head = String.fromCharCodes(bytes.take(64)).toLowerCase();
      if (head.contains('<!doctype') ||
          head.contains('<html') ||
          head.contains('"detail"') && head.contains('not found')) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Attachment download did not return a file.',
        );
      }
    }

    final rawName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'drawing.pdf';
    var safe = rawName.replaceAll(RegExp(r'[/\\]+'), '_');
    if (safe.isEmpty) safe = 'drawing.pdf';
    // Ensure PDF magic bytes get a .pdf suffix so native viewers can open them.
    final isPdf = bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if (isPdf && !safe.toLowerCase().endsWith('.pdf')) {
      safe = '$safe.pdf';
    }

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
    final response = await _dio.get<dynamic>(
      AppApiUrls.projectLevels(projectId),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = _listRowsFromApiRoot(root);
    final out = <ProjectLevelItem>[];
    for (final row in rows) {
      final item = _projectLevelItemFromMap(_coerceMap(row));
      if (item != null) out.add(item);
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  /// Loads each level's full detail when the list response omits `plots` / `pins`.
  Future<List<ProjectLevelItem>> fetchProjectLevelsForQuotation({
    required String projectId,
  }) async {
    final levels = await fetchProjectLevels(projectId: projectId);
    if (levels.isEmpty) return levels;

    final enriched = <ProjectLevelItem>[];
    for (final level in levels) {
      if (level.plots.isNotEmpty && _levelHasPinData(level)) {
        enriched.add(level);
        continue;
      }
      try {
        final detail = await fetchProjectLevelById(
          projectId: projectId,
          levelId: level.id,
        );
        enriched.add(detail ?? level);
      } catch (_) {
        enriched.add(level);
      }
    }
    return enriched;
  }

  Future<ProjectLevelItem?> fetchProjectLevelById({
    required String projectId,
    required String levelId,
  }) async {
    final id = levelId.trim();
    if (id.isEmpty) return null;
    final response = await _dio.get<dynamic>(
      AppApiUrls.projectLevelById(projectId, id),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return _projectLevelItemFromMap(body.isNotEmpty ? body : root);
  }

  static bool _levelHasPinData(ProjectLevelItem level) {
    for (final plot in level.plots) {
      final pins = plot['pins'];
      if (pins is List && pins.isNotEmpty) return true;
    }
    return false;
  }

  static List<dynamic> _listRowsFromApiRoot(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['results', 'items', 'rows', 'levels']) {
        final nested = data[key];
        if (nested is List) return nested;
      }
    }
    for (final key in const ['results', 'items', 'rows', 'levels']) {
      final nested = root[key];
      if (nested is List) return nested;
    }
    return const <dynamic>[];
  }

  static ProjectLevelItem? _projectLevelItemFromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    final id = _readString(map, const ['id', 'level_id']);
    if (id == null || id.isEmpty) return null;
    final drawingFile = _readString(map, const ['drawing_file']) ?? '';
    final name = _readString(map, const ['name']) ?? 'Level';
    final orderRaw = map['order'];
    final sortOrder = orderRaw is int
        ? orderRaw
        : int.tryParse('${orderRaw ?? ''}') ?? 0;
    return ProjectLevelItem(
      id: id,
      name: name,
      drawingFile: drawingFile,
      plots: _plotsFromLevelMap(map),
      sortOrder: sortOrder,
    );
  }

  /// Plots may be nested under `payload` (JSON string or map) on level read responses.
  static List<Map<String, dynamic>> _plotsFromLevelMap(
    Map<String, dynamic> map,
  ) {
    final direct = _asMapList(map['plots']);
    if (direct.isNotEmpty) return direct;

    final payload = map['payload'];
    if (payload is Map) {
      final fromPayload = _asMapList(payload['plots']);
      if (fromPayload.isNotEmpty) return fromPayload;
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final fromPayload = _asMapList(decoded['plots']);
          if (fromPayload.isNotEmpty) return fromPayload;
        }
      } catch (_) {
        // Ignore malformed payload strings.
      }
    }

    for (final key in const ['plot_areas', 'plot_data', 'markup']) {
      final alt = _asMapList(map[key]);
      if (alt.isNotEmpty) return alt;
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<PinStatusItem>> fetchPinStatuses({
    int page = 1,
    int pageSize = 100,
    bool? isActive,
    String? search,
  }) async {
    final out = <PinStatusItem>[];
    var nextPage = page < 1 ? 1 : page;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.pinStatuses,
        queryParameters: <String, dynamic>{
          'page': nextPage,
          'page_size': pageSize,
          if (isActive != null) 'is_active': isActive.toString(),
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = _pinStatusRowsFromRoot(root);
      for (final row in rows) {
        final item = PinStatusItem.tryFromMap(_coerceMap(row));
        if (item != null) out.add(item);
      }
      if (!_pinStatusListHasNextPage(root)) break;
      nextPage += 1;
    }
    return out;
  }

  /// `PATCH /jobs/{jobId}/` — update one or more job pin statuses.
  ///
  /// Callers should pass:
  /// - level/drawing jobs → each pin's level `id`
  /// - jobs without levels → each pin's `job_pin_id`
  Future<JobRead> updateJobPinStatuses({
    required int jobId,
    required List<({int pinId, int statusId})> pinStatuses,
  }) async {
    final payload = <String, dynamic>{
      'pins': [
        for (final row in pinStatuses)
          <String, dynamic>{
            'id': row.pinId,
            'status': row.statusId,
          },
      ],
    };
    return patchJob(jobId: jobId.toString(), payload: payload);
  }

  /// `GET /pin-status/{id}/` — pin-status_read
  Future<PinStatusItem> fetchPinStatusById(String statusId) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.pinStatusById(statusId),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = PinStatusItem.tryFromMap(body);
    if (item == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Pin status response is invalid.',
      );
    }
    return item;
  }

  static List<dynamic> _pinStatusRowsFromRoot(Map<String, dynamic> root) {
    if (root['results'] is List) return root['results'] as List<dynamic>;
    if (root['data'] is List) return root['data'] as List<dynamic>;
    final pagination = _coerceMap(root['pagination']);
    if (pagination['results'] is List) {
      return pagination['results'] as List<dynamic>;
    }
    if (pagination['data'] is List) {
      return pagination['data'] as List<dynamic>;
    }
    return const <dynamic>[];
  }

  static bool _pinStatusListHasNextPage(Map<String, dynamic> root) {
    final next = root['next'];
    if (next != null && next.toString().trim().isNotEmpty) return true;
    final pagination = _coerceMap(root['pagination']);
    final pagNext = pagination['next'];
    return pagNext != null && pagNext.toString().trim().isNotEmpty;
  }

  Future<List<GroupItemOption>> fetchGroups() async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.groups,
      queryParameters: const <String, dynamic>{'page': 1, 'page_size': 20},
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = root['data'] is List
        ? (root['data'] as List<dynamic>)
        : (root['results'] is List
              ? (root['results'] as List<dynamic>)
              : const <dynamic>[]);
    final out = <GroupItemOption>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final idRaw = map['id'] ?? map['group_id'];
      final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      if (id == null) continue;
      final name =
          _readString(map, const ['name', 'group_name', 'title']) ??
          'Group $id';
      out.add(GroupItemOption(id: id, name: name));
    }
    return out;
  }

  /// Reads `installation_type` id for a catalog / composite item row.
  Future<int?> fetchItemInstallationTypeId(int itemId) async {
    for (final endpoint in [
      AppApiUrls.itemById(itemId.toString()),
      AppApiUrls.compositeItemById(itemId.toString()),
    ]) {
      try {
        final response = await _dio.get<dynamic>(endpoint);
        final root = _coerceMap(_normalizeResponseData(response.data));
        final body = _entityBody(root);
        final fromBody = readInstallationTypeId(body);
        if (fromBody != null) return fromBody;
        final itemKey = body['item_key'];
        if (itemKey is Map) {
          final fromKey = readInstallationTypeId(
            Map<String, dynamic>.from(
              itemKey.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
          if (fromKey != null) return fromKey;
        }
      } catch (_) {
        // Try the alternate item endpoint.
      }
    }
    return null;
  }

  Future<List<CompositeItemOption>> fetchCompositeItems({int? groupId}) async {
    List<CompositeItemOption> groupItems = const [];
    if (groupId != null) {
      try {
        final response = await _dio.get<dynamic>(
          AppApiUrls.groupById(groupId.toString()),
        );
        final root = _coerceMap(_normalizeResponseData(response.data));
        final body = _entityBody(root);
        final rows = _asMapList(
          body['items'] ??
              body['composite_items'] ??
              root['items'] ??
              root['composite_items'],
        );
        if (rows.isNotEmpty) {
          final out = <CompositeItemOption>[];
          final seen = <int>{};
          for (final map in rows) {
            final parsed = _parseCompositeItemOption(map, groupId: groupId);
            if (parsed == null || !seen.add(parsed.id)) continue;
            out.add(parsed);
          }
          groupItems = out;
        }
      } catch (_) {
        // Fall back to catalog list below.
      }
    }

    final requiredIds = groupItems.map((e) => e.id).toSet();
    var catalogPrices = await _fetchCompositeSellingPricesById(
      groupId: groupId,
    );
    if (groupId != null &&
        requiredIds.isNotEmpty &&
        requiredIds.any((id) => !catalogPrices.containsKey(id))) {
      final globalPrices = await _fetchCompositeSellingPricesById();
      for (final id in requiredIds) {
        if (catalogPrices.containsKey(id)) continue;
        final price = globalPrices[id];
        if (price != null) catalogPrices[id] = price;
      }
    }

    if (groupItems.isNotEmpty) {
      return _enrichCompositeItemsWithSellingPrices(groupItems, catalogPrices);
    }

    return _fetchCompositeItemsFromCatalog(groupId: groupId);
  }

  /// Selling prices keyed by composite item id from `GET /item/?is_composite=true`.
  Future<Map<int, double>> _fetchCompositeSellingPricesById({
    int? groupId,
  }) async {
    final prices = <int, double>{};
    var page = 1;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.items,
        queryParameters: <String, dynamic>{
          'page': page,
          'page_size': kDefaultApiPageSize,
          'is_composite': true,
          if (groupId != null) 'group': groupId,
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = readApiRows(root);
      if (rows.isEmpty) break;

      for (final map in rows) {
        final idRaw = map['id'];
        final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
        if (id == null) continue;
        final price = _readDouble(map, const [
          'selling_price',
          'sell_price',
          'price',
          'unit_price',
        ]);
        if (price != null) prices[id] = price;
      }

      final meta = readApiPageMeta(root, page: page);
      if (meta.currentPage >= meta.totalPages) break;
      page = meta.currentPage + 1;
      if (page > 50) break;
    }
    return prices;
  }

  Future<List<CompositeItemOption>> _fetchCompositeItemsFromCatalog({
    int? groupId,
  }) async {
    final out = <CompositeItemOption>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.items,
        queryParameters: <String, dynamic>{
          'page': page,
          'page_size': kDefaultApiPageSize,
          'is_composite': true,
          if (groupId != null) 'group': groupId,
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = readApiRows(root);
      if (rows.isEmpty) break;

      for (final map in rows) {
        final rawGroup = map['group'] ?? map['group_id'];
        final parsedGroupId = rawGroup is Map
            ? int.tryParse('${rawGroup['id'] ?? ''}')
            : (rawGroup is int ? rawGroup : int.tryParse('${rawGroup ?? ''}'));
        if (groupId != null &&
            parsedGroupId != null &&
            parsedGroupId != groupId) {
          continue;
        }
        final parsed = _parseCompositeItemOption(
          map,
          groupId: parsedGroupId ?? groupId,
        );
        if (parsed != null) out.add(parsed);
      }

      final meta = readApiPageMeta(root, page: page);
      if (meta.currentPage >= meta.totalPages) break;
      page = meta.currentPage + 1;
      if (page > 50) break;
    }
    return out;
  }

  static List<CompositeItemOption> _enrichCompositeItemsWithSellingPrices(
    List<CompositeItemOption> items,
    Map<int, double> catalogPrices,
  ) {
    if (catalogPrices.isEmpty) return items;
    return items
        .map((item) {
          if (item.sellingPrice != null) return item;
          final price = catalogPrices[item.id];
          if (price == null) return item;
          return CompositeItemOption(
            id: item.id,
            name: item.name,
            groupId: item.groupId,
            abbreviation: item.abbreviation,
            sellingPrice: price,
            quantity: item.quantity,
            installationTypeId: item.installationTypeId,
          );
        })
        .toList(growable: false);
  }

  /// Sites linked to a project (`GET /project/{id}/` → `sites[]`).
  ///
  /// Quotation `site` expects this FK, not `/item/` rows.
  Future<List<SiteModel>> fetchProjectSites({required String projectId}) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectById(projectId));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final raw = body['sites'] ?? root['sites'];
    if (raw is! List) return const [];
    final out = <SiteModel>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(
        e.map((k, v) => MapEntry(k.toString(), v)),
      );
      out.add(SiteModel.fromJson(m));
    }
    return out;
  }

  Future<GroupCompositeCatalog> fetchGroupCompositeCatalog({
    required String projectId,
  }) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectById(projectId));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final groupNodes = _asMapList(
      body['composite_groups'] ??
          root['composite_groups'] ??
          body['composite_item_groups'] ??
          root['composite_item_groups'],
    );

    final groups = <GroupItemOption>[];
    final items = <CompositeItemOption>[];
    final seenGroupIds = <int>{};
    final seenItemIds = <int>{};

    for (final g in groupNodes) {
      final groupIdRaw = g['id'] ?? g['group_id'] ?? g['pk'];
      final groupId = groupIdRaw is int
          ? groupIdRaw
          : int.tryParse('${groupIdRaw ?? ''}');
      final groupName =
          _readString(g, const ['name', 'group_name', 'title']) ??
          (groupId == null ? null : 'Group $groupId');
      if (groupId != null && groupName != null && seenGroupIds.add(groupId)) {
        groups.add(GroupItemOption(id: groupId, name: groupName));
      }

      final itemNodes = _asMapList(
        g['items'] ?? g['composite_items'] ?? g['products'] ?? g['line_items'],
      );
      for (final item in itemNodes) {
        final nestedGroupRaw = item['group'] ?? item['group_id'];
        final nestedGroupId = nestedGroupRaw is Map
            ? int.tryParse('${nestedGroupRaw['id'] ?? ''}')
            : (nestedGroupRaw is int
                  ? nestedGroupRaw
                  : int.tryParse('${nestedGroupRaw ?? ''}'));
        final parsed = _parseCompositeItemOption(
          item,
          groupId: nestedGroupId ?? groupId,
        );
        if (parsed == null || !seenItemIds.add(parsed.id)) continue;
        items.add(parsed);
      }
    }

    final catalogPrices = await _fetchCompositeSellingPricesById();
    return GroupCompositeCatalog(
      groups: groups,
      items: _enrichCompositeItemsWithSellingPrices(items, catalogPrices),
    );
  }

  Future<PinStatusItem> createPinStatus({
    required String statusName,
    required String bgColour,
    required String textColour,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      'status_name': statusName,
      'bg_colour': bgColour,
      'text_colour': textColour,
      if (isActive != null) 'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'createPinStatus',
      endpoint: AppApiUrls.pinStatuses,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(
      AppApiUrls.pinStatuses,
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = PinStatusItem.tryFromMap(body);
    if (item == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Pin status created but payload is invalid.',
      );
    }
    return item;
  }

  Future<PinStatusItem> updatePinStatus({
    required String statusId,
    required String statusName,
    required String bgColour,
    required String textColour,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'status_name': statusName,
      'bg_colour': bgColour,
      'text_colour': textColour,
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'updatePinStatus',
      endpoint: AppApiUrls.pinStatusById(statusId),
      payload: payload,
    );
    final response = await _dio.put<dynamic>(
      AppApiUrls.pinStatusById(statusId),
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = PinStatusItem.tryFromMap(body);
    if (item == null) {
      return PinStatusItem(
        id: statusId,
        statusName: statusName,
        bgColour: bgColour,
        textColour: textColour,
        isActive: isActive,
      );
    }
    return item;
  }

  /// `PATCH /pin-status/{id}/` — pin-status_partial_update
  Future<PinStatusItem> patchPinStatus({
    required String statusId,
    String? statusName,
    String? bgColour,
    String? textColour,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (statusName != null) 'status_name': statusName,
      if (bgColour != null) 'bg_colour': bgColour,
      if (textColour != null) 'text_colour': textColour,
      if (isActive != null) 'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'patchPinStatus',
      endpoint: AppApiUrls.pinStatusById(statusId),
      payload: payload,
    );
    final response = await _dio.patch<dynamic>(
      AppApiUrls.pinStatusById(statusId),
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = PinStatusItem.tryFromMap(body);
    if (item != null) return item;
    return fetchPinStatusById(statusId);
  }

  /// `DELETE /pin-status/{id}/` — pin-status_delete
  ///
  /// When [moveToStatusId] is set, sends reassignment in the request body
  /// (`move_to` / `reassign_to`) for backends that support it.
  Future<void> deletePinStatus(
    String statusId, {
    String? moveToStatusId,
  }) async {
    final moveTo = moveToStatusId?.trim();
    await _dio.delete<void>(
      AppApiUrls.pinStatusById(statusId),
      data: moveTo != null && moveTo.isNotEmpty
          ? <String, dynamic>{'move_to': moveTo, 'reassign_to': moveTo}
          : null,
    );
  }

  /// `GET /jobs/` — jobs_list
  Future<List<JobRead>> fetchJobs({
    String? jobStatus,
    String? assignedWorker,
    String? jobSource,
    String? jobCategory,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobs,
      queryParameters: _jobsListQuery(
        jobStatus: jobStatus,
        assignedWorker: assignedWorker,
        jobSource: jobSource,
        jobCategory: jobCategory,
        search: search,
        page: page,
        pageSize: pageSize,
      ),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    return _jobReadsFromApiRoot(root);
  }

  /// Paginated `GET /jobs/` — jobs list for the dashboard Jobs screen.
  Future<JobsPageResult> fetchJobsPage({
    int page = 1,
    int pageSize = kDefaultApiPageSize,
    String? jobStatus,
    String? assignedWorker,
    String? jobSource,
    String? jobCategory,
    String? search,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobs,
      queryParameters: _jobsListQuery(
        jobStatus: jobStatus,
        assignedWorker: assignedWorker,
        jobSource: jobSource,
        jobCategory: jobCategory,
        search: search,
        page: page,
        pageSize: pageSize,
      ),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final items = _jobReadsFromApiRoot(root);
    final meta = readApiPageMeta(root, page: page);
    return JobsPageResult(
      items: items,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  /// `GET /project/{id}/jobs/` — hierarchical levels → plots → jobs.
  Future<ProjectJobsTree> fetchProjectJobsTree({
    required String projectId,
    String? search,
  }) async {
    final id = projectId.trim();
    if (id.isEmpty) return const ProjectJobsTree();

    final response = await _dio.get<dynamic>(
      AppApiUrls.projectJobs(id),
      queryParameters: <String, dynamic>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final tree = ProjectJobsTree.fromApiRoot(root);
    return tree.filteredBySearch(search ?? '');
  }

  /// `GET /project/{id}/jobs/` — jobs for a single project.
  Future<List<JobRead>> fetchProjectJobs({
    required String projectId,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final id = projectId.trim();
    if (id.isEmpty) return const [];

    final response = await _dio.get<dynamic>(
      AppApiUrls.projectJobs(id),
      queryParameters: <String, dynamic>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': page < 1 ? 1 : page,
        'page_size': pageSize,
      },
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    return _jobReadsFromApiRoot(root);
  }

  /// Fetches all jobs from `GET /project/{id}/jobs/` (flattened).
  Future<List<JobRead>> fetchAllProjectJobs({
    required String projectId,
    String? search,
    int pageSize = 50,
  }) async {
    final tree = await fetchProjectJobsTree(
      projectId: projectId,
      search: search,
    );
    return _jobReadsFromProjectTree(tree);
  }

  static List<JobRead> _jobReadsFromProjectTree(ProjectJobsTree tree) {
    final jobs = <JobRead>[];
    for (final level in tree.levels) {
      for (final plot in level.plots) {
        for (final job in plot.jobs) {
          jobs.add(
            JobRead(
              id: job.id,
              title: job.title,
              description: job.description,
              jobSource: job.jobSource,
              startDate: job.startDate,
              completedAt: job.completedAt,
              workerName: job.assignedWorkerName,
              assignedWorker: job.assignedWorkerId,
              jobPinStatus: job.statusName,
              plotName: plot.name,
              sectionName: level.name,
            ),
          );
        }
      }
    }
    for (final job in tree.manualJobs) {
      jobs.add(
        JobRead(
          id: job.id,
          title: job.title,
          description: job.description,
          jobSource: job.jobSource,
          startDate: job.startDate,
          completedAt: job.completedAt,
          workerName: job.assignedWorkerName,
          assignedWorker: job.assignedWorkerId,
          jobPinStatus: job.statusName,
        ),
      );
    }
    return jobs;
  }

  /// Fetches all pages from `GET /jobs/`.
  Future<List<JobRead>> fetchAllJobs({
    String? jobStatus,
    String? assignedWorker,
    String? jobSource,
    String? jobCategory,
    String? search,
    int pageSize = 50,
  }) async {
    final jobs = <JobRead>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.jobs,
        queryParameters: _jobsListQuery(
          jobStatus: jobStatus,
          assignedWorker: assignedWorker,
          jobSource: jobSource,
          jobCategory: jobCategory,
          search: search,
          page: page,
          pageSize: pageSize,
        ),
      );
      if (kDebugMode && page == 1) {
        JobCompletionDebugLog.banner('Employee home — GET /jobs/');
        JobCompletionDebugLog.api(
          label: 'Jobs list (page 1)',
          method: 'GET',
          url: '/api/v1${AppApiUrls.jobs}',
          statusCode: response.statusCode,
          response: response.data,
        );
      }
      final root = _coerceMap(_normalizeResponseData(response.data));
      final pageJobs = _jobReadsFromApiRoot(root);
      jobs.addAll(pageJobs);
      if (!readApiHasNextPage(root) || pageJobs.isEmpty) break;
      page += 1;
    }
    return jobs;
  }

  /// Job status options for create/edit job forms.
  Future<List<NamedIdOption>> fetchJobStatusOptions() async {
    return _fetchNamedIdOptions(
      AppApiUrls.jobStatuses,
      nameKeys: const ['status_name', 'name', 'title', 'label'],
    );
  }

  /// `GET /job-status/{id}/` — job-status_read (`data.id` → `job_status` FK).
  Future<NamedIdOption?> fetchJobStatusById(int id) async {
    try {
      final response = await _dio.get<dynamic>(
        AppApiUrls.jobStatusById('$id'),
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final body = readApiEntityBody(root);
      final parsedId = readApiIntFromMap(body, const ['id']);
      if (parsedId == null) return null;
      final name =
          _readString(body, const ['status_name', 'name', 'title', 'label']) ??
          'Status $parsedId';
      return NamedIdOption(id: parsedId, name: name);
    } catch (_) {
      return null;
    }
  }

  /// Project type options for create project forms.
  Future<List<NamedIdOption>> fetchProjectTypeOptions() async {
    final items = await fetchProjectTypes(isActive: true);
    return items
        .map((item) {
          final id = int.tryParse(item.id);
          if (id == null) return null;
          return NamedIdOption(id: id, name: item.name);
        })
        .whereType<NamedIdOption>()
        .toList(growable: false);
  }

  /// `GET /project-type/` — project-type_list
  Future<List<MetadataColourItem>> fetchProjectTypes({
    int page = 1,
    int pageSize = 100,
    bool? isActive,
  }) {
    return _fetchMetadataColourItems(
      endpoint: AppApiUrls.projectTypes,
      nameKeys: const ['project_type', 'type_name', 'name', 'title', 'label'],
      page: page,
      pageSize: pageSize,
      isActive: isActive,
    );
  }

  /// `GET /project-type/{id}/` — project-type_read
  Future<MetadataColourItem> fetchProjectTypeById(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectTypeById(id));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = MetadataColourItem.tryFromMap(
      body,
      nameKeys: const ['project_type', 'type_name', 'name', 'title', 'label'],
    );
    if (item == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Project type response is invalid.',
      );
    }
    return item;
  }

  /// `POST /project-type/` — create a project type metadata row.
  Future<NamedIdOption> createProjectType({
    required String projectType,
    required String bgColor,
    required String textColor,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      'project_type': projectType.trim(),
      'bg_color': bgColor.trim().toLowerCase(),
      'text_color': textColor.trim().toLowerCase(),
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'createProjectType',
      endpoint: AppApiUrls.projectTypes,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(
      AppApiUrls.projectTypes,
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final idRaw = body['id'];
    final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
    if (id == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Project type created but no id returned.',
      );
    }
    final name =
        _readString(body, const ['project_type', 'name']) ?? projectType.trim();
    return NamedIdOption(id: id, name: name);
  }

  /// `PUT /project-type/{id}/` — project-type_update
  Future<MetadataColourItem> updateProjectType({
    required String id,
    required String projectType,
    required String bgColor,
    required String textColor,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'project_type': projectType.trim(),
      'bg_color': bgColor.trim().toLowerCase(),
      'text_color': textColor.trim().toLowerCase(),
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'updateProjectType',
      endpoint: AppApiUrls.projectTypeById(id),
      payload: payload,
    );
    final response = await _dio.put<dynamic>(
      AppApiUrls.projectTypeById(id),
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return MetadataColourItem.tryFromMap(
          body,
          nameKeys: const [
            'project_type',
            'type_name',
            'name',
            'title',
            'label',
          ],
        ) ??
        MetadataColourItem(
          id: id,
          name: projectType.trim(),
          bgColour: bgColor,
          textColour: textColor,
          isActive: isActive,
        );
  }

  /// `DELETE /project-type/{id}/` — project-type_delete
  Future<void> deleteProjectType(String id) async {
    await _dio.delete<void>(AppApiUrls.projectTypeById(id));
  }

  /// Installation type options for dropdowns.
  Future<List<NamedIdOption>> fetchInstallationTypeOptions({
    bool? isActive,
  }) async {
    final items = await fetchInstallationTypes(isActive: isActive ?? true);
    return items
        .map((item) {
          final id = int.tryParse(item.id);
          if (id == null) return null;
          return NamedIdOption(id: id, name: item.name);
        })
        .whereType<NamedIdOption>()
        .toList(growable: false);
  }

  /// `GET /installation-type/` — installation-type_list
  Future<List<MetadataColourItem>> fetchInstallationTypes({
    int page = 1,
    int pageSize = 100,
    bool? isActive,
  }) {
    return _fetchMetadataColourItems(
      endpoint: AppApiUrls.installationTypes,
      nameKeys: const [
        'installation_type',
        'type_name',
        'name',
        'title',
        'label',
      ],
      page: page,
      pageSize: pageSize,
      isActive: isActive,
    );
  }

  /// `GET /installation-type/{id}/` — installation-type_read
  Future<MetadataColourItem> fetchInstallationTypeById(String id) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.installationTypeById(id),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = MetadataColourItem.tryFromMap(
      body,
      nameKeys: const [
        'installation_type',
        'type_name',
        'name',
        'title',
        'label',
      ],
    );
    if (item == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Installation type response is invalid.',
      );
    }
    return item;
  }

  /// `POST /installation-type/` — installation-type_create
  Future<MetadataColourItem> createInstallationType({
    required String installationType,
    required String bgColor,
    required String textColor,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      'installation_type': installationType.trim(),
      'bg_color': bgColor.trim().toLowerCase(),
      'text_color': textColor.trim().toLowerCase(),
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'createInstallationType',
      endpoint: AppApiUrls.installationTypes,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(
      AppApiUrls.installationTypes,
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final item = MetadataColourItem.tryFromMap(
      body,
      nameKeys: const [
        'installation_type',
        'type_name',
        'name',
        'title',
        'label',
      ],
    );
    if (item == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Installation type created but payload is invalid.',
      );
    }
    return item;
  }

  /// `PUT /installation-type/{id}/` — installation-type_update
  Future<MetadataColourItem> updateInstallationType({
    required String id,
    required String installationType,
    required String bgColor,
    required String textColor,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'installation_type': installationType.trim(),
      'bg_color': bgColor.trim().toLowerCase(),
      'text_color': textColor.trim().toLowerCase(),
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'updateInstallationType',
      endpoint: AppApiUrls.installationTypeById(id),
      payload: payload,
    );
    final response = await _dio.put<dynamic>(
      AppApiUrls.installationTypeById(id),
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return MetadataColourItem.tryFromMap(
          body,
          nameKeys: const [
            'installation_type',
            'type_name',
            'name',
            'title',
            'label',
          ],
        ) ??
        MetadataColourItem(
          id: id,
          name: installationType.trim(),
          bgColour: bgColor,
          textColour: textColor,
          isActive: isActive,
        );
  }

  /// `DELETE /installation-type/{id}/` — installation-type_delete
  Future<void> deleteInstallationType(String id) async {
    await _dio.delete<void>(AppApiUrls.installationTypeById(id));
  }

  Future<List<MetadataColourItem>> _fetchMetadataColourItems({
    required String endpoint,
    required List<String> nameKeys,
    int page = 1,
    int pageSize = 100,
    bool? isActive,
  }) async {
    final out = <MetadataColourItem>[];
    var nextPage = page < 1 ? 1 : page;
    while (true) {
      final response = await _dio.get<dynamic>(
        endpoint,
        queryParameters: <String, dynamic>{
          'page': nextPage,
          'page_size': pageSize,
          if (isActive != null) 'is_active': isActive,
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = root['data'] is List
          ? (root['data'] as List<dynamic>)
          : (root['results'] is List
                ? (root['results'] as List<dynamic>)
                : const <dynamic>[]);
      for (final row in rows) {
        final item = MetadataColourItem.tryFromMap(
          _coerceMap(row),
          nameKeys: nameKeys,
        );
        if (item != null) out.add(item);
      }
      final pagination = _coerceMap(root['pagination']);
      final hasNext = pagination['next'] != null;
      if (!hasNext) break;
      nextPage += 1;
    }
    return out;
  }

  /// Registered QR codes for create/edit job forms.
  Future<List<NamedIdOption>> fetchQrCodeOptions() async {
    return _fetchNamedIdOptions(
      AppApiUrls.qrCodes,
      nameKeys: const [
        'qr_code_id',
        'code',
        'name',
        'title',
        'label',
        'qr_code',
      ],
    );
  }

  Future<List<NamedIdOption>> _fetchNamedIdOptions(
    String endpoint, {
    required List<String> nameKeys,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        endpoint,
        queryParameters:
            queryParameters ??
            const <String, dynamic>{'page': 1, 'page_size': 100},
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      var rows = readApiRows(root);
      if (rows.isEmpty) {
        final entity = readApiEntityBody(root);
        if (readApiIntFromMap(entity, const ['id']) != null) {
          rows = [entity];
        }
      }
      final out = <NamedIdOption>[];
      final seen = <int>{};
      for (final map in rows) {
        final id = readApiIntFromMap(map, const ['id']);
        if (id == null || !seen.add(id)) continue;
        final name = _readString(map, nameKeys) ?? 'Item $id';
        out.add(NamedIdOption(id: id, name: name));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// `GET /jobs/{id}/` — jobs_read
  Future<JobRead> fetchJobById(String jobId) async {
    final response = await _dio.get<dynamic>(AppApiUrls.jobById(jobId));
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final job = JobRead.tryFromMap(body);
    if (job == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Job response missing id.',
      );
    }
    return job;
  }

  /// `POST /jobs/` — jobs_create
  Future<JobRead> createJob(Map<String, dynamic> payload) async {
    _logOutgoingPayload(
      methodName: 'createJob',
      endpoint: AppApiUrls.jobs,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(AppApiUrls.jobs, data: payload);
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final job = JobRead.tryFromMap(body);
    if (job == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Job created but response missing id.',
      );
    }
    return job;
  }

  /// `POST /jobs/create-from-quotation/` — jobs_create_from_quotation
  Future<JobRead> createJobFromQuotation(Map<String, dynamic> payload) async {
    _logOutgoingPayload(
      methodName: 'createJobFromQuotation',
      endpoint: AppApiUrls.jobsCreateFromQuotation,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(
      AppApiUrls.jobsCreateFromQuotation,
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    final job = JobRead.tryFromMap(body);
    if (job == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Job created but response missing id.',
      );
    }
    return job;
  }

  /// `PATCH /jobs/{id}/` — jobs_partial_update (operative partial saves).
  Future<JobRead> patchJob({
    required String jobId,
    required Map<String, dynamic> payload,
  }) async {
    _logOutgoingPayload(
      methodName: 'patchJob',
      endpoint: AppApiUrls.jobById(jobId),
      payload: payload,
    );
    final response = await _dio.patch<dynamic>(
      AppApiUrls.jobById(jobId),
      data: payload,
    );
    if (kDebugMode) {
      JobCompletionDebugLog.api(
        label: 'patchJob (HTTP)',
        method: 'PATCH',
        url: '/api/v1${AppApiUrls.jobById(jobId)}',
        statusCode: response.statusCode,
        response: response.data,
      );
    }
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return JobRead.tryFromMap(body) ?? fetchJobById(jobId);
  }

  /// `PUT /jobs/{id}/` — jobs_update
  Future<JobRead> updateJob({
    required String jobId,
    required Map<String, dynamic> payload,
  }) async {
    _logOutgoingPayload(
      methodName: 'updateJob',
      endpoint: AppApiUrls.jobById(jobId),
      payload: payload,
    );
    final response = await _dio.put<dynamic>(
      AppApiUrls.jobById(jobId),
      data: payload,
    );
    if (kDebugMode) {
      JobCompletionDebugLog.api(
        label: 'updateJob (HTTP)',
        method: 'PUT',
        url: '/api/v1${AppApiUrls.jobById(jobId)}',
        statusCode: response.statusCode,
        response: response.data,
      );
    }
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return JobRead.tryFromMap(body) ?? fetchJobById(jobId);
  }

  /// `DELETE /jobs/{id}/` — jobs_delete
  Future<void> deleteJob(String jobId) async {
    await _dio.delete<void>(AppApiUrls.jobById(jobId));
  }

  Future<List<TagItem>> fetchTags({int page = 1, int pageSize = 50}) async {
    final out = <TagItem>[];
    var nextPage = page < 1 ? 1 : page;
    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.tags,
        queryParameters: <String, dynamic>{
          'page': nextPage,
          'page_size': pageSize,
        },
      );
      final root = _coerceMap(_normalizeResponseData(response.data));
      final rows = root['data'] is List
          ? (root['data'] as List<dynamic>)
          : const <dynamic>[];
      for (final row in rows) {
        final map = _coerceMap(row);
        final id = _readString(map, const ['id', 'tag_id']) ?? '';
        final name =
            _readString(map, const ['name', 'tag_name', 'label', 'title']) ??
            '';
        if (id.isEmpty || name.isEmpty) continue;
        final colour =
            _readString(map, const ['colour', 'color', 'bg_colour', 'hex']) ??
            '#3B82F6';
        final textC = _readString(map, const ['text_colour', 'text_color']);
        final isActiveRaw = map['is_active'];
        final isActive = isActiveRaw is bool
            ? isActiveRaw
            : '${isActiveRaw ?? 'true'}'.toLowerCase() != 'false';
        out.add(
          TagItem(
            id: id,
            name: name,
            colourHex: colour,
            textColourHex: textC,
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

  Future<TagItem> createTag({
    required String name,
    required String colourHex,
    String? textColourHex,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'colour': colourHex,
      if (textColourHex != null) 'text_colour': textColourHex,
      if (isActive != null) 'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'createTag',
      endpoint: AppApiUrls.tags,
      payload: payload,
    );
    final response = await _dio.post<dynamic>(AppApiUrls.tags, data: payload);
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return _tagItemFromMap(body);
  }

  Future<TagItem> updateTag({
    required String tagId,
    required String name,
    required String colourHex,
    String? textColourHex,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'colour': colourHex,
      if (textColourHex != null) 'text_colour': textColourHex,
      'is_active': isActive,
    };
    _logOutgoingPayload(
      methodName: 'updateTag',
      endpoint: AppApiUrls.tagById(tagId),
      payload: payload,
    );
    final response = await _dio.put<dynamic>(
      AppApiUrls.tagById(tagId),
      data: payload,
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final body = _entityBody(root);
    return _tagItemFromMap(body, fallbackId: tagId);
  }

  Future<void> deleteTag(String tagId) async {
    await _dio.delete<void>(AppApiUrls.tagById(tagId));
  }

  TagItem _tagItemFromMap(Map<String, dynamic> body, {String? fallbackId}) {
    final id = _readString(body, const ['id', 'tag_id']) ?? fallbackId ?? '';
    final name = _readString(body, const ['name', 'tag_name', 'label']) ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: AppApiUrls.tags),
        type: DioExceptionType.badResponse,
        message: 'Tag response missing id or name.',
      );
    }
    final colour =
        _readString(body, const ['colour', 'color', 'bg_colour']) ?? '#3B82F6';
    final textC = _readString(body, const ['text_colour', 'text_color']);
    final isActiveRaw = body['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : '${isActiveRaw ?? 'true'}'.toLowerCase() != 'false';
    return TagItem(
      id: id,
      name: name,
      colourHex: colour,
      textColourHex: textC,
      isActive: isActive,
    );
  }

  static List<JobRead> _jobReadsFromApiRoot(Map<String, dynamic> root) {
    return readApiRows(
      root,
    ).map(JobRead.tryFromMap).whereType<JobRead>().toList(growable: false);
  }

  static Map<String, dynamic> _jobsListQuery({
    String? jobStatus,
    String? assignedWorker,
    String? jobSource,
    String? jobCategory,
    String? search,
    required int page,
    required int pageSize,
  }) {
    return <String, dynamic>{
      if (jobStatus != null && jobStatus.trim().isNotEmpty)
        'job_status': jobStatus.trim(),
      if (assignedWorker != null && assignedWorker.trim().isNotEmpty)
        'assigned_worker': assignedWorker.trim(),
      if (jobSource != null && jobSource.trim().isNotEmpty)
        'job_source': jobSource.trim(),
      if (jobCategory != null && jobCategory.trim().isNotEmpty)
        'job_category': jobCategory.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'page': page < 1 ? 1 : page,
      'page_size': pageSize,
    };
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

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
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

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value == null) continue;
      final parsed = double.tryParse(
        value.toString().trim().replaceAll(RegExp(r'[^\d.-]'), ''),
      );
      if (parsed != null) return parsed;
    }
    return null;
  }

  static int _readInt(
    Map<String, dynamic> map,
    List<String> keys, {
    int fallback = 1,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value == null) continue;
      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static Map<String, dynamic>? _nestedItemMap(Map<String, dynamic> map) {
    for (final key in const [
      'item',
      'composite_item',
      'item_key',
      'product',
      'item_detail',
      'composite_item_detail',
    ]) {
      final raw = map[key];
      if (raw is Map) {
        return Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return null;
  }

  static int? _resolveCompositeItemId(
    Map<String, dynamic> map,
    Map<String, dynamic>? nested,
  ) {
    for (final key in const ['composite_item_id', 'item_id']) {
      final raw = map[key];
      if (raw is int) return raw;
      final parsed = int.tryParse('${raw ?? ''}');
      if (parsed != null) return parsed;
    }
    if (nested != null) {
      final raw = nested['id'];
      if (raw is int) return raw;
      final parsed = int.tryParse('${raw ?? ''}');
      if (parsed != null) return parsed;
    }
    for (final key in const ['item', 'composite_item']) {
      final raw = map[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    final raw = map['id'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  static CompositeItemOption? _parseCompositeItemOption(
    Map<String, dynamic> map, {
    int? groupId,
  }) {
    final nested = _nestedItemMap(map);
    final id = _resolveCompositeItemId(map, nested);
    if (id == null) return null;

    final name =
        _readString(map, const [
          'item_name',
          'name',
          'title',
          'product_name',
        ]) ??
        (nested != null
            ? _readString(nested, const ['name', 'item_name', 'title'])
            : null) ??
        'Item $id';
    final abbreviation =
        _readString(map, const ['abbreviation', 'short_code', 'code']) ??
        (nested != null
            ? _readString(nested, const ['abbreviation', 'short_code', 'code'])
            : null) ??
        '';
    final sellingPrice =
        _readDouble(map, const [
          'selling_price',
          'sell_price',
          'price',
          'unit_price',
        ]) ??
        (nested != null
            ? _readDouble(nested, const [
                'selling_price',
                'sell_price',
                'price',
                'unit_price',
              ])
            : null);
    final quantity = _readInt(map, const ['quantity', 'qty'], fallback: 1);
    final installationTypeId =
        readInstallationTypeId(map) ??
        (nested != null ? readInstallationTypeId(nested) : null) ??
        _readInstallationTypeFromItemKey(map);

    return CompositeItemOption(
      id: id,
      name: name,
      groupId: groupId,
      abbreviation: abbreviation,
      sellingPrice: sellingPrice,
      quantity: quantity > 0 ? quantity : 1,
      installationTypeId: installationTypeId,
    );
  }

  static int? _readInstallationTypeFromItemKey(Map<String, dynamic> map) {
    final raw = map['item_key'];
    if (raw is! Map) return null;
    return readInstallationTypeId(
      Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))),
    );
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

  static void _logOutgoingPayload({
    required String methodName,
    required String endpoint,
    required Object payload,
  }) {
    if (!kDebugMode) return;
    final prettyPayload = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('[API PAYLOAD] $methodName -> $endpoint\n$prettyPayload');
  }
}

final quoteProjectApiClientProvider = Provider<QuoteProjectApiClient>(
  (ref) => sl<QuoteProjectApiClient>(),
);
