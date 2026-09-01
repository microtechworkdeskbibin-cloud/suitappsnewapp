import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:suitapps/features/direct_sale/presentation/pages/direct_sale_customer_page.dart';
import 'package:suitapps/features/receipt/presentation/pages/customer_receipt_page.dart';
import 'package:suitapps/core/config/api_config.dart';

// TODO: update this import path to wherever your Direct Sale page actually lives.


// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DESIGN SYSTEM
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AppColors {
  static const Color primary = Color.fromARGB(255, 35, 0, 196);
  static const Color secondary = Color(0xFF6F7FDB);

  static const Color background = Color(0xFFF5F7FB);
  static const Color cardBg = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
}

class AppFonts {
  static TextStyle pageTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static TextStyle cardValue = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  static TextStyle cardTitle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.cardBg,
  );

  static TextStyle inputText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle smallText = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double card = 16;
  static const double button = 12;
  static const double textField = 12;
  static const double dialog = 16;
  static const double bottomSheet = 20;
  static const double badge = 16;
}

class AppShadows {
  static BoxShadow card = BoxShadow(
    color: AppColors.textPrimary.withOpacity(0.05),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
}

class AppIcons {
  static const double cardIcon = 16;
  static const double listTile = 20;
  static const double appBar = 24;
  static const double fab = 24;
}

class AppLayout {
  static const double screenPadding = 16;
  static const double cardGap = 8;
  static const double sectionGap = 16;
  static const double pageGap = 24;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DATA MODELS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class MenuItemData {
  final IconData icon;
  final String title;
  final Color color;
  // Optional tap handler. If null, the tile is a no-op placeholder.
  final VoidCallback? onTap;

  const MenuItemData(this.icon, this.title, this.color, {this.onTap});
}

class DetailItemData {
  final String label;
  final String value;
  final Color color;

