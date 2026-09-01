import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suitapps/features/direct_sale/presentation/theme/direct_sale_theme.dart';
import 'package:suitapps/features/direct_sale/presentation/pages/direct_sale_customer_page.dart'; // adjust path if different
import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';

/// Lists every locally-saved bill (see DirectSaleOfCustomer._saveBill /
/// DatabaseHelper.insertBillWithItems) so the user can review or edit one.
/// Mirrors the structure of ReceiptListPage â€” same filter-chips-then-cards
/// layout â€” but reads from the `bills` table instead of `receipts`, and
/// uses the DirectSale module's own theme (Dstheme.dart) rather than
/// GoogleFonts.tenorSans, since this belongs to that module.
class DirectSaleListPage extends StatefulWidget {
  const DirectSaleListPage({super.key});

  @override
  State<DirectSaleListPage> createState() => _DirectSaleListPageState();
}

class _DirectSaleListPageState extends State<DirectSaleListPage> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Cash', 'UPI', 'Credit', 'Other'];

  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = await DatabaseHelper.instance.getAllBills();
      if (!mounted) return;
      setState(() {
        _bills = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load bills: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredBills {
    if (_selectedFilter == 'All') return _bills;
    return _bills.where((b) {
      final type = (b['paymentType'] ?? '').toString();
      return type == _selectedFilter;
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  IconData _paymentIcon(String? type) {
    switch (type) {
      case 'Cash':
        return Icons.payments_outlined;
      case 'UPI':
        return Icons.qr_code_2_outlined;
      case 'Credit':
        return Icons.receipt_long_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  /// Pulls this bill's line items and rebuilds a `customer` map good enough
  /// for DirectSaleOfCustomer's edit mode to work from â€” reconstructed
  /// from the stored headerPayloadJson rather than a live customer lookup,
  /// since the original customer record may have since changed.
  ///
  /// CAVEAT: headerPayloadJson stores InvoiceType (B2B/B2C) but not the
  /// actual GSTIN, so a real GST number can't be restored here â€” only the
  /// B2B/B2C flag (see DirectSaleOfCustomer._isB2BCustomer, which reads an
  /// 'InvoiceType' key during edit instead of requiring a GST number). If
  /// you need the GSTIN itself to survive into edit mode, store it in
  /// headerPayload alongside InvoiceType at save time.
  Future<void> _openForEdit(Map<String, dynamic> bill) async {
    final suitAppsId = bill['suitAppsId'] as String?;
    if (suitAppsId == null) return;

    Map<String, dynamic> headerPayload = {};
    final headerJson = bill['headerPayloadJson'] as String?;
    if (headerJson != null && headerJson.isNotEmpty) {
      try {
        headerPayload = jsonDecode(headerJson) as Map<String, dynamic>;
      } catch (_) {
        // Fall back to the flat bill columns below if this ever fails.
      }
    }

    final items = await DatabaseHelper.instance.getItemsForBill(suitAppsId);

    final customer = <String, dynamic>{
      'AccountName': headerPayload['CustomerName'] ?? bill['customerName'] ?? '',
      'AccountCode': (headerPayload['CustomerID'] ?? bill['customerId'])?.toString() ?? '',
      'Address': headerPayload['CumAddress'] ?? '',
      'Contact': headerPayload['CumContact'] ?? '',
      'Place': headerPayload['CumPlace'] ?? '',
      // Read by DirectSaleOfCustomer._isB2BCustomer during edit mode only.
      'InvoiceType': headerPayload['InvoiceType'] ?? '',
    };

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectSaleOfCustomer(
          customer: customer,
          billToEdit: bill,
          billItemsToEdit: items,
        ),
      ),
    );
    _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.background,
      appBar: AppBar(
        backgroundColor: DashboardConstants.brandBlue,
        elevation: 0,
        title: Text('Bill List', style: DsFonts.pageTitle.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(child: _buildBillList()),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: DsSpacing.sm),
            Text(_error!, style: DsFonts.smallText, textAlign: TextAlign.center),
            const SizedBox(height: DsSpacing.md),
            ElevatedButton.icon(
              onPressed: _loadBills,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: DsColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      color: DsColors.cardBg,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.sm),
          itemBuilder: (context, index) {
            final filter = _filterOptions[index];
            final isSelected = _selectedFilter == filter;
            return ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = filter),
              labelStyle: DsFonts.smallText.copyWith(
                color: isSelected ? Colors.white : DsColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: DashboardConstants.brandBlue,
              backgroundColor: DsColors.background,
              side: BorderSide(color: isSelected ? DashboardConstants.brandBlue : DsColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.chip)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBillList() {
    final bills = _filteredBills;

    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 56, color: DsColors.textSecondary),
            const SizedBox(height: DsSpacing.md),
            Text('No bills found', style: DsFonts.bodyBold),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      color: DashboardConstants.brandBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(DsSpacing.md),
        itemCount: bills.length,
        itemBuilder: (context, index) => _buildBillCard(bills[index]),
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final billNo = bill['billNo']?.toString() ?? '';
    final billSeries = bill['billSeries']?.toString() ?? '';
    final billLabel = billSeries.isEmpty ? billNo : '$billSeries-$billNo';
    final customerName = (bill['customerName'] ?? 'N/A').toString();
    final paymentType = bill['paymentType']?.toString();
    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
    final isSynced = bill['isSynced'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.card)),
      child: InkWell(
        onTap: () => _openForEdit(bill),
        borderRadius: BorderRadius.circular(DsRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DashboardConstants.brandBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_paymentIcon(paymentType), color: DashboardConstants.brandBlue, size: 22),
                        ),
                        const SizedBox(width: DsSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: DsFonts.bodyBold.copyWith(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text('Bill #$billLabel', style: DsFonts.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'â‚¹${totalAmount.toStringAsFixed(2)}',
                        style: DsFonts.bodyBold.copyWith(color: Colors.green[700], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isSynced ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSynced ? 'Synced' : 'Pending',
                          style: DsFonts.caption.copyWith(
                            color: isSynced ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: DsSpacing.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: DsColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_formatDate(bill['billDate']?.toString()), style: DsFonts.caption),
                  const SizedBox(width: DsSpacing.md),
                  Icon(Icons.payment, size: 13, color: DsColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(paymentType ?? 'N/A', style: DsFonts.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
