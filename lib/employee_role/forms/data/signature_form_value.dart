import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:red5/core/network/api_urls.dart';

const double kSignatureExportWidth = 400;
const double kSignatureExportHeight = 160;

/// PNG bytes rendered from signature stroke data.
Future<Uint8List?> renderSignaturePngBytes(
  List<List<Offset>> strokes, {
  double width = kSignatureExportWidth,
  double height = kSignatureExportHeight,
}) async {
  if (strokes.every((stroke) => stroke.length < 2)) return null;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  final baselineY = height - 28;
  canvas.drawLine(
    Offset(16, baselineY),
    Offset(width - 16, baselineY),
    Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1,
  );

  final strokePaint = Paint()
    ..color = const Color(0xFF111827)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final dotPaint = Paint()
    ..color = const Color(0xFF111827)
    ..style = PaintingStyle.fill;

  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, 1.2, dotPaint);
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, strokePaint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// Base64 PNG (legacy / preview only — API stores short filenames, not inline PNG).
Future<String?> encodeSignaturePngForApi(List<List<Offset>> strokes) async {
  final bytes = await renderSignaturePngBytes(strokes);
  if (bytes == null || bytes.isEmpty) return null;
  return base64Encode(bytes);
}

/// Short filename sent in `values[]` for signature fields (`varchar(100)` limit).
String signatureFilenameForField(int fieldId) => 'sig_f$fieldId.png';

@immutable
class SignaturePngFileExport {
  const SignaturePngFileExport({
    required this.filename,
    required this.path,
    required this.bytes,
  });

  final String filename;
  final String path;
  final Uint8List bytes;
}

/// Writes a PNG to app storage and returns the filename for submit-form.
Future<SignaturePngFileExport?> exportSignaturePngFile({
  required int fieldId,
  required List<List<Offset>> strokes,
}) async {
  final bytes = await renderSignaturePngBytes(strokes);
  if (bytes == null || bytes.isEmpty) return null;

  final filename = signatureFilenameForField(fieldId);
  final base = await getApplicationSupportDirectory();
  final dir = Directory(
    p.join(base.path, 'job_form_attachments', 'signatures'),
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final path = p.join(dir.path, filename);
  await File(path).writeAsBytes(bytes, flush: true);
  return SignaturePngFileExport(
    filename: filename,
    path: path,
    bytes: bytes,
  );
}

/// Decodes a stored signature value (base64 PNG or `data:image/png;base64,...`).
Uint8List? decodeSignaturePngValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  var payload = trimmed;
  const dataPrefix = 'data:image/png;base64,';
  if (payload.toLowerCase().startsWith(dataPrefix)) {
    payload = payload.substring(dataPrefix.length);
  }

  payload = payload.replaceAll(RegExp(r'\s+'), '');

  try {
    final bytes = base64Decode(payload);
    return isPngBytes(bytes) ? bytes : null;
  } catch (_) {
    return null;
  }
}

/// Image bytes or remote URL for showing a saved signature.
@immutable
class SignatureDisplaySource {
  const SignatureDisplaySource({this.bytes, this.imageUrl});

  final Uint8List? bytes;
  final String? imageUrl;

  static const empty = SignatureDisplaySource();

  bool get hasImage =>
      (bytes != null && bytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.trim().isNotEmpty);
}

/// Parses API / draft values: PNG base64, data URI, http URL, or JSON wrappers.
SignatureDisplaySource parseSignatureDisplayValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return SignatureDisplaySource.empty;

  final inlinePng = decodeSignaturePngValue(trimmed);
  if (inlinePng != null) {
    return SignatureDisplaySource(bytes: inlinePng);
  }

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return SignatureDisplaySource(imageUrl: trimmed);
  }

  if (trimmed.startsWith('/')) {
    final resolved = Uri.parse(AppApiUrls.baseUrl).resolve(trimmed).toString();
    return SignatureDisplaySource(imageUrl: resolved);
  }

  if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    final resolved = Uri.parse(AppApiUrls.baseUrl).resolve(trimmed).toString();
    return SignatureDisplaySource(imageUrl: resolved);
  }

  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return SignatureDisplaySource.empty;
      final map = Map<String, dynamic>.from(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );

      for (final key in const [
        'url',
        'file_url',
        'image_url',
        'signature_url',
        'file',
      ]) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        final nested = parseSignatureDisplayValue(value);
        if (nested.hasImage) return nested;
      }

      for (final key in const [
        'data',
        'image',
        'signature',
        'value',
        'content',
        'base64',
      ]) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        final nested = parseSignatureDisplayValue(value);
        if (nested.hasImage) return nested;
      }
    } catch (_) {}
  }

  return SignatureDisplaySource.empty;
}

bool isPngBytes(List<int> bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

/// Whether [raw] is a PNG signature payload sent to / restored from the API.
bool isSignaturePngBase64Payload(String raw) {
  return decodeSignaturePngValue(raw) != null;
}

/// Legacy stroke JSON — still accepted when loading saved forms.
bool isSignatureStrokePayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('{')) return false;
  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map && decoded['strokes'] is List;
  } catch (_) {
    return false;
  }
}

bool isSignatureApiPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  // Inline PNG base64 exceeds DB varchar(100); must be uploaded as a file.
  if (isSignaturePngBase64Payload(trimmed)) return false;
  if (isSignatureStrokePayload(trimmed)) return true;
  final lower = trimmed.toLowerCase();
  return trimmed.length <= 100 &&
      (lower.startsWith('sig_') || lower.endsWith('.png'));
}

/// Restores saved signature stroke data from legacy API / draft payloads.
List<List<Offset>> strokesFromSignatureValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return const [];
    final strokes = decoded['strokes'];
    if (strokes is! List) return const [];
    return strokes.map((stroke) {
      if (stroke is! List) return <Offset>[];
      return stroke.map((point) {
        if (point is! Map) return Offset.zero;
        final x = (point['x'] as num?)?.toDouble() ?? 0;
        final y = (point['y'] as num?)?.toDouble() ?? 0;
        return Offset(x, y);
      }).toList(growable: false);
    }).toList(growable: false);
  } catch (_) {
    return const [];
  }
}
