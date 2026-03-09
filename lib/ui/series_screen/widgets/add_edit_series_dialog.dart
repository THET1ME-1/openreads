import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:openreads/core/themes/app_theme.dart';
import 'package:openreads/generated/locale_keys.g.dart';
import 'package:openreads/main.dart';
import 'package:openreads/model/book_series.dart';

class AddEditSeriesDialog extends StatefulWidget {
  const AddEditSeriesDialog({
    super.key,
    this.series,
    this.parentSeriesId,
  });

  final BookSeries? series;
  final int? parentSeriesId;

  @override
  State<AddEditSeriesDialog> createState() => _AddEditSeriesDialogState();
}

class _AddEditSeriesDialogState extends State<AddEditSeriesDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedParentId;
  List<BookSeries> _allSeries = [];

  bool get _isEditing => widget.series != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.series!.name;
      _descCtrl.text = widget.series!.description ?? '';
      _selectedParentId = widget.series!.parentSeriesId;
    } else {
      _selectedParentId = widget.parentSeriesId;
    }

    _loadSeries();
  }

  void _loadSeries() async {
    final series = await seriesCubit.repository.getAllSeries();
    setState(() {
      // Don't allow selecting itself or its own children as parent
      _allSeries = series.where((s) {
        if (_isEditing) {
          return s.id != widget.series!.id;
        }
        return true;
      }).toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;

    final now = DateTime.now();

    if (_isEditing) {
      final updated = widget.series!.copyWith(
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dateModified: now,
      );
      // Handle parent change
      BookSeries result;
      if (_selectedParentId != widget.series!.parentSeriesId) {
        if (_selectedParentId == null) {
          result = updated.copyWithNullParent();
        } else {
          result = updated.copyWith(parentSeriesId: _selectedParentId);
        }
      } else {
        result = updated;
      }
      Navigator.pop(context, result);
    } else {
      final newSeries = BookSeries(
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        parentSeriesId: _selectedParentId,
        dateCreated: now,
        dateModified: now,
      );
      Navigator.pop(context, newSeries);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? LocaleKeys.edit_series.tr() : LocaleKeys.add_series.tr(),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: LocaleKeys.enter_series_name.tr(),
                labelText: LocaleKeys.series_name.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: LocaleKeys.enter_series_description.tr(),
                labelText: LocaleKeys.series_description.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Parent series selector
            DropdownButtonFormField<int?>(
              value: _selectedParentId,
              decoration: InputDecoration(
                labelText: LocaleKeys.parent_series.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(120),
                    ),
                  ),
                ),
                ..._allSeries.map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedParentId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr()),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(LocaleKeys.save.tr()),
        ),
      ],
    );
  }
}
