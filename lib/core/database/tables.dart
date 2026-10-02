/// Database table and column names used by the customer feature.
class Tables {
  Tables._();

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

  // Distributor relationship
  static const String COLUMN_NAME_IF_DISTRIBUTOR = 'IfDistributor';
  static const String COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID =
      'DistribtrWiseCustId';

  // NEW (schema v3) — offline-sync tracking, same role as
  // sale_orders.suitAppsId/isSynced/serverOrderId in DatabaseHelper.
  //   SuitAppsId          -> stable local id generated at insert time,
  //                          independent of the autoincrement CustomerId.
  //                          Sent to the server as SuitAppsId and used to
  //                          correlate this row with the server's account
  //                          after a successful sync (mirrors
  //                          Accout.Customer_SuitAppsId server-side).
  //   IsSynced            -> 0 until /InsertUpdateCustomer succeeds, then 1.
  //   ServerAccountCode   -> the server's Accout.AccountCode, filled in
  //                          once IsSynced = 1 (needed for any future
  //                          UPDATE sync of this same customer).
  static const String COLUMN_NAME_SUIT_APPS_ID = 'SuitAppsId';
  static const String COLUMN_NAME_IS_SYNCED = 'IsSynced';
  static const String COLUMN_NAME_SERVER_ACCOUNT_CODE = 'ServerAccountCode';
}