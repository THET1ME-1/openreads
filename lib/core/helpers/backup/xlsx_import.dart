import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';

import 'package:openreads/core/constants/enums/enums.dart';
import 'package:openreads/core/helpers/backup/backup.dart';
import 'package:openreads/model/reading.dart';
import 'package:openreads/model/reading_time.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:openreads/main.dart';

/// Carries parsed book data + collection names (for series linking)
class _ImportedBook {
  final Book book;
  final List<String> seriesNames;
  _ImportedBook({required this.book, required this.seriesNames});
}

class XLSXImport {
  // Map of field names to possible header variants (lowercase, trimmed)
  static const _headerAliases = <String, List<String>>{
    'title': [
      'заголовок',
      'название',
      'title',
      'book title',
      'name',
    ],
    'author': [
      'авторы',
      'автор',
      'author',
      'authors',
      'book author',
    ],
    'narrators': [
      'рассказчики',
      'рассказчик',
      'чтец',
      'чтецы',
      'narrator',
      'narrators',
    ],
    'isbn': [
      'isbn',
      'isbn13',
      'isbn10',
      'isbn-13',
      'isbn-10',
    ],
    'pages': [
      'всего страниц',
      'страницы',
      'количество страниц',
      'pages',
      'number of pages',
      'num pages',
      'page count',
    ],
    'tags': [
      'используемые теги',
      'теги',
      'тэги',
      'tags',
      'shelves',
      'bookshelves',
    ],
    'collections': [
      'коллекции',
      'коллекция',
      'collections',
      'collection',
    ],
    'status': [
      'положение дел',
      'статус',
      'status',
      'reading status',
      'exclusive shelf',
      'read status',
    ],
    'rating': [
      'звездные рейтинги',
      'рейтинг',
      'оценка',
      'rating',
      'my rating',
      'star rating',
    ],
    'review': [
      'комментарий',
      'отзыв',
      'рецензия',
      'review',
      'my review',
    ],
    'notes': [
      'памятка',
      'заметки',
      'заметка',
      'notes',
      'note',
      'private notes',
    ],
    'reading_period': [
      'период чтения',
      'даты чтения',
      'reading period',
      'date read',
      'date started',
    ],
    'reading_time': [
      'общее время чтения',
      'время чтения',
      'reading time',
    ],
    'date_read': [
      'date read',
      'дата прочтения',
      'finish date',
    ],
    'date_added': [
      'date added',
      'дата добавления',
    ],
    'publication_year': [
      'год публикации',
      'год издания',
      'original publication year',
      'year published',
      'year',
      'publication year',
    ],
    'description': [
      'описание',
      'аннотация',
      'description',
      'summary',
    ],
  };

  /// Resolve header index by field key using alias matching
  /// Tries exact match first, then partial (contains) match
  static int _resolveHeaderIndex(
    List<String> headers,
    String fieldKey,
  ) {
    final aliases = _headerAliases[fieldKey];
    if (aliases == null) return -1;

    // Pass 1: Exact match (lowercase, trimmed, stripped of invisible chars)
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalizeHeader(headers[i]);
      if (aliases.contains(normalized)) return i;
    }

