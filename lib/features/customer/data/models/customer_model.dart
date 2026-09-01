import 'dart:convert';
import 'package:suitapps/core/database/tables.dart';

class CustomerModel {
  final int? id;
  final String gstinNo;
  final String customerName;
  final String address;
  final String type;
  final String customerType; // category (Retail/Wholesale)
  final String rateType;
  final String email;
  final String mobile;
  final String phone;
  final String city;
  final String country;
  final String pinNo;
  final String place;
  final String discountPercentage;
  final String creditDays;
  final String imagePath;
  final List<String> additionalImages;
  final String? companyId;
  final String? date;

  CustomerModel({
    this.id,
    required this.gstinNo,
    required this.customerName,
    required this.address,
    required this.type,
    required this.customerType,
    required this.rateType,
    required this.email,
    required this.mobile,
    required this.phone,
    required this.city,
    required this.country,
    required this.pinNo,
    required this.place,
    required this.discountPercentage,
    required this.creditDays,
    required this.imagePath,
    required this.additionalImages,
    this.companyId,
    this.date,
  });

  /// Converts this model into a Map keyed by the exact column names
  /// declared in Tables.CustomerTable, so it lines up with the schema
  /// used on the Android/Java side.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) Tables.KEY_CustomerID: id,
      Tables.COLUMN_NAME_GSTIN: gstinNo,
      Tables.COLUMN_NAME_CUSTOMERNAME: customerName,
      Tables.COLUMN_NAME_ADDRESS: address,
      Tables.COLUMN_NAME_TYPE: type,
      Tables.COLUMN_NAME_CUSTOMERTYPE: customerType,
      Tables.COLUMN_NAME_RATETYPE: rateType,
      Tables.COLUMN_NAME_EMAIL: email,
      Tables.COLUMN_NAME_MOBILE: mobile,
      Tables.COLUMN_NAME_PHONE: phone,
      Tables.COLUMN_NAME_CITY: city,
      Tables.COLUMN_NAME_COUNTRY: country,
      Tables.COLUMN_NAME_PINNO: pinNo,
      Tables.COLUMN_NAME_PLACE: place,
      Tables.COLUMN_NAME_DISCOUNTPERCENTAGE: discountPercentage,
      Tables.COLUMN_NAME_CREDITDAYS: creditDays,
      Tables.COLUMN_NAME_IMAGEPATH: imagePath,
      Tables.COLUMN_NAME_ADDITIONALIMAGES: jsonEncode(additionalImages),
      Tables.COLUMN_NAME_COMPANY_ID: companyId ?? '',
      Tables.COLUMN_NAME_Date: date ?? DateTime.now().toIso8601String(),
    };
  }

  /// Builds a model back from a sqflite row map (column-name keyed).
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    List<String> images = [];
    final raw = map[Tables.COLUMN_NAME_ADDITIONALIMAGES];
    if (raw != null && raw.toString().isNotEmpty) {
      try {
        images = List<String>.from(jsonDecode(raw as String) as List);
      } catch (_) {
        images = [];
      }
    }

    return CustomerModel(
      id: map[Tables.KEY_CustomerID] as int?,
      gstinNo: map[Tables.COLUMN_NAME_GSTIN]?.toString() ?? '',
      customerName: map[Tables.COLUMN_NAME_CUSTOMERNAME]?.toString() ?? '',
      address: map[Tables.COLUMN_NAME_ADDRESS]?.toString() ?? '',
      type: map[Tables.COLUMN_NAME_TYPE]?.toString() ?? '',
      customerType: map[Tables.COLUMN_NAME_CUSTOMERTYPE]?.toString() ?? '',
      rateType: map[Tables.COLUMN_NAME_RATETYPE]?.toString() ?? '',
      email: map[Tables.COLUMN_NAME_EMAIL]?.toString() ?? '',
      mobile: map[Tables.COLUMN_NAME_MOBILE]?.toString() ?? '',
      phone: map[Tables.COLUMN_NAME_PHONE]?.toString() ?? '',
      city: map[Tables.COLUMN_NAME_CITY]?.toString() ?? '',
      country: map[Tables.COLUMN_NAME_COUNTRY]?.toString() ?? '',
      pinNo: map[Tables.COLUMN_NAME_PINNO]?.toString() ?? '',
      place: map[Tables.COLUMN_NAME_PLACE]?.toString() ?? '',
      discountPercentage:
          map[Tables.COLUMN_NAME_DISCOUNTPERCENTAGE]?.toString() ?? '',
      creditDays: map[Tables.COLUMN_NAME_CREDITDAYS]?.toString() ?? '',
      imagePath: map[Tables.COLUMN_NAME_IMAGEPATH]?.toString() ?? '',
      additionalImages: images,
      companyId: map[Tables.COLUMN_NAME_COMPANY_ID]?.toString(),
      date: map[Tables.COLUMN_NAME_Date]?.toString(),
    );
  }

  CustomerModel copyWith({int? id}) {
    return CustomerModel(
      id: id ?? this.id,
      gstinNo: gstinNo,
      customerName: customerName,
      address: address,
      type: type,
      customerType: customerType,
      rateType: rateType,
      email: email,
      mobile: mobile,
      phone: phone,
      city: city,
      country: country,
      pinNo: pinNo,
      place: place,
      discountPercentage: discountPercentage,
      creditDays: creditDays,
      imagePath: imagePath,
      additionalImages: additionalImages,
      companyId: companyId,
      date: date,
    );
  }
}
