import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/logic/cubit/current_book_cubit.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:openreads/ui/book_screen/book_screen.dart';
import 'package:openreads/ui/series_screen/series_detail_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays series membership info on the book detail screen.
/// Shows series chips, order number, and prev/next navigation.
class BookSeriesInfo extends StatefulWidget {
  const BookSeriesInfo({super.key, required this.bookId});

  final int bookId;

  @override
  State<BookSeriesInfo> createState() => _BookSeriesInfoState();
}

class _BookSeriesInfoState extends State<BookSeriesInfo> {
  List<_SeriesWithLink> _seriesWithLinks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  @override
  void didUpdateWidget(BookSeriesInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _loadSeriesInfo();
    }
  }

  void _loadSeriesInfo() async {
    final links = await seriesCubit.getSeriesForBookDirect(widget.bookId);
    final seriesWithLinks = <_SeriesWithLink>[];

    for (final link in links) {
      final series = await seriesCubit.repository.getSeries(link.seriesId);
      if (series != null) {
        seriesWithLinks.add(_SeriesWithLink(series: series, link: link));
      }
    }

    if (mounted) {
      setState(() {
        _seriesWithLinks = seriesWithLinks;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox();
    if (_seriesWithLinks.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.series.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._seriesWithLinks.map((sw) => _buildSeriesEntry(context, sw)),
        ],
      ),
    );
  }

  Widget _buildSeriesEntry(BuildContext context, _SeriesWithLink sw) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(cornerRadius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(series: sw.series),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cornerRadius),
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.layerGroup,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sw.series.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (sw.link.orderInSeries != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Text(
                        '#${sw.link.orderInSeries == sw.link.orderInSeries!.truncateToDouble() ? sw.link.orderInSeries!.toInt() : sw.link.orderInSeries}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              // Prev / Next navigation
              FutureBuilder<List<Book>>(
                future: seriesCubit.getBooksInSeriesDirect(sw.series.id!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.length <= 1) {
                    return const SizedBox();
                  }

                  final books = snapshot.data!;
                  final currentIndex =
                      books.indexWhere((b) => b.id == widget.bookId);
                  if (currentIndex == -1) return const SizedBox();

                  final prevBook =
                      currentIndex > 0 ? books[currentIndex - 1] : null;
                  final nextBook = currentIndex < books.length - 1
                      ? books[currentIndex + 1]
                      : null;

                  if (prevBook == null && nextBook == null) {
                    return const SizedBox();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (prevBook != null)
                          Expanded(
                            child: _NavButton(
                              icon: Icons.arrow_back_ios,
                              label: prevBook.title,
                              isPrev: true,
                              onTap: () => _navigateToBook(context, prevBook),
                            ),
                          ),
                        if (prevBook != null && nextBook != null)
                          const SizedBox(width: 8),
                        if (nextBook != null)
                          Expanded(
                            child: _NavButton(
                              icon: Icons.arrow_forward_ios,
                              label: nextBook.title,
                              isPrev: false,
                              onTap: () => _navigateToBook(context, nextBook),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToBook(BuildContext context, Book book) {
    context.read<CurrentBookCubit>().setBook(book);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BookScreen(heroTag: ''),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isPrev,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isPrev;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPrev)
              Icon(icon,
                  size: 12, color: Theme.of(context).colorScheme.primary),
            if (isPrev) const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (!isPrev) const SizedBox(width: 4),
            if (!isPrev)
              Icon(icon,
                  size: 12, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SeriesWithLink {
  final BookSeries series;
  final BookSeriesLink link;

  _SeriesWithLink({required this.series, required this.link});
}
