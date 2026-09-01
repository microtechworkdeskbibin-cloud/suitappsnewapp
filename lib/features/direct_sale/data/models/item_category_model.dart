class ItemCategory {
  final int categoryId;
  final String categoryName;
  final String? categoryCode;
  final int? categoryType;
  final int? categoryParent;

  const ItemCategory({
    required this.categoryId,
    required this.categoryName,
    this.categoryCode,
    this.categoryType,
    this.categoryParent,
  });

  /// From API JSON response (field names match the SQL procedure output)
  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    return ItemCategory(
      categoryId: json['CategoryID'] as int,
      categoryName: (json['CatgoryName'] ?? '') as String, // NOTE: matches DB column spelling
      categoryCode: json['CategoryCode'] as String?,
      categoryType: json['CategoryType'] as int?,
      categoryParent: json['CategoryParent'] as int?,
    );
  }

  /// From/To local sqlite rows
  factory ItemCategory.fromMap(Map<String, dynamic> map) {
    return ItemCategory(
      categoryId: map['categoryId'] as int,
      categoryName: map['categoryName'] as String,
      categoryCode: map['categoryCode'] as String?,
      categoryType: map['categoryType'] as int?,
      categoryParent: map['categoryParent'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryCode': categoryCode,
      'categoryType': categoryType,
      'categoryParent': categoryParent,
    };
  }
}