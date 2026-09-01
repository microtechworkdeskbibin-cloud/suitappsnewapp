import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:suitapps/features/receipt/presentation/pages/customer_receipt_page.dart';
import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/receipt/data/models/receipt_model.dart';

class ReceiptListPage extends StatefulWidget {
  final int userId;

  const ReceiptListPage({
    super.key,
    required this.userId,
  });

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Cash', 'Cheque', 'UPI'];

  List<ReceiptModel> _receipts = [];
  bool _isLoadingReceipts = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load receipts after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceipts();
    });
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoadingReceipts = true;
      _error = null;
    });

    try {
      // This page shows every locally saved receipt (it filters by payment
      // type client-side only), so pull them all via getAllReceipts().
      final rows = await DatabaseHelper.instance.getAllReceipts();
      final receipts = rows.map((row) => ReceiptModel.fromMap(row)).toList();

      if (!mounted) return;
      setState(() {
        _receipts = receipts;
        _isLoadingReceipts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load receipts: $e';
        _isLoadingReceipts = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load receipts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<ReceiptModel> _getFilteredReceipts(List<ReceiptModel> receipts) {
    if (_selectedFilter == 'All') return receipts;

    return receipts.where((receipt) {
      final type = receipt.type?.toLowerCase() ?? '';
      switch (_selectedFilter) {
        case 'Cash':
          return type == 'cash';
        case 'Cheque':
          return type == 'cheque';
        case 'UPI':
          return type == 'upi' || type == 'gpay';
        default:
          return true;
      }
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAmount(int? amount) {
    if (amount == null) return 'â‚¹0.00';
    return 'â‚¹${amount.toStringAsFixed(2)}';
  }

  Color _getStatusColor(int? status) {
    if (status == null) return Colors.orange;
    switch (status) {
      case 1:
        return Colors.green;
      case 0:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _getStatusText(int? status) {
    if (status == null) return 'Pending';
    switch (status) {
      case 1:
        return 'Approved';
      case 0:
        return 'Pending';
      default:
        return 'Rejected';
    }
  }

  IconData _getPaymentIcon(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t == 'cash') return Icons.money;
    if (t == 'cheque') return Icons.receipt_long;
    if (t == 'upi' || t == 'gpay') return Icons.phone_android;
    return Icons.payment;
  }

  String _formatBillAmount(int? amount) {
    if (amount == null) return 'â‚¹0.00';
    return 'â‚¹${amount.toStringAsFixed(0)}'; // Assuming whole numbers for bill amounts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: Text(
          'Receipt List',
          style: GoogleFonts.tenorSans(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2D4FA9),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadReceipts,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoadingReceipts) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: [
                  // Shimmer for Filter Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shimmer for filter title
                        Container(
                          height: 16,
                          width: 150,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        // Shimmer for filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(4, (index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                width: 60,
                                height: 32,
                                color: Colors.white,
                              ),
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shimmer for Summary Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D4FA9), Color(0xFF5E7DE3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildShimmerSummaryItem(),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.white38,
                        ),
                        _buildShimmerSummaryItem(),
                      ],
                    ),
                  ),
                  // Shimmer for Receipt List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5, // Number of shimmer items to show
                      itemBuilder: (context, index) {
                        return _buildShimmerReceiptCard();
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading receipts',
                      style: GoogleFonts.tenorSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tenorSans(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadReceipts,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Retry',
                        style: GoogleFonts.tenorSans(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4FA9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredReceipts = _getFilteredReceipts(_receipts);

          if (filteredReceipts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No receipts found',
                    style: GoogleFonts.tenorSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first receipt to see it here',
                    style: GoogleFonts.tenorSans(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Payment Type',
                      style: GoogleFonts.tenorSans(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                filter,
                                style: GoogleFonts.tenorSans(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: const Color(0xFF2D4FA9),
                              checkmarkColor: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Receipt List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadReceipts,
                  color: const Color(0xFF2D4FA9),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredReceipts.length,
                    itemBuilder: (context, index) {
                      final receipt = filteredReceipts[index];
                      return _buildReceiptCard(receipt);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerSummaryItem() {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        Container(
          height: 20,
          width: 40,
          color: Colors.white,
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: 30,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildShimmerReceiptCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 120, // Approximate height for shimmer
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shimmer for Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Shimmer for icon container
                      Container(
                        width: 48,
                        height: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Shimmer for party name
                            Container(
                              height: 16,
                              width: double.infinity,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            // Shimmer for receipt number
                            Container(
                              height: 12,
                              width: 80,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Shimmer for amount and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 18,
                      width: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 20,
                      width: 50,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Shimmer for divider (simplified)
            Container(
              height: 1,
              width: double.infinity,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            // Shimmer for Details Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.tenorSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tenorSans(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(ReceiptModel receipt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showReceiptDetails(receipt),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (existing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4FA9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getPaymentIcon(receipt.type),
                            color: const Color(0xFF2D4FA9),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receipt.CustomerName ?? 'N/A',
                                style: GoogleFonts.tenorSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
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
                        _formatAmount(receipt.amt),
                        style: GoogleFonts.tenorSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(receipt.approvalStatus)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusText(receipt.approvalStatus),
                          style: GoogleFonts.tenorSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(receipt.approvalStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Existing Details Row
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.payment,
                      receipt.type?.toUpperCase() ?? 'N/A',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today,
                      _formatDate(receipt.rDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.account_balance,
                      receipt.pBank ?? 'N/A',
                    ),
                  ),
                ],
              ),
              // New Bill Details Row
              if (receipt.billNo != null || receipt.billDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.description,
                        'Bill #${receipt.billNo ?? 'N/A'}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.event,
                        _formatDate(receipt.billDate),
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.currency_rupee,
                        _formatBillAmount(receipt.billAmount),
                      ),
                    ),
                  ],
                ),
              ],
              if (receipt.remark != null && receipt.remark!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        receipt.remark!,
                        style: GoogleFonts.tenorSans(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.tenorSans(
                fontSize: 11,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptDetails(ReceiptModel receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle (existing)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (existing)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D4FA9).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getPaymentIcon(receipt.type),
                              color: const Color(0xFF2D4FA9),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Receipt Details',
                                  style: GoogleFonts.tenorSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(receipt.approvalStatus)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusText(receipt.approvalStatus),
                              style: GoogleFonts.tenorSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(receipt.approvalStatus),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF2D4FA9)),
                            onPressed: () {
                              Navigator.pop(context); // Close the modal
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Receiptpage(
                                    accountCode: receipt.partyID?.toString(),
                                    rootId: receipt.routeID,
                                    accountName: receipt.CustomerName,
                                    outstandingAmount: null,
                                    receiptToEdit: receipt,
                                  ),
                                ),
                              ).then((_) {
                                _loadReceipts();
                              });
                            },
                            tooltip: 'Edit Receipt',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Amount Card (existing)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D4FA9), Color(0xFF5E7DE3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Amount',
                              style: GoogleFonts.tenorSans(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatAmount(receipt.amt),
                              style: GoogleFonts.tenorSans(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Existing Details
                      _buildDetailRow('Customer Name', receipt.CustomerName ?? 'N/A'),
                      _buildDetailRow('Payment Type', receipt.type?.toUpperCase() ?? 'N/A'),
                      _buildDetailRow('Date', _formatDate(receipt.rDate)),
                      if (receipt.type?.toLowerCase() == 'cheque') ...[
                        _buildDetailRow('Cheque No', receipt.chkNo ?? 'N/A'),
                        _buildDetailRow('Cheque Date', _formatDate(receipt.chkDate)),
                        _buildDetailRow('BankName', receipt.pBank ?? 'N/A'),
                        if (receipt.chequeApprovedDate != null)
                          _buildDetailRow('Approved Date', _formatDate(receipt.chequeApprovedDate)),
                      ],
                      if (receipt.remark != null && receipt.remark!.isNotEmpty)
                        _buildDetailRow('Remarks', receipt.remark!),
                      // New Bill Details
                      if (receipt.billNo != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Bill Details',
                          style: GoogleFonts.tenorSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Bill No', '${receipt.billNo ?? 'N/A'}'),
                        if (receipt.billDate != null)
                          _buildDetailRow('Bill Date', _formatDate(receipt.billDate)),
                        if (receipt.billAmount != null)
                          _buildDetailRow('Bill Amount', _formatBillAmount(receipt.billAmount)),
                        if (receipt.pendingAmount != null)
                          _buildDetailRow('Pending Amount', _formatBillAmount(receipt.pendingAmount)),
                        if (receipt.paidAmount != null)
                          _buildDetailRow('Paid Amount', _formatBillAmount(receipt.paidAmount)),
                        if (receipt.appliedAmount != null)
                          _buildDetailRow('Applied Amount', _formatBillAmount(receipt.appliedAmount)),
                        if (receipt.extraAmount != null)
                          _buildDetailRow('Extra Amount', _formatBillAmount(receipt.extraAmount)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.tenorSans(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.tenorSans(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
