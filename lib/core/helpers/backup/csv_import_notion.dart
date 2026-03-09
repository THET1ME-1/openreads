import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import 'package:openreads/core/constants/enums/enums.dart';
import 'package:openreads/core/helpers/backup/backup.dart';
import 'package:openreads/model/reading.dart';
import 'package:openreads/model/reading_time.dart';
import 'package:openreads/model/book.dart';
import 'package:openreads/model/book_series.dart';
import 'package:openreads/model/book_series_link.dart';
import 'package:openreads/main.dart';

/// Carries parsed book data + series name (for series linking)
class _ImportedBook {
  final Book book;
  final String? seriesName;
  final int? orderInSeries;
  final String? coverUrl;

  _ImportedBook({
    required this.book,
    this.seriesName,
    this.orderInSeries,
    this.coverUrl,
  });
}

class CSVImportNotion {
  static importCSVLegacyStorage(BuildContext context) async {
    try {
      final csvPath = await BackupGeneral.openFilePicker(
        context,
        allowedExtensions: ['.csv'],
      );
      if (csvPath == null) return;

      final csvBytes = await File(csvPath).readAsBytes();

      // ignore: use_build_context_synchronously
      await _importFromBytes(context, csvBytes);
    } catch (e) {
      BackupGeneral.showInfoSnackbar(e.toString());
    }
  }

  static Future importCSV(BuildContext context) async {
    try {
      final csvBytes = await BackupGeneral.pickCSVFileAndGetContent();
      if (csvBytes == null) return;

      // ignore: use_build_context_synchronously
      await _importFromBytes(context, csvBytes);
    } catch (e) {
      BackupGeneral.showInfoSnackbar(e.toString());
    }
  }

  static Future<void> _importFromBytes(
    BuildContext context,
    Uint8List csvBytes,
  ) async {
    final parsed = await _parseCSV(context, csvBytes);
    if (parsed.isEmpty) {
      BackupGeneral.showInfoSnackbar('Не удалось распознать книги в файле');
      return;
    }

    // Load existing books for duplicate check
    await bookCubit.getAllBooks(getTags: false, getAuthors: false);
    final allExistingBooks = await bookCubit.allBooks.first;

    // Build key → Book map so we can find IDs of existing books
    final existingKeyToBook = <String, Book>{};
    for (final b in allExistingBooks) {
      existingKeyToBook[
          '${b.title.trim().toLowerCase()}|||${b.author.trim().toLowerCase()}'] = b;
    }

    // Separate new books from duplicates.
    // Duplicates that have series info still need series re-linking
    // (previous broken imports may have left them without series links).
    final toImport = <_ImportedBook>[];
    // Two parallel lists: DB id of existing book + its parsed series info
    final duplicateExistingIds = <int>[];
    final duplicateExistingParsed = <_ImportedBook>[];

    for (final p in parsed) {
      final key = '${p.book.title.trim().toLowerCase()}|||'
          '${p.book.author.trim().toLowerCase()}';
      final existing = existingKeyToBook[key];
      if (existing == null) {
        toImport.add(p);
      } else if (p.seriesName != null && existing.id != null) {
        // Already exists — queue series re-link with the real DB id
        duplicateExistingIds.add(existing.id!);
        duplicateExistingParsed.add(p);
      }
    }

    final skippedCount = parsed.length - toImport.length;
    if (toImport.isEmpty && duplicateExistingIds.isEmpty) {
      BackupGeneral.showInfoSnackbar(
        'Все ${parsed.length} книг уже есть в библиотеке',
      );
      return;
    }
    if (skippedCount > 0) {
      BackupGeneral.showInfoSnackbar(
        'Уже в библиотеке (пропущено): $skippedCount',
      );
    }

    List<int> importedBooksIDs = [];
    if (toImport.isNotEmpty) {
      final books = toImport.map((e) => e.book).toList();
      importedBooksIDs = await bookCubit.importAdditionalBooks(books);

      // Explicit refresh so book lists are updated
      await bookCubit.getAllBooks();
      await bookCubit.getAllBooksByStatus();
    }

    // Link series for newly imported books
    await _linkSeries(importedBooksIDs, toImport);

    // Re-link series for existing duplicate books that may be missing links
    if (duplicateExistingIds.isNotEmpty) {
      await _linkSeries(duplicateExistingIds, duplicateExistingParsed);
    }

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    if (importedBooksIDs.isNotEmpty) {
      BackupGeneral.showRestoreMissingCoversDialog(
        bookIDs: importedBooksIDs,
        context: context,
      );
    }

    // Download covers from CSV URLs in background (non-blocking)
    _downloadCovers(importedBooksIDs, toImport);
  }

