import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/pdf_coordinates/pdf_coordinates.dart';

export 'package:red5/core/pdf_coordinates/pdf_coordinate_transformer.dart'
    show
        docToViewportLocal,
        findNearestPage,
        findPageContainingDoc,
        safeGetPageRect,
        viewportLocalToDoc;

/// Pin in page-local normalized coords (0–1 within page rect) for PDF,
/// or layer-normalized (0–1 overlay) when [page] is null (raster image).
class PinEntry {
  PinEntry({
    required this.nx,
    required this.ny,
    this.page,
    this.pdfPoint,
    this.productName,
    this.groupName,
    this.blockName,
    this.levelName,
    this.zoneLabel,
    this.description = '',
    this.quantity = 1,
    this.status = 'To Do',
    this.variation = 'No',
    this.droppedAt,
    this.attachmentNames = const <String>[],
  });

  final double nx;
  final double ny;

  /// 1-based page index for PDF; null for images.
  final int? page;

  /// True PDF user-space position (source of truth when set).
  final PdfAnnotationPoint? pdfPoint;

  /// Captured when the pin is placed (product picker / “Place Pin”).
  final String? productName;

  final String? groupName;
  final String? blockName;
  final String? levelName;

  /// Often the plot / highlight name under the drop point.
  final String? zoneLabel;

  final String description;
  final int quantity;
  final String status;
  final String variation;
  final DateTime? droppedAt;
  final List<String> attachmentNames;

  factory PinEntry.fromAnnotation(
    PdfAnnotationPoint point, {
    String? productName,
    String? groupName,
    String? blockName,
    String? levelName,
    String? zoneLabel,
    String description = '',
    int quantity = 1,
    String status = 'To Do',
    String variation = 'No',
    DateTime? droppedAt,
    List<String> attachmentNames = const <String>[],
  }) {
    return PinEntry(
      nx: point.fractionX,
      ny: point.fractionY,
      page: point.page,
      pdfPoint: point,
      productName: productName,
      groupName: groupName,
      blockName: blockName,
      levelName: levelName,
      zoneLabel: zoneLabel,
      description: description,
      quantity: quantity,
      status: status,
      variation: variation,
      droppedAt: droppedAt,
      attachmentNames: attachmentNames,
    );
  }

  PinEntry copyWith({
    double? nx,
    double? ny,
    int? page,
    PdfAnnotationPoint? pdfPoint,
    String? productName,
    String? groupName,
    String? blockName,
    String? levelName,
    String? zoneLabel,
    String? description,
    int? quantity,
    String? status,
    String? variation,
    DateTime? droppedAt,
    List<String>? attachmentNames,
  }) {
    return PinEntry(
      nx: nx ?? this.nx,
      ny: ny ?? this.ny,
      page: page ?? this.page,
      pdfPoint: pdfPoint ?? this.pdfPoint,
      productName: productName ?? this.productName,
      groupName: groupName ?? this.groupName,
      blockName: blockName ?? this.blockName,
      levelName: levelName ?? this.levelName,
      zoneLabel: zoneLabel ?? this.zoneLabel,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      variation: variation ?? this.variation,
      droppedAt: droppedAt ?? this.droppedAt,
      attachmentNames: attachmentNames ?? this.attachmentNames,
    );
  }

  Map<String, dynamic> toJson() => {
    'nx': nx,
    'ny': ny,
    if (page != null) 'page': page,
    if (productName != null && productName!.trim().isNotEmpty)
      'productName': productName!.trim(),
    if (groupName != null && groupName!.trim().isNotEmpty)
      'groupName': groupName!.trim(),
    if (blockName != null && blockName!.trim().isNotEmpty)
      'blockName': blockName!.trim(),
    if (levelName != null && levelName!.trim().isNotEmpty)
      'levelName': levelName!.trim(),
    if (zoneLabel != null && zoneLabel!.trim().isNotEmpty)
      'zoneLabel': zoneLabel!.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
    if (quantity != 1) 'quantity': quantity,
    if (status != 'To Do') 'status': status,
    if (variation != 'No') 'variation': variation,
    if (droppedAt != null) 'droppedAt': droppedAt!.toUtc().toIso8601String(),
    if (attachmentNames.isNotEmpty) 'attachmentNames': attachmentNames,
  };

