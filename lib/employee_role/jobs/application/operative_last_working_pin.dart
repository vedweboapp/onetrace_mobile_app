import 'package:shared_preferences/shared_preferences.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/operative_pin_workflow.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

/// Remembers the last pin an operative worked on per job + design level so the
/// canvas can auto-zoom back to that part when the drawing is reopened.
class OperativeLastWorkingPin {
  OperativeLastWorkingPin._();

  static String _key(int jobId, int levelId) =>
      'operative_last_working_pin_${jobId}_$levelId';

  static Future<void> remember({
    required int jobId,
    required int levelId,
    required int pinId,
  }) async {
    if (jobId <= 0 || levelId <= 0 || pinId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(jobId, levelId), pinId);
  }

  static Future<int?> read({
    required int jobId,
    required int levelId,
  }) async {
    if (jobId <= 0 || levelId <= 0) return null;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key(jobId, levelId));
    if (value == null || value <= 0) return null;
    return value;
  }
}

/// Picks which pin the canvas should zoom to when an operative opens a design.
///
/// Prefer the last pin they worked on (if it still exists on this level),
/// otherwise the first incomplete pin, otherwise the first pin on the level.
int? resolveOperativeFocusPinId({
  required EmployeeJobDrawingLevel level,
  required EmployeeJobDetailState state,
  int? lastWorkingPinId,
}) {
  final pins = <EmployeeJobDrawingPin>[
    for (final plot in level.plots) ...plot.pins,
  ];
  if (pins.isEmpty) return null;

  bool hasPin(int id) => pins.any((p) => p.id == id);

  final lastId = lastWorkingPinId;
  if (lastId != null && lastId > 0 && hasPin(lastId)) {
    final lastPin = pins.firstWhere((p) => p.id == lastId);
    if (!isOperativePinComplete(lastPin, state)) {
      return lastId;
    }
  }

  for (final pin in pins) {
    if (!isOperativePinComplete(pin, state)) return pin.id;
  }

  if (lastId != null && lastId > 0 && hasPin(lastId)) return lastId;
  return pins.first.id;
}
