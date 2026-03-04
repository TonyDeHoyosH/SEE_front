import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'awos.db');

    return await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE crisis (
            id TEXT PRIMARY KEY,
            started_at TEXT NOT NULL,
            emotion TEXT NOT NULL,
            emotion_ids TEXT,
            intensity INTEGER DEFAULT 5,
            evaluation TEXT,
            breathing_completed INTEGER NOT NULL DEFAULT 0,
            is_synced INTEGER NOT NULL DEFAULT 0,
            reflection_pending INTEGER NOT NULL DEFAULT 1,
            reflection_trigger TEXT,
            reflection_location TEXT,
            reflection_company TEXT,
            reflection_substance TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE capsules (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL DEFAULT '',
            emotion_ids TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            type TEXT NOT NULL DEFAULT 'texto',
            audio_path TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE victory_definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE victory_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            definition_id INTEGER NOT NULL,
            logged_date TEXT NOT NULL,
            UNIQUE(definition_id, logged_date)
          )
        ''');
        await _seedDefaultVictories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS capsules (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              emotion_id INTEGER NOT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              type TEXT NOT NULL DEFAULT 'texto',
              audio_path TEXT,
              is_synced INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS victory_definitions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS victory_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              definition_id INTEGER NOT NULL,
              logged_date TEXT NOT NULL,
              UNIQUE(definition_id, logged_date)
            )
          ''');
          await _seedDefaultVictories(db);
        }
        if (oldVersion < 4) {
          await db.delete('victory_definitions');
          await db.delete('victory_logs');
          await _seedDefaultVictories(db);
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE crisis ADD COLUMN emotion_ids TEXT');
          await db.execute(
              'ALTER TABLE crisis ADD COLUMN intensity INTEGER DEFAULT 5');
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE capsules ADD COLUMN emotion_ids TEXT');
        }
        if (oldVersion < 7) {
          // Recreate capsules table without the deprecated emotion_id NOT NULL column
          await db.execute('''
            CREATE TABLE capsules_new (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              emotion_ids TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              type TEXT NOT NULL DEFAULT 'texto',
              audio_path TEXT,
              is_synced INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
          await db.execute('''
            INSERT INTO capsules_new (id, title, content, emotion_ids, is_active, type, audio_path, is_synced, created_at)
            SELECT id, title, content, emotion_ids, is_active, type, audio_path, is_synced, created_at
            FROM capsules
          ''');
          await db.execute('DROP TABLE capsules');
          await db.execute('ALTER TABLE capsules_new RENAME TO capsules');
        }
      },
    );
  }

  // --- Crisis methods ---

  static Future<int> insertCrisis(Map<String, dynamic> crisis) async {
    final db = await database;
    return await db.insert(
      'crisis',
      crisis,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateCrisisReflection(
    String crisisId, {
    required String trigger,
    required String location,
    required String company,
    required String substance,
  }) async {
    final db = await database;
    return await db.update(
      'crisis',
      {
        'reflection_trigger': trigger,
        'reflection_location': location,
        'reflection_company': company,
        'reflection_substance': substance,
        'reflection_pending': 0,
      },
      where: 'id = ?',
      whereArgs: [crisisId],
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedCrises() async {
    final db = await database;
    return await db.query(
      'crisis',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  static Future<int> markAsSynced(String crisisId) async {
    final db = await database;
    return await db.update(
      'crisis',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [crisisId],
    );
  }

  static Future<List<Map<String, dynamic>>> getAllCrises() async {
    final db = await database;
    return await db.query('crisis', orderBy: 'started_at DESC');
  }

  // --- Capsules methods ---

  static Future<int> insertCapsule(Map<String, dynamic> capsule) async {
    final db = await database;
    return await db.insert(
      'capsules',
      capsule,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateCapsule(Map<String, dynamic> capsule) async {
    final db = await database;
    return await db.update(
      'capsules',
      capsule,
      where: 'id = ?',
      whereArgs: [capsule['id']],
    );
  }

  static Future<List<Map<String, dynamic>>> getAllCapsules() async {
    final db = await database;
    return await db.query('capsules', orderBy: 'created_at DESC');
  }

  static Future<int> updateCapsuleSync(String capsuleId) async {
    final db = await database;
    return await db.update(
      'capsules',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [capsuleId],
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedCapsules() async {
    final db = await database;
    return await db.query(
      'capsules',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  static Future<int> deleteCapsule(String id) async {
    final db = await database;
    return await db.delete(
      'capsules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Victory methods ---

  static const _defaultVictories = [
    'Salir a caminar',
    'Hacer 10 respiraciones',
    'Hablar con un ser querido',
    'Leer un libro',
    'Mandar un mensaje lindo',
  ];

  static Future<void> _seedDefaultVictories(Database db) async {
    for (final name in _defaultVictories) {
      await db.insert('victory_definitions', {'name': name});
    }
  }

  static Future<int> insertVictoryDefinition(String name) async {
    final db = await database;
    return await db.insert('victory_definitions', {'name': name});
  }

  static Future<List<Map<String, dynamic>>> getAllVictoryDefinitions() async {
    final db = await database;
    return await db.query('victory_definitions', orderBy: 'id ASC');
  }

  static Future<int> updateVictoryDefinition(int id, String name) async {
    final db = await database;
    return await db.update(
      'victory_definitions',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteVictoryDefinition(int id) async {
    final db = await database;
    await db
        .delete('victory_logs', where: 'definition_id = ?', whereArgs: [id]);
    return await db
        .delete('victory_definitions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> logVictoryToday(int definitionId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await db.insert(
      'victory_logs',
      {'definition_id': definitionId, 'logged_date': today},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<int> unlogVictoryToday(int definitionId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await db.delete(
      'victory_logs',
      where: 'definition_id = ? AND logged_date = ?',
      whereArgs: [definitionId, today],
    );
  }

  static Future<Set<int>> getTodayLoggedIds() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      'victory_logs',
      where: 'logged_date = ?',
      whereArgs: [today],
    );
    return results.map((r) => r['definition_id'] as int).toSet();
  }

  static Future<List<Map<String, dynamic>>> getVictoryHistory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT vl.id, vd.name, vl.logged_date
      FROM victory_logs vl
      INNER JOIN victory_definitions vd ON vd.id = vl.definition_id
      ORDER BY vl.logged_date DESC, vl.id DESC
      LIMIT 50
    ''');
  }

  // --- Dashboard metrics ---

  static Future<int> countActiveCapsules() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM capsules WHERE is_active = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<int> countWeeklyVictories() async {
    final db = await database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoStr = weekAgo.toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM victory_logs WHERE logged_date >= ?',
      [weekAgoStr],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<int> countTotalCrises() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM crisis',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