  static PinEntry? fromJson(dynamic e) {
    if (e is List && e.length >= 2) {
      return PinEntry(
        nx: (e[0] as num).toDouble(),
        ny: (e[1] as num).toDouble(),
        page: null,
      );
    }
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      PdfAnnotationPoint? pdfPoint;
      if (m.containsKey('pdfX') || m.containsKey('pdfWidth')) {
        pdfPoint = PdfAnnotationPoint.fromJson(m);
      }
      final nx =
          (m['nx'] as num?)?.toDouble() ?? pdfPoint?.fractionX;
      final ny =
          (m['ny'] as num?)?.toDouble() ?? pdfPoint?.fractionY;
      if (nx == null || ny == null) return null;
      final pg = m['page'] ?? pdfPoint?.page;
      DateTime? dropped;
      final rawD = m['droppedAt'];
      if (rawD is String) {
        dropped = DateTime.tryParse(rawD);
      }
      return PinEntry(
        nx: nx,
        ny: ny,
        page: pg is int ? pg : (pg is num ? pg.toInt() : null),
        pdfPoint: pdfPoint,
        productName: m['productName'] as String?,
        groupName: m['groupName'] as String?,
        blockName: m['blockName'] as String?,
        levelName: m['levelName'] as String?,
        zoneLabel: m['zoneLabel'] as String?,
        description: (m['description'] as String?)?.trim() ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        status: (m['status'] as String?)?.trim().isNotEmpty == true
            ? m['status'] as String
            : 'To Do',
        variation: (m['variation'] as String?)?.trim().isNotEmpty == true
            ? m['variation'] as String
            : 'No',
        droppedAt: dropped,
        attachmentNames: _readAttachmentNames(m),
      );
    }
    return null;
  }

  static List<String> _readAttachmentNames(Map<String, dynamic> m) {
    final raw = m['attachmentNames'] ?? m['attachments'];
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        final name = entry['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) out.add(name);
      } else {
        final text = entry.toString().trim();
        if (text.isNotEmpty) out.add(text);
      }
    }
    return out;
  }

  PdfPageCoordinate get pageCoordinate =>
      PdfPageCoordinate(page: page ?? 1, xPercent: nx, yPercent: ny);

  PdfAnnotationPoint? toAnnotationPoint(PdfPageMetadataCache metadata) {
    if (page == null) return null;
    final meta = metadata.page(page!);
    if (meta == null) return null;
    return PdfAnnotationPoint.fromMetadata(
      metadata: meta,
      pdfX: nx * meta.width,
      pdfY: ny * meta.height,
    );
  }

  /// Viewport pixel position for this pin (overlay top-left origin).
  Offset? toViewportOffset(
    PdfControllerPinch? pdf,
    Size viewport,
    bool isPdf, {
    PdfCoordinateEngine? engine,
  }) {
    if (!isPdf || page == null || pdf == null) {
      return Offset(nx * viewport.width, ny * viewport.height);
    }
    if (engine != null) {
      final ann =
          pdfPoint ??
          toAnnotationPoint(engine.metadata) ??
          PdfAnnotationPoint(
            page: page!,
            pdfX: nx,
            pdfY: ny,
            pageWidth: 1,
            pageHeight: 1,
          );
      return engine.pdfToScreen(ann);
    }
    if (pdfPoint != null) {
      return PdfCoordinateTransformer.toViewportLocal(
        pdf,
        PdfPageCoordinate(
          page: pdfPoint!.page,
          xPercent: pdfPoint!.fractionX,
          yPercent: pdfPoint!.fractionY,
        ),
      );
    }
    return PdfCoordinateTransformer.toViewportLocal(pdf, pageCoordinate);
  }
}

/// Rectangle highlight: [page] null = layer-normalized (image); non-null = page-local norm.
class BoxEntry {
  const BoxEntry({
    required this.n,
    this.page,
    this.plotName = '',
    this.colorValue,
  });

