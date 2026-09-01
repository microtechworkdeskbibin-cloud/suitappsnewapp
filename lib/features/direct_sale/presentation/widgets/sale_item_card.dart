import 'package:flutter/material.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';

class SaleItemCard extends StatelessWidget {
  const SaleItemCard({required this.item, required this.onTap, super.key});

  final ProductData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(item.itemName), subtitle: Text(item.categoryName), onTap: onTap),
      );
}
