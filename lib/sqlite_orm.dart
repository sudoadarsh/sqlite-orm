import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

import "src/sqlite_provider.dart";

export "package:sqlite_orm/annotations/foreign_key.dart";
export "package:sqlite_orm/annotations/primary_key.dart";
export "package:sqlite_orm/annotations/ignore_key.dart";
export "package:sqlite_orm/annotations/schema.dart";
export "package:sqlite_orm/src/sqlite_provider.dart";

typedef SqliteDatabase = Database;

abstract class SqliteOrm {
  /// Singular instance of the database.
  static late final SqliteDatabase database;

  /// Configure the database.
  static Future<void> config({
    required final String name,
    required int version,
    final List<SqliteProvider>? providers,
  }) async {
    final String databasePath = await getDatabasesPath();
    final String path = join(databasePath, name);
    database = await openDatabase(
      path,
      version: version,
      onCreate: (final Database database, _) => _onCreate(providers, database),
    );
  }

  /// Get the next_id for the table.
  static Future<int?> nextId({required String table, required String key}) async {
    final List<Map<String, dynamic>> result;
    result = await database.rawQuery('SELECT COALESCE(MAX($key), 0) as next_id FROM $table');
    return result.firstOrNull?["next_id"];
  }

  static void _onCreate(
    final List<SqliteProvider>? providers,
    final Database database,
  ) async {
    await database.transaction((final Transaction txn) async {
      if (providers == null) return;
      for (final SqliteProvider provider in providers) {
        await database.rawQuery(provider.schema);
      }
    });
  }
}
