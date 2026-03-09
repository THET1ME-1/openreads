class BookSeries {
  int? id;
  String name;
  String? description;
  int? parentSeriesId;
  int sortOrder;
  DateTime dateCreated;
  DateTime dateModified;

  BookSeries({
    this.id,
    required this.name,
    this.description,
    this.parentSeriesId,
    this.sortOrder = 0,
    required this.dateCreated,
    required this.dateModified,
  });

  factory BookSeries.empty() {
    final now = DateTime.now();
    return BookSeries(
      name: '',
      dateCreated: now,
      dateModified: now,
    );
  }

  factory BookSeries.fromJSON(Map<String, dynamic> json) {
    return BookSeries(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      parentSeriesId: json['parent_series_id'],
      sortOrder: json['sort_order'] ?? 0,
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : DateTime.now(),
      dateModified: json['date_modified'] != null
          ? DateTime.parse(json['date_modified'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'parent_series_id': parentSeriesId,
      'sort_order': sortOrder,
      'date_created': dateCreated.toIso8601String(),
      'date_modified': dateModified.toIso8601String(),
    };
  }

  BookSeries copyWith({
    int? id,
    String? name,
    String? description,
    int? parentSeriesId,
    int? sortOrder,
    DateTime? dateCreated,
    DateTime? dateModified,
  }) {
    return BookSeries(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentSeriesId: parentSeriesId ?? this.parentSeriesId,
      sortOrder: sortOrder ?? this.sortOrder,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }

  BookSeries copyWithNullParent() {
    return BookSeries(
      id: id,
      name: name,
      description: description,
      parentSeriesId: null,
      sortOrder: sortOrder,
      dateCreated: dateCreated,
      dateModified: dateModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSeries && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BookSeries(id: $id, name: $name)';
}
