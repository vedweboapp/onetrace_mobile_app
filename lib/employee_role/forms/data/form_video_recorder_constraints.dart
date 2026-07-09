/// Limits for operative `video_recorder` form fields.
abstract final class FormVideoRecorderConstraints {
  FormVideoRecorderConstraints._();

  /// Maximum clip length.
  static const Duration maxDuration = Duration(minutes: 1);

  /// Maximum upload size (20 MB).
  static const int maxBytes = 20 * 1024 * 1024;

  /// Target resolution label shown in the UI.
  static const String resolutionLabel = '780p';

  /// Target width for ~780p recording (device may use closest preset).
  static const int targetWidth = 1280;

  /// Target height for ~780p recording.
  static const int targetHeight = 780;

  /// Suggested video bitrate to stay under [maxBytes] for [maxDuration].
  static const int videoBitrate = 2800000;

  static String get limitsHint =>
      '$resolutionLabel · max ${maxDuration.inSeconds}s · max ${maxBytes ~/ (1024 * 1024)} MB';

  /// Validates recording duration (byTime).
  static bool passesByTime(Duration duration) => duration <= maxDuration;

  /// Validates file size (bySize).
  static bool passesBySize(int bytes) => bytes > 0 && bytes <= maxBytes;

  static String? validate({
    required Duration duration,
    required int bytes,
  }) {
    if (!passesByTime(duration)) {
      return 'Video must be ${maxDuration.inSeconds} seconds or shorter.';
    }
    if (!passesBySize(bytes)) {
      return 'Video must be ${maxBytes ~/ (1024 * 1024)} MB or smaller.';
    }
    return null;
  }

  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

final class FormPickedVideoValue {
  const FormPickedVideoValue({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.duration,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final Duration duration;
}

bool isVideoRecorderFieldType(String? fieldType) {
  final type = fieldType?.trim().toLowerCase() ?? '';
  return type == 'video_recorder' ||
      type == 'video_recording' ||
      type == 'video_record';
}

bool isVideoRecorderSectionName(String? sectionName) {
  final name = sectionName?.trim().toLowerCase() ?? '';
  if (name.isEmpty) return false;
  return name == 'video_recorder' || name.contains('video recorder');
}
