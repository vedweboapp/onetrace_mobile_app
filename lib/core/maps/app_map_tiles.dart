/// Shared raster tile URLs for [flutter_map] / static map previews.
///
/// Prefer CartoCDN over `tile.openstreetmap.org` — OSM’s public tiles are
/// frequently slow or blocked for mobile clients and flood the console with
/// socket timeouts.
abstract final class AppMapTiles {
  const AppMapTiles._();

  static const lightUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const darkUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  /// Secondary source if the primary CDN fails for a tile.
  static const fallbackUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static const userAgentPackageName = 'com.example.red5';

  /// Static Image.network URL (no `{s}` subdomain placeholder).
  static String staticTileUrl({
    required int zoom,
    required int x,
    required int y,
    bool dark = false,
  }) {
    final style = dark ? 'dark_all' : 'rastertiles/voyager';
    return 'https://a.basemaps.cartocdn.com/$style/$zoom/$x/$y.png';
  }
}
