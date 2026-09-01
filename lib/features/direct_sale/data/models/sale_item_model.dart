import 'package:flutter/material.dart';

class ProductData {
  final int itemId;
  final String itemName;
  final int categoryId;
  final String categoryName; // filled in after joining with categories table
  final double mrp;
  final double dp;
  final double sp;
  final double wp;
  final double ccp;
  final double stock;
  final double totalStock;
  final double netStock;
  final double taxPercent;
  final String hsn;
  final int companyId;
  final int unitId;
  final String unitName;

  const ProductData({
    required this.itemId,
    required this.itemName,
    required this.categoryId,
    this.categoryName = '',
    required this.mrp,
    required this.dp,
    required this.sp,
    required this.wp,
    this.ccp = 0,
    required this.stock,
    required this.totalStock,
    required this.netStock,
    required this.taxPercent,
    required this.hsn,
    required this.companyId,
    this.unitId = 0,
    this.unitName = '',
  });

  // ---- Convenience getters used by the UI (keeps old widget code working) ----
  String get id => itemId.toString();
  String get productId => itemId.toString();
  String get name => itemName;
  String get displayName => itemName;
  String get subtitle => hsn;
  String get category => categoryName;

  Map<String, double> get rates => {
        'MRP': mrp,
        'CCP': ccp,
        'DP': dp,
        'WP': wp,
        'SP': sp,
      };

  IconData get icon => _iconForCategory(categoryName);
  Color get iconColor => _colorForCategory(categoryName);

  /// From API JSON response (field names match the SQL procedure output)
  factory ProductData.fromJson(Map<String, dynamic> json) {
    return ProductData(
      itemId: json['ItemID'] as int,
      itemName: (json['ItemName'] ?? '') as String,
      categoryId: (json['CategoryID'] ?? 0) as int,
      mrp: _toDouble(json['MRP']),
      dp: _toDouble(json['DP']),
      sp: _toDouble(json['SP']),
      wp: _toDouble(json['WP']),
      ccp: _toDouble(json['CCP']),
      stock: _toDouble(json['Stock']),
      totalStock: _toDouble(json['TotalStock']),
      netStock: _toDouble(json['NetStock']),
      taxPercent: _toDouble(json['Tax']),
      hsn: (json['HSNCode'] ?? '') as String,
      companyId: (json['CompanyId'] ?? 0) as int,
      unitId: (json['UnitID'] ?? 0) as int,
      unitName: (json['UnitName'] ?? '') as String,
    );
  }

  /// From/To local sqlite rows
  factory ProductData.fromMap(Map<String, dynamic> map) {
    return ProductData(
      itemId: map['itemId'] as int,
      itemName: map['itemName'] as String,
      categoryId: map['categoryId'] as int,
      categoryName: (map['categoryName'] ?? '') as String,
      mrp: map['mrp'] as double,
      dp: map['dp'] as double,
      sp: map['sp'] as double,
      wp: map['wp'] as double,
      ccp: (map['ccp'] as double?) ?? 0,
      stock: map['stock'] as double,
      totalStock: map['totalStock'] as double,
      netStock: map['netStock'] as double,
      taxPercent: map['taxPercent'] as double,
      hsn: map['hsn'] as String,
      companyId: map['companyId'] as int,
      unitId: (map['UnitID'] as int?) ?? 0,
      unitName: (map['UnitName'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'categoryId': categoryId,
      'mrp': mrp,
      'dp': dp,
      'sp': sp,
      'wp': wp,
      'ccp': ccp,
      'stock': stock,
      'totalStock': totalStock,
      'netStock': netStock,
      'taxPercent': taxPercent,
      'hsn': hsn,
      'companyId': companyId,
      'UnitID': unitId,
      'UnitName': unitName,
    };
  }

  ProductData copyWith({String? categoryName}) {
    return ProductData(
      itemId: itemId,
      itemName: itemName,
      categoryId: categoryId,
      categoryName: categoryName ?? this.categoryName,
      mrp: mrp,
      dp: dp,
      sp: sp,
      wp: wp,
      ccp: ccp,
      stock: stock,
      totalStock: totalStock,
      netStock: netStock,
      taxPercent: taxPercent,
      hsn: hsn,
      companyId: companyId,
      unitId: unitId,
      unitName: unitName,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

IconData _iconForCategory(String categoryName) {
  final c = categoryName.toLowerCase();
  if (c.contains('beverage')) return Icons.local_drink;
  if (c.contains('snack')) return Icons.fastfood;
  if (c.contains('grocery')) return Icons.shopping_basket;
  if (c.contains('dairy')) return Icons.icecream;
  if (c.contains('personal')) return Icons.spa;
  return Icons.shopping_bag;
}

Color _colorForCategory(String categoryName) {
  final c = categoryName.toLowerCase();
  if (c.contains('beverage')) return Colors.blue;
  if (c.contains('snack')) return Colors.orange;
  if (c.contains('grocery')) return Colors.green;
  if (c.contains('dairy')) return Colors.purple;
  if (c.contains('personal')) return Colors.pink;
  return Colors.teal;
}
