part of '../drawing_canvas.dart';

enum _CanvasTool { share, pin, selectArea, line, location }

class _PlotRegion {
  _PlotRegion({
    required this.rect,
    required this.name,
    required this.pins,
    this.lines,
    this.serverPlotId,
    this.pdfAnchorA,
    this.pdfAnchorB,
    this.pdfVertices,
    this.locked = false,
    Set<int>? pendingDeletedPinIds,
    this.apiCoordinatesRaw,
  }) : pendingDeletedPinIds = pendingDeletedPinIds ?? const <int>{};

  final Rect rect;
  final String? name;
  final List<_CanvasPin> pins;
  final List<_CanvasLine>? lines;
  final int? serverPlotId;

  /// Server pin ids removed locally; sent on next plot PUT as `deleted_pin_ids`.
  final Set<int> pendingDeletedPinIds;

  /// Raw `coordinates` from GET — used to re-layout after viewport is ready.
  final dynamic apiCoordinatesRaw;

  /// Box plots from the select-area tool cannot be dragged.
  final bool locked;

  /// PDF-space corners for box plots (survives zoom on PDF).
  PdfAnnotationPoint? pdfAnchorA;
  PdfAnnotationPoint? pdfAnchorB;
  List<PdfAnnotationPoint>? pdfVertices;

  List<_CanvasLine> get safeLines => lines ?? const <_CanvasLine>[];

  _PlotRegion copyWith({
    Rect? rect,
    String? name,
    List<_CanvasPin>? pins,
    List<_CanvasLine>? lines,
    int? serverPlotId,
    PdfAnnotationPoint? pdfAnchorA,
    PdfAnnotationPoint? pdfAnchorB,
    List<PdfAnnotationPoint>? pdfVertices,
    bool? locked,
    Set<int>? pendingDeletedPinIds,
    dynamic apiCoordinatesRaw,
  }) {
    return _PlotRegion(
      rect: rect ?? this.rect,
      name: name ?? this.name,
      pins: pins ?? this.pins,
      lines: lines ?? this.lines ?? const <_CanvasLine>[],
      serverPlotId: serverPlotId ?? this.serverPlotId,
      pdfAnchorA: pdfAnchorA ?? this.pdfAnchorA,
      pdfAnchorB: pdfAnchorB ?? this.pdfAnchorB,
      pdfVertices: pdfVertices ?? this.pdfVertices,
      locked: locked ?? this.locked,
      pendingDeletedPinIds: pendingDeletedPinIds ?? this.pendingDeletedPinIds,
      apiCoordinatesRaw: apiCoordinatesRaw ?? this.apiCoordinatesRaw,
    );
  }
}

class _CanvasLine {
  const _CanvasLine({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

class _PinAttachment {
  const _PinAttachment({
    required this.name,
    this.localPath,
    this.url,
    this.serverId,
  });

  final String name;
  final String? localPath;
  final String? url;
  final int? serverId;
}

class _CanvasPin {
  const _CanvasPin({
    required this.offset,
    this.pdfPoint,
    required this.productName,
    this.abbreviation = '',
    required this.status,
    this.statusId,
    this.statusBgColor,
    this.statusFgColor,
    this.groupId,
    this.groupName = '',
    this.compositeItemId,
    required this.quantity,
    required this.blockName,
    required this.levelName,
    required this.zoneName,
    required this.variation,
    required this.droppedAt,
    required this.description,
    this.formName = '',
    this.formId,
    this.installationTypeId,
    this.attachments = const <_PinAttachment>[],
    this.serverPinId,
    this.contentNormX,
    this.contentNormY,
  });

  final Offset offset;

  /// Portrait-normalized position (0–1) inside the letterboxed image — for reload.
  final double? contentNormX;
  final double? contentNormY;

  /// True PDF user-space position; source of truth on PDF (not screen pixels).
  final PdfAnnotationPoint? pdfPoint;

  final String productName;
  final String abbreviation;
  final String status;
  final int? statusId;
  final Color? statusBgColor;
  final Color? statusFgColor;
  final int? groupId;
  final String groupName;
  final int? compositeItemId;
  final int quantity;
  final String blockName;
  final String levelName;
  final String zoneName;
  final String variation;
  final DateTime droppedAt;
  final String description;
  final String formName;
  final int? formId;
  final int? installationTypeId;
  final List<_PinAttachment> attachments;
  final int? serverPinId;

  List<String> get attachmentNames =>
      attachments.map((attachment) => attachment.name).toList(growable: false);

  _CanvasPin copyWith({
    Offset? offset,
    PdfAnnotationPoint? pdfPoint,
    String? productName,
    String? abbreviation,
    String? status,
    int? statusId,
    Color? statusBgColor,
    Color? statusFgColor,
    int? groupId,
    String? groupName,
    int? compositeItemId,
    int? quantity,
    String? blockName,
    String? levelName,
    String? zoneName,
    String? variation,
    DateTime? droppedAt,
    String? description,
    String? formName,
    int? formId,
    int? installationTypeId,
    List<_PinAttachment>? attachments,
    int? serverPinId,
    double? contentNormX,
    double? contentNormY,
  }) {
    return _CanvasPin(
      offset: offset ?? this.offset,
      contentNormX: contentNormX ?? this.contentNormX,
      contentNormY: contentNormY ?? this.contentNormY,
      pdfPoint: pdfPoint ?? this.pdfPoint,
      productName: productName ?? this.productName,
      abbreviation: abbreviation ?? this.abbreviation,
      status: status ?? this.status,
      statusId: statusId ?? this.statusId,
      statusBgColor: statusBgColor ?? this.statusBgColor,
      statusFgColor: statusFgColor ?? this.statusFgColor,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      compositeItemId: compositeItemId ?? this.compositeItemId,
      quantity: quantity ?? this.quantity,
      blockName: blockName ?? this.blockName,
      levelName: levelName ?? this.levelName,
      zoneName: zoneName ?? this.zoneName,
      variation: variation ?? this.variation,
      droppedAt: droppedAt ?? this.droppedAt,
      description: description ?? this.description,
      formName: formName ?? this.formName,
      formId: formId ?? this.formId,
      installationTypeId: installationTypeId ?? this.installationTypeId,
      attachments: attachments ?? this.attachments,
      serverPinId: serverPinId ?? this.serverPinId,
    );
  }
}

class _PinHit {
  const _PinHit({required this.regionIndex, required this.pinIndex});

  final int regionIndex;
  final int pinIndex;
}

class _PinSheetResult {
  const _PinSheetResult({this.updatedPin, this.removePin = false});

  final _CanvasPin? updatedPin;
  final bool removePin;
}
