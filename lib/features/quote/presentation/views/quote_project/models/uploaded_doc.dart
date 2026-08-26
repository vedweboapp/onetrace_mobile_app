part of '../quote_project.dart';

class _UploadedDoc {
  const _UploadedDoc({
    required this.path,
    required this.displayName,
    required this.isPdf,
    this.levelName = '',
    this.levelId,
    this.remoteUri,
  });

  final String path;
  final String displayName;
  final bool isPdf;
  final String? remoteUri;

  /// User-defined label from the Initialize Level dialog (per file).
  final String levelName;
  final String? levelId;

  String get identityKey => remoteUri != null && remoteUri!.trim().isNotEmpty
      ? 'uri:${remoteUri!.trim()}'
      : 'file:$path';

  Map<String, dynamic> toJson() => {
    'path': path,
    'displayName': displayName,
    'isPdf': isPdf,
    'levelName': levelName,
    if (levelId != null && levelId!.trim().isNotEmpty) 'levelId': levelId,
    if (remoteUri != null && remoteUri!.trim().isNotEmpty)
      'remoteUri': remoteUri,
  };

  static _UploadedDoc? fromMap(Map<String, dynamic> m) {
    final path = m['path'] as String?;
    if (path == null) return null;
    return _UploadedDoc(
      path: path,
      displayName:
          m['displayName'] as String? ??
          path.split(Platform.pathSeparator).last,
      isPdf: m['isPdf'] as bool? ?? path.toLowerCase().endsWith('.pdf'),
      levelName: (m['levelName'] as String?)?.trim() ?? '',
      levelId: (m['levelId'] as String?)?.trim(),
      remoteUri: (m['remoteUri'] as String?)?.trim(),
    );
  }
}