  final Rect n;
  final int? page;

  /// User label from "New Plot Name" (optional).
  final String plotName;

  /// Optional ARGB color value used to render this highlight.
  final int? colorValue;

  Map<String, dynamic> toJson() => {
    'r': [n.left, n.top, n.right, n.bottom],
    if (page != null) 'page': page,
    if (plotName.isNotEmpty) 'plotName': plotName,
    if (colorValue != null) 'color': colorValue,
  };

  static BoxEntry? fromJson(dynamic e) {
    if (e is List && e.length >= 4) {
      final a = e.map((v) => (v as num).toDouble()).toList();
      return BoxEntry(
        n: Rect.fromLTRB(a[0], a[1], a[2], a[3]),
        page: null,
        colorValue: null,
      );
    }
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      final r = m['r'];
      if (r is! List || r.length < 4) return null;
      final a = r.map((v) => (v as num).toDouble()).toList();
      final pg = m['page'];
      final pn = m['plotName'];
      final c = m['color'];
      return BoxEntry(
        n: Rect.fromLTRB(a[0], a[1], a[2], a[3]),
        page: pg is int ? pg : (pg is num ? pg.toInt() : null),
        plotName: pn is String ? pn : '',
        colorValue: c is int ? c : (c is num ? c.toInt() : null),
      );
    }
    return null;
  }
}

/// Polygon: points normalized like [BoxEntry].
class PolyEntry {
  const PolyEntry({
    required this.points,
    this.page,
    this.plotName = '',
    this.colorValue,
  });

  final List<Offset> points;
  final int? page;

  /// User label from "New Plot Name" (optional).
  final String plotName;

  /// Optional ARGB color value used to render this highlight.
  final int? colorValue;

  Map<String, dynamic> toJson() => {
    'p': points.map((o) => [o.dx, o.dy]).toList(),
    if (page != null) 'page': page,
    if (plotName.isNotEmpty) 'plotName': plotName,
    if (colorValue != null) 'color': colorValue,
  };

