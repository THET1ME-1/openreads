import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/logic/cubit/current_book_cubit.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/ui/book_screen/book_screen.dart';
import 'package:openreads/ui/series_screen/widgets/add_edit_series_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final BookSeries series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late BookSeries _series;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _refreshData();
  }

  void _refreshData() {
    seriesCubit.getBooksInSeries(_series.id!);
    seriesCubit.getSubSeries(_series.id!);
  }

  void _editSeries() async {
    final result = await showDialog<BookSeries>(
      context: context,
      builder: (context) => AddEditSeriesDialog(series: _series),
    );

    if (result != null) {
      await seriesCubit.updateSeries(result);
      final updated = await seriesCubit.getSeries(_series.id!);
      if (updated != null && mounted) {
        setState(() {
          _series = updated;
        });
      }
    }
  }

  void _deleteSeries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.delete_series.tr()),
        content: Text(LocaleKeys.delete_series_question.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.no.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              LocaleKeys.yes.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await seriesCubit.deleteSeries(_series.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _series.name,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editSeries();
              if (value == 'delete') _deleteSeries();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 20),
                    const SizedBox(width: 8),
                    Text(LocaleKeys.edit_series.tr()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete,
                        size: 20, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      LocaleKeys.delete_series.tr(),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Series header
            if (_series.description != null && _series.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _series.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),

            // Sub-series section
            StreamBuilder<List<BookSeries>>(
              stream: seriesCubit.subSeries,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        LocaleKeys.sub_series.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...snapshot.data!.map((subSeries) => ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(cornerRadius),
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                            ),
                            child: Icon(
                              FontAwesomeIcons.folderOpen,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          title: Text(subSeries.name),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SeriesDetailScreen(series: subSeries),
                              ),
                            );
                          },
                        )),
                    const Divider(),
                  ],
                );
              },
            ),

            // Books section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                LocaleKeys.books_in_series.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            StreamBuilder<List<Book>>(
              stream: seriesCubit.booksInSeries,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final books = snapshot.data!;
                if (books.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        LocaleKeys.no_books_in_series.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _BookInSeriesTile(
                      book: book,
                      seriesId: _series.id!,
                      index: index,
                      totalBooks: books.length,
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _BookInSeriesTile extends StatelessWidget {
  const _BookInSeriesTile({
    required this.book,
    required this.seriesId,
    required this.index,
    required this.totalBooks,
  });

  final Book book;
  final int seriesId;
  final int index;
  final int totalBooks;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: seriesCubit.repository.getSeriesForBook(book.id!),
      builder: (context, snapshot) {
        double? order;
        if (snapshot.hasData) {
          final links = snapshot.data!;
          for (final link in links) {
            if (link.seriesId == seriesId) {
              order = link.orderInSeries;
              break;
            }
          }
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: SizedBox(
            width: 40,
            height: 56,
            child: _buildCover(book, context),
          ),
          title: Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          trailing: order != null
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: Text(
                      order == order.truncateToDouble()
                          ? order.toInt().toString()
                          : order.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                )
              : null,
          onTap: () {
            context.read<CurrentBookCubit>().setBook(book);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BookScreen(heroTag: ''),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCover(Book book, BuildContext context) {
    final coverFile = book.getCoverFile();
    if (coverFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          coverFile,
          fit: BoxFit.cover,
          width: 40,
          height: 56,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
