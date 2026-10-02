import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/core/database/session_storage.dart'; // adjust import path

/// Second screen of the report flow — pick a date range, fetch that
/// distributor's customer/item-wise orders (APPGetDistributorCustomerOrders),
/// preview grouped-by-customer results, then generate/share a PDF.
///
/// Company and Distributor header details are read from SharedPreferences
/// (already saved at login — see _fetchAndSaveAllocation-style flows),
/// NOT from the API, per the report requirement.
class DistributorOrderReportPage extends StatefulWidget {
  final int distributorAccountId;
  final String distributorName;

  const DistributorOrderReportPage({
    super.key,
    required this.distributorAccountId,
    required this.distributorName,
  });

  @override
  State<DistributorOrderReportPage> createState() =>
      _DistributorOrderReportPageState();
}

class _DistributorOrderReportPageState extends State<DistributorOrderReportPage> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  List<dynamic> _rawRows = [];
  List<_CustomerGroup> _groups = [];
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  String? _error;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _dateParamFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.apiBaseUrl}${ApiConfig.getDistributorCustomerOrdersUrl}'
        '?DistributorAccountId=${widget.distributorAccountId}'
        '&FromDate=${_dateParamFmt.format(_fromDate)}'
        '&ToDate=${_dateParamFmt.format(_toDate)}',
      );

      final response = await http
          .get(uri)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final rows = (body['data'] as List?) ?? [];
          setState(() {
            _rawRows = rows;
            _groups = _groupByCustomer(rows);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = body['message']?.toString() ?? 'Failed to load orders';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Groups the flat SQL rows (one row per item) into one card per
  /// customer, matching the PDF layout — mirrors the JS groupByCustomer
  /// helper used server-side for reference.
  List<_CustomerGroup> _groupByCustomer(List<dynamic> rows) {
    final Map<dynamic, _CustomerGroup> map = {};

    for (final row in rows) {
      final key = row['CustomerAccountID'];
      map.putIfAbsent(
        key,
        () => _CustomerGroup(
          name: row['CustomerName']?.toString() ?? '',
          address: row['CustomerAddress']?.toString() ?? '',
          gst: row['CustomerGST']?.toString() ?? '',
          mobile: row['CustomerMobile']?.toString() ?? '',
        ),
      );
      map[key]!.items.add(
        _OrderItemRow(
          itemName: row['ItemName']?.toString() ?? '',
          quantity: (row['Quantity'] as num?)?.toString() ??
              row['Quantity']?.toString() ??
              '0',
        ),
      );
    }

    return map.values.toList();
  }

  // ── Session-stored header details (company + distributor) ──
// ── Session-stored header details ──
// Company details come from SessionStore.getCompanyDetails() — the same
// helper DirectSaleOfCustomer/invoice_pdf_service uses when building
// invoiceData (see buildInvoiceDataWithSessionCompany), rather than
// reading raw CompanyName/CompanyAddress/... keys directly off
// SharedPreferences. Distributor details still come from plain prefs
// since there's no SessionStore method for that yet.
Future<Map<String, String>> _loadHeaderFromSession() async {
  final prefs = await SharedPreferences.getInstance();
  final company = await SessionStore.getCompanyDetails();

  return {
    'companyName': company.companyName,
    'companyAddress': company.companyAddress,      // << rename to match your CompanyDetails model's real field name
    'companyPhone': company.companyPhone,          // << rename to match your CompanyDetails model's real field name
    'companyGst': company.companyGstin,            // << rename to match your CompanyDetails model's real field name
    'distributorName': prefs.getString('DistributorName') ?? widget.distributorName,
    'distributorAddress': prefs.getString('DistributorAddress') ?? '',
    'distributorMobile': prefs.getString('DistributorMobile') ?? '',
    'distributorGst': prefs.getString('DistributorGST') ?? '',
  };
}

  Future<void> _generateAndSharePdf() async {
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to generate a PDF for.')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final header = await _loadHeaderFromSession();
      final pdfBytes = await _buildPdf(header);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'Distributor_Orders_${_dateParamFmt.format(_fromDate)}_to_${_dateParamFmt.format(_toDate)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // Future<Uint8List> _buildPdf(Map<String, String> header) async {
  //   final doc = pw.Document();

  //   doc.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(24),
  //       header: (context) => _pdfCompanyHeader(header),
  //       build: (context) => [
  //         pw.SizedBox(height: 8),
  //         _pdfDistributorBlock(header),
  //         pw.SizedBox(height: 6),
  //         pw.Text(
  //           'Orders: ${_dateFmt.format(_fromDate)} - ${_dateFmt.format(_toDate)}',
  //           style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
  //         ),
  //         pw.SizedBox(height: 10),
  //         pw.Divider(borderStyle: pw.BorderStyle.dashed),
  //         pw.SizedBox(height: 10),
  //         for (final group in _groups) ...[
  //           _pdfCustomerBlock(group),
  //           pw.SizedBox(height: 14),
  //         ],
  //       ],
  //     ),
  //   );

  //   return doc.save();
  // }

  Future<Uint8List> _buildPdf(Map<String, String> header) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      // NOTE: no `header:` callback here — a MultiPage header repeats on
      // EVERY page, which is why the company block was showing again on
      // page 2. The company header is now the first item in `build`
      // below, so it prints exactly once, only on page 1, and content
      // flows straight into page 2+ without repeating it.
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        _pdfCompanyHeader(header),
        pw.SizedBox(height: 8),
        _pdfDistributorBlock(header),
        pw.SizedBox(height: 6),
        pw.Text(
          'Orders: ${_dateFmt.format(_fromDate)} - ${_dateFmt.format(_toDate)}',
          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 10),
        for (final group in _groups) ...[
          _pdfCustomerBlock(group),
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );

  return doc.save();
}


  pw.Widget _pdfCompanyHeader(Map<String, String> h) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          h['companyName'] ?? '',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          h['companyAddress'] ?? '',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          h['companyPhone'] ?? '',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          h['companyGst'] ?? '',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _pdfDistributorBlock(Map<String, String> h) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Distributor Name : ${h['distributorName']}'),
          pw.Text('Address           : ${h['distributorAddress']}'),
          pw.Text('Mobile No         : ${h['distributorMobile']}'),
          pw.Text('GST               : ${h['distributorGst']}'),
        ],
      ),
    );
  }

  pw.Widget _pdfCustomerBlock(_CustomerGroup group) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Customer Name : ${group.name}'),
              pw.Text('Address           : ${group.address}'),
              pw.Text('GST               : ${group.gst}'),
              pw.Text('Mobile No         : ${group.mobile}'),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.6),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Item Name',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Quantity',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
              ],
            ),
            for (final item in group.items)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(item.itemName),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(item.quantity, textAlign: pw.TextAlign.center),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.distributorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_dateFmt.format(_fromDate)}  -  ${_dateFmt.format(_toDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGeneratingPdf ? null : _generateAndSharePdf,
        icon: _isGeneratingPdf
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(_isGeneratingPdf ? 'Generating...' : 'Generate PDF'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _fetchOrders, child: const Text('Retry')),
          ),
        ],
      );
    }

    if (_groups.isEmpty) {
      return const Center(child: Text('No orders in this date range'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(group.address, style: const TextStyle(color: Colors.grey)),
                if (group.mobile.isNotEmpty) Text('Mobile: ${group.mobile}'),
                const Divider(),
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.itemName)),
                        Text('Qty: ${item.quantity}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomerGroup {
  final String name;
  final String address;
  final String gst;
  final String mobile;
  final List<_OrderItemRow> items = [];

  _CustomerGroup({
    required this.name,
    required this.address,
    required this.gst,
    required this.mobile,
  });
}

class _OrderItemRow {
  final String itemName;
  final String quantity;

  _OrderItemRow({required this.itemName, required this.quantity});
}