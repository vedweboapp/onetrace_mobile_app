part of '../job_details.dart';

class _VisibleMapTiles extends StatelessWidget {
  const _VisibleMapTiles({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static const _zoom = 15;
  static const _tileSize = 256.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final center = _worldPixel(latitude, longitude, _zoom);
        final left = center.dx - width / 2;
        final top = center.dy - height / 2;
        final firstTileX = (left / _tileSize).floor();
        final firstTileY = (top / _tileSize).floor();
        final lastTileX = ((left + width) / _tileSize).floor();
        final lastTileY = ((top + height) / _tileSize).floor();
        final maxTile = 1 << _zoom;
        final tiles = <Widget>[];

        for (var x = firstTileX; x <= lastTileX; x++) {
          for (var y = firstTileY; y <= lastTileY; y++) {
            if (y < 0 || y >= maxTile) continue;
            final wrappedX = ((x % maxTile) + maxTile) % maxTile;
            tiles.add(
              Positioned(
                left: x * _tileSize - left,
                top: y * _tileSize - top,
                width: _tileSize,
                height: _tileSize,
                child: Image.network(
                  AppMapTiles.staticTileUrl(
                    zoom: _zoom,
                    x: wrappedX,
                    y: y,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFE5E7EB)),
            ...tiles,
          ],
        );
      },
    );
  }

  static Offset _worldPixel(double lat, double lng, int zoom) {
    final sinLat = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    final scale = (1 << zoom) * _tileSize;
    final x = (lng + 180) / 360 * scale;
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }
}
