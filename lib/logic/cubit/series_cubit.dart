import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:openreads/resources/repository.dart';
import 'package:rxdart/rxdart.dart';

class SeriesCubit extends Cubit {
  final Repository repository = Repository();

  final BehaviorSubject<List<BookSeries>> _allSeriesFetcher =
      BehaviorSubject<List<BookSeries>>();
  final BehaviorSubject<List<BookSeries>> _rootSeriesFetcher =
      BehaviorSubject<List<BookSeries>>();
  final BehaviorSubject<List<BookSeries>> _subSeriesFetcher =
      BehaviorSubject<List<BookSeries>>();
  final BehaviorSubject<List<Book>> _booksInSeriesFetcher =
      BehaviorSubject<List<Book>>();
  final BehaviorSubject<List<BookSeriesLink>> _seriesForBookFetcher =
      BehaviorSubject<List<BookSeriesLink>>();
  final BehaviorSubject<BookSeries?> _currentSeriesFetcher =
      BehaviorSubject<BookSeries?>();

  Stream<List<BookSeries>> get allSeries => _allSeriesFetcher.stream;
  Stream<List<BookSeries>> get rootSeries => _rootSeriesFetcher.stream;
  Stream<List<BookSeries>> get subSeries => _subSeriesFetcher.stream;
  Stream<List<Book>> get booksInSeries => _booksInSeriesFetcher.stream;
  Stream<List<BookSeriesLink>> get seriesForBook =>
      _seriesForBookFetcher.stream;
  Stream<BookSeries?> get currentSeries => _currentSeriesFetcher.stream;

  SeriesCubit() : super(null) {
    getAllSeries();
  }

  Future<void> getAllSeries() async {
    final series = await repository.getAllSeries();
    _allSeriesFetcher.sink.add(series);
  }

  Future<void> getRootSeries() async {
    final series = await repository.getRootSeries();
    _rootSeriesFetcher.sink.add(series);
  }

  Future<void> getSubSeries(int parentId) async {
    final series = await repository.getSubSeries(parentId);
    _subSeriesFetcher.sink.add(series);
  }

  Future<BookSeries?> getSeries(int id) async {
    final series = await repository.getSeries(id);
    _currentSeriesFetcher.sink.add(series);
    return series;
  }

  Future<int> addSeries(BookSeries series) async {
    final id = await repository.insertSeries(series);
    await getAllSeries();
    await getRootSeries();
    return id;
  }

  Future<void> updateSeries(BookSeries series) async {
    await repository.updateSeries(series);
    await getAllSeries();
    await getRootSeries();
  }

  Future<void> deleteSeries(int id) async {
    await repository.deleteSeries(id);
    await getAllSeries();
    await getRootSeries();
  }

  Future<List<BookSeries>> searchSeries(String query) async {
    return repository.searchSeries(query);
  }

  // ── Book-Series Links ─────────────────────────────────────────

  Future<void> addBookToSeries(BookSeriesLink link) async {
    await repository.addBookToSeries(link);
    await getBooksInSeries(link.seriesId);
    await getSeriesForBook(link.bookId);
    await getAllSeries();
  }

  Future<void> removeBookFromSeries(int bookId, int seriesId) async {
    await repository.removeBookFromSeries(bookId, seriesId);
    await getBooksInSeries(seriesId);
    await getSeriesForBook(bookId);
    await getAllSeries();
  }

  Future<void> updateBookOrderInSeries(
      int bookId, int seriesId, double? order) async {
    await repository.updateBookOrderInSeries(bookId, seriesId, order);
    await getBooksInSeries(seriesId);
  }

  Future<void> getSeriesForBook(int bookId) async {
    final links = await repository.getSeriesForBook(bookId);
    _seriesForBookFetcher.sink.add(links);
  }

  Future<List<BookSeriesLink>> getSeriesForBookDirect(int bookId) async {
    return repository.getSeriesForBook(bookId);
  }

  Future<void> getBooksInSeries(int seriesId) async {
    final books = await repository.getBooksInSeries(seriesId);
    _booksInSeriesFetcher.sink.add(books);
  }

  Future<List<Book>> getBooksInSeriesDirect(int seriesId) async {
    return repository.getBooksInSeries(seriesId);
  }

  Future<int> countBooksInSeries(int seriesId) async {
    return repository.countBooksInSeries(seriesId);
  }

  Future<void> setBookSeriesLinks(
      int bookId, List<BookSeriesLink> links) async {
    await repository.setBookSeriesLinks(bookId, links);
    await getAllSeries();
  }

  Future<void> removeAllSeries() async {
    await repository.removeAllSeries();
    await getAllSeries();
    await getRootSeries();
  }
}
