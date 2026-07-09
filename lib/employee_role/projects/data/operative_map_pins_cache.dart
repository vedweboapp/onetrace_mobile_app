import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/operative_map_pin.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';

final operativeMapPinsCacheProvider = Provider<OperativeMapPinsCache>(
  (ref) => OperativeMapPinsCache(),
);

/// In-memory cache so map pins are not re-geocoded on every tab switch.
final class OperativeMapPinsCache {
  String? _projectKey;
  List<OperativeMapPin> _projectPins = const [];

  String? _jobKey;
  List<OperativeMapPin> _jobPins = const [];

  String? _employeeJobKey;
  List<OperativeMapPin> _employeeJobPins = const [];

  List<OperativeMapPin>? cachedProjectPins(
    List<EmployeeProjectSummary> projects,
  ) {
    final key = _projectListKey(projects);
    if (key == _projectKey && _projectPins.isNotEmpty) return _projectPins;
    return null;
  }

  void storeProjectPins(
    List<EmployeeProjectSummary> projects,
    List<OperativeMapPin> pins,
  ) {
    _projectKey = _projectListKey(projects);
    _projectPins = pins;
  }

  List<OperativeMapPin>? cachedJobPins(List<ProjectMapJob> jobs) {
    final key = _jobListKey(jobs);
    if (key == _jobKey && _jobPins.isNotEmpty) return _jobPins;
    return null;
  }

  void storeJobPins(List<ProjectMapJob> jobs, List<OperativeMapPin> pins) {
    _jobKey = _jobListKey(jobs);
    _jobPins = pins;
  }

  List<OperativeMapPin>? cachedEmployeeJobPins(
    List<EmployeeJobSummary> jobs,
  ) {
    final key = _employeeJobListKey(jobs);
    if (key == _employeeJobKey && _employeeJobPins.isNotEmpty) {
      return _employeeJobPins;
    }
    return null;
  }

  void storeEmployeeJobPins(
    List<EmployeeJobSummary> jobs,
    List<OperativeMapPin> pins,
  ) {
    _employeeJobKey = _employeeJobListKey(jobs);
    _employeeJobPins = pins;
  }

  static String _projectListKey(List<EmployeeProjectSummary> projects) {
    return projects.map((p) => '${p.id}:${p.address.trim()}').join('|');
  }

  static String _jobListKey(List<ProjectMapJob> jobs) {
    return jobs
        .map(
          (j) =>
              '${j.id}:${j.address.trim()}:${j.position.latitude},${j.position.longitude}',
        )
        .join('|');
  }

  static String _employeeJobListKey(List<EmployeeJobSummary> jobs) {
    return jobs.map((j) => '${j.id}:${j.location.trim()}').join('|');
  }
}
