import 'package:suitapps/features/direct_sale/data/datasources/billing_api_datasource.dart';
import 'package:suitapps/features/direct_sale/data/datasources/item_sync_datasource.dart';

/// Coordinates direct-sale data sources for presentation code.
class DirectSaleRepository {
  DirectSaleRepository({BillingApiService? billingApi, ItemSyncService? itemSync})
      : billingApi = billingApi ?? BillingApiService(),
        itemSync = itemSync ?? ItemSyncService();

  final BillingApiService billingApi;
  final ItemSyncService itemSync;
}
