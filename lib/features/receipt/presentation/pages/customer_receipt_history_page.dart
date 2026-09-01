import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/receipt/data/models/receipt_customer_model.dart';

class CustomerRecepitPage extends StatefulWidget {
  final int partyId; // PartyID / accountCode
  final String? partyName;
  final String? customerAddress;

  const CustomerRecepitPage({
    super.key,
    required this.partyId,
    this.partyName,
    this.customerAddress,
  });

  @override
  State<CustomerRecepitPage> createState() => _CustomerRecepitPageState();
}

class _CustomerRecepitPageState extends State<CustomerRecepitPage> {
  late Future<List<ReceiptCustModel>> _receiptsFuture;

  @override
  void initState() {
    super.initState();
    _receiptsFuture = _fetchReceipts();
  }

  // ============================================================
  // FETCH RECEIPTS FROM LOCAL DATABASE
  // ============================================================

  Future<List<ReceiptCustModel>> _fetchReceipts() async {
    final partyIdStr = widget.partyId.toString();

    final rows = await DatabaseHelper.instance
        .getReceiptsByAccountCode(partyIdStr);

    final receipts = rows.map((row) {
      final receipt = ReceiptCustModel.fromMap(row);

      // Customer name comes from LOCAL DATABASE
      // receipts.accountName
      //
      // If old receipt doesn't have accountName,
      // use widget.partyName as fallback.
      if (receipt.partyName == null ||
          receipt.partyName!.trim().isEmpty) {
        receipt.partyName = widget.partyName;
      }

      return receipt;
    }).toList();

    return receipts;
  }

  // ============================================================
  // REFRESH
  // ============================================================

  void _refreshReceipts() {
    setState(() {
      _receiptsFuture = _fetchReceipts();
    });
  }

  // ============================================================
  // GET CUSTOMER NAME
  // ============================================================

  String _getCustomerName(List<ReceiptCustModel> receipts) {
    // First preference: name stored in local receipt
    for (final receipt in receipts) {
      if (receipt.partyName != null &&
          receipt.partyName!.trim().isNotEmpty) {
        return receipt.partyName!.trim();
      }
    }

    // Second preference: page customer name
    if (widget.partyName != null &&
        widget.partyName!.trim().isNotEmpty) {
      return widget.partyName!.trim();
    }

    return 'Customer';
  }

  // ============================================================
  // SAFE DATE FORMAT
  // ============================================================

