import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openreads/model/book_series_link.dart';

/// Cubit for managing the series links being edited on the add/edit book screen.
class EditBookSeriesCubit extends Cubit<List<BookSeriesLink>> {
  EditBookSeriesCubit() : super([]);

  void setLinks(List<BookSeriesLink> links) => emit(links);

  void addLink(BookSeriesLink link) {
    final newLinks = List<BookSeriesLink>.from(state)..add(link);
    emit(newLinks);
  }

  void removeLink(int seriesId) {
    final newLinks = state.where((l) => l.seriesId != seriesId).toList();
    emit(newLinks);
  }

  void updateOrder(int seriesId, double? order) {
    final newLinks = state.map((l) {
      if (l.seriesId == seriesId) {
        return l.copyWith(orderInSeries: order ?? 0);
      }
      return l;
    }).toList();
    emit(newLinks);
  }

  void clear() => emit([]);
}
