import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

void main() {
  group('readApiRows', () {
    test('reads rows from top-level results', () {
      final rows = readApiRows({
        'results': [
          {'id': 1, 'title': 'Job A'},
        ],
      });
      expect(rows, hasLength(1));
      expect(rows.first['id'], 1);
    });

    test('reads rows from top-level data array', () {
      final rows = readApiRows({
        'success': true,
        'data': [
          {'id': 2, 'title': 'Job B'},
        ],
      });
      expect(rows, hasLength(1));
      expect(rows.first['title'], 'Job B');
    });

    test('reads rows from nested data.results envelope', () {
      final rows = readApiRows({
        'success': true,
        'data': {
          'results': [
            {'id': 3, 'title': 'Job C'},
          ],
          'pagination': {
            'current_page': 1,
            'total_pages': 2,
            'total_records': 3,
            'next': '/api/v1/jobs/?page=2',
          },
        },
      });
      expect(rows, hasLength(1));
      expect(rows.first['id'], 3);
    });
  });

  group('readApiMap', () {
    test('decodes JSON string response bodies', () {
      const encoded = '{"data":[{"id":1}],"pagination":{}}';
      final root = readApiMap(encoded);
      expect(readApiRows(root), hasLength(1));
    });
  });

  group('readApiMutationEntityBody', () {
    test('resolves entity from list-shaped create response', () {
      final body = readApiMutationEntityBody(
        {
          'data': [
            {'id': 3, 'email': 'new@example.com', 'name': 'New Vendor'},
            {'id': 2, 'email': 'old@example.com', 'name': 'Old Vendor'},
          ],
        },
        matchPayload: {'email': 'new@example.com'},
      );
      expect(body['id'], 3);
      expect(body['name'], 'New Vendor');
    });
  });

  group('readApiPageMeta', () {
    test('reads pagination nested under data', () {
      final meta = readApiPageMeta(
        {
          'data': {
            'results': [
              {'id': 1, 'title': 'Job'},
            ],
            'pagination': {
              'current_page': 1,
              'total_pages': 4,
              'total_records': 72,
            },
          },
        },
        page: 1,
      );
      expect(meta.currentPage, 1);
      expect(meta.totalPages, 4);
      expect(meta.totalRecords, 72);
    });
  });

  group('JobRead parsing from API rows', () {
    test('parses jobs from nested list envelope', () {
      final rows = readApiRows({
        'data': {
          'results': [
            {'id': 10, 'title': 'Install sensors'},
          ],
        },
      });
      final jobs = rows.map(JobRead.tryFromMap).whereType<JobRead>().toList();
      expect(jobs, hasLength(1));
      expect(jobs.first.id, 10);
      expect(jobs.first.title, 'Install sensors');
    });
  });
}
