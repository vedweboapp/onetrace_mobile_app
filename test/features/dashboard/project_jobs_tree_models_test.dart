import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/dashboard/data/project_jobs_tree_models.dart';

void main() {
  const sampleResponse = {
    'success': true,
    'message': 'Job fetched successfully',
    'data': {
      'levels': [
        {
          'id': 1,
          'name': 'Complex',
          'plots': [
            {
              'id': 2,
              'name': 'Room 2',
              'jobs': [
                {
                  'id': 8,
                  'title': 'Mark.Powai Commercial Complex Phase 1.Mark Commercial',
                  'description': '',
                  'job_source': 'quotation',
                  'status': {'id': 3, 'name': 'Completed'},
                  'start_date': '2026-06-22T10:54:00Z',
                  'completed_at': '2026-06-22T11:02:52.510579Z',
                  'job_serial_number': 'JB008',
                  'assigned_worker': {'id': 2, 'name': 'Jhon Doe'},
                },
                {
                  'id': 6,
                  'title': 'Pending job',
                  'status': null,
                  'assigned_worker': null,
                },
              ],
            },
          ],
        },
      ],
      'manual_jobs': [
        {
          'id': 99,
          'title': 'Manual job',
          'status': null,
        },
      ],
    },
  };

  group('ProjectJobsTree', () {
    test('parses levels, plots, and jobs from API root', () {
      final tree = ProjectJobsTree.fromApiRoot(sampleResponse);
      expect(tree.levels, hasLength(1));
      expect(tree.levels.first.name, 'Complex');
      expect(tree.levels.first.plots, hasLength(1));
      expect(tree.levels.first.plots.first.name, 'Room 2');
      expect(tree.levels.first.plots.first.jobs, hasLength(2));

      final completed = tree.levels.first.plots.first.jobs.first;
      expect(completed.id, 8);
      expect(completed.statusName, 'Completed');
      expect(completed.assignedWorkerName, 'Jhon Doe');
      expect(completed.jobSerialNumber, 'JB008');
      expect(completed.isCompleted, isTrue);
      expect(completed.plotName, 'Room 2');
      expect(completed.levelName, 'Complex');

      final pending = tree.levels.first.plots.first.jobs[1];
      expect(pending.statusName, isNull);
      expect(pending.isCompleted, isFalse);

      expect(tree.manualJobs, hasLength(1));
      expect(tree.manualJobs.first.id, 99);
    });

    test('filters jobs by search term', () {
      final tree = ProjectJobsTree.fromApiRoot(sampleResponse);
      final filtered = tree.filteredBySearch('JB008');
      expect(filtered.totalJobCount, 1);
      expect(filtered.levels.first.plots.first.jobs.single.id, 8);
    });

    test('reports empty tree correctly', () {
      const empty = ProjectJobsTree();
      expect(empty.isEmpty, isTrue);
      expect(empty.totalJobCount, 0);
    });
  });
}
