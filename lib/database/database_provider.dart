import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Instruction how to add a new database field:
// 1. Add new parameters to the Book class in book.dart
// 2. Increase version number in the createDatabase method below
// 3. Add new fields to the booksTable in the onCreate argument below
// 4. Add a new case to the onUpgrade argument below
// 5. Add a new list of migration scripts to the migrationScriptsVx
// 6. Add a new method _updateBookDatabaseVytoVx
// 7. Update existing methods with new migration scripts
// 7. Update existing methods names with new version number

class DatabaseProvider {
  static final DatabaseProvider dbProvider = DatabaseProvider();

  late final Future<Database> db = createDatabase();

  Future<Database> createDatabase() async {
    Directory docDirectory = await getApplicationDocumentsDirectory();

    String path = join(
      docDirectory.path,
      "Books.db",
    );

    return await openDatabase(
      path,
      version: 9,
      onCreate: (Database db, int version) async {
        await db.execute("CREATE TABLE booksTable ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "title TEXT, "
            "subtitle TEXT, "
            "author TEXT, "
            "description TEXT, "
            "book_type TEXT, "
            "status INTEGER, "
            "rating INTEGER, "
            "favourite INTEGER, "
            "deleted INTEGER, "
            "start_date TEXT, "
            "finish_date TEXT, "
            "pages INTEGER, "
            "publication_year INTEGER, "
            "isbn TEXT, "
            "olid TEXT, "
            "tags TEXT, "
            "my_review TEXT, "
            "notes TEXT, "
            "has_cover INTEGER, "
            "blur_hash TEXT, "
            "readings TEXT, "
            "date_added TEXT, "
            "date_modified TEXT "
            ")");

        await db.execute("CREATE TABLE seriesTable ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "name TEXT NOT NULL, "
            "description TEXT, "
            "parent_series_id INTEGER, "
            "sort_order INTEGER DEFAULT 0, "
            "date_created TEXT, "
            "date_modified TEXT, "
            "FOREIGN KEY (parent_series_id) REFERENCES seriesTable(id) ON DELETE SET NULL"
            ")");

        await db.execute("CREATE TABLE bookSeriesTable ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "book_id INTEGER NOT NULL, "
            "series_id INTEGER NOT NULL, "
            "order_in_series REAL, "
            "FOREIGN KEY (book_id) REFERENCES booksTable(id) ON DELETE CASCADE, "
            "FOREIGN KEY (series_id) REFERENCES seriesTable(id) ON DELETE CASCADE"
            ")");

        await db.execute(
            "CREATE UNIQUE INDEX idx_book_series ON bookSeriesTable(book_id, series_id)");
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (newVersion > oldVersion) {
          var batch = db.batch();

          switch (oldVersion) {
            case 1:
              _updateBookDatabaseV1toLatest(batch);
              break;
            case 2:
              _updateBookDatabaseV2toLatest(batch);
              break;
            case 3:
              _updateBookDatabaseV3toLatest(batch);
              break;
            case 4:
              _updateBookDatabaseV4toLatest(batch);
              break;
            case 5:
              _updateBookDatabaseV5toLatest(batch);
              break;
            case 6:
              _updateBookDatabaseV6toLatest(batch);
              break;
            case 7:
              _updateBookDatabaseV7toLatest(batch);
              break;
            case 8:
              _updateBookDatabaseV8toLatest(batch);
              break;
          }

          await batch.commit();
        }
      },
    );
  }

  void _executeBatch(Batch batch, List<String> scripts) {
    for (var script in scripts) {
      batch.execute(script);
    }
  }

  final migrationScriptsV2 = [
    "ALTER TABLE booksTable ADD description TEXT",
  ];

  final migrationScriptsV3 = [
    "ALTER TABLE booksTable ADD book_type TEXT",
  ];

  final migrationScriptsV4 = [
    "ALTER TABLE booksTable ADD has_cover INTEGER DEFAULT 0",
  ];

  final migrationScriptsV5 = [
    "ALTER TABLE booksTable ADD notes TEXT",
  ];

  final migrationScriptsV6 = [
    "ALTER TABLE booksTable ADD reading_time INTEGER",
  ];

  // added readings - combined start_date, finish_date and reading_time
  final migrationScriptsV7 = [
    "ALTER TABLE booksTable ADD readings TEXT",
    "UPDATE booksTable SET readings = COALESCE(start_date, '') || '|' || COALESCE(finish_date, '') || '|' || COALESCE(CAST(reading_time AS TEXT), '')",
  ];

  final migrationScriptsV8 = [
    "ALTER TABLE booksTable ADD date_added TEXT DEFAULT '${DateTime.now().toIso8601String()}'",
    "ALTER TABLE booksTable ADD date_modified TEXT DEFAULT '${DateTime.now().toIso8601String()}'",
  ];

  final migrationScriptsV9 = [
    "CREATE TABLE IF NOT EXISTS seriesTable ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "name TEXT NOT NULL, "
        "description TEXT, "
        "parent_series_id INTEGER, "
        "sort_order INTEGER DEFAULT 0, "
        "date_created TEXT, "
        "date_modified TEXT, "
        "FOREIGN KEY (parent_series_id) REFERENCES seriesTable(id) ON DELETE SET NULL"
        ")",
    "CREATE TABLE IF NOT EXISTS bookSeriesTable ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "book_id INTEGER NOT NULL, "
        "series_id INTEGER NOT NULL, "
        "order_in_series REAL, "
        "FOREIGN KEY (book_id) REFERENCES booksTable(id) ON DELETE CASCADE, "
        "FOREIGN KEY (series_id) REFERENCES seriesTable(id) ON DELETE CASCADE"
        ")",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_book_series ON bookSeriesTable(book_id, series_id)",
  ];

  void _updateBookDatabaseV1toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV2 +
          migrationScriptsV3 +
          migrationScriptsV4 +
          migrationScriptsV5 +
          migrationScriptsV6 +
          migrationScriptsV7 +
          migrationScriptsV8 +
          migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV2toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV3 +
          migrationScriptsV4 +
          migrationScriptsV5 +
          migrationScriptsV6 +
          migrationScriptsV7 +
          migrationScriptsV8 +
          migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV3toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV4 +
          migrationScriptsV5 +
          migrationScriptsV6 +
          migrationScriptsV7 +
          migrationScriptsV8 +
          migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV4toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV5 +
          migrationScriptsV6 +
          migrationScriptsV7 +
          migrationScriptsV8 +
          migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV5toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV6 +
          migrationScriptsV7 +
          migrationScriptsV8 +
          migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV6toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV7 + migrationScriptsV8 + migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV7toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV8 + migrationScriptsV9,
    );
  }

  void _updateBookDatabaseV8toLatest(Batch batch) {
    _executeBatch(
      batch,
      migrationScriptsV9,
    );
  }
}
