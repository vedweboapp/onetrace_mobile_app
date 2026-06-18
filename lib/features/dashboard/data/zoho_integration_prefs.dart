import 'package:shared_preferences/shared_preferences.dart';

/// Local Zoho integration state for Settings and pending OAuth setup.
class ZohoIntegrationPrefs {
  const ZohoIntegrationPrefs({
    required this.isConnected,
    this.lastConnected,
    this.pullHistoricalData = false,
    this.connectionId,
    this.pendingConnectionId,
  });

  final bool isConnected;
  final DateTime? lastConnected;
  final bool pullHistoricalData;
  final int? connectionId;
  final int? pendingConnectionId;

  static const prefsKeyLastConnectedIso = 'integration_zoho_last_connected_iso';
  static const prefsKeyPullHistoricalData =
      'integration_zoho_pull_historical_data';
  static const prefsKeyIsConnected = 'integration_zoho_is_connected';
  static const prefsKeyConnectionId = 'integration_zoho_connection_id';
  static const prefsKeyPendingConnectionId =
      'integration_zoho_pending_connection_id';

  static Future<ZohoIntegrationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool(prefsKeyIsConnected) ?? false;
    final pullHistorical = prefs.getBool(prefsKeyPullHistoricalData) ?? false;
    final connectionId = prefs.getInt(prefsKeyConnectionId);
    final pendingConnectionId = prefs.getInt(prefsKeyPendingConnectionId);
    final raw = prefs.getString(prefsKeyLastConnectedIso);
    DateTime? lastConnected;
    if (raw != null && raw.trim().isNotEmpty) {
      lastConnected = DateTime.tryParse(raw.trim());
    }
    return ZohoIntegrationPrefs(
      isConnected: connected,
      lastConnected: lastConnected,
      pullHistoricalData: pullHistorical,
      connectionId: connectionId,
      pendingConnectionId: pendingConnectionId,
    );
  }

  static Future<void> savePendingConnection(int connectionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKeyPendingConnectionId, connectionId);
  }

  static Future<void> clearPendingConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyPendingConnectionId);
  }

  static Future<void> saveCompletedConnection({
    required int connectionId,
    required bool pullHistoricalData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    await prefs.setBool(prefsKeyIsConnected, true);
    await prefs.setBool(prefsKeyPullHistoricalData, pullHistoricalData);
    await prefs.setInt(prefsKeyConnectionId, connectionId);
    await prefs.setString(prefsKeyLastConnectedIso, now.toIso8601String());
    await prefs.remove(prefsKeyPendingConnectionId);
  }
}
