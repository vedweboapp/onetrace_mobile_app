part of 'drawing_canvas.dart';

/// Route payload for [DrawingCanvasPage]. Use [toExtra] with GoRouter and
/// [DrawingCanvasPage.push] so every entry point matches [AppRouter] parsing.
@immutable
class DrawingCanvasArgs {
  const DrawingCanvasArgs({
    required this.title,
    this.filePath,
    this.remoteDrawingUrl,
    this.levelName,
    this.projectName,
    this.projectId,
    this.levelId,
    this.embeddedLevelPlots = const [],
    this.viewOnly = false,
    this.operativeWorkflow = false,
    this.operativeJobId,
    this.focusPinId,
  });

  final String title;
  final String? filePath;

  /// Absolute URL or API path; passed to the route as `drawingUrl`.
  final String? remoteDrawingUrl;
  final String? levelName;
  final String? projectName;
  final String? projectId;
  final String? levelId;

  /// Preloaded plot/pin markup (e.g. operative job drawings) — skips level API fetch.
  final List<Map<String, dynamic>> embeddedLevelPlots;

  /// Read-only preview — hides editing tools and submit controls.
  final bool viewOnly;

  /// Operative pin-first job flow — tappable pins, no editing chrome.
  final bool operativeWorkflow;
  final int? operativeJobId;

  /// When set (operative designs), canvas zooms to this server pin after load.
  final int? focusPinId;

  Map<String, dynamic> toExtra() {
    final t = title.trim();
    final fp = (filePath ?? '').trim();
    final url = (remoteDrawingUrl ?? '').trim();
    final ln = (levelName ?? '').trim();
    final pn = (projectName ?? '').trim();
    final pid = (projectId ?? '').trim();
    final lid = (levelId ?? '').trim();
    final plots = embeddedLevelPlots
        .map((plot) => Map<String, dynamic>.from(plot))
        .toList(growable: false);
    return <String, dynamic>{
      if (t.isNotEmpty) 'title': t,
      if (fp.isNotEmpty) 'filePath': fp,
      if (url.isNotEmpty) 'drawingUrl': url,
      if (ln.isNotEmpty) 'levelName': ln,
      if (pn.isNotEmpty) 'projectName': pn,
      if (pid.isNotEmpty) 'projectId': pid,
      if (lid.isNotEmpty) 'levelId': lid,
      if (plots.isNotEmpty) 'embeddedLevelPlots': plots,
      if (viewOnly) 'viewOnly': true,
      if (operativeWorkflow) 'operativeWorkflow': true,
      if (operativeJobId != null) 'operativeJobId': operativeJobId,
      if (focusPinId != null) 'focusPinId': focusPinId,
    };
  }

  /// Same field mapping used after [UploadDrawingPage] returns a result map.
  factory DrawingCanvasArgs.fromUploadResult(
    Map<String, dynamic> map, {
    required String projectName,
    required String projectId,
  }) {
    final fileName = (map['fileName'] ?? '').toString().trim();
    final pdfName = (map['pdfName'] ?? '').toString().trim();
    final filePath = (map['filePath'] ?? '').toString().trim();
    final levelName = (map['levelName'] ?? '').toString().trim();
    final uploadedProjectId = (map['projectId'] ?? '').toString().trim();
    final levelId = (map['levelId'] ?? '').toString().trim();
    final title = (pdfName.isNotEmpty ? pdfName : fileName).trim();
    final resolvedPid = uploadedProjectId.isEmpty
        ? projectId.trim()
        : uploadedProjectId;
    return DrawingCanvasArgs(
      title: title,
      filePath: filePath.isEmpty ? null : filePath,
      levelName: levelName.isEmpty ? null : levelName,
      projectName: projectName.trim().isEmpty ? null : projectName.trim(),
      projectId: resolvedPid.isEmpty ? null : resolvedPid,
      levelId: levelId.isEmpty ? null : levelId,
    );
  }

  static int uploadCountFromResult(Map<String, dynamic> map) {
    final uploadCount = map['uploadCount'] is int
        ? (map['uploadCount'] as int).clamp(1, 999)
        : (((map['filePath'] ?? '').toString().trim().isNotEmpty) ? 1 : 0);
    return uploadCount;
  }
}