  static Future<List<_ImportedBook>> _parseCSV(
    BuildContext context,
    Uint8List csvBytes,
  ) async {
    final books = List<_ImportedBook>.empty(growable: true);

    var csvString = utf8.decode(csvBytes);

    // Strip BOM (Byte Order Mark) - Notion exports UTF-8 with BOM
    if (csvString.startsWith('\uFEFF')) {
      csvString = csvString.substring(1);
    }

    // Detect EOL: Notion on Windows exports \r\n, on Mac/Linux \n.
    // The wrong check (csv[0].length < 3) fails for \n files because the whole
    // CSV becomes one giant row with hundreds of "columns" from all commas.
    // The correct check is whether we got more than just a header row.
    var csv = const CsvToListConverter().convert(csvString, eol: '\r\n');
    if (csv.length <= 1) {
      csv = const CsvToListConverter().convert(csvString, eol: '\n');
    }
    // Last resort: auto-detect
    if (csv.length <= 1) {
      csv = const CsvToListConverter().convert(csvString);
    }

    if (csv.isEmpty) {
      debugPrint('Notion CSV Import: CSV is empty after parsing');
      return books;
    }

    final headers = csv[0].map((e) => e.toString().trim()).toList();
    debugPrint('Notion CSV Import: Found ${csv.length} rows, '
        '${headers.length} columns');
    debugPrint('Notion CSV Import: Headers: $headers');

    for (var i = 1; i < csv.length; i++) {
      if (csv[i].isEmpty) continue;

      // Skip rows that are shorter than headers (broken data)
      if (csv[i].length < 2) continue;

      final imported = _parseBook(i, csv, headers);
      if (imported != null) {
        books.add(imported);
      } else {
        debugPrint('Notion CSV Import: Skipped row $i '
            '(title: "${csv[i].isNotEmpty ? csv[i][0] : "empty"}")');
      }
    }

    return books;
  }

