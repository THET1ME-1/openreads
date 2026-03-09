import 'package:openreads/core/constants/enums/enums.dart';
import 'package:openreads/database/database_provider.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseController {
  final dbClient = DatabaseProvider.dbProvider;

  Future<int> createBook(Book book) async {
    final db = await dbClient.db;

    return db.insert("booksTable", book.toJSON());
  }

  Future<List<Book>> getAllNotDeletedBooks({List<String>? columns}) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      columns: columns,
      where: 'deleted = 0',
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<List<Book>> getAllBooks({List<String>? columns}) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      columns: columns,
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<List<Book>> getBooks({
    List<String>? columns,
    required int status,
  }) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      columns: columns,
      where: 'status = ? AND deleted = 0',
      whereArgs: [status],
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<List<Book>> searchBooks({
    List<String>? columns,
    required String query,
  }) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      columns: columns,
      where:
          "(title LIKE ? OR subtitle LIKE ? OR author LIKE ?) AND deleted LIKE ?",
      whereArgs: [
        '%$query%',
        '%$query%',
        '%$query%',
        '0',
      ],
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<int> countBooks({
    List<String>? columns,
    required int status,
  }) async {
    final db = await dbClient.db;

    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM booksTable WHERE status = $status AND deleted = 0',
    ));

    return count ?? 0;
  }

  Future<int> updateBook(Book book) async {
    final db = await dbClient.db;

    return await db.update("booksTable", book.toJSON(),
        where: "id = ?", whereArgs: [book.id]);
  }

  Future<int> deleteBook(int id) async {
    final db = await dbClient.db;

    return await db.delete("booksTable", where: 'id = ?', whereArgs: [id]);
  }

  Future<Book?> getBook(int id) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()[0]
        : null;
  }

  Future<List<Book>> getDeletedBooks() async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      where: 'deleted = 1',
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<int> removeAllBooks() async {
    final db = await dbClient.db;
    return await db.delete("booksTable");
  }

  Future<List<Object?>> bulkUpdateBookFormat(
    Set<int> ids,
    BookFormat bookFormat,
  ) async {
    final db = await dbClient.db;
    var batch = db.batch();

    String bookFormatString = bookFormat == BookFormat.audiobook
        ? 'audiobook'
        : bookFormat == BookFormat.ebook
            ? 'ebook'
            : bookFormat == BookFormat.paperback
                ? 'paperback'
                : bookFormat == BookFormat.hardcover
                    ? 'hardcover'
                    : 'paperback';

    for (int id in ids) {
      batch.update("booksTable", {"book_type": bookFormatString},
          where: "id = ?", whereArgs: [id]);
    }
    return await batch.commit();
  }

  Future<List<Object?>> bulkUpdateBookAuthor(
    Set<int> ids,
    String author,
  ) async {
    final db = await dbClient.db;
    var batch = db.batch();

    for (int id in ids) {
      batch.update("booksTable", {"author": author},
          where: "id = ?", whereArgs: [id]);
    }
    return await batch.commit();
  }

  Future<List<Book>> getBooksWithSameTag(String tag) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      where: 'tags IS NOT NULL AND deleted = 0',
      orderBy: 'publication_year ASC',
    );

    final booksWithTag = List<Book>.empty(growable: true);

    if (result.isNotEmpty) {
      final books = result.map((item) => Book.fromJSON(item)).toList();
      for (final book in books) {
        if (book.tags != null && book.tags!.isNotEmpty) {
          for (final bookTag in book.tags!.split('|||||')) {
            if (bookTag == tag) {
              booksWithTag.add(book);
            }
          }
        }
      }
    }

    return booksWithTag;
  }

  Future<List<Book>> getBooksWithSameAuthor(String author) async {
    final db = await dbClient.db;

    var result = await db.query(
      "booksTable",
      where: 'author = ? AND deleted = 0',
      whereArgs: [author],
      orderBy: 'publication_year ASC',
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  // ── Series CRUD ──────────────────────────────────────────────

  Future<int> createSeries(BookSeries series) async {
    final db = await dbClient.db;
    return db.insert("seriesTable", series.toJSON());
  }

  Future<List<BookSeries>> getAllSeries() async {
    final db = await dbClient.db;

    var result = await db.query(
      "seriesTable",
      orderBy: 'sort_order ASC, name ASC',
    );

    return result.isNotEmpty
        ? result.map((item) => BookSeries.fromJSON(item)).toList()
        : [];
  }

  Future<List<BookSeries>> getRootSeries() async {
    final db = await dbClient.db;

    var result = await db.query(
      "seriesTable",
      where: 'parent_series_id IS NULL',
      orderBy: 'sort_order ASC, name ASC',
    );

    return result.isNotEmpty
        ? result.map((item) => BookSeries.fromJSON(item)).toList()
        : [];
  }

  Future<List<BookSeries>> getSubSeries(int parentId) async {
    final db = await dbClient.db;

    var result = await db.query(
      "seriesTable",
      where: 'parent_series_id = ?',
      whereArgs: [parentId],
      orderBy: 'sort_order ASC, name ASC',
    );

    return result.isNotEmpty
        ? result.map((item) => BookSeries.fromJSON(item)).toList()
        : [];
  }

  Future<BookSeries?> getSeries(int id) async {
    final db = await dbClient.db;

    var result = await db.query(
      "seriesTable",
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty ? BookSeries.fromJSON(result.first) : null;
  }

  Future<int> updateSeries(BookSeries series) async {
    final db = await dbClient.db;

    return await db.update(
      "seriesTable",
      series.toJSON(),
      where: "id = ?",
      whereArgs: [series.id],
    );
  }

  Future<int> deleteSeries(int id) async {
    final db = await dbClient.db;

    // First delete all book-series links
    await db.delete("bookSeriesTable", where: 'series_id = ?', whereArgs: [id]);

    // Set children's parent to null
    await db.update(
      "seriesTable",
      {'parent_series_id': null},
      where: 'parent_series_id = ?',
      whereArgs: [id],
    );

    return await db.delete("seriesTable", where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BookSeries>> searchSeries(String query) async {
    final db = await dbClient.db;

    var result = await db.query(
      "seriesTable",
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );

    return result.isNotEmpty
        ? result.map((item) => BookSeries.fromJSON(item)).toList()
        : [];
  }

  // ── Book-Series Links ────────────────────────────────────────

  Future<int> addBookToSeries(BookSeriesLink link) async {
    final db = await dbClient.db;
    return db.insert(
      "bookSeriesTable",
      link.toJSON(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeBookFromSeries(int bookId, int seriesId) async {
    final db = await dbClient.db;
    return db.delete(
      "bookSeriesTable",
      where: 'book_id = ? AND series_id = ?',
      whereArgs: [bookId, seriesId],
    );
  }

  Future<int> updateBookOrderInSeries(
      int bookId, int seriesId, double? order) async {
    final db = await dbClient.db;
    return db.update(
      "bookSeriesTable",
      {'order_in_series': order},
      where: 'book_id = ? AND series_id = ?',
      whereArgs: [bookId, seriesId],
    );
  }

  Future<List<BookSeriesLink>> getSeriesForBook(int bookId) async {
    final db = await dbClient.db;

    var result = await db.query(
      "bookSeriesTable",
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    return result.isNotEmpty
        ? result.map((item) => BookSeriesLink.fromJSON(item)).toList()
        : [];
  }

  Future<List<Book>> getBooksInSeries(int seriesId) async {
    final db = await dbClient.db;

    var result = await db.rawQuery(
      '''SELECT b.*, bs.order_in_series 
         FROM booksTable b 
         INNER JOIN bookSeriesTable bs ON b.id = bs.book_id 
         WHERE bs.series_id = ? AND b.deleted = 0
         ORDER BY bs.order_in_series ASC NULLS LAST, b.title ASC''',
      [seriesId],
    );

    return result.isNotEmpty
        ? result.map((item) => Book.fromJSON(item)).toList()
        : [];
  }

  Future<int> countBooksInSeries(int seriesId) async {
    final db = await dbClient.db;

    final count = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(*) FROM bookSeriesTable bs
         INNER JOIN booksTable b ON bs.book_id = b.id
         WHERE bs.series_id = ? AND b.deleted = 0''',
      [seriesId],
    ));

    return count ?? 0;
  }

  Future<void> removeAllBookSeriesLinks(int bookId) async {
    final db = await dbClient.db;
    await db.delete(
      "bookSeriesTable",
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> setBookSeriesLinks(
      int bookId, List<BookSeriesLink> links) async {
    final db = await dbClient.db;

    // Remove existing links
    await db.delete(
      "bookSeriesTable",
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    // Add new links
    for (final link in links) {
      await db.insert(
        "bookSeriesTable",
        link.copyWith(bookId: bookId).toJSON(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> removeAllSeries() async {
    final db = await dbClient.db;
    await db.delete("bookSeriesTable");
    return await db.delete("seriesTable");
  }
}