  static PolyEntry? fromJson(dynamic e) {
    if (e is List) {
      final pts = <Offset>[];
      for (final pt in e) {
        if (pt is! List || pt.length < 2) continue;
        pts.add(Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
      }
      if (pts.isEmpty) return null;
      return PolyEntry(points: pts, page: null, colorValue: null);
    }
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      final raw = m['p'];
      if (raw is! List) return null;
      final pts = <Offset>[];
      for (final pt in raw) {
        if (pt is! List || pt.length < 2) continue;
        pts.add(Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
      }
      if (pts.isEmpty) return null;
      final pg = m['page'];
      final pn = m['plotName'];
      final c = m['color'];
      return PolyEntry(
        points: pts,
        page: pg is int ? pg : (pg is num ? pg.toInt() : null),
        plotName: pn is String ? pn : '',
        colorValue: c is int ? c : (c is num ? c.toInt() : null),
      );
    }
    return null;
  }
}

/// Converts a layer-normalized draft rect (PDF overlay) to a [BoxEntry] anchored to a page.
BoxEntry? pdfCommitLayerNormBox(
  PdfControllerPinch c,
  Rect layerNorm,
  Size viewport,
) {
  final tl = viewportLocalToDoc(
    c,
    Offset(layerNorm.left * viewport.width, layerNorm.top * viewport.height),
  );
  final br = viewportLocalToDoc(
    c,
    Offset(
      layerNorm.right * viewport.width,
      layerNorm.bottom * viewport.height,
    ),
  );
  final docRect = Rect.fromPoints(tl, br);
  final center = docRect.center;
  final page = findPageContainingDoc(c, center) ?? findNearestPage(c, center);
  if (page == null) return null;
  final pr = safeGetPageRect(c, page);
  if (pr == null) return null;
  final inter = docRect.intersect(pr);
  if (inter.width < 1 || inter.height < 1) return null;
  final n = Rect.fromLTRB(
    ((inter.left - pr.left) / pr.width).clamp(0.0, 1.0),
    ((inter.top - pr.top) / pr.height).clamp(0.0, 1.0),
    ((inter.right - pr.left) / pr.width).clamp(0.0, 1.0),
    ((inter.bottom - pr.top) / pr.height).clamp(0.0, 1.0),
  );
  return BoxEntry(n: n, page: page, plotName: '', colorValue: null);
}

/// Creates a pin from a tap in viewport-local coordinates (PDF).
PinEntry? pdfPinFromViewportLocal(
  PdfControllerPinch c,
  Offset local, {
  PdfCoordinateEngine? engine,
}) {
  if (engine != null) {
    final point = engine.screenToPdf(local);
    if (point == null) return null;
    return PinEntry.fromAnnotation(point);
  }
  final coord = PdfCoordinateTransformer.fromViewportLocal(c, local);
  if (coord == null) return null;
  return PinEntry(
    nx: coord.xPercent,
    ny: coord.yPercent,
    page: coord.page,
    droppedAt: null,
  );
}

/// Converts polygon draft points (layer norm) to page-local normalized polygon.
PolyEntry? pdfCommitLayerNormPoly(
  PdfControllerPinch c,
  List<Offset> layerNormPts,
  Size viewport,
) {
  if (layerNormPts.length < 3) return null;
  final docPts = layerNormPts
      .map(
        (o) => viewportLocalToDoc(
          c,
          Offset(o.dx * viewport.width, o.dy * viewport.height),
        ),
      )
      .toList();
  var cx = 0.0, cy = 0.0;
  for (final d in docPts) {
    cx += d.dx;
    cy += d.dy;
  }
  cx /= docPts.length;
  cy /= docPts.length;
  final center = Offset(cx, cy);
  final page = findPageContainingDoc(c, center) ?? findNearestPage(c, center);
  if (page == null) return null;
  final pr = safeGetPageRect(c, page);
  if (pr == null) return null;
  final out = <Offset>[];
  for (final d in docPts) {
    if (!pr.contains(d)) continue;
    out.add(
      Offset(
        ((d.dx - pr.left) / pr.width).clamp(0.0, 1.0),
        ((d.dy - pr.top) / pr.height).clamp(0.0, 1.0),
      ),
    );
  }
  if (out.length < 3) return null;
  return PolyEntry(points: out, page: page, plotName: '', colorValue: null);
}

/// Viewport rectangle for drawing a stored box (image or PDF).
Rect? boxEntryToViewportRect(
  BoxEntry e,
  PdfControllerPinch? pdf,
  Size viewport,
  bool isPdf,
) {
  if (!isPdf || e.page == null || pdf == null) {
    final n = e.n;
    return Rect.fromLTRB(
      n.left * viewport.width,
      n.top * viewport.height,
      n.right * viewport.width,
      n.bottom * viewport.height,
    );
  }
  final pr = safeGetPageRect(pdf, e.page!);
  if (pr == null) return null;
  final doc = Rect.fromLTRB(
    pr.left + e.n.left * pr.width,
    pr.top + e.n.top * pr.height,
    pr.left + e.n.right * pr.width,
    pr.top + e.n.bottom * pr.height,
  );
  final tl = docToViewportLocal(pdf, doc.topLeft);
  final br = docToViewportLocal(pdf, doc.bottomRight);
  return Rect.fromPoints(tl, br);
}

/// Builds a closed path in viewport coordinates for a polygon entry.
Path? polyEntryToViewportPath(
  PolyEntry e,
  PdfControllerPinch? pdf,
  Size viewport,
  bool isPdf,
) {
  if (e.points.isEmpty) return null;
  if (!isPdf || e.page == null || pdf == null) {
    final path = Path();
    final p0 = Offset(
      e.points[0].dx * viewport.width,
      e.points[0].dy * viewport.height,
    );
    path.moveTo(p0.dx, p0.dy);
    for (var i = 1; i < e.points.length; i++) {
      path.lineTo(
        e.points[i].dx * viewport.width,
        e.points[i].dy * viewport.height,
      );
    }
    return path;
  }
  final pr = safeGetPageRect(pdf, e.page!);
  if (pr == null) return null;
  final path = Path();
  for (var i = 0; i < e.points.length; i++) {
    final o = e.points[i];
    final doc = Offset(pr.left + o.dx * pr.width, pr.top + o.dy * pr.height);
    final v = docToViewportLocal(pdf, doc);
    if (i == 0) {
      path.moveTo(v.dx, v.dy);
    } else {
      path.lineTo(v.dx, v.dy);
    }
  }
  return path;
}

/// Polygon vertices in overlay (viewport) pixels — same geometry as [polyEntryToViewportPath].
List<Offset>? polyEntryToViewportPoints(
  PolyEntry e,
  PdfControllerPinch? pdf,
  Size viewport,
  bool isPdf,
) {
  if (e.points.length < 3) return null;
  if (!isPdf || e.page == null || pdf == null) {
    return e.points
        .map((o) => Offset(o.dx * viewport.width, o.dy * viewport.height))
        .toList();
  }
  final pr = safeGetPageRect(pdf, e.page!);
  if (pr == null) return null;
  return e.points.map((o) {
    final doc = Offset(pr.left + o.dx * pr.width, pr.top + o.dy * pr.height);
    return docToViewportLocal(pdf, doc);
  }).toList();
}

/// Ray-casting test (avoids [Path.contains] quirks across backends).
bool viewportPointInPolygon(Offset p, List<Offset> vertices) {
  if (vertices.length < 3) return false;
  var inside = false;
  for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    final pi = vertices[i];
    final pj = vertices[j];
    final dy = pj.dy - pi.dy;
    if (dy == 0) continue;
    if ((pi.dy > p.dy) != (pj.dy > p.dy)) {
      final xInt = pi.dx + (p.dy - pi.dy) * (pj.dx - pi.dx) / dy;
      if (p.dx < xInt) inside = !inside;
    }
  }
  return inside;
}

