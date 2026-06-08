import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';

final projectMapRepositoryProvider = Provider<ProjectMapRepository>((ref) {
  return const ProjectMapRepository();
});

final class ProjectMapRepository {
  const ProjectMapRepository();

  static const _inbuiltJobs = <ProjectMapJob>[
    ProjectMapJob(
      id: 101,
      title: 'North Wing Foundation',
      address: 'Employee Site A, Riverside Tower',
      status: 'ACTIVE',
      position: LatLng(40.71386, -74.0072),
      distanceMiles: 0.4,
      isActive: true,
    ),
    ProjectMapJob(
      id: 102,
      title: 'East Parking Structure',
      address: 'Employee Site B, East Gate',
      status: 'SCHEDULED',
      position: LatLng(40.71605, -74.0019),
      distanceMiles: 1.2,
      isActive: true,
    ),
    ProjectMapJob(
      id: 103,
      title: 'Utility Check-in',
      address: 'Employee Site C, West Gate Entry',
      status: 'IN PROGRESS',
      position: LatLng(40.71064, -74.0111),
      distanceMiles: 0.2,
      isActive: true,
    ),
  ];

  Future<List<ProjectMapJob>> fetchJobs({String? search}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final query = search?.trim().toLowerCase();
    if (query == null || query.isEmpty) return _inbuiltJobs;
    return _inbuiltJobs
        .where((job) {
          return job.title.toLowerCase().contains(query) ||
              job.address.toLowerCase().contains(query) ||
              job.status.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }
}
