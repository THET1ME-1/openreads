import 'package:openreads/database/database_controler.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';

import 'package:openreads/core/constants/enums/enums.dart';

class Repository {
  final DatabaseController dbController = DatabaseController();

  Future<List<Book>> getAllNotDeletedBooks() =>
      dbController.getAllNotDeletedBooks();

  Future<List<Book>> getAllBooks() => dbController.getAllBooks();

  Future<List<Book>> getBooks(int status) => dbController.getBooks(
        status: status,
      );

  Future<List<Book>> searchBooks(String query) => dbController.searchBooks(
        query: query,
      );

  Future<int> countBooks(int status) => dbController.countBooks(status: status);

  Future<int> insertBook(Book book) => dbController.createBook(book);

  Future updateBook(Book book) => dbController.updateBook(book);

  Future bulkUpdateBookFormat(Set<int> ids, BookFormat bookFormat) =>
      dbController.bulkUpdateBookFormat(ids, bookFormat);

  Future bulkUpdateBookAuthor(Set<int> ids, String author) =>
      dbController.bulkUpdateBookAuthor(ids, author);

  Future deleteBook(int index) => dbController.deleteBook(index);

  Future<Book?> getBook(int index) => dbController.getBook(index);

  Future<List<Book>> getDeletedBooks() => dbController.getDeletedBooks();

  Future<int> removeAllBooks() => dbController.removeAllBooks();

  Future<List<Book>> getBooksWithSameTag(String tag) =>
      dbController.getBooksWithSameTag(tag);

  Future<List<Book>> getBooksWithSameAuthor(String author) =>
      dbController.getBooksWithSameAuthor(author);

  // ── Series ────────────────────────────────────────────────────

  Future<int> insertSeries(BookSeries series) =>
      dbController.createSeries(series);

  Future<List<BookSeries>> getAllSeries() => dbController.getAllSeries();

  Future<List<BookSeries>> getRootSeries() => dbController.getRootSeries();

  Future<List<BookSeries>> getSubSeries(int parentId) =>
      dbController.getSubSeries(parentId);

  Future<BookSeries?> getSeries(int id) => dbController.getSeries(id);

  Future<int> updateSeries(BookSeries series) =>
      dbController.updateSeries(series);

  Future<int> deleteSeries(int id) => dbController.deleteSeries(id);

  Future<List<BookSeries>> searchSeries(String query) =>
      dbController.searchSeries(query);

  // ── Book-Series Links ─────────────────────────────────────────

  Future<int> addBookToSeries(BookSeriesLink link) =>
      dbController.addBookToSeries(link);

  Future<int> removeBookFromSeries(int bookId, int seriesId) =>
      dbController.removeBookFromSeries(bookId, seriesId);

  Future<int> updateBookOrderInSeries(
          int bookId, int seriesId, double? order) =>
      dbController.updateBookOrderInSeries(bookId, seriesId, order);

  Future<List<BookSeriesLink>> getSeriesForBook(int bookId) =>
      dbController.getSeriesForBook(bookId);

  Future<List<Book>> getBooksInSeries(int seriesId) =>
      dbController.getBooksInSeries(seriesId);

  Future<int> countBooksInSeries(int seriesId) =>
      dbController.countBooksInSeries(seriesId);

  Future<void> removeAllBookSeriesLinks(int bookId) =>
      dbController.removeAllBookSeriesLinks(bookId);

  Future<void> setBookSeriesLinks(int bookId, List<BookSeriesLink> links) =>
      dbController.setBookSeriesLinks(bookId, links);

  Future<int> removeAllSeries() => dbController.removeAllSeries();
}