  static _ImportedBook? _parseBook(
    int i,
    List<List<dynamic>> csv,
    List<String> headers,
  ) {
    try {
      // Try both possible header names for title
      var title = _getField(i, csv, headers, 'Book name');
      if (title.isEmpty) {
        title = _getField(i, csv, headers, 'Name');
      }
      if (title.isEmpty) {
        title = _getField(i, csv, headers, 'Название');
      }
      // Fallback: try first column if headers don't match
      if (title.isEmpty && csv[i].isNotEmpty) {
        title = csv[i][0].toString().trim();
      }
      if (title.isEmpty) return null;

      final author = _cleanNotionLink(_getField(i, csv, headers, 'Автор'));
      final description = _getFieldOrNull(i, csv, headers, 'Aннотация') ??
          _getFieldOrNull(i, csv, headers, 'Аннотация');
      final coverField = _getFieldOrNull(i, csv, headers, 'Обложка');
      final categoryField = _getFieldOrNull(i, csv, headers, 'Категория');
      final readingDates = _getFieldOrNull(i, csv, headers, 'Даты прочтения');
      final readingDates1 =
          _getFieldOrNull(i, csv, headers, 'Даты прочтения (1)');
      final durationStr = _getFieldOrNull(i, csv, headers, 'Длительность');
      final narratorsField = _getFieldOrNull(i, csv, headers, 'Озвучивает');
      final formatField = _getFieldOrNull(i, csv, headers, 'Формат');
      final dateCreatedField =
          _getFieldOrNull(i, csv, headers, 'Дата создания');
      final readYearField = _getFieldOrNull(i, csv, headers, 'Год прочтения');

      // Series and order: use exact-only aliases to prevent 'Цикл' from
      // partially matching 'Номер книги в цикле'.
      final seriesField = _getFieldOrNullByAliases(
        i,
        csv,
        headers,
        ['Цикл', 'Серия', 'Серия/Цикл', 'Цикл/Серия'],
      );
      final orderField = _getFieldOrNullByAliases(
        i,
        csv,
        headers,
        [
          'Номер книги в цикле',
          'Номер в серии',
          'Порядок в цикле',
          'Порядок в серии',
        ],
      );

      // Tags / status: try several possible column names (exact match only)
      final tagsField = _getFieldOrNullByAliases(
        i,
        csv,
        headers,
        ['Метки', 'Теги', 'Tags', 'Статус', 'Status', 'Метка', 'Тег'],
      );

      final ratingField = _getFieldOrNull(i, csv, headers, 'Средняя оценка');

      // Parse rating from ⛊⛉ symbols (out of 10 → stored as 0-50)
      final rating = _parseRating(ratingField);

      // Parse categories as tags (strip Notion links)
      final tags = _parseTags(categoryField);

      // Pre-compute whether the book has any reading data at the raw field level.
      // Used for status override before parsing reading dates.
      final readYear = readYearField != null
          ? int.tryParse(_cleanNotionLink(readYearField))
          : null;
      final hasReadingDates =
          (readingDates != null && readingDates.isNotEmpty) ||
              (readingDates1 != null && readingDates1.isNotEmpty);

      final rawStatus = _parseStatus(tagsField);

      // Status override rules (in priority order):
      // 1. If tagged forLater but has reading dates/year → was actually read
      // 2. If explicitly tagged read/inProgress/unfinished → trust that tag
      // 3. Otherwise keep rawStatus (including forLater default)
      final BookStatus status;
      if (rawStatus == BookStatus.forLater &&
          (readYear != null || hasReadingDates)) {
        status = BookStatus.read;
      } else if (rawStatus != BookStatus.forLater &&
          rawStatus != BookStatus.unfinished &&
          readYear != null) {
        // e.g. inProgress but has a year → finished
        status = BookStatus.read;
      } else {
        status = rawStatus;
      }

      // Parse reading dates only for statuses that can have them.
      // Books with status forLater (Прочитать) must not have reading dates.
      final readings = status == BookStatus.forLater
          ? <Reading>[]
          : _parseReadingDates(readingDates, readingDates1);

      // Fallback: if no dates but Год прочтения is set, create reading for that year
      if (readings.isEmpty &&
          readYear != null &&
          status != BookStatus.forLater) {
        final yearDate = DateTime(readYear, 12, 31);
        readings.add(Reading(startDate: yearDate, finishDate: yearDate));
      }

      // Parse duration as custom reading time
      final customReadingTime = _parseDuration(durationStr);

      // Attach reading time to first reading if exists, or create one.
      // Skip for forLater books.
      if (customReadingTime != null && status != BookStatus.forLater) {
        if (readings.isNotEmpty) {
          readings[0] = readings[0].copyWith(
            customReadingTime: customReadingTime,
          );
        } else {
          readings.add(Reading(customReadingTime: customReadingTime));
        }
      }

      // Parse narrators (strip Notion links)
      final narrators = _parseNarrators(narratorsField);

      // Parse book format
      final bookFormat = _parseBookFormat(formatField);

      // Parse series
      final seriesName = _cleanNotionLink(seriesField ?? '');
      final isNoSeries = seriesName.isEmpty ||
          seriesName == 'Нет цикла' ||
          seriesName == 'нет цикла';

      // Parse order in series (strip Notion relation links before parsing)
      int? orderInSeries;
      if (orderField != null && orderField.isNotEmpty) {
        orderInSeries = int.tryParse(_cleanNotionLink(orderField).trim());
      }

      // Parse date added
      DateTime dateAdded = DateTime.now();
      if (dateCreatedField != null && dateCreatedField.isNotEmpty) {
        final parsed = _parseNotionDate(dateCreatedField);
        if (parsed != null) dateAdded = parsed;
      }

      // Determine cover URL: "Обложка" field may contain URL(s)
      // User said "Ссылка это обложка" - cover is from the link column
      String? coverUrl = _extractCoverUrl(coverField);
      // If cover field has no valid URL, try "Ссылка на книгу"
      // Actually user said "Ссылка это обложка" meaning Обложка column IS the cover
      // So we use the Обложка field primarily

      final book = Book(
        title: title,
        author: author.isNotEmpty ? author : 'Неизвестный автор',
        description: description,
        status: status,
        rating: rating,
        narrators: narrators,
        tags: tags,
        bookFormat: bookFormat,
        readings: readings,
        dateAdded: dateAdded,
        dateModified: DateTime.now(),
      );

      return _ImportedBook(
        book: book,
        seriesName: isNoSeries ? null : seriesName,
        orderInSeries: orderInSeries,
        coverUrl: coverUrl,
      );
    } catch (e) {
      debugPrint('Notion CSV Import: Error parsing row $i: $e');
      return null;
    }
  }

