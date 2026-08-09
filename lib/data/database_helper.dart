import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/measurement_record.dart';

/// طبقة الوصول لقاعدة البيانات المحلية (SQLite) المخزّنة على الجهاز.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'tailor_measurements.db';
  static const _dbVersion = 3;
  static const table = 'measurement_records';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS $table');
          await _createSchema(db);
          return;
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $table ADD COLUMN deletedAt TEXT');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phone TEXT NOT NULL,
        notes TEXT,
        measurements TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_fullName_phone ON $table (fullName, phone)',
    );
  }

  Future<MeasurementRecord> insertRecord(MeasurementRecord record) async {
    final db = await database;
    final map = record.toMap()..remove('id');
    final id = await db.insert(table, map);
    return record.copyWith(id: id);
  }

  Future<int> updateRecord(MeasurementRecord record) async {
    final db = await database;
    return db.update(
      table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// ينقل السجل إلى سلة المحذوفات (حذف ناعم) بدل حذفه فعليًا.
  Future<void> softDeleteRecord(int id) async {
    final db = await database;
    await db.update(
      table,
      {'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// يعيد سجلاً من سلة المحذوفات، مع إمكانية تغيير اسمه إذا تعارض مع اسم
  /// عميل نشط آخر.
  Future<void> restoreRecord(int id, {String? newFullName}) async {
    final db = await database;
    final values = <String, Object?>{
      'deletedAt': null,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (newFullName != null) values['fullName'] = newFullName;
    await db.update(table, values, where: 'id = ?', whereArgs: [id]);
  }

  /// يحذف السجل نهائيًا من قاعدة البيانات، بدون إمكانية تراجع.
  Future<int> permanentlyDeleteRecord(int id) async {
    final db = await database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// السجلات النشطة فقط (غير الموجودة في سلة المحذوفات).
  Future<List<MeasurementRecord>> fetchAllRecords() async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
    );
    return rows.map(MeasurementRecord.fromMap).toList();
  }

  /// السجلات الموجودة حاليًا في سلة المحذوفات.
  Future<List<MeasurementRecord>> fetchDeletedRecords() async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'deletedAt IS NOT NULL',
      orderBy: 'deletedAt DESC',
    );
    return rows.map(MeasurementRecord.fromMap).toList();
  }
}