  const DetailItemData(this.label, this.value, this.color);
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CUSTOMER INFO PAGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class CustomerInfoPage extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerInfoPage({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerInfoPage> createState() => _CustomerInfoPageState();
}

class _CustomerInfoPageState extends State<CustomerInfoPage> {
  late Future<_CustomerDashboardData> _dashboardFuture;
  DateTimeRange? _historyRange;

  // Tracks which history cards (by key) are currently expanded.
  final Set<String> _expandedHistoryCards = {};

  @override
  void initState() {
    super.initState();
    _historyRange = DateTimeRange(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 7, 1),
    );
    _dashboardFuture = _loadDashboardData();
  }

  Future<_CustomerDashboardData> _loadDashboardData() async {
    final customerId = _readCustomerValue(
      widget.customer,
      const ['AccountID', 'CustomerID', 'accountid', 'customerid', 'ID', 'Id'],
    );
    final partyId = _readCustomerValue(
      widget.customer,
      const ['AccountCode', 'PartyID', 'accountcode', 'partyid', 'Code', 'PartyCode'],
    );

    final fromDate = '2026-01-01';
    final toDate = '2026-12-31';

    final results = await Future.wait([
      _fetchRows(ApiConfig.getOutstanding, {
        'CustomerID': customerId,
        'PartyID': partyId,
      }),
      _fetchRows(ApiConfig.getNotApprovalCheque, {
        'PartyID': partyId,
      }),
      _fetchRows(ApiConfig.getSalesHistory, {
        'CustomerID': customerId,
        'FromDate': fromDate,
        'ToDate': toDate,
      }),
      _fetchRows(ApiConfig.getReceiptsHistoryByID, {
        'PartyID': partyId,
        'FromDate': fromDate,
        'ToDate': toDate,
      }),
      _fetchRows(ApiConfig.getBillingReturnHistory, {
        'CustomerID': customerId,
        'FromDate': fromDate,
        'ToDate': toDate,
      }),
    ]);

    final outstandingRows = results[0] as List<Map<String, dynamic>>;
    final chequeRows = results[1] as List<Map<String, dynamic>>;
    final salesRows = results[2] as List<Map<String, dynamic>>;
    final receiptRows = results[3] as List<Map<String, dynamic>>;
    final billingRows = results[4] as List<Map<String, dynamic>>;

    final chequeValue = _extractChequeValue(chequeRows);

    return _CustomerDashboardData(
      outstandingValue: _formatCurrency(_sumAmounts(outstandingRows)),
      chequesValue: chequeValue,
      salesHistoryCount: salesRows.length,
      salesHistoryRows: salesRows,
      receiptsHistoryCount: receiptRows.length,
      receiptHistoryRows: receiptRows,
      billingReturnHistoryRows: billingRows,
      billingReturnHistoryCount: billingRows.length,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRows(
    String endpoint,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint').replace(
      queryParameters: params..removeWhere((key, value) => value.isEmpty),
    );
    debugPrint('Fetching customer data: $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }

      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          return (decoded['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
        if (decoded['result'] is List) {
          return (decoded['result'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
        if (decoded['rows'] is List) {
          return (decoded['rows'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
        return [decoded];
      }
    } catch (e) {
      debugPrint('Customer info API error: $e');
    }

    return [];
  }

  String _readCustomerValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  double _sumAmounts(List<Map<String, dynamic>> rows) {
    double total = 0;
    for (final row in rows) {
      total += _readNumericValue(
        row,
        const ['Amount', 'amount', 'OutstandingAmount', 'OutstandingAmt', 'Balance', 'NetAmount', 'TotalAmount'],
      );
    }
    return total;
  }

  double _readNumericValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  String _formatCurrency(double value) {
    return 'â‚¹${value.toStringAsFixed(2)}';
  }

  String _extractChequeValue(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return '0';
    }

    final firstRow = rows.first;
    final amount = _readNumericValue(
      firstRow,
      const ['PendingChequeAmount', 'pendingChequeAmount', 'Amount', 'amount', 'ChequeAmount', 'ChequeAmt'],
    );
    if (amount > 0) {
      return _formatCurrency(amount);
    }

    return '0';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'N/A';
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return value.toString();
    }

    return DateFormat('dd-MMM-yyyy').format(parsed.toLocal());
  }

  String _formatAmount(dynamic value) {
    if (value is num) {
      return _formatCurrency(value.toDouble());
    }

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return _formatCurrency(parsed);
      }
    }

    return 'â‚¹0.00';
  }

  String _readStringValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'N/A';
  }

  String _buildInvoiceLabel(Map<String, dynamic> row) {
    final invSeries = _readStringValue(row, const ['InvSeries', 'invseries', 'InvoiceSeries']);
    final billNo = _readStringValue(row, const ['BillNo', 'billno', 'BillNumber', 'InvoiceNo']);

    if (invSeries != 'N/A' && billNo != 'N/A') {
      return '$invSeries$billNo';
    }

    if (billNo != 'N/A') {
      return billNo;
    }

    return invSeries;
  }

  Future<void> _pickHistoryRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _historyRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || pickedRange == null) {
      return;
    }

    setState(() {
      _historyRange = pickedRange;
    });
  }

  DateTime? _parseRowDate(Map<String, dynamic> row, List<String> keys) {
    final rawValue = _readStringValue(row, keys);
    if (rawValue == 'N/A') {
      return null;
    }

    return DateTime.tryParse(rawValue);
  }

  List<Map<String, dynamic>> _filterRowsByRange(
    List<Map<String, dynamic>> rows,
    List<String> dateKeys,
    DateTimeRange? range,
  ) {
    if (range == null) {
      return rows;
    }

    return rows.where((row) {
      final rowDate = _parseRowDate(row, dateKeys);
      if (rowDate == null) {
        return false;
      }

      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      final current = DateTime(rowDate.year, rowDate.month, rowDate.day);

      return !current.isBefore(start) && !current.isAfter(end);
    }).toList();
  }

  double _sumFilteredAmounts(
    List<Map<String, dynamic>> rows,
    List<String> amountKeys,
  ) {
    double total = 0;
    for (final row in rows) {
      total += _readNumericValue(row, amountKeys);
    }
    return total;
  }

  String _formatDateRangeLabel(DateTimeRange? range) {
    if (range == null) {
      return 'Tap to choose dates';
    }

    final start = DateFormat('dd MMM yyyy').format(range.start);
    final end = DateFormat('dd MMM yyyy').format(range.end);
    return '$start  â†’  $end';
  }

  String _getActiveFilterLabel() {
    return _formatDateRangeLabel(_historyRange);
  }

  void _toggleHistoryCard(String key) {
    setState(() {
      if (_expandedHistoryCards.contains(key)) {
        _expandedHistoryCards.remove(key);
      } else {
        _expandedHistoryCards.add(key);
      }
    });
  }

  // Navigates to the Direct Sale page, passing the current customer along
  // so that screen can pre-select / pre-fill the account.
  void _openDirectSale() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectSaleOfCustomer(customer: widget.customer),
      ),
    );
  }

void _openReceipt() {
  final customerIdStr = _readCustomerValue(
    widget.customer,
    const ['AccountID', 'CustomerID', 'accountid', 'customerid', 'ID', 'Id'],
  );
  final partyIdStr = _readCustomerValue(
    widget.customer,
    const ['AccountCode', 'PartyID', 'accountcode', 'partyid', 'Code', 'PartyCode'],
  );
  final accountName = _readStringValue(widget.customer, const ['AccountName', 'accountname']);
  final address = _readStringValue(widget.customer, const ['Address', 'address']);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Receiptpage(
        rootId: int.tryParse(customerIdStr),
        accountCode: partyIdStr.isNotEmpty ? partyIdStr : null,
        accountName: accountName == 'N/A' ? null : accountName,
        customerAddress: address == 'N/A' ? null : address,
        outstandingAmount: 0.0,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Customer Info',
          style: AppFonts.pageTitle,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: FutureBuilder<_CustomerDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load customer details',
                style: AppFonts.body,
              ),
            );
          }

