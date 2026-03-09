import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/ui/series_screen/series_detail_screen.dart';
import 'package:openreads/ui/series_screen/widgets/add_edit_series_dialog.dart';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  @override
  void initState() {
    super.initState();
    seriesCubit.getAllSeries();
  }

  void _addSeries() async {
    final result = await showDialog<BookSeries>(
      context: context,
      builder: (context) => const AddEditSeriesDialog(),
    );

    if (result != null) {
      await seriesCubit.addSeries(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.all_series.tr(),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSeries,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<BookSeries>>(
        stream: seriesCubit.allSeries,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final allSeries = snapshot.data!;

            if (allSeries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.layerGroup,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LocaleKeys.no_series.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Separate root series and sub-series
            final rootSeries =
                allSeries.where((s) => s.parentSeriesId == null).toList();
            final subSeriesMap = <int, List<BookSeries>>{};
            for (final s in allSeries) {
              if (s.parentSeriesId != null) {
                subSeriesMap.putIfAbsent(s.parentSeriesId!, () => []).add(s);
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: rootSeries.length,
              itemBuilder: (context, index) {
                final series = rootSeries[index];
                final children = subSeriesMap[series.id] ?? [];

                return _SeriesListTile(
                  series: series,
                  children: children,
                  allSeries: allSeries,
                  subSeriesMap: subSeriesMap,
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class _SeriesListTile extends StatelessWidget {
  const _SeriesListTile({
    required this.series,
    required this.children,
    required this.allSeries,
    required this.subSeriesMap,
    this.depth = 0,
  });

  final BookSeries series;
  final List<BookSeries> children;
  final List<BookSeries> allSeries;
  final Map<int, List<BookSeries>> subSeriesMap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 16.0 + (depth * 24.0),
            right: 16.0,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cornerRadius),
              color:
                  Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
            ),
            child: Icon(
              depth == 0
                  ? FontAwesomeIcons.layerGroup
                  : FontAwesomeIcons.folderOpen,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            series.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: series.description != null && series.description!.isNotEmpty
              ? Text(
                  series.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  ),
                )
              : null,
          trailing: FutureBuilder<int>(
            future: seriesCubit.countBooksInSeries(series.id!),
            builder: (context, snap) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Text(
                  '${snap.data ?? 0}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeriesDetailScreen(series: series),
              ),
            );
          },
        ),
        if (children.isNotEmpty)
          ...children.map((child) {
            final grandChildren = subSeriesMap[child.id] ?? [];
            return _SeriesListTile(
              series: child,
              children: grandChildren,
              allSeries: allSeries,
              subSeriesMap: subSeriesMap,
              depth: depth + 1,
            );
          }),
      ],
    );
  }
}
