import 'dart:convert';

FLWorkResult flWorkResultFromJson(String str) =>
    FLWorkResult.fromJson(json.decode(str) as Map<String, dynamic>);

class FLWorkResult {
  FLWorkResult({
    required this.workId,
    this.workName,
    this.workNameOrig,
    this.workDescription,
    this.workYear,
    this.workType,
    this.workTypeName,
    this.image,
    this.imagePreview,
    this.authors,
    this.rating,
    this.voters,
    this.editionsInfo,
  });

  final int workId;
  final String? workName;
  final String? workNameOrig;
  final String? workDescription;
  final int? workYear;
  final String? workType;
  final String? workTypeName;
  final String? image;
  final String? imagePreview;
  final List<FLWorkAuthor>? authors;
  final String? rating;
  final int? voters;
  final FLEditionsInfo? editionsInfo;

  factory FLWorkResult.fromJson(Map<String, dynamic> json) {
    List<FLWorkAuthor>? authors;
    if (json['authors'] != null && json['authors'] is List) {
      authors = (json['authors'] as List)
          .map((a) => FLWorkAuthor.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    String? rating;
    int? voters;
    if (json['rating'] is Map<String, dynamic>) {
      rating = json['rating']['rating']?.toString();
      voters = json['rating']['voters'] is int
          ? json['rating']['voters'] as int
          : int.tryParse(json['rating']['voters']?.toString() ?? '');
    }

    FLEditionsInfo? editionsInfo;
    if (json['editions_info'] is Map<String, dynamic>) {
      editionsInfo = FLEditionsInfo.fromJson(
          json['editions_info'] as Map<String, dynamic>);
    }

    return FLWorkResult(
      workId: json['work_id'] as int,
      workName: json['work_name'] as String?,
      workNameOrig: json['work_name_orig'] as String?,
      workDescription: json['work_description'] as String?,
      workYear: json['work_year'] as int?,
      workType: json['work_type'] as String?,
      workTypeName: json['work_type_name'] as String?,
      image: json['image'] as String?,
      imagePreview: json['image_preview'] as String?,
      authors: authors,
      rating: rating,
      voters: voters,
      editionsInfo: editionsInfo,
    );
  }

  /// Display title: prefer Russian name, fallback to original
  String get displayTitle {
    if (workName != null && workName!.isNotEmpty) return workName!;
    return workNameOrig ?? '';
  }

  /// Display author string from authors list
  String get displayAuthor {
    if (authors == null || authors!.isEmpty) return '';
    return authors!.map((a) => a.name ?? a.nameOrig ?? '').join(', ');
  }
}

class FLWorkAuthor {
  final String? type;
  final int? id;
  final String? name;
  final String? nameOrig;
  final int? isOpened;

  FLWorkAuthor({
    this.type,
    this.id,
    this.name,
    this.nameOrig,
    this.isOpened,
  });

  factory FLWorkAuthor.fromJson(Map<String, dynamic> json) {
    return FLWorkAuthor(
      type: json['type'] as String?,
      id: json['id'] as int?,
      name: json['name'] as String?,
      nameOrig: json['name_orig'] as String?,
      isOpened: json['is_opened'] as int?,
    );
  }
}

class FLEditionsInfo {
  final int? editionCount;
  final int? langCount;

  FLEditionsInfo({
    this.editionCount,
    this.langCount,
  });

  factory FLEditionsInfo.fromJson(Map<String, dynamic> json) {
    return FLEditionsInfo(
      editionCount: json['count'] as int?,
      langCount: json['langs_count'] as int?,
    );
  }
}
