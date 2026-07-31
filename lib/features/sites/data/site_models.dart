import 'package:flutter/foundation.dart';

@immutable
class SiteContactPerson {
  const SiteContactPerson({
    required this.title,
    required this.contactId,
    this.contactName = '',
  });

  final String title;
  final String contactId;
  final String contactName;

  Map<String, dynamic> toJson() {
    final id = contactId.trim();
    final asInt = int.tryParse(id);
    return <String, dynamic>{
      'title': title.trim(),
      'contact': asInt ?? id,
      if (contactName.trim().isNotEmpty) 'contact_name': contactName.trim(),
    };
  }

  static SiteContactPerson? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    String read(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value == null) continue;
        if (value is Map) {
          final nested = value['id'] ?? value['name'] ?? value['contact_name'];
          final text = nested?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
          continue;
        }
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
      return '';
    }

    final title = read(const ['title', 'role', 'contact_title']);
    final contactId = read(const ['contact_id', 'contact', 'id']);
    final contactName = read(const [
      'contact_name',
      'name',
      'full_name',
    ]);
    if (title.isEmpty && contactId.isEmpty) return null;
    return SiteContactPerson(
      title: title,
      contactId: contactId,
      contactName: contactName,
    );
  }
}

@immutable
class SiteModel {
  const SiteModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    this.clientId,
    required this.addressLine1,
    required this.addressLine2,
    required this.country,
    required this.city,
    required this.state,
    required this.postalCode,
    this.what3Words = '',
    this.contactPersons = const <SiteContactPerson>[],
    this.isActive = true,
  });

  final String id;
  final String siteName;
  final String clientName;
  final int? clientId;
  final String addressLine1;
  final String addressLine2;
  final String country;
  final String city;
  final String state;
  final String postalCode;
  final String what3Words;
  final List<SiteContactPerson> contactPersons;
  final bool isActive;

  static SiteModel fromJson(Map<String, dynamic> json) {
    String read(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is Map) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    var clientName = read(const ['client_name'], fallback: 'Client');
    int? clientId;
    final clientRaw = json['client'];
    if (clientRaw is Map) {
      final clientMap = Map<String, dynamic>.from(
        clientRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final idRaw = clientMap['id'];
      clientId = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      final nestedName = clientMap['name']?.toString().trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        clientName = nestedName;
      }
    } else {
      final clientFk = json['client_id'] ?? json['client'];
      if (clientFk is int) {
        clientId = clientFk;
      } else {
        clientId = int.tryParse('${clientFk ?? ''}');
      }
    }

    final idRaw = json['id'];
    final id = idRaw == null ? '' : idRaw.toString();

    final contactsRaw =
        json['contact_persons'] ??
        json['site_contacts'] ??
        json['contacts'];
    final contactPersons = <SiteContactPerson>[];
    if (contactsRaw is List) {
      for (final entry in contactsRaw) {
        final parsed = SiteContactPerson.fromJson(entry);
        if (parsed != null) contactPersons.add(parsed);
      }
    }

    return SiteModel(
      id: id,
      siteName: read(const [
        'site_name',
        'name',
        'item_name',
      ], fallback: 'Site Name'),
      clientName: clientName,
      clientId: clientId,
      addressLine1: read(const ['address_line_1', 'address_line1', 'address']),
      addressLine2: read(const ['address_line_2', 'address_line2']),
      country: read(const ['country']),
      city: read(const ['city']),
      state: read(const ['state', 'province']),
      postalCode: read(const ['postal_code', 'pincode', 'zip_code']),
      what3Words: read(const ['what3words', 'what_3_words', 'w3w']),
      contactPersons: contactPersons,
      isActive: _readBool(json['is_active']) ?? true,
    );
  }
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}
