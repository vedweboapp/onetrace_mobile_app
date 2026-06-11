import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:red5/employee_role/forms/data/cached_technician_form.dart';

final class TechnicianFormDatabase {
  TechnicianFormDatabase(this._db);

  final Database _db;

  static const _dbName = 'technician_forms.db';
  static const _tableName = 'technician_form_cache';

  static Future<TechnicianFormDatabase> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
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
      },
    );
    return TechnicianFormDatabase(db);
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

  Future<void> close() async {
    await _db.close();
  }
}