/// Whether [viewportLocal] lies inside any committed box or polygon highlight.
bool viewportPointInsideMarkupHighlights(
  Offset viewportLocal,
  Size viewport,
  QuoteDocMarkup markup,
  PdfControllerPinch? pdf,
  bool isPdf,
) {
  if (!viewport.width.isFinite ||
      !viewport.height.isFinite ||
      viewport.width <= 0 ||
      viewport.height <= 0) {
    return false;
  }
  for (final b in markup.boxHighlights) {
    final r = boxEntryToViewportRect(b, pdf, viewport, isPdf);
    if (r == null || !r.width.isFinite || !r.height.isFinite) continue;
    final hit = r.width >= 4 && r.height >= 4
        ? r.inflate(1).contains(viewportLocal)
        : r.contains(viewportLocal);
    if (hit) return true;
  }
  for (final e in markup.polygons) {
    final pts = polyEntryToViewportPoints(e, pdf, viewport, isPdf);
    if (pts == null || pts.length < 3) continue;
    if (viewportPointInPolygon(viewportLocal, pts)) return true;
  }
  return false;
}

/// Plot / zone label from the highlight that contains [viewportLocal], if any.
String? plotNameForViewportPoint(
  Offset viewportLocal,
  Size viewport,
  QuoteDocMarkup markup,
  PdfControllerPinch? pdf,
  bool isPdf,
) {
  for (final b in markup.boxHighlights) {
    final r = boxEntryToViewportRect(b, pdf, viewport, isPdf);
    if (r == null || !r.width.isFinite || !r.height.isFinite) continue;
    final hit = r.width >= 4 && r.height >= 4
        ? r.inflate(1).contains(viewportLocal)
        : r.contains(viewportLocal);
    if (hit && b.plotName.trim().isNotEmpty) {
      return b.plotName.trim();
    }
  }
  for (final e in markup.polygons) {
    final pts = polyEntryToViewportPoints(e, pdf, viewport, isPdf);
    if (pts == null || pts.length < 3) continue;
    if (viewportPointInPolygon(viewportLocal, pts) &&
        e.plotName.trim().isNotEmpty) {
      return e.plotName.trim();
    }
  }
  return null;
}

