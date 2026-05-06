import 'package:logger/logger.dart';

/// Central app logging. Prefer [write] for API traces and diagnostics.
abstract final class AppLogger {
  const AppLogger._();

  static final Logger _logger = Logger(
    level: Level.debug,
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Logs a single message, optionally with structured [extra], [error], or [stackTrace].
  static void write(
    String message, {
    Object? extra,
    Object? error,
    StackTrace? stackTrace,
    Level level = Level.info,
  }) {
    if (error != null || stackTrace != null) {
      _logger.log(level, message, error: error, stackTrace: stackTrace);
    } else if (extra != null) {
      _logger.log(level, '$message | $extra');
    } else {
      _logger.log(level, message);
    }
  }
}
