import 'package:flutter/material.dart';

class SaleSummary extends StatelessWidget {
  const SaleSummary({required this.total, super.key});

  final num total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Total'), Text('₹${total.toStringAsFixed(2)}')],
        ),
      );
}
