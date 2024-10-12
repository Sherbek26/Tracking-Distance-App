import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tracking_distance/database/journey.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'journeys.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE journeys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            distance REAL,
            address TEXT,
            startTime TEXT,
            endTime TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertJourney(Journey journey) async {
    final db = await database;
    await db.insert('journeys', journey.toMap());
  }

  Future<List<Journey>> getJourneys() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('journeys');
    return List.generate(maps.length, (i) {
      return Journey(
        id: maps[i]['id'],
        distance: maps[i]['distance'],
        address: maps[i]['address'],
        startTime: DateTime.parse(maps[i]['startTime']),
        endTime: DateTime.parse(maps[i]['endTime']),
      );
    });
  }
}
