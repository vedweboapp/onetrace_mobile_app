class ZohoConnectResult {
  const ZohoConnectResult({
    required this.newConnection,
    required this.connectionId,
    required this.authorizationUrl,
  });

  final bool newConnection;
  final int connectionId;
  final String authorizationUrl;

  factory ZohoConnectResult.fromJson(Map<String, dynamic> json) {
    final idRaw = json['connection_id'] ?? json['id'];
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
    return ZohoConnectResult(
      newConnection: json['new_connection'] == true,
      connectionId: id,
      authorizationUrl: '${json['authorization_url'] ?? ''}'.trim(),
    );
  }
}

class ZohoConnectionDetail {
  const ZohoConnectionDetail({
    required this.id,
    this.status,
    this.isConnected = false,
    this.setupComplete = false,
    this.pullHistoricalData,
    this.connectedAt,
  });

  final int id;
  final String? status;
  final bool isConnected;
  final bool setupComplete;
  final bool? pullHistoricalData;
  final DateTime? connectedAt;

  bool get isAuthorized {
    final s = status?.trim().toLowerCase();
    if (isConnected || setupComplete) return true;
    if (s == null || s.isEmpty) return false;
    return s == 'connected' ||
        s == 'authorized' ||
        s == 'active' ||
        s == 'callback_received' ||
        s == 'completed';
  }

  factory ZohoConnectionDetail.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['connection_id'];
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
    final status = json['status']?.toString().trim();
    final connectedRaw = json['connected_at'] ?? json['modified_at'];
    DateTime? connectedAt;
    if (connectedRaw != null) {
      connectedAt = DateTime.tryParse(connectedRaw.toString());
    }
    return ZohoConnectionDetail(
      id: id,
      status: status?.isEmpty == true ? null : status,
      isConnected: _readBool(json['is_connected']) ?? false,
      setupComplete: _readBool(json['setup_complete']) ?? false,
      pullHistoricalData: _readBool(json['pull_historical_data']),
      connectedAt: connectedAt,
    );
  }
}

class ZohoKeyMappingField {
  const ZohoKeyMappingField({
    required this.zohoField,
    required this.red5Field,
    this.label,
    this.required = false,
  });

  final String zohoField;
  final String red5Field;
  final String? label;
  final bool required;

  ZohoKeyMappingField copyWith({String? red5Field}) {
    return ZohoKeyMappingField(
      zohoField: zohoField,
      red5Field: red5Field ?? this.red5Field,
      label: label,
      required: required,
    );
  }

  factory ZohoKeyMappingField.fromJson(Map<String, dynamic> json) {
    final zoho = '${json['zoho_field'] ?? json['source_field'] ?? json['key'] ?? ''}'
        .trim();
    final red5 =
        '${json['red5_field'] ?? json['target_field'] ?? json['value'] ?? ''}'
            .trim();
    final label = json['label']?.toString().trim();
    return ZohoKeyMappingField(
      zohoField: zoho,
      red5Field: red5,
      label: label?.isEmpty == true ? null : label,
      required: _readBool(json['required']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'zoho_field': zohoField,
        'red5_field': red5Field,
      };
}

class ZohoWebhookDetails {
  const ZohoWebhookDetails({
    this.webhookUrl,
    this.secret,
    this.events = const [],
    this.instructions,
  });

  final String? webhookUrl;
  final String? secret;
  final List<String> events;
  final String? instructions;

  factory ZohoWebhookDetails.fromJson(Map<String, dynamic> json) {
    final eventsRaw = json['events'];
    final events = eventsRaw is List
        ? eventsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return ZohoWebhookDetails(
      webhookUrl: json['webhook_url']?.toString().trim(),
      secret: json['secret']?.toString().trim(),
      events: events,
      instructions: json['instructions']?.toString().trim(),
    );
  }
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final t = value.toString().trim().toLowerCase();
  if (t == 'true' || t == '1') return true;
  if (t == 'false' || t == '0') return false;
  return null;
}
