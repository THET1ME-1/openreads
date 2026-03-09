import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:openreads/model/fl_search_result.dart';
import 'package:openreads/model/fl_work_result.dart';

class FantLabService {
  static const baseUrl = 'https://api.fantlab.ru';
  static const siteUrl = 'https://fantlab.ru';

  /// Search works by query
  Future<List<FLSearchResultWork>> searchWorks({
    required String query,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/search-works?q=${Uri.encodeComponent(query)}&page=$page&onlymatches=1',
    );

    final response = await get(uri);

    if (response.statusCode == 200) {
      // Use bodyBytes with UTF-8 decode to handle Cyrillic properly
      final body = utf8.decode(response.bodyBytes);
      debugPrint('FantLab search response length: ${body.length}');
      return flSearchResultFromJson(body);
    }
    debugPrint('FantLab search error: status ${response.statusCode}');
    return [];
  }

  /// Get detailed work information
  Future<FLWorkResult?> getWork(int workId) async {
    final uri = Uri.parse('$baseUrl/work/$workId');

    final response = await get(uri);

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      return flWorkResultFromJson(body);
    }
    return null;
  }

  /// Get extended work information (includes editions, translations, etc.)
  Future<FLWorkResult?> getWorkExtended(int workId) async {
    final uri = Uri.parse('$baseUrl/work/$workId/extended');

    final response = await get(uri);

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      return flWorkResultFromJson(body);
    }
    return null;
  }

  /// Get cover image bytes for an edition
  Future<Uint8List?> getEditionCover(int editionId) async {
    try {
      final response = await get(
        Uri.parse('$siteUrl/images/editions/big/$editionId'),
      );

      // If the response is too small, probably no cover available
      if (response.bodyBytes.length < 500) return null;

      return response.bodyBytes;
    } catch (e) {
      return null;
    }
  }

  /// Get cover image bytes for a work (via its image path)
  Future<Uint8List?> getWorkCover(String imagePath) async {
    try {
      final response = await get(
        Uri.parse('$siteUrl$imagePath'),
      );

      if (response.bodyBytes.length < 500) return null;

      return response.bodyBytes;
    } catch (e) {
      return null;
    }
  }

  /// Build cover URL for a search result
  static String? getCoverUrl(FLSearchResultWork work) {
    final editionId = work.coverEditionId;
    if (editionId != null && editionId > 0) {
      return '$siteUrl/images/editions/big/$editionId';
    }
    return null;
  }

  /// Build cover URL for a work result
  static String? getWorkCoverUrl(FLWorkResult work) {
    if (work.image != null && work.image!.isNotEmpty) {
      return '$siteUrl${work.image}';
    }
    return null;
  }
}