  /// Get field value by header name (case-insensitive, trimmed)
  static String _getField(
    int i,
    List<List<dynamic>> csv,
    List<String> headers,
    String headerName,
  ) {
    final index = _findHeaderIndex(headers, headerName);
    if (index == -1 || index >= csv[i].length) return '';
    return csv[i][index].toString().trim();
  }

  /// Find header index by name (case-insensitive, ignores leading/trailing spaces)
  static int _findHeaderIndex(List<String> headers, String headerName) {
    final normalized = headerName.trim().toLowerCase();
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].toLowerCase().trim() == normalized) return i;
    }
    // Partial match: only check if the HEADER contains the search term,
    // NOT the reverse — prevents short headers like 'Цикл' from matching
    // long search terms like 'Номер книги в цикле'.
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].toLowerCase().trim().contains(normalized)) {
        return i;
      }
    }
    return -1;
  }

  /// Find header index using a list of aliases, EXACT match only.
  /// Use this for fields whose names could be substrings of other columns
  /// (e.g. 'Цикл' is a substring of 'Номер книги в цикле').
  static int _findHeaderByAliases(
    List<String> headers,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final normalized = alias.trim().toLowerCase();
      for (var i = 0; i < headers.length; i++) {
        if (headers[i].toLowerCase().trim() == normalized) return i;
      }
    }
    return -1;
  }

  /// Get field value by one of several alias header names (exact match only)
  static String _getFieldByAliases(
    int i,
    List<List<dynamic>> csv,
    List<String> headers,
    List<String> aliases,
  ) {
    final index = _findHeaderByAliases(headers, aliases);
    if (index == -1 || index >= csv[i].length) return '';
    return csv[i][index].toString().trim();
  }

  /// Get nullable field value by one of several alias header names (exact match only)
  static String? _getFieldOrNullByAliases(
    int i,
    List<List<dynamic>> csv,
    List<String> headers,
    List<String> aliases,
  ) {
    final value = _getFieldByAliases(i, csv, headers, aliases);
    return value.isNotEmpty ? value : null;
  }

  /// Get field value or null by header name
  static String? _getFieldOrNull(
    int i,
    List<List<dynamic>> csv,
    List<String> headers,
    String headerName,
  ) {
    final value = _getField(i, csv, headers, headerName);
    return value.isNotEmpty ? value : null;
  }

  /// Remove Notion link from text: "Герберт Уэллс (https://www.notion.so/...)" → "Герберт Уэллс"
  /// Also handles multiple comma-separated entries with links
  static String _cleanNotionLink(String text) {
    if (text.isEmpty) return text;

    // Remove all (https://www.notion.so/...) patterns
    final cleaned = text.replaceAll(
      RegExp(r'\s*\(https?://(?:www\.)?notion\.so/[^)]*\)'),
      '',
    );

    return cleaned.trim();
  }

  /// Parse book status from the "Метки" (tags) field
  static BookStatus _parseStatus(String? tagsField) {
    if (tagsField == null || tagsField.isEmpty) return BookStatus.forLater;

    final lower = tagsField.toLowerCase();

    if (tagsField.contains('✅') || lower.contains('прочитал')) {
      return BookStatus.read;
    } else if (tagsField.contains('❌') || lower.contains('не зашло')) {
      return BookStatus.unfinished;
    } else if (tagsField.contains('⛔') || lower.contains('отложено')) {
      return BookStatus.forLater;
    } else if (tagsField.contains('❗') || lower.contains('прочитать')) {
      return BookStatus.forLater;
    } else if (lower.contains('читаю') || lower.contains('в процессе')) {
      return BookStatus.inProgress;
    }

    return BookStatus.forLater;
  }

  /// Parse rating from ⛊⛉ symbols
  /// ⛊ = filled (Unicode 26CA), ⛉ = empty (Unicode 26C9)
  /// Count of ⛊ out of 10 → multiply by 5 to get 0-50 scale
  static int? _parseRating(String? ratingField) {
    if (ratingField == null || ratingField.isEmpty) return null;

    final filledCount = ratingField.codeUnits.where((c) => c == 0x26CA).length;

    if (filledCount == 0) return null;

    // Rating scale: 10 filled stars = max (50 in internal scale)
    // Each filled star = 5 points
    return filledCount * 5;
  }

  /// Parse categories into tags (strip Notion links, join with |||||)
  static String? _parseTags(String? categoryField) {
    if (categoryField == null || categoryField.isEmpty) return null;

    // Split by comma, clean each
    final parts = categoryField
        .split(',')
        .map((part) {
          return _cleanNotionLink(part.trim());
        })
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return null;

    return parts.join('|||||');
  }

  /// Parse reading dates from "Даты прочтения" columns
  /// Formats:
  /// - "October 2, 2023 → October 5, 2023" (range with arrow)
  /// - "July 17, 2023" (single date)
  /// - "May 13, 2023" (single date — could be start or finish)
  static List<Reading> _parseReadingDates(
    String? dates1,
    String? dates2,
  ) {
    final readings = <Reading>[];

    if (dates1 == null || dates1.isEmpty) return readings;

    // Check if it contains a range (→)
    if (dates1.contains('→')) {
      final parts = dates1.split('→').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        final start = _parseEnglishDate(parts[0]);
        final finish = _parseEnglishDate(parts[1]);
        readings.add(Reading(startDate: start, finishDate: finish));
      }
    } else {
      // Single date — book was read in one day, use as both start and finish
      final date = _parseEnglishDate(dates1);
      if (date != null) {
        readings.add(Reading(startDate: date, finishDate: date));
      }
    }

    // If there's a second reading dates column (dates2)
    // and we didn't already parse it from dates1
    if (dates2 != null && dates2.isNotEmpty) {
      if (dates2.contains('→')) {
        final parts = dates2.split('→').map((p) => p.trim()).toList();
        if (parts.length == 2) {
          final start = _parseEnglishDate(parts[0]);
          final finish = _parseEnglishDate(parts[1]);
          // If first reading had only start/finish, merge
          if (readings.isNotEmpty &&
              readings.last.startDate != null &&
              readings.last.finishDate == null) {
            readings[readings.length - 1] = readings.last.copyWith(
              finishDate: finish,
            );
          } else {
            readings.add(Reading(startDate: start, finishDate: finish));
          }
        }
      } else {
        final date = _parseEnglishDate(dates2);
        if (date != null) {
          // If first reading has start but no finish, add as finish
          if (readings.isNotEmpty &&
              readings.last.startDate != null &&
              readings.last.finishDate == null) {
            readings[readings.length - 1] = readings.last.copyWith(
              finishDate: date,
            );
          }
        }
      }
    }

    return readings;
  }

  /// Parse English date format: "October 2, 2023" or "July 17, 2023"
  /// Also handles Notion format: "May 16, 2023 8:48 PM"
  static DateTime? _parseEnglishDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    final months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    final cleaned = dateStr.trim();

    // Try pattern: "Month Day, Year [Time]"
    final match = RegExp(
      r'(\w+)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (match != null) {
      final monthStr = match.group(1)!.toLowerCase();
      final day = int.tryParse(match.group(2)!);
      final year = int.tryParse(match.group(3)!);

      if (day != null && year != null && months.containsKey(monthStr)) {
        return DateTime(year, months[monthStr]!, day);
      }
    }

    // Fallback: try DateTime.parse
    return DateTime.tryParse(cleaned);
  }

  /// Parse Notion date (used for "Дата создания"):
  /// "July 18, 2023 11:24 AM" or "September 20, 2024 10:58 PM"
  static DateTime? _parseNotionDate(String dateStr) {
    return _parseEnglishDate(dateStr);
  }

  /// Parse duration string "HH:MM:SS" into ReadingTime
  static ReadingTime? _parseDuration(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) return null;

    final parts = durationStr.split(':');
    if (parts.length != 3) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);

    if (hours == null || minutes == null || seconds == null) return null;
    if (hours == 0 && minutes == 0 && seconds == 0) return null;

    // Total minutes (round seconds)
    final totalMinutes = minutes + (seconds >= 30 ? 1 : 0);

    return ReadingTime.toMilliSeconds(0, hours, totalMinutes);
  }

  /// Parse narrators field (strip Notion links, handle multiple narrators)
  static String? _parseNarrators(String? narratorsField) {
    if (narratorsField == null || narratorsField.isEmpty) return null;

    // Split by comma, clean Notion links from each
    final narrators = narratorsField
        .split(',')
        .map((part) {
          return _cleanNotionLink(part.trim());
        })
        .where((part) => part.isNotEmpty)
        .toList();

    if (narrators.isEmpty) return null;

    return narrators.join(', ');
  }

  /// Parse book format from "Формат" field
  static BookFormat _parseBookFormat(String? formatField) {
    if (formatField == null || formatField.isEmpty) return BookFormat.paperback;

    final lower = formatField.toLowerCase();

    if (lower.contains('аудио')) {
      return BookFormat.audiobook;
    } else if (lower.contains('электрон') || lower.contains('ebook')) {
      return BookFormat.ebook;
    } else if (lower.contains('твёрд') || lower.contains('hardcover')) {
      return BookFormat.hardcover;
    } else if (lower.contains('мягк') || lower.contains('paperback')) {
      return BookFormat.paperback;
    }

    return BookFormat.paperback;
  }

  /// Extract a valid image URL from the cover field.
  /// Notion exports file attachments as "filename.jpg (https://...)" so the
  /// URL is inside parentheses — a simple startsWith check would always miss it.
  /// We use a regex to find the first http(s) URL anywhere in the string.
  static String? _extractCoverUrl(String? coverField) {
    if (coverField == null || coverField.isEmpty) return null;

    // Match first http(s) URL, stopping at whitespace or closing paren
    final match = RegExp(r'https?://[^\s\)]+').firstMatch(coverField);
    return match?.group(0);
  }

  /// Download covers from URLs and save them for imported books.
  /// Uses repository.updateBook directly to avoid triggering a full stream
  /// refresh for every single book; does one final refresh at the end.
  static Future<void> _downloadCovers(
    List<int> bookIds,
    List<_ImportedBook> parsed,
  ) async {
    if (bookIds.length != parsed.length) return;

    bool anyUpdated = false;

    for (var i = 0; i < bookIds.length; i++) {
      final bookId = bookIds[i];
      final coverUrl = parsed[i].coverUrl;

      if (coverUrl == null || coverUrl.isEmpty) continue;

      try {
        final response = await http.get(
          Uri.parse(coverUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 && response.bodyBytes.length > 100) {
          final file = File('${appDocumentsDirectory.path}/$bookId.jpg');
          await file.writeAsBytes(response.bodyBytes);

          // Update hasCover in DB directly — avoids a full stream refresh per book
          final book = await bookCubit.getBook(bookId);
          if (book != null && !book.hasCover) {
            await bookCubit.repository
                .updateBook(book.copyWith(hasCover: true));
            anyUpdated = true;
          }
        }
      } catch (e) {
        debugPrint('Notion CSV Import: Failed to download cover for '
            'book $bookId from $coverUrl: $e');
      }
    }

    // Single refresh after all covers are processed
    if (anyUpdated) {
      await bookCubit.getAllBooks();
      await bookCubit.getAllBooksByStatus();
    }
  }

  /// Link imported books to series
  static Future<void> _linkSeries(
    List<int> bookIds,
    List<_ImportedBook> parsed,
  ) async {
    if (bookIds.length != parsed.length) return;

    final seriesCache = <String, int>{};

    for (var i = 0; i < bookIds.length; i++) {
      final bookId = bookIds[i];
      final seriesName = parsed[i].seriesName;
      if (seriesName == null || seriesName.isEmpty) continue;

      final key = seriesName.toLowerCase();
      int seriesId;

      if (seriesCache.containsKey(key)) {
        seriesId = seriesCache[key]!;
      } else {
        // Try to find existing series with this name
        final existing = await seriesCubit.repository.searchSeries(seriesName);
        final match = existing.where(
          (s) => s.name.toLowerCase() == key,
        );
        if (match.isNotEmpty) {
          seriesId = match.first.id!;
        } else {
          // Create new series
          final now = DateTime.now();
          final newSeries = BookSeries(
            name: seriesName,
            dateCreated: now,
            dateModified: now,
          );
          seriesId = await seriesCubit.repository.insertSeries(newSeries);
        }
        seriesCache[key] = seriesId;
      }

      await seriesCubit.repository.addBookToSeries(
        BookSeriesLink(
          bookId: bookId,
          seriesId: seriesId,
          orderInSeries: parsed[i].orderInSeries?.toDouble(),
        ),
      );
    }

    // Refresh series list
    await seriesCubit.getAllSeries();
  }
}
