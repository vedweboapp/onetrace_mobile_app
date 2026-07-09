/// inDrive / Rapido–style map palettes (minimal labels, light roads).
abstract final class OperativeRideMapStyles {
  OperativeRideMapStyles._();

  /// Clean silver day map — similar to ride-hailing apps.
  static const light = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f3f4f6"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f9fafb"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e8f5e9"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e5e7eb"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#d1d5db"}]},
  {"featureType":"road.arterial","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#dbeafe"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  /// Night / dark ride map.
  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1f2937"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9ca3af"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#111827"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#374151"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#4b5563"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#4b5563"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#111827"}]}
]
''';
}