    // Pass 2: Partial match — header contains alias or alias contains header
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalizeHeader(headers[i]);
      if (normalized.isEmpty) continue;
      for (final alias in aliases) {
        if (normalized.contains(alias) || alias.contains(normalized)) {
          return i;
        }
      }
    }

    return -1;
  }

  /// Normalize a header string for matching:
  /// lowercase, trim, remove BOM, zero-width chars, non-breaking spaces
  static String _normalizeHeader(String header) {
    return header
        .toLowerCase()
        .trim()
        .replaceAll('\u00A0', ' ') // non-breaking space → space
        .replaceAll('\uFEFF', '') // BOM
        .replaceAll('\u200B', '') // zero-width space
        .replaceAll('\u200C', '') // zero-width non-joiner
        .replaceAll('\u200D', '') // zero-width joiner
        .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
        .trim();
  }

  /// Resolve all header indices matching a field key (for multi-column fields)
  static List<int> _resolveAllHeaderIndices(
    List<String> headers,
    String fieldKey,
  ) {
    final aliases = _headerAliases[fieldKey];
    if (aliases == null) return [];

    final indices = <int>[];
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalizeHeader(headers[i]);
      bool matched = false;
      if (aliases.contains(normalized)) {
        matched = true;
      } else {
        for (final alias in aliases) {
          if (normalized.contains(alias) || alias.contains(normalized)) {
            matched = true;
            break;
          }
        }
      }
      if (matched) indices.add(i);
    }
    return indices;
  }

  /// Stores diagnostic info from last parse attempt
  static String _lastParseInfo = '';

  static Future importXLSX(BuildContext context) async {
    try {
      final xlsxBytes = await BackupGeneral.pickFileAndGetContent(
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (xlsxBytes == null) return;

      final parsed = await _parseXLSX(context, xlsxBytes);

      if (parsed.isEmpty) {
        BackupGeneral.showInfoSnackbar(
          'Не удалось распознать книги. $_lastParseInfo',
        );
        return;
      }

      final books = parsed.map((e) => e.book).toList();
      final importedBooksIDs = await bookCubit.importAdditionalBooks(books);

      await _linkSeries(importedBooksIDs, parsed);

      if (!context.mounted) return;
      BackupGeneral.showRestoreMissingCoversDialog(
        bookIDs: importedBooksIDs,
        context: context,
      );
    } catch (e) {
      BackupGeneral.showInfoSnackbar(e.toString());
    }
  }

  static Future importXLSXLegacyStorage(BuildContext context) async {
    try {
      final xlsxPath = await BackupGeneral.openFilePicker(
        context,
        allowedExtensions: ['.xlsx', '.xls'],
      );
      if (xlsxPath == null) return;

      final xlsxBytes = await File(xlsxPath).readAsBytes();

      final parsed = await _parseXLSX(context, xlsxBytes);

      if (parsed.isEmpty) {
        BackupGeneral.showInfoSnackbar(
          'Не удалось распознать книги. $_lastParseInfo',
        );
        return;
      }

      final books = parsed.map((e) => e.book).toList();
      final importedBooksIDs = await bookCubit.importAdditionalBooks(books);

      await _linkSeries(importedBooksIDs, parsed);

      if (!context.mounted) return;
      BackupGeneral.showRestoreMissingCoversDialog(
        bookIDs: importedBooksIDs,
        context: context,
      );
    } catch (e) {
      BackupGeneral.showInfoSnackbar(e.toString());
    }
  }

  /// Links imported books to series based on collection names.
  /// Finds or creates each series, then adds a book-series link.
  static Future<void> _linkSeries(
    List<int> bookIds,
    List<_ImportedBook> parsed,
  ) async {
    if (bookIds.length != parsed.length) return;

    // Cache series name → id to avoid duplicate DB lookups
    final seriesCache = <String, int>{};

    for (var i = 0; i < bookIds.length; i++) {
      final bookId = bookIds[i];
      final seriesNames = parsed[i].seriesNames;
      if (seriesNames.isEmpty) continue;

      for (final name in seriesNames) {
        final key = name.toLowerCase();
        int seriesId;

        if (seriesCache.containsKey(key)) {
          seriesId = seriesCache[key]!;
        } else {
          // Try to find existing series with this name
          final existing = await seriesCubit.repository.searchSeries(name);
          final match = existing.where(
            (s) => s.name.toLowerCase() == key,
          );
          if (match.isNotEmpty) {
            seriesId = match.first.id!;
          } else {
            // Create new series
            final now = DateTime.now();
            final newSeries = BookSeries(
              name: name,
              dateCreated: now,
              dateModified: now,
            );
            seriesId = await seriesCubit.repository.insertSeries(newSeries);
          }
          seriesCache[key] = seriesId;
        }

        await seriesCubit.repository.addBookToSeries(
          BookSeriesLink(bookId: bookId, seriesId: seriesId),
        );
      }
    }

    // Refresh series list in cubit
    await seriesCubit.getAllSeries();
  }

  static Future<List<_ImportedBook>> _parseXLSX(
    BuildContext context,
    Uint8List xlsxBytes,
  ) async {
    final books = List<_ImportedBook>.empty(growable: true);

    final excel = Excel.decodeBytes(xlsxBytes);

    if (excel.tables.isEmpty) {
      debugPrint('XLSX Import: No sheets found in file');
      _lastParseInfo = 'Файл пуст или не содержит листов.';
      return [];
    }

    // Use the first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null) {
      debugPrint('XLSX Import: Sheet "$sheetName" is null');
      _lastParseInfo = 'Лист "$sheetName" пуст.';
      return [];
    }

    final rows = sheet.rows;
    debugPrint('XLSX Import: Sheet "$sheetName" has ${rows.length} rows, '
        'maxRows=${sheet.maxRows}, maxCols=${sheet.maxColumns}');

    if (rows.length < 2) {
      debugPrint('XLSX Import: Not enough rows (need at least header + 1)');
      _lastParseInfo =
          'Недостаточно строк: ${rows.length} (нужна шапка + данные).';
      return [];
    }

    // Scan first rows to find the header row (may not be row 0 if there
    // are merged section headers like "информация о книге", etc.)
    int headerRowIndex = -1;
    var headers = <String>[];
    final maxScanRows = rows.length < 10 ? rows.length : 10;

    for (var r = 0; r < maxScanRows; r++) {
      final candidateHeaders = <String>[];
      for (final cell in rows[r]) {
        candidateHeaders.add(cell?.value?.toString() ?? '');
      }
      // Check if this row contains a recognizable title column
      if (_resolveHeaderIndex(candidateHeaders, 'title') != -1) {
        headerRowIndex = r;
        headers = candidateHeaders;
        break;
      }
    }

    debugPrint('XLSX Import: Header row index: $headerRowIndex');
    debugPrint('XLSX Import: Headers found: $headers');

    // Normalize headers for diagnostics
    final normalizedHeaders = headers.map(_normalizeHeader).toList();

    if (headerRowIndex == -1) {
      // Could not find a header row — show info from ALL scanned rows
      final allScannedHeaders = <String>[];
      for (var r = 0; r < maxScanRows; r++) {
        for (final cell in rows[r]) {
          final v = cell?.value?.toString() ?? '';
          if (v.isNotEmpty) allScannedHeaders.add(_normalizeHeader(v));
        }
      }
      debugPrint('XLSX Import: Could not find title column in first '
          '$maxScanRows rows! Scanned: $allScannedHeaders');
      _lastParseInfo = 'Столбец "Заголовок/Title" не найден. '
          'Найдены: [${allScannedHeaders.join(", ")}]';
      return [];
    }

    _lastParseInfo =
        'Строк: ${rows.length}, Шапка в строке ${headerRowIndex + 1}, '
        'Заголовки: [${normalizedHeaders.join(", ")}]';

    // Parse each row after the header row
    for (var i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final imported = _parseBook(context, row, headers);
      if (imported != null) {
        books.add(imported);
      }
    }

    debugPrint('XLSX Import: Parsed ${books.length} books '
        'from ${rows.length - 1} data rows');

    return books;
  }

  static _ImportedBook? _parseBook(
    BuildContext context,
    List<Data?> row,
    List<String> headers,
  ) {
    if (!context.mounted) return null;

    try {
      final title = _getField(row, headers, 'title');
      if (title.isEmpty) return null;

      final author = _getField(row, headers, 'author');
      final narrators = _getFieldOrNull(row, headers, 'narrators');
      final isbn = _getFieldOrNull(row, headers, 'isbn');
      final pagesStr = _getFieldOrNull(row, headers, 'pages');
      final tagsStr = _getFieldOrNull(row, headers, 'tags');
      final collectionsStr = _getFieldOrNull(row, headers, 'collections');
      final statusStr = _getFieldOrNull(row, headers, 'status');
      final ratingStr = _getFieldOrNull(row, headers, 'rating');
      final reviewStr = _getFieldOrNull(row, headers, 'review');
      final noteStr = _getFieldOrNull(row, headers, 'notes');
      final description = _getFieldOrNull(row, headers, 'description');
      final pubYearStr = _getFieldOrNull(row, headers, 'publication_year');

      // Determine book format from tags
      BookFormat bookFormat = BookFormat.paperback;
      if (tagsStr != null &&
          (tagsStr.contains('#Audiobook') ||
              tagsStr.toLowerCase().contains('audiobook'))) {
        bookFormat = BookFormat.audiobook;
      }

      // Parse pages - percentage handling for audiobooks
      int? pages;
      if (pagesStr != null && pagesStr.isNotEmpty) {
        final cleaned =
            pagesStr.replaceAll('%', '').replaceAll(',', '.').trim();
        final parsed = double.tryParse(cleaned);
        if (parsed != null) {
          if (bookFormat != BookFormat.audiobook) {
            pages = parsed.toInt();
          }
        }
      }

      // Parse status
      BookStatus status = _parseStatus(statusStr);

      // Parse rating (1.0-5.0 → stored as int 0-50)
      int? rating = _parseRating(ratingStr);

      // Parse tags (without collections — those become series)
      String? tags = _parseTags(tagsStr);

      // Parse series names from collections column
      final seriesNames = _parseSeriesNames(collectionsStr);

      // Parse reading periods
      List<Reading> readings = _parseReadings(row, headers);

      // Parse publication year
      int? publicationYear;
      if (pubYearStr != null) {
        publicationYear = int.tryParse(pubYearStr.trim());
      }

      final book = Book(
        title: title,
        author: author,
        narrators: narrators,
        description: description,
        status: status,
        rating: rating,
        pages: pages,
        isbn: _cleanISBN(isbn),
        publicationYear: publicationYear,
        tags: tags,
        myReview: reviewStr,
        notes: noteStr,
        bookFormat: bookFormat,
        readings: readings,
        dateAdded: DateTime.now(),
        dateModified: DateTime.now(),
      );

      return _ImportedBook(book: book, seriesNames: seriesNames);
    } catch (e) {
      debugPrint('XLSX Import: Error parsing row: $e');
      return null;
    }
  }

  /// Get cell value by field key (resolved via header aliases)
  static String _getField(
    List<Data?> row,
    List<String> headers,
    String fieldKey,
  ) {
    final index = _resolveHeaderIndex(headers, fieldKey);
    if (index == -1 || index >= row.length) return '';
    return row[index]?.value?.toString() ?? '';
  }

  /// Get cell value or null by field key
  static String? _getFieldOrNull(
    List<Data?> row,
    List<String> headers,
    String fieldKey,
  ) {
    final value = _getField(row, headers, fieldKey);
    return value.isNotEmpty ? value : null;
  }

  static BookStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return BookStatus.read;

    final trimmed = statusStr.trim().toLowerCase();

    // Russian variants
    if (trimmed == 'я все прочитал!' ||
        trimmed == 'я все прочитал' ||
        trimmed == 'прочитано' ||
        trimmed == 'прочитана') {
      return BookStatus.read;
    } else if (trimmed == 'читать' ||
        trimmed == 'хочу прочитать' ||
        trimmed == 'в планах' ||
        trimmed == 'to-read' ||
        trimmed == 'want to read') {
      return BookStatus.forLater;
    } else if (trimmed == 'сдаться' ||
        trimmed == 'брошено' ||
        trimmed == 'не дочитал' ||
        trimmed == 'did not finish' ||
        trimmed == 'dnf') {
      return BookStatus.unfinished;
    } else if (trimmed == 'читаю' ||
        trimmed == 'в процессе' ||
        trimmed == 'currently-reading' ||
        trimmed == 'currently reading') {
      return BookStatus.inProgress;
    }

    // English (Goodreads) variants
    if (trimmed == 'read') return BookStatus.read;
    if (trimmed == 'to-read') return BookStatus.forLater;

    return BookStatus.read;
  }

  static int? _parseRating(String? ratingStr) {
    if (ratingStr == null || ratingStr.isEmpty) return null;

    // Format: "5.0" or "4.5" or "~ 4.5"
    String cleaned = ratingStr.replaceAll('~', '').trim();

    final rating = double.tryParse(cleaned);
    if (rating == null || rating <= 0) return null;

    // Store as int * 10 (e.g. 4.5 → 45)
    return (rating * 10).toInt();
  }

  static String? _parseTags(String? tagsStr) {
    if (tagsStr == null || tagsStr.isEmpty) return null;
    final tagsList = tagsStr
        .split(RegExp(r'[,\s]+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.startsWith('#') ? t.substring(1) : t)
        .where((t) => t.isNotEmpty && t != 'Audiobook')
        .toList();
    return tagsList.isNotEmpty ? tagsList.join('|||||') : null;
  }

  /// Parse collections string into a list of series names.
  /// Input format: comma-separated names, e.g. "Дюна, Хайнский цикл"
  static List<String> _parseSeriesNames(String? collectionsStr) {
    if (collectionsStr == null || collectionsStr.isEmpty) return [];
    return collectionsStr
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  static String? _cleanISBN(String? isbn) {
    if (isbn == null || isbn.isEmpty) return null;
    // Remove non-digit characters except X (for ISBN-10)
    final cleaned = isbn.replaceAll(RegExp(r'[^\dXx]'), '');
    return cleaned.isNotEmpty ? cleaned : null;
  }

  static List<Reading> _parseReadings(
    List<Data?> row,
    List<String> headers,
  ) {
    final readings = <Reading>[];

    // Try to find all reading period / reading time columns
    final readingPeriodIndices =
        _resolveAllHeaderIndices(headers, 'reading_period');
    final readingTimeIndices =
        _resolveAllHeaderIndices(headers, 'reading_time');
    final dateReadIndices = _resolveAllHeaderIndices(headers, 'date_read');

    for (var j = 0; j < readingPeriodIndices.length; j++) {
      final periodIndex = readingPeriodIndices[j];
      final periodValue =
          periodIndex < row.length ? row[periodIndex]?.value?.toString() : null;

      ReadingTime? readingTime;
      if (j < readingTimeIndices.length) {
        final timeIndex = readingTimeIndices[j];
        final timeValue =
            timeIndex < row.length ? row[timeIndex]?.value?.toString() : null;
        readingTime = _parseReadingTime(timeValue);
      }

      if (periodValue != null && periodValue.isNotEmpty) {
        final reading = _parseReadingPeriod(periodValue, readingTime);
        if (reading != null) {
          readings.add(reading);
        }
      } else if (readingTime != null) {
        readings.add(Reading(customReadingTime: readingTime));
      }
    }

    // Fallback: try "Date Read" columns (Goodreads format: "2023/08/26")
    if (readings.isEmpty && dateReadIndices.isNotEmpty) {
      for (final dateIndex in dateReadIndices) {
        final dateValue =
            dateIndex < row.length ? row[dateIndex]?.value?.toString() : null;
        if (dateValue != null && dateValue.isNotEmpty) {
          final date = _parseFlexibleDate(dateValue);
          if (date != null) {
            readings.add(Reading(finishDate: date));
          }
        }
      }
    }

    return readings;
  }

  /// Parse reading period in format "26 авг. 2023 г. ~ 29 авг. 2023 г."
  static Reading? _parseReadingPeriod(String period, ReadingTime? readingTime) {
    // Split by ~
    final parts = period.split('~').map((p) => p.trim()).toList();

    DateTime? startDate;
    DateTime? finishDate;

    if (parts.length == 2) {
      startDate = _parseRussianDate(parts[0]);
      finishDate = _parseRussianDate(parts[1]);
    } else if (parts.length == 1) {
      // Single date - treat as finish date
      finishDate = _parseRussianDate(parts[0]);
    }

    if (startDate == null && finishDate == null && readingTime == null) {
      return null;
    }

    return Reading(
      startDate: startDate,
      finishDate: finishDate,
      customReadingTime: readingTime,
    );
  }

  /// Parse Russian date format "26 авг. 2023 г." or "14 мар. 2023 г."
  static DateTime? _parseRussianDate(String dateStr) {
    final cleaned = dateStr.replaceAll('г.', '').replaceAll('.', '').trim();

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    final day = int.tryParse(parts[0]);
    if (day == null) return null;

    final monthStr = parts[1].toLowerCase();
    final year = int.tryParse(parts[2]);
    if (year == null) return null;

    final monthMap = {
      'янв': 1,
      'января': 1,
      'фев': 2,
      'февр': 2,
      'февраля': 2,
      'мар': 3,
      'марта': 3,
      'апр': 4,
      'апреля': 4,
      'мая': 5,
      'май': 5,
      'июн': 6,
      'июня': 6,
      'июл': 7,
      'июля': 7,
      'авг': 8,
      'августа': 8,
      'сен': 9,
      'сент': 9,
      'сентября': 9,
      'окт': 10,
      'октября': 10,
      'ноя': 11,
      'нояб': 11,
      'ноября': 11,
      'дек': 12,
      'декабря': 12,
    };

    final month = monthMap[monthStr];
    if (month == null) return null;

    return DateTime(year, month, day);
  }

  /// Parse reading time in format "4 часов 22 минут" or "10 часов 57 минут"
  static ReadingTime? _parseReadingTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    int hours = 0;
    int minutes = 0;

    // Match hours
    final hoursMatch = RegExp(r'(\d+)\s*час').firstMatch(timeStr);
    if (hoursMatch != null) {
      hours = int.parse(hoursMatch.group(1)!);
    }

    // Match minutes
    final minutesMatch = RegExp(r'(\d+)\s*мин').firstMatch(timeStr);
    if (minutesMatch != null) {
      minutes = int.parse(minutesMatch.group(1)!);
    }

    if (hours == 0 && minutes == 0) return null;

    return ReadingTime.toMilliSeconds(0, hours, minutes);
  }

  /// Parse flexible date formats: "2023/08/26", "2023-08-26", ISO 8601, etc.
  static DateTime? _parseFlexibleDate(String dateStr) {
    // Try ISO 8601 / standard formats first
    final parsed = DateTime.tryParse(dateStr.trim());
    if (parsed != null) return parsed;

    // Try "YYYY/MM/DD" format (Goodreads)
    final slashMatch =
        RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(dateStr);
    if (slashMatch != null) {
      final y = int.parse(slashMatch.group(1)!);
      final m = int.parse(slashMatch.group(2)!);
      final d = int.parse(slashMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // Try "DD/MM/YYYY" or "DD.MM.YYYY" format
    final dmyMatch =
        RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(dateStr);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // Try Russian date
    return _parseRussianDate(dateStr);
  }
}
