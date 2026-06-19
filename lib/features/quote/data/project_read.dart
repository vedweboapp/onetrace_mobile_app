import 'package:flutter/foundation.dart';
import 'package:red5/features/forms/data/linked_form_ids.dart';
import 'package:red5/features/sites/data/site_models.dart';
@immutable
final class ProjectRead {
  const ProjectRead({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.clientId,
    this.clientName,
    this.formIds = const [],
    this.sites = const [],
    this.raw = const {},
  });

  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? clientId;
  final String? clientName;
  final List<int> formIds;
  final List<SiteModel> sites;
  final Map<String, dynamic> raw;

  bool get isCompleted {
    if (!isActive) return true;
    final end = endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String get primarySiteName {
    if (sites.isEmpty) return '—';
    return sites.first.siteName;
  }

  static ProjectRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final name = _readString(map, const ['name', 'project_name', 'title']) ??
        'Project $id';

    final clientRaw = map['client'];
    int? clientId;
    String? clientName;
    if (clientRaw is Map) {
      final clientMap = Map<String, dynamic>.from(
        clientRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      clientId = _readInt(clientMap['id']);
      clientName = _readString(clientMap, const ['name', 'client_name']);
    }

    final sitesRaw = map['sites'];
    final sites = <SiteModel>[];
    if (sitesRaw is List) {
      for (final row in sitesRaw) {
        if (row is! Map) continue;
        sites.add(
          SiteModel.fromJson(
            Map<String, dynamic>.from(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          ),
        );
      }
    }

    return ProjectRead(
      id: id,
      name: name,
      description: _readString(map, const ['description']),
      isActive: _readBool(map['is_active']) ?? true,
      startDate: _readDate(map['start_date']),
      endDate: _readDate(map['end_date']),
      clientId: clientId,
      clientName: clientName,
      formIds: readLinkedTemplateFormIds(map),
      sites: sites,
      raw: Map<String, dynamic>.from(map),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
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

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
