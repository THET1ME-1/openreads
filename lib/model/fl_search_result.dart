import 'dart:convert';

import 'package:flutter/foundation.dart';

List<FLSearchResultWork> flSearchResultFromJson(String str) {
  final decoded = json.decode(str);

  List items;
  if (decoded is List) {
    items = decoded;
  } else if (decoded is Map) {
    // When the API wraps results: {"matches": [...], "Count": N}
    items = decoded['matches'] as List? ?? [];
  } else {
    debugPrint('FantLab: unexpected response type: ${decoded.runtimeType}');
    return [];
  }

  return items
      .map((x) => FLSearchResultWork.fromJson(x as Map<String, dynamic>))
      .toList();
}

class FLSearchResultWork {
  FLSearchResultWork({
    required this.workId,
    this.name,
    this.rusname,
    this.fullname,
    this.altname,
    this.allAutorName,
    this.allAutorRusname,
    this.autorId,
    this.year,
    this.workTypeId,
    this.workTypeName,
    this.workTypeNameShow,
    this.midmark,
    this.markcount,
    this.picEditionId,
    this.picEditionIdAuto,
  });

  final int workId;
  final String? name;
  final String? rusname;
  final String? fullname;
  final String? altname;
  final String? allAutorName;
  final String? allAutorRusname;
  final int? autorId;
  final int? year;
  final int? workTypeId;
  final String? workTypeName;
  final String? workTypeNameShow;
  final double? midmark;
  final int? markcount;
  final int? picEditionId;
  final int? picEditionIdAuto;

  factory FLSearchResultWork.fromJson(Map<String, dynamic> json) {
    double? midmark;
    if (json['midmark'] != null) {
      if (json['midmark'] is List && (json['midmark'] as List).isNotEmpty) {
        midmark = (json['midmark'][0] as num).toDouble();
      } else if (json['midmark'] is num) {
        midmark = (json['midmark'] as num).toDouble();
      }
    }

    return FLSearchResultWork(
      workId: json['work_id'] as int,
      name: json['name'] as String?,
      rusname: json['rusname'] as String?,
      fullname: json['fullname'] as String?,
      altname: json['altname'] as String?,
      allAutorName: json['all_autor_name'] as String?,
      allAutorRusname: json['all_autor_rusname'] as String?,
      autorId: json['autor_id'] as int?,
      year: json['year'] as int?,
      workTypeId: json['work_type_id'] as int?,
      workTypeName: json['name_eng'] as String?,
      workTypeNameShow: json['name_show_im'] as String?,
      midmark: midmark,
      markcount: json['markcount'] as int?,
      picEditionId: json['pic_edition_id'] as int?,
      picEditionIdAuto: json['pic_edition_id_auto'] as int?,
    );
  }

  /// Whether this is a "book-like" work type (novel, novella, collection, cycle, etc.)
  /// Filters out articles, reviews, poems, essays, etc.
  bool get isBookType {
    // work_type_id mapping from FantLab:
    // 1=роман, 4=цикл, 10=сборник, 11=антология, 12=статья,
    // 13=эпопея, 22=рассказ, 23=монография, 24=повесть,
    // 43=графический роман, 45=рассказ(short), 5=стих, 52=рецензия,
    // 53=научно-поп, 54=артбук, 7=другое
    // Allow: novel, cycle, collection, anthology, epic, novella,
    //        short story, graphic novel, monograph, popular science, artbook, other
    const excludedTypes = {
      12, // статья / article
      52, // рецензия / review
      5, // стихотворение / poem
    };
    if (workTypeId != null && excludedTypes.contains(workTypeId)) return false;
    return true;
  }

  /// Display title: prefer Russian name, fall back to original
  String get displayTitle {
    if (rusname != null && rusname!.isNotEmpty) return rusname!;
    if (name != null && name!.isNotEmpty) return name!;
    return fullname ?? '';
  }

  /// Display author: prefer Russian name, fall back to original
  String get displayAuthor {
    if (allAutorRusname != null && allAutorRusname!.isNotEmpty) {
      return allAutorRusname!;
    }
    return allAutorName ?? '';
  }

  /// Get the best available cover edition id
  int? get coverEditionId {
    if (picEditionId != null && picEditionId! > 0) return picEditionId;
    if (picEditionIdAuto != null && picEditionIdAuto! > 0) {
      return picEditionIdAuto;
    }
    return null;
  }
}
