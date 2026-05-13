import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';

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
  });

  final int id;
  final String name;
  final int? groupId;
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
    return id;
  }

  Future<void> updateProject({
    required String projectId,
    required String name,
  }) async {
    final payload = <String, dynamic>{'name': name};
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

  /// `PUT` [project_level_update] — JSON body per API: `{ "plots": [...] }`.
  Future<void> updateLevelPlots({
    required String projectId,
    required String levelId,
    required List<Map<String, dynamic>> plots,
  }) async {
    final payload = <String, dynamic>{'plots': plots};
    _logOutgoingPayload(
      methodName: 'updateLevelPlots',
      endpoint: AppApiUrls.projectLevelById(projectId, levelId),
      payload: payload,
    );
    await _dio.put<dynamic>(
      AppApiUrls.projectLevelById(projectId, levelId),
      data: payload,
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
    final response = await _dio.get<dynamic>(
      AppApiUrls.projectLevels(projectId),
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final data = root['data'];
    final rows = data is List ? data : const <dynamic>[];
    final out = <ProjectLevelItem>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final id = _readString(map, const ['id', 'level_id']);
      final drawingFile = _readString(map, const ['drawing_file']);
      if (id == null ||
          id.isEmpty ||
          drawingFile == null ||
          drawingFile.isEmpty) {
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
      final rows = root['data'] is List
          ? (root['data'] as List<dynamic>)
          : const <dynamic>[];
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

  Future<List<CompositeItemOption>> fetchCompositeItems({int? groupId}) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.items,
      queryParameters: <String, dynamic>{
        'page': 1,
        'page_size': 20,
        'is_composite': true,
        if (groupId != null) 'group': groupId,
      },
    );
    final root = _coerceMap(_normalizeResponseData(response.data));
    final rows = root['data'] is List
        ? (root['data'] as List<dynamic>)
        : (root['results'] is List
              ? (root['results'] as List<dynamic>)
              : const <dynamic>[]);
    final out = <CompositeItemOption>[];
    for (final row in rows) {
      final map = _coerceMap(row);
      final idRaw = map['id'] ?? map['item_id'] ?? map['composite_item_id'];
      final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      if (id == null) continue;
      final rawGroup = map['group'] ?? map['group_id'];
      final parsedGroupId = rawGroup is Map
          ? int.tryParse('${rawGroup['id'] ?? ''}')
          : (rawGroup is int ? rawGroup : int.tryParse('${rawGroup ?? ''}'));
      if (groupId != null &&
          parsedGroupId != null &&
          parsedGroupId != groupId) {
        continue;
      }
      final name =
          _readString(map, const ['name', 'item_name', 'title']) ?? 'Item $id';
      out.add(CompositeItemOption(id: id, name: name, groupId: parsedGroupId));
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
        final itemIdRaw =
            item['id'] ?? item['item_id'] ?? item['composite_item_id'];
        final itemId = itemIdRaw is int
            ? itemIdRaw
            : int.tryParse('${itemIdRaw ?? ''}');
        if (itemId == null || !seenItemIds.add(itemId)) continue;
        final name =
            _readString(item, const [
              'name',
              'item_name',
              'title',
              'product_name',
            ]) ??
            'Item $itemId';
        final nestedGroupRaw = item['group'] ?? item['group_id'];
        final nestedGroupId = nestedGroupRaw is Map
            ? int.tryParse('${nestedGroupRaw['id'] ?? ''}')
            : (nestedGroupRaw is int
                  ? nestedGroupRaw
                  : int.tryParse('${nestedGroupRaw ?? ''}'));
        items.add(
          CompositeItemOption(
            id: itemId,
            name: name,
            groupId: nestedGroupId ?? groupId,
          ),
        );
      }
    }

    return GroupCompositeCatalog(groups: groups, items: items);
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
      isActive: body['is_active'] is bool
          ? body['is_active'] as bool
          : isActive,
    );
  }

  Future<void> deletePinStatus(String statusId) async {
    await _dio.delete<void>(AppApiUrls.pinStatusById(statusId));
  }

  Future<List<TagItem>> fetchTags({
    int page = 1,
    int pageSize = 50,
  }) async {
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
        final name = _readString(map, const [
              'name',
              'tag_name',
              'label',
              'title',
            ]) ??
            '';
        if (id.isEmpty || name.isEmpty) continue;
        final colour = _readString(map, const [
              'colour',
              'color',
              'bg_colour',
              'hex',
            ]) ??
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
    final response = await _dio.post<dynamic>(
      AppApiUrls.tags,
      data: payload,
    );
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
    final name = _readString(body, const [
          'name',
          'tag_name',
          'label',
        ]) ??
        '';
    if (id.isEmpty || name.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: AppApiUrls.tags),
        type: DioExceptionType.badResponse,
        message: 'Tag response missing id or name.',
      );
    }
    final colour = _readString(body, const [
          'colour',
          'color',
          'bg_colour',
        ]) ??
        '#3B82F6';
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
