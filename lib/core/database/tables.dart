/// Mirrors the structure of Tables.java from the native Android app —
/// one static "table" class per entity, holding TABLE_NAME and
/// COLUMN_NAME_* constants. Keeping these in one place means the
/// column names used by CustomerModel / CustomerService always match
/// what's referenced elsewhere (queries, migrations, etc.).
class Tables {
  Tables._(); // not meant to be instantiated

  //region Customer
  static const String CUSTOMER_TABLE_NAME = 'CustomerTable';

  static const String KEY_CustomerID = 'CustomerId';
  static const String COLUMN_NAME_GSTIN = 'GstinNo';
  static const String COLUMN_NAME_CUSTOMERNAME = 'CustomerName';
  static const String COLUMN_NAME_ADDRESS = 'Address';
  static const String COLUMN_NAME_TYPE = 'Type';
  static const String COLUMN_NAME_CUSTOMERTYPE = 'CustomerType';
  static const String COLUMN_NAME_RATETYPE = 'RateType';
  static const String COLUMN_NAME_EMAIL = 'Email';
  static const String COLUMN_NAME_MOBILE = 'Mobile';
  static const String COLUMN_NAME_PHONE = 'Phone';
  static const String COLUMN_NAME_CITY = 'City';
  static const String COLUMN_NAME_COUNTRY = 'Country';
  static const String COLUMN_NAME_PINNO = 'PinNo';
  static const String COLUMN_NAME_PLACE = 'Place';
  static const String COLUMN_NAME_DISCOUNTPERCENTAGE = 'DiscountPercentage';
  static const String COLUMN_NAME_CREDITDAYS = 'CreditDays';
  static const String COLUMN_NAME_IMAGEPATH = 'ImagePath';
  static const String COLUMN_NAME_ADDITIONALIMAGES = 'AdditionalImages';
  static const String COLUMN_NAME_COMPANY_ID = 'CompanyId';
  static const String COLUMN_NAME_Date = 'Date';
  //endregion
}