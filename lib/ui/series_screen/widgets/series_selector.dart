import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:openreads/ui/series_screen/widgets/add_edit_series_dialog.dart';

/// A widget for selecting series memberships when adding/editing a book.
class SeriesSelector extends StatefulWidget {
  const SeriesSelector({
    super.key,
    required this.seriesLinks,
    required this.onChanged,
  });

  /// Current list of series links for the book being edited
  final List<BookSeriesLink> seriesLinks;
  final ValueChanged<List<BookSeriesLink>> onChanged;

  @override
  State<SeriesSelector> createState() => _SeriesSelectorState();
}

class _SeriesSelectorState extends State<SeriesSelector> {
  List<BookSeries> _allSeries = [];
  final Map<int, TextEditingController> _orderControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  void _loadSeries() async {
    final series = await seriesCubit.repository.getAllSeries();
    if (mounted) {
      setState(() {
        _allSeries = series;
      });
    }
  }

  @override
  void dispose() {
    for (final ctrl in _orderControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _getSeriesName(int seriesId) {
    for (final s in _allSeries) {
      if (s.id == seriesId) return s.name;
    }
    return '?';
  }

  void _addToSeries() async {
    final existingSeriesIds = widget.seriesLinks.map((l) => l.seriesId).toSet();
    final availableSeries =
        _allSeries.where((s) => !existingSeriesIds.contains(s.id)).toList();

    final result = await showDialog<_SeriesPickResult>(
      context: context,
      builder: (context) => _SeriesPickerDialog(
        availableSeries: availableSeries,
      ),
    );

    if (result != null) {
      if (result.createNew) {
        // Create a new series first
        final newSeriesDialog = await showDialog<BookSeries>(
          context: context,
          builder: (context) => const AddEditSeriesDialog(),
        );
        if (newSeriesDialog != null) {
          final newId = await seriesCubit.addSeries(newSeriesDialog);
          _loadSeries();
          final newLinks = List<BookSeriesLink>.from(widget.seriesLinks)
            ..add(BookSeriesLink(bookId: 0, seriesId: newId));
          widget.onChanged(newLinks);
        }
      } else if (result.seriesId != null) {
        final newLinks = List<BookSeriesLink>.from(widget.seriesLinks)
          ..add(BookSeriesLink(bookId: 0, seriesId: result.seriesId!));
        widget.onChanged(newLinks);
      }
    }
  }

  void _removeFromSeries(int seriesId) {
    final newLinks =
        widget.seriesLinks.where((l) => l.seriesId != seriesId).toList();
    _orderControllers.remove(seriesId)?.dispose();
    widget.onChanged(newLinks);
  }

  void _updateOrder(int seriesId, String orderStr) {
    final order = double.tryParse(orderStr);
    final newLinks = widget.seriesLinks.map((l) {
      if (l.seriesId == seriesId) {
        return l.copyWith(orderInSeries: order ?? 0);
      }
      return l;
    }).toList();
    widget.onChanged(newLinks);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.seriesLinks.isNotEmpty) ...[
          ...widget.seriesLinks.map((link) {
            final ctrl = _orderControllers.putIfAbsent(link.seriesId, () {
              final c = TextEditingController();
              if (link.orderInSeries != null) {
                c.text =
                    link.orderInSeries == link.orderInSeries!.truncateToDouble()
                        ? link.orderInSeries!.toInt().toString()
                        : link.orderInSeries.toString();
              }
              return c;
            });

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cornerRadius),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.layerGroup,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getSeriesName(link.seriesId),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    height: 36,
                    child: TextField(
                      controller: ctrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$')),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '#',
                        hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(80),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) => _updateOrder(link.seriesId, val),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _removeFromSeries(link.seriesId),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          child: FilledButton.tonal(
            onPressed: _addToSeries,
            style: ButtonStyle(
              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cornerRadius),
              )),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FontAwesomeIcons.layerGroup, size: 14),
                const SizedBox(width: 10),
                Text(LocaleKeys.add_to_series.tr()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesPickResult {
  final int? seriesId;
  final bool createNew;
  _SeriesPickResult({this.seriesId, this.createNew = false});
}

class _SeriesPickerDialog extends StatelessWidget {
  const _SeriesPickerDialog({required this.availableSeries});

  final List<BookSeries> availableSeries;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LocaleKeys.select_series.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Create new button
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                LocaleKeys.create_new_series.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(
                  context,
                  _SeriesPickResult(createNew: true),
                );
              },
            ),
            if (availableSeries.isNotEmpty) const Divider(),
            ...availableSeries.map((s) {
              return ListTile(
                leading: const Icon(FontAwesomeIcons.layerGroup, size: 18),
                title: Text(s.name),
                subtitle: s.description != null && s.description!.isNotEmpty
                    ? Text(
                        s.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(
                    context,
                    _SeriesPickResult(seriesId: s.id),
                  );
                },
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr()),
        ),
      ],
    );
  }
}