  String _formatDate(String? date) {
    if (date == null || date.trim().isEmpty) {
      return '';
    }

    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (_) {
      return date;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: FutureBuilder<List<ReceiptCustModel>>(
            future: _receiptsFuture,
            builder: (context, snapshot) {
              String titleName =
                  widget.partyName?.trim().isNotEmpty == true
                      ? widget.partyName!.trim()
                      : 'Customer';

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                titleName = _getCustomerName(snapshot.data!);
              }

              return Text(
                'Receipts for $titleName',
                style: GoogleFonts.tenorSans(
                  fontSize: 20,
                  color: Colors.white,
                ),
              );
            },
          ),
          backgroundColor: const Color(0xFF2D4FA9),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              onPressed: _refreshReceipts,
            ),
          ],
        ),

        // ========================================================
        // BODY
        // ========================================================

        body: FutureBuilder<List<ReceiptCustModel>>(
          future: _receiptsFuture,

          builder: (context, snapshot) {
            // ----------------------------------------------------
            // LOADING
            // ----------------------------------------------------

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // ----------------------------------------------------
            // ERROR
            // ----------------------------------------------------

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.tenorSans(),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _refreshReceipts,
                        child: Text(
                          'Retry',
                          style: GoogleFonts.tenorSans(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ----------------------------------------------------
            // DATA
            // ----------------------------------------------------

            final receipts = snapshot.data ?? [];

            // ----------------------------------------------------
            // NO RECEIPTS
            // ----------------------------------------------------

            if (receipts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'No receipts found',
                      style: GoogleFonts.tenorSans(
                        fontSize: 18,
                      ),
                    ),

                    if (widget.customerAddress != null &&
                        widget.customerAddress!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),

                      Text(
                        widget.customerAddress!,
                        style: GoogleFonts.tenorSans(
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              );
            }

            // ----------------------------------------------------
            // CUSTOMER NAME FROM LOCAL DB
            // ----------------------------------------------------

            final customerName = _getCustomerName(receipts);

            // ====================================================
            // MAIN CONTENT
            // ====================================================

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _receiptsFuture = _fetchReceipts();
                });

                await _receiptsFuture;
              },

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // CUSTOMER HEADER CARD
                    // ==================================================

                    Card(
                      elevation: 4,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),

                      child: Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(20),

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2D4FA9),
                              Color(0xFF5E7DE3),
                            ],

                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),

                          borderRadius:
                              BorderRadius.circular(15),
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            // ------------------------------------------
                            // CUSTOMER NAME
                            // ------------------------------------------

                            Text(
                              customerName.toUpperCase(),

                              style: GoogleFonts.tenorSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            // ------------------------------------------
                            // ADDRESS
                            // ------------------------------------------

                            if (widget.customerAddress != null &&
                                widget.customerAddress!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),

                              Text(
                                'ADDRESS: ${widget.customerAddress!.toUpperCase()}',

                                style: GoogleFonts.tenorSans(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),

                            // ------------------------------------------
                            // TOTAL RECEIPTS
                            // ------------------------------------------

                            Text(
                              'TOTAL RECEIPTS: ${receipts.length}',

                              style: GoogleFonts.tenorSans(
                                color: Colors.yellowAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // RECEIPTS LIST
                    // ==================================================

                    ...receipts.map(
                      (receipt) => _buildReceiptCard(receipt),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // RECEIPT CARD
  // ============================================================

  Widget _buildReceiptCard(ReceiptCustModel receipt) {
    // Local DB customer name
    final receiptCustomerName =
        receipt.partyName != null &&
                receipt.partyName!.trim().isNotEmpty
            ? receipt.partyName!.trim()
            : widget.partyName?.trim() ?? 'N/A';

    return Card(
      elevation: 2,

      margin: const EdgeInsets.only(bottom: 12),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ========================================================
            // CUSTOMER NAME
            // ========================================================

            Text(
              receiptCustomerName.toUpperCase(),

              style: GoogleFonts.tenorSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: const Color(0xFF2D4FA9),
              ),
            ),

            const SizedBox(height: 4),

            // ========================================================
            // DATE
            // ========================================================

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  _formatDate(receipt.rDate),

                  style: GoogleFonts.tenorSans(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ========================================================
            // AMOUNT
            // ========================================================

            Text(
              'Amount: â‚¹${(receipt.amt ?? 0).toStringAsFixed(2)}',

              style: GoogleFonts.tenorSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 4),

            // ========================================================
            // PAYMENT TYPE
            // ========================================================

            if (receipt.type != null &&
                receipt.type!.trim().isNotEmpty)
              Chip(
                label: Text(
                  receipt.type!.toUpperCase(),
                ),

                backgroundColor:
                    const Color(0xFF2D4FA9),

                labelStyle: GoogleFonts.tenorSans(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),

            // ========================================================
            // CHEQUE DETAILS
            // ========================================================

            if (receipt.chkNo != null &&
                receipt.chkNo!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),

              Text(
                'Cheque No: ${receipt.chkNo}',
                style: GoogleFonts.tenorSans(),
              ),

              if (receipt.pBank != null &&
                  receipt.pBank!.trim().isNotEmpty)
                Text(
                  'Bank: ${receipt.pBank}',
                  style: GoogleFonts.tenorSans(),
                ),

              if (receipt.chkDate != null &&
                  receipt.chkDate!.trim().isNotEmpty)
                Text(
                  'Cheque Date: ${receipt.chkDate}',
                  style: GoogleFonts.tenorSans(),
                ),
            ],

            // ========================================================
            // NARRATION
            // ========================================================

            if (receipt.remark != null &&
                receipt.remark!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),

              Text(
                'Narration: ${receipt.remark}',

                style: GoogleFonts.tenorSans(
                  color: Colors.grey[600],
                ),
              ),
            ],

            // ========================================================
            // APPROVAL STATUS
            // ========================================================

            const SizedBox(height: 4),

            if (receipt.approvalStatus == 1)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    'Approved',
                    style: GoogleFonts.tenorSans(
                      color: Colors.green,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.pending,
                    color: Colors.orange,
                    size: 16,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    'Pending Approval',
                    style: GoogleFonts.tenorSans(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
