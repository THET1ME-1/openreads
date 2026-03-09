/// Represents a link between a book and a series (many-to-many).
/// A book can belong to multiple series, and a series can contain multiple books.
class BookSeriesLink {
  int? id;
  int bookId;
  int seriesId;
  double? orderInSeries;

  BookSeriesLink({
    this.id,
    required this.bookId,
    required this.seriesId,
    this.orderInSeries,
  });

  factory BookSeriesLink.fromJSON(Map<String, dynamic> json) {
    return BookSeriesLink(
      id: json['id'],
      bookId: json['book_id'],
      seriesId: json['series_id'],
      orderInSeries: json['order_in_series'] != null
          ? (json['order_in_series'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      'id': id,
      'book_id': bookId,
      'series_id': seriesId,
      'order_in_series': orderInSeries,
    };
  }

  BookSeriesLink copyWith({
    int? id,
    int? bookId,
    int? seriesId,
    double? orderInSeries,
  }) {
    return BookSeriesLink(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      seriesId: seriesId ?? this.seriesId,
      orderInSeries: orderInSeries ?? this.orderInSeries,
    );
  }

  @override
  String toString() =>
      'BookSeriesLink(bookId: $bookId, seriesId: $seriesId, order: $orderInSeries)';
}