          final data = snapshot.data ?? const _CustomerDashboardData();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppLayout.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerCard(data),
                const SizedBox(height: AppLayout.sectionGap),
                _buildMenuGrid(),
                const SizedBox(height: AppLayout.sectionGap),
                _buildDateCard(),
                const SizedBox(height: AppLayout.sectionGap),
                _buildHistorySection(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerCard(_CustomerDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.customer['AccountName'] ?? 'Unknown'}',
                      style: AppFonts.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'GSTIN NO: ${widget.customer['GSTinNo'] ?? 'N/A'}',
                      style: AppFonts.smallText,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.lg),

          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: widget.customer['Mob'] ?? widget.customer['Phone'] ?? 'N/A',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: widget.customer['Address'] ?? 'N/A',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildSummaryPill(
                  title: 'Outstanding',
                  value: data.outstandingValue,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryPill(
                  title: 'Cheques',
                  value: data.chequesValue,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.caption.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppFonts.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: AppIcons.listTile,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppFonts.caption),
              const SizedBox(height: 2),
              Text(value, style: AppFonts.body),
            ],
          ),
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Quick Actions grid.
  // "Van Sales" is now the FIRST tile and, on tap, navigates
  // straight to the Direct Sale page (see _openDirectSale).
  // childAspectRatio was lowered from 0.85 -> 0.72 to fix the
  // "BOTTOM OVERFLOWED BY 7.0 PIXELS" error on these tiles.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Widget _buildMenuGrid() {
  //   final menuItems = [
  //     MenuItemData(
  //       Icons.delivery_dining_outlined,
  //       'Van Sales',
  //       AppColors.primary,
  //       onTap: _openDirectSale,
  //     ),
  //     const MenuItemData(Icons.shopping_cart_outlined, 'Primary\nOrder', AppColors.primary),
  //     const MenuItemData(Icons.local_shipping_outlined, 'Secondary\nSales', AppColors.secondary),
  //     const MenuItemData(Icons.person_outline, 'Counter\nSales', AppColors.warning),
  //     const MenuItemData(Icons.store_outlined, 'Outlets', AppColors.success),
  //     const MenuItemData(Icons.analytics_outlined, 'Projection', AppColors.error),
  //     const MenuItemData(Icons.inventory_2_outlined, 'GRN', AppColors.secondary),
  //     const MenuItemData(Icons.shopping_bag_outlined, 'Stock\nUpload', AppColors.success),
  //   ];

  Widget _buildMenuGrid() {
  final menuItems = [
    MenuItemData(
      Icons.delivery_dining_outlined,
      'Van Sales',
      AppColors.primary,
      onTap: _openDirectSale,
    ),
    const MenuItemData(Icons.shopping_cart_outlined, 'Primary\nOrder', AppColors.primary),
    const MenuItemData(Icons.local_shipping_outlined, 'Secondary\nSales', AppColors.secondary),
    const MenuItemData(Icons.person_outline, 'Counter\nSales', AppColors.warning),
    const MenuItemData(Icons.store_outlined, 'Outlets', AppColors.success),
    MenuItemData(
      Icons.receipt_long_outlined,
      'Receipt',
      AppColors.error,
      onTap: _openReceipt,
    ),
    const MenuItemData(Icons.inventory_2_outlined, 'GRN', AppColors.secondary),
    const MenuItemData(Icons.shopping_bag_outlined, 'Stock\nUpload', AppColors.success),
  ];


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppFonts.sectionTitle),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            return _buildMenuItem(menuItems[index]);
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: item.onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: AppFonts.cardTitle.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Date range card â€” fixed layout that never overflows.
  // Title row and the date chip are stacked vertically, and
  // the chip's text is wrapped in Expanded + ellipsis so a
  // long "dd MMM yyyy  â†’  dd MMM yyyy" string can never push
  // the row past the available width.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDateCard() {
    return InkWell(
      onTap: _pickHistoryRange,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [AppShadows.card],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'History Date Range',
                    style: AppFonts.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.edit_calendar_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _getActiveFilterLabel(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(_CustomerDashboardData data) {
    final salesRows = _filterRowsByRange(
      data.salesHistoryRows,
      const ['BillDate', 'billdate', 'Date', 'date'],
      _historyRange,
    );
    final receiptRows = _filterRowsByRange(
      data.receiptHistoryRows,
      const ['RDate', 'rdate', 'Date', 'date'],
      _historyRange,
    );
    final salesReturnRows = _filterRowsByRange(
      data.billingReturnHistoryRows,
      const ['BillDate', 'billdate', 'Date', 'date'],
      _historyRange,
    );

    final salesTotal = _sumFilteredAmounts(
      salesRows,
      const ['BillAmount', 'billamount', 'Amount', 'amount'],
    );
    final receiptTotal = _sumFilteredAmounts(
      receiptRows,
      const ['Amt', 'amt', 'Amount', 'amount'],
    );
    final salesReturnTotal = _sumFilteredAmounts(
      salesReturnRows,
      const ['Amount', 'amount', 'Amt', 'amt', 'BillAmount', 'billamount'],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account History', style: AppFonts.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          _buildHistoryOptionCard(
            cardKey: 'sales',
            icon: Icons.receipt_long_outlined,
            title: 'Sales',
            amountValue: _formatCurrency(salesTotal),
            detailText: '${salesRows.length} records',
            color: AppColors.primary,
            rows: salesRows,
            detailBuilder: () => _buildSalesHistoryList(salesRows),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildHistoryOptionCard(
            cardKey: 'salesReturn',
            icon: Icons.assignment_return_outlined,
            title: 'Sales Return',
            amountValue: _formatCurrency(salesReturnTotal),
            detailText: '${salesReturnRows.length} records',
            color: AppColors.primary,
            rows: salesReturnRows,
            detailBuilder: () => _buildGenericHistoryList(
              salesReturnRows,
              labelHeader: 'Ref',
              dateKeys: const ['BillDate', 'billdate', 'Date', 'date'],
              amountKeys: const ['Amount', 'amount', 'Amt', 'amt', 'BillAmount', 'billamount'],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildHistoryOptionCard(
            cardKey: 'receipt',
            icon: Icons.account_balance_wallet_outlined,
            title: 'Receipt',
            amountValue: _formatCurrency(receiptTotal),
            detailText: '${receiptRows.length} records',
            color: AppColors.primary,
            rows: receiptRows,
            detailBuilder: () => _buildReceiptHistoryList(receiptRows),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Expandable history card. Tapping the header toggles the
  // detail list open/closed with an animated chevron + size
  // transition instead of always rendering the detail rows.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHistoryOptionCard({
    required String cardKey,
    required IconData icon,
    required String title,
    required String amountValue,
    required String detailText,
    required Color color,
    required List<Map<String, dynamic>> rows,
    required Widget Function() detailBuilder,
  }) {
    final isExpanded = _expandedHistoryCards.contains(cardKey);
    final hasRows = rows.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: isExpanded ? color.withOpacity(0.4) : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasRows ? () => _toggleHistoryCard(cardKey) : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppFonts.body.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(detailText, style: AppFonts.smallText),
                        ],
                      ),
                    ),
                    Text(
                      amountValue,
                      style: AppFonts.body.copyWith(fontWeight: FontWeight.w700, color: color),
                    ),
                    if (hasRows) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !hasRows
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text('No records for the selected date range', style: AppFonts.smallText),
                  )
                : (isExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: detailBuilder(),
                      )
                    : const SizedBox(width: double.infinity)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryList(List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('Date', style: AppFonts.caption)),
              Expanded(flex: 2, child: Text('Mode', style: AppFonts.caption)),
              Expanded(
                flex: 3,
                child: Text('Amount', style: AppFonts.caption, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 3,
                child: Text('Invoice', style: AppFonts.caption, textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...rows.take(5).map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatDate(_readStringValue(row, const ['BillDate', 'billdate', 'Date'])),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _readStringValue(row, const ['BillMode', 'billmode', 'Mode']),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatAmount(_readNumericValue(row, const ['BillAmount', 'billamount', 'Amount'])),
                      style: AppFonts.smallText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _buildInvoiceLabel(row),
                      style: AppFonts.smallText,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReceiptHistoryList(List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('Date', style: AppFonts.caption)),
              Expanded(flex: 2, child: Text('Type', style: AppFonts.caption)),
              Expanded(
                flex: 3,
                child: Text('Amount', style: AppFonts.caption, textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...rows.take(5).map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatDate(_readStringValue(row, const ['RDate', 'rdate', 'Date'])),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _readStringValue(row, const ['Type', 'type', 'PaymentType']),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatAmount(_readNumericValue(row, const ['Amt', 'amt', 'Amount'])),
                      style: AppFonts.smallText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildGenericHistoryList(
    List<Map<String, dynamic>> rows, {
    required String labelHeader,
    required List<String> dateKeys,
    required List<String> amountKeys,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('Date', style: AppFonts.caption)),
              Expanded(flex: 2, child: Text(labelHeader, style: AppFonts.caption)),
              Expanded(
                flex: 3,
                child: Text('Amount', style: AppFonts.caption, textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...rows.take(5).map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatDate(_readStringValue(row, dateKeys)),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _readStringValue(row, const ['InvoiceNo', 'BillNo', 'billno', 'InvNo', 'invno', 'Reference', 'reference']),
                      style: AppFonts.smallText,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatAmount(_readNumericValue(row, amountKeys)),
                      style: AppFonts.smallText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value, style: AppFonts.smallText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDashboardData {
  final String outstandingValue;
  final String chequesValue;
  final int salesHistoryCount;
  final List<Map<String, dynamic>> salesHistoryRows;
  final int receiptsHistoryCount;
  final List<Map<String, dynamic>> receiptHistoryRows;
  final List<Map<String, dynamic>> billingReturnHistoryRows;
  final int billingReturnHistoryCount;

  const _CustomerDashboardData({
    this.outstandingValue = 'â‚¹0.00',
    this.chequesValue = '0',
    this.salesHistoryCount = 0,
    this.salesHistoryRows = const [],
    this.receiptsHistoryCount = 0,
    this.receiptHistoryRows = const [],
    this.billingReturnHistoryRows = const [],
    this.billingReturnHistoryCount = 0,
  });
}
