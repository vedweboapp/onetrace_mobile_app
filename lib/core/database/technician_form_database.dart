import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

final class TechnicianFormDatabase {
  TechnicianFormDatabase(this._db);

  final Database _db;

  static const _dbName = 'technician_forms.db';
  static const _tableName = 'technician_form_cache';
  static const _submissionTable = 'job_form_submission';
  static const _jobFormLinkTable = 'job_form_link';
  static const _jobListCacheTable = 'operative_job_list_cache';
  static const _jobDetailCacheTable = 'operative_job_detail_cache';
  static const _syncQueueTable = 'operative_sync_queue';

  static Future<TechnicianFormDatabase> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: 5,
      onCreate: (database, version) async {
        await _createFormCacheTable(database);
        await _createSubmissionTable(database);
        await _createJobFormLinkTable(database);
        await _createOperativeCacheTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSubmissionTable(database);
        }
        if (oldVersion < 3) {
          await _createJobFormLinkTable(database);
        }
        if (oldVersion < 4) {
          await _createOperativeCacheTables(database);
        }
        if (oldVersion < 5) {
          await database.execute(
            'ALTER TABLE $_submissionTable ADD COLUMN job_pin_id INTEGER',
          );
        }
      },
    );
    return TechnicianFormDatabase(db);
  }

  static Future<void> _createFormCacheTable(Database database) async {
    await database.execute('''
      CREATE TABLE $_tableName (
        form_id INTEGER PRIMARY KEY,
        summary_json TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        rules_json TEXT NOT NULL,
        fetched_at INTEGER NOT NULL,
        content_hash TEXT
      )
    ''');
  }

  static Future<void> _createSubmissionTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_submissionTable (
        local_id TEXT PRIMARY KEY,
        job_id INTEGER NOT NULL,
        form_id INTEGER NOT NULL,
        job_form_id INTEGER NOT NULL,
        job_pin_id INTEGER,
        status TEXT NOT NULL,
        remarks TEXT,
        values_json TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        server_submission_id INTEGER,
        last_error TEXT,
        updated_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_job_form_submission_job
      ON $_submissionTable (job_id, form_id)
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_job_form_submission_sync
      ON $_submissionTable (sync_status)
    ''');
  }

  static Future<void> _createJobFormLinkTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_jobFormLinkTable (
        job_id INTEGER NOT NULL,
        form_id INTEGER NOT NULL,
        job_form_id INTEGER NOT NULL,
        submission_id INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (job_id, form_id)
      )
    ''');
  }

  Future<void> upsertForm(TechnicianFormBundle bundle) async {
    await _db.insert(
      _tableName,
      bundle.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TechnicianFormBundle?> readForm(int formId) async {
    final rows = await _db.query(
      _tableName,
      where: 'form_id = ?',
      whereArgs: [formId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TechnicianFormBundle.fromDbRow(rows.first);
  }

  Future<List<int>> listCachedFormIds() async {
    final rows = await _db.query(
      _tableName,
      columns: ['form_id'],
      orderBy: 'fetched_at DESC',
    );
    return rows
        .map((row) => row['form_id'] as int)
        .toList(growable: false);
  }

  Future<void> upsertSubmission(CachedJobFormSubmission submission) async {
    await _db.insert(
      _submissionTable,
      submission.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSubmission(String localId) async {
    await _db.delete(
      _submissionTable,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<CachedJobFormSubmission?> readSubmission({
    required int jobId,
    required int formId,
    int? jobPinId,
  }) async {
    if (jobPinId != null && jobPinId > 0) {
      final rows = await _db.query(
        _submissionTable,
        where: 'job_id = ? AND form_id = ? AND job_pin_id = ?',
        whereArgs: [jobId, formId, jobPinId],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CachedJobFormSubmission.fromDbRow(rows.first);
    }

    final rows = await _db.query(
      _submissionTable,
      where: 'job_id = ? AND form_id = ?',
      whereArgs: [jobId, formId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedJobFormSubmission.fromDbRow(rows.first);
  }

  Future<List<CachedJobFormSubmission>> listSubmissionsForJob(int jobId) async {
    final rows = await _db.query(
      _submissionTable,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(CachedJobFormSubmission.fromDbRow).toList(growable: false);
  }

  Future<List<CachedJobFormSubmission>> listPendingSubmissions() async {
    final rows = await _db.query(
      _submissionTable,
      where: 'sync_status = ?',
      whereArgs: [JobFormSubmissionSyncStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(CachedJobFormSubmission.fromDbRow).toList(growable: false);
  }

  Future<List<CachedJobFormSubmission>> listPendingSubmissionsForJob(
    int jobId,
  ) async {
    final rows = await _db.query(
      _submissionTable,
      where: 'sync_status = ? AND job_id = ?',
      whereArgs: [JobFormSubmissionSyncStatus.pending.name, jobId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CachedJobFormSubmission.fromDbRow).toList(growable: false);
  }

  Future<List<CachedJobFormSubmission>> listUnsyncedSubmissionsForJob(
    int jobId,
  ) async {
    final rows = await _db.query(
      _submissionTable,
      where:
          'job_id = ? AND sync_status IN (?, ?)',
      whereArgs: [
        jobId,
        JobFormSubmissionSyncStatus.pending.name,
        JobFormSubmissionSyncStatus.failed.name,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(CachedJobFormSubmission.fromDbRow).toList(growable: false);
  }

  /// Persists `job_form_id` from `GET /jobs/{id}/` forms[] for offline completion.
  Future<void> upsertJobFormLink({
    required int jobId,
    required int formId,
    required int jobFormId,
    int? submissionId,
  }) async {
    await _db.insert(
      _jobFormLinkTable,
      <String, Object?>{
        'job_id': jobId,
        'form_id': formId,
        'job_form_id': jobFormId,
        'submission_id': submissionId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> readJobFormId({
    required int jobId,
    required int formId,
  }) async {
    final rows = await _db.query(
      _jobFormLinkTable,
      columns: ['job_form_id'],
      where: 'job_id = ? AND form_id = ?',
      whereArgs: [jobId, formId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['job_form_id'] as int?;
  }

  Future<int?> readSubmissionIdFromLink({
    required int jobId,
    required int formId,
  }) async {
    final rows = await _db.query(
      _jobFormLinkTable,
      columns: ['submission_id'],
      where: 'job_id = ? AND form_id = ?',
      whereArgs: [jobId, formId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['submission_id'] as int?;
  }

  Future<List<JobFormAssignment>> listJobFormLinks(int jobId) async {
    final rows = await _db.query(
      _jobFormLinkTable,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'form_id ASC',
    );
    return rows
        .map((row) {
          final jobFormId = row['job_form_id'] as int?;
          final formId = row['form_id'] as int?;
          if (jobFormId == null || formId == null) return null;
          final submissionId = row['submission_id'] as int?;
          return JobFormAssignment(
            jobFormId: jobFormId,
            formId: formId,
            submissionId: submissionId != null && submissionId > 0
                ? submissionId
                : null,
          );
        })
        .whereType<JobFormAssignment>()
        .toList(growable: false);
  }

  static Future<void> _createOperativeCacheTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_jobListCacheTable (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        jobs_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_jobDetailCacheTable (
        job_id INTEGER PRIMARY KEY,
        job_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_syncQueueTable (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_operative_sync_queue_created
      ON $_syncQueueTable (created_at ASC)
    ''');
  }

  Future<void> saveJobListCache(String jobsJson) async {
    await _db.insert(
      _jobListCacheTable,
      <String, Object?>{
        'id': 1,
        'jobs_json': jobsJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readJobListCache() async {
    final rows = await _db.query(
      _jobListCacheTable,
      columns: ['jobs_json'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['jobs_json'] as String?;
  }

  Future<void> saveJobDetailCache({
    required int jobId,
    required String jobJson,
  }) async {
    await _db.insert(
      _jobDetailCacheTable,
      <String, Object?>{
        'job_id': jobId,
        'job_json': jobJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readJobDetailCache(int jobId) async {
    final rows = await _db.query(
      _jobDetailCacheTable,
      columns: ['job_json'],
      where: 'job_id = ?',
      whereArgs: [jobId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['job_json'] as String?;
  }

  Future<void> enqueueSyncOperation({
    required String id,
    required String operationType,
    required String payloadJson,
  }) async {
    await _db.insert(
      _syncQueueTable,
      <String, Object?>{
        'id': id,
        'operation_type': operationType,
        'payload_json': payloadJson,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listSyncQueue() async {
    return _db.query(
      _syncQueueTable,
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deleteSyncQueueItem(String id) async {
    await _db.delete(
      _syncQueueTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSyncQueueError({
    required String id,
    required String error,
  }) async {
    await _db.rawUpdate(
      '''
      UPDATE $_syncQueueTable
      SET retry_count = retry_count + 1, last_error = ?
      WHERE id = ?
      ''',
      [error, id],
    );
  }

  Future<int> countPendingSyncItems() async {
    final forms = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM $_submissionTable
      WHERE sync_status = ?
      ''',
      [JobFormSubmissionSyncStatus.pending.name],
    );
    final queue = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_syncQueueTable',
    );
    final formCount = (forms.first['count'] as int?) ?? 0;
    final queueCount = (queue.first['count'] as int?) ?? 0;
    return formCount + queueCount;
  }

  Future<void> close() async {
    await _db.close();
  }
}
