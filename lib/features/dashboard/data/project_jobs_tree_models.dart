import 'package:red5/core/network/api_pagination.dart';

/// Hierarchical jobs from `GET /project/{id}/jobs/` (`levels` → `plots` → `jobs`).
final class ProjectJobsTree {
  const ProjectJobsTree({
    this.levels = const [],
    this.manualJobs = const [],
  });

  factory ProjectJobsTree.fromApiRoot(Map<String, dynamic> root) {
    final body = readApiEntityBody(root);
    final levelsRaw = body['levels'] ?? root['levels'];
    final manualRaw = body['manual_jobs'] ?? root['manual_jobs'];

    final levels = <ProjectJobsLevel>[];
    if (levelsRaw is List) {
      for (final row in levelsRaw) {
        if (row is! Map) continue;
        final level = ProjectJobsLevel.tryFromMap(
          Map<String, dynamic>.from(row),
        );
        if (level != null) levels.add(level);
      }
    }

    final manualJobs = <ProjectPlotJob>[];
    if (manualRaw is List) {
      for (final row in manualRaw) {
        if (row is! Map) continue;
        final job = ProjectPlotJob.tryFromMap(
          Map<String, dynamic>.from(row),
        );
        if (job != null) manualJobs.add(job);
      }
    }

    return ProjectJobsTree(levels: levels, manualJobs: manualJobs);
  }

  final List<ProjectJobsLevel> levels;
  final List<ProjectPlotJob> manualJobs;

  bool get isEmpty =>
      levels.every((level) => level.plots.every((plot) => plot.jobs.isEmpty)) &&
      manualJobs.isEmpty;

  int get totalJobCount {
    var count = manualJobs.length;
    for (final level in levels) {
      for (final plot in level.plots) {
        count += plot.jobs.length;
      }
    }
    return count;
  }

  ProjectJobsTree filteredBySearch(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return this;

    bool matches(ProjectPlotJob job) {
      return job.title.toLowerCase().contains(term) ||
          job.id.toString().contains(term) ||
          (job.jobSerialNumber?.toLowerCase().contains(term) ?? false) ||
          (job.assignedWorkerName?.toLowerCase().contains(term) ?? false) ||
          (job.statusName?.toLowerCase().contains(term) ?? false) ||
          (job.description?.toLowerCase().contains(term) ?? false);
    }

    final filteredLevels = <ProjectJobsLevel>[];
    for (final level in levels) {
      final plots = <ProjectJobsPlot>[];
      for (final plot in level.plots) {
        final jobs = plot.jobs.where(matches).toList(growable: false);
        if (jobs.isEmpty) continue;
        plots.add(
          ProjectJobsPlot(
            id: plot.id,
            name: plot.name,
            jobs: jobs,
          ),
        );
      }
      if (plots.isEmpty) continue;
      filteredLevels.add(
        ProjectJobsLevel(id: level.id, name: level.name, plots: plots),
      );
    }

    return ProjectJobsTree(
      levels: filteredLevels,
      manualJobs: manualJobs.where(matches).toList(growable: false),
    );
  }
}

final class ProjectJobsLevel {
  const ProjectJobsLevel({
    required this.id,
    required this.name,
    this.plots = const [],
  });

  static ProjectJobsLevel? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final name = _readString(map, const ['name']) ?? 'Level $id';

    final plots = <ProjectJobsPlot>[];
    final plotsRaw = map['plots'];
    if (plotsRaw is List) {
      for (final row in plotsRaw) {
        if (row is! Map) continue;
        final plot = ProjectJobsPlot.tryFromMap(
          Map<String, dynamic>.from(row),
          levelName: name,
        );
        if (plot != null) plots.add(plot);
      }
    }

    return ProjectJobsLevel(id: id, name: name, plots: plots);
  }

  final int id;
  final String name;
  final List<ProjectJobsPlot> plots;
}

final class ProjectJobsPlot {
  const ProjectJobsPlot({
    required this.id,
    required this.name,
    this.jobs = const [],
  });

  static ProjectJobsPlot? tryFromMap(
    Map<String, dynamic> map, {
    String? levelName,
  }) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final name = _readString(map, const ['name']) ?? 'Plot $id';

    final jobs = <ProjectPlotJob>[];
    final jobsRaw = map['jobs'];
    if (jobsRaw is List) {
      for (final row in jobsRaw) {
        if (row is! Map) continue;
        final job = ProjectPlotJob.tryFromMap(
          Map<String, dynamic>.from(row),
          levelName: levelName,
          plotName: name,
        );
        if (job != null) jobs.add(job);
      }
    }

    return ProjectJobsPlot(id: id, name: name, jobs: jobs);
  }

  final int id;
  final String name;
  final List<ProjectPlotJob> jobs;
}

final class ProjectPlotJob {
  const ProjectPlotJob({
    required this.id,
    required this.title,
    this.description,
    this.jobSource,
    this.statusId,
    this.statusName,
    this.startDate,
    this.completedAt,
    this.jobSerialNumber,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.levelName,
    this.plotName,
  });

  static ProjectPlotJob? tryFromMap(
    Map<String, dynamic> map, {
    String? levelName,
    String? plotName,
  }) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final title = _readString(map, const ['title']) ?? 'Untitled Job';

    final statusRaw = map['status'];
    String? statusName;
    int? statusId;
    if (statusRaw is Map) {
      final statusMap = Map<String, dynamic>.from(
        statusRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      statusId = _readInt(statusMap['id']);
      statusName = _readString(statusMap, const ['name', 'status_name']);
    }

    final workerRaw = map['assigned_worker'];
    String? workerName;
    int? workerId;
    if (workerRaw is Map) {
      final workerMap = Map<String, dynamic>.from(
        workerRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      workerId = _readInt(workerMap['id']);
      workerName = _readString(workerMap, const ['name', 'worker_name']);
    }

    final description = _readString(map, const ['description']);
    return ProjectPlotJob(
      id: id,
      title: title,
      description: description?.isEmpty == true ? null : description,
      jobSource: _readString(map, const ['job_source']),
      statusId: statusId,
      statusName: statusName,
      startDate: _readDate(map['start_date']),
      completedAt: _readDate(map['completed_at']),
      jobSerialNumber: _readString(map, const ['job_serial_number']),
      assignedWorkerId: workerId,
      assignedWorkerName: workerName,
      levelName: levelName,
      plotName: plotName,
    );
  }

  final int id;
  final String title;
  final String? description;
  final String? jobSource;
  final int? statusId;
  final String? statusName;
  final DateTime? startDate;
  final DateTime? completedAt;
  final String? jobSerialNumber;
  final int? assignedWorkerId;
  final String? assignedWorkerName;
  final String? levelName;
  final String? plotName;

  String get displaySerial =>
      jobSerialNumber?.trim().isNotEmpty == true
          ? jobSerialNumber!.trim()
          : 'JB-$id';

  bool get isCompleted {
    if (completedAt != null) return true;
    final name = statusName?.trim().toLowerCase() ?? '';
    return name.contains('complete');
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString().trim());
}