/// Identifies which highlight the user tapped (top-most when overlapping).
class PlotHighlightHit {
  const PlotHighlightHit.box(this.index) : isBox = true;
  const PlotHighlightHit.poly(this.index) : isBox = false;

  final bool isBox;
  final int index;
}

/// Returns the top-most box or polygon under [viewportLocal], or null.
PlotHighlightHit? findTopPlotHighlightAt(
  Offset viewportLocal,
  Size viewport,
  QuoteDocMarkup markup,
  PdfControllerPinch? pdf,
  bool isPdf,
) {
  if (!viewport.width.isFinite ||
      !viewport.height.isFinite ||
      viewport.width <= 0 ||
      viewport.height <= 0) {
    return null;
  }
  for (var i = markup.polygons.length - 1; i >= 0; i--) {
    final pts = polyEntryToViewportPoints(
      markup.polygons[i],
      pdf,
      viewport,
      isPdf,
    );
    if (pts != null &&
        pts.length >= 3 &&
        viewportPointInPolygon(viewportLocal, pts)) {
      return PlotHighlightHit.poly(i);
    }
  }
  for (var i = markup.boxHighlights.length - 1; i >= 0; i--) {
    final r = boxEntryToViewportRect(
      markup.boxHighlights[i],
      pdf,
      viewport,
      isPdf,
    );
    if (r == null || !r.width.isFinite || !r.height.isFinite) continue;
    final hit = r.width >= 4 && r.height >= 4
        ? r.inflate(1).contains(viewportLocal)
        : r.contains(viewportLocal);
    if (hit) return PlotHighlightHit.box(i);
  }
  return null;
}

/// Persisted markup for one document (paths / PDF pages).
class QuoteDocMarkup {
  QuoteDocMarkup();

  final List<BoxEntry> boxHighlights = [];
  final List<PolyEntry> polygons = [];
  final List<PinEntry> pins = [];

  bool get isEmpty => boxHighlights.isEmpty && polygons.isEmpty && pins.isEmpty;

  Map<String, dynamic> toJson() => {
    'v': 2,
    'boxes': boxHighlights.map((e) => e.toJson()).toList(),
    'polygons': polygons.map((e) => e.toJson()).toList(),
    'pins': pins.map((e) => e.toJson()).toList(),
  };

  static QuoteDocMarkup fromJson(Map<String, dynamic>? json) {
    final m = QuoteDocMarkup();
    if (json == null) return m;

    final ver = json['v'];
    if (ver == 2) {
      final boxes = json['boxes'] as List?;
      if (boxes != null) {
        for (final e in boxes) {
          final b = BoxEntry.fromJson(e);
          if (b != null) m.boxHighlights.add(b);
        }
      }
      final polys = json['polygons'] as List?;
      if (polys != null) {
        for (final e in polys) {
          final p = PolyEntry.fromJson(e);
          if (p != null) m.polygons.add(p);
        }
      }
      final pinList = json['pins'] as List?;
      if (pinList != null) {
        for (final e in pinList) {
          final p = PinEntry.fromJson(e);
          if (p != null) m.pins.add(p);
        }
      }
      return m;
    }

    final boxes = json['boxes'] as List?;
    if (boxes != null) {
      for (final e in boxes) {
        final b = BoxEntry.fromJson(e);
        if (b != null) m.boxHighlights.add(b);
      }
    }

    final polys = json['polygons'] as List?;
    if (polys != null) {
      for (final poly in polys) {
        final p = PolyEntry.fromJson(poly);
        if (p != null) m.polygons.add(p);
      }
    }

    final pinList = json['pins'] as List?;
    if (pinList != null) {
      for (final e in pinList) {
        final p = PinEntry.fromJson(e);
        if (p != null) m.pins.add(p);
      }
    }

    return m;
  }

  QuoteDocMarkup copy() {
    final c = QuoteDocMarkup();
    c.boxHighlights.addAll(boxHighlights);
    c.polygons.addAll(polygons);
    c.pins.addAll(pins);
    return c;
  }
}
