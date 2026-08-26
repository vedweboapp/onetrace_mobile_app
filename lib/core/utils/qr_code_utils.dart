import 'dart:convert';

/// Helpers for values read from QR stickers and scanners.
abstract final class QrCodeUtils {
  QrCodeUtils._();

  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// Bare QR id or public UUID from
  /// `http://host/scan/18552ae0-af7e-4385-b243-80609f04bf19`.
  ///
  /// Used for:
  /// - `POST /api/v1/jobs/{job_id}/scan-qr/` →
  ///   `{ "public_uuid": "...", "job_pin_id": 157 }`
  /// - `GET /api/v1/qr-codes/{qr_code}/details/`
  static String normalizeScannedValue(String raw) {
    final uuid = extractPublicUuid(raw);
    if (uuid != null) return uuid;

    var value = raw.trim();
    if (value.isEmpty) return value;

    if (value.contains('%')) {
      try {
        final decoded = Uri.decodeComponent(value);
        if (decoded.trim().isNotEmpty) value = decoded.trim();
      } catch (_) {}
    }

    value = value.replaceAll(RegExp(r'\s+'), '');

    // Sticker URLs: .../scan/QR-VLBUJL (with or without http://)
    final scanMatch = RegExp(
      r'(?:^|[/:])scan/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (scanMatch != null) {
      return canonicalize(Uri.decodeComponent(scanMatch.group(1)!.trim()));
    }

    final uri = _parseAsUri(value);
    if (uri != null) {
      final fromQuery = uri.queryParameters['public_uuid'] ??
          uri.queryParameters['uuid'];
      final queryUuid = fromQuery == null ? null : extractPublicUuid(fromQuery);
      if (queryUuid != null) return queryUuid;

      final fromPath = _codeFromPathSegments(uri.pathSegments);
      if (fromPath != null) return canonicalize(fromPath);

      for (final segment in uri.pathSegments.reversed) {
        final trimmed = segment.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'details') continue;
        final segmentUuid = extractPublicUuid(trimmed);
        if (segmentUuid != null) return segmentUuid;
        if (trimmed.toLowerCase().startsWith('qr-')) {
          return canonicalize(trimmed);
        }
      }
    }

    final qrCodesMatch = RegExp(
      r'(?:^|/)qr-codes/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (qrCodesMatch != null) {
      final candidate = Uri.decodeComponent(qrCodesMatch.group(1)!.trim());
      if (candidate.toLowerCase() != 'details') {
        return canonicalize(candidate);
      }
    }

    final qrMatch = RegExp(
      r'QR-[A-Za-z0-9]+',
      caseSensitive: false,
    ).firstMatch(value);
    if (qrMatch != null) return canonicalize(qrMatch.group(0)!);

    if (RegExp(r'^\d+$').hasMatch(value)) return 'QR-$value';

    return canonicalize(value);
  }

  /// UUID used as `public_uuid` on `POST .../scan-qr/`.
  static String? extractPublicUuid(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    if (value.contains('%')) {
      try {
        final decoded = Uri.decodeComponent(value);
        if (decoded.trim().isNotEmpty) value = decoded.trim();
      } catch (_) {}
    }

    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          final nested = decoded['public_uuid'] ??
              decoded['uuid'] ??
              decoded['qr_code'];
          if (nested != null) {
            final nestedUuid = extractPublicUuid(nested.toString());
            if (nestedUuid != null) return nestedUuid;
          }
        }
      } catch (_) {}
    }

    final match = _uuidPattern.firstMatch(value);
    if (match == null) return null;
    return match.group(0)!.toLowerCase();
  }

  /// Normalizes `QR-xxxx` casing for API requests.
  static String canonicalize(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return trimmed;
    final uuid = extractPublicUuid(trimmed);
    if (uuid != null) return uuid;
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('qr-')) return trimmed;
    return 'QR-${trimmed.substring(3).toUpperCase()}';
  }

  static Uri? _parseAsUri(String value) {
    final direct = Uri.tryParse(value);
    if (direct != null &&
        direct.hasScheme &&
        (direct.scheme == 'http' || direct.scheme == 'https')) {
      return direct;
    }

    if (value.startsWith('//')) {
      return Uri.tryParse('http:$value');
    }

    if (RegExp(r'^[\d.]+:\d+/').hasMatch(value) || value.contains('/scan/')) {
      return Uri.tryParse('http://$value');
    }

    if (value.startsWith('/')) {
      return Uri.tryParse('http://local$value');
    }

    return direct;
  }

  static String? _codeFromPathSegments(List<String> segments) {
    final cleaned =
        segments.where((segment) => segment.trim().isNotEmpty).toList();

    final scanIndex = cleaned.indexWhere(
      (segment) => segment.toLowerCase() == 'scan',
    );
    if (scanIndex >= 0 && scanIndex + 1 < cleaned.length) {
      return cleaned[scanIndex + 1].trim();
    }

    final qrCodesIndex = cleaned.indexWhere(
      (segment) => segment.toLowerCase() == 'qr-codes',
    );
    if (qrCodesIndex >= 0 && qrCodesIndex + 1 < cleaned.length) {
      final candidate = cleaned[qrCodesIndex + 1].trim();
      if (candidate.toLowerCase() != 'details') return candidate;
    }

    return null;
  }
}
