import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:suitapps/core/database/session_storage.dart';

// lib/services/invoice_pdf_service.dart
//
// Builds a Tax Invoice PDF matching the old app's layout (company header,
// customer/invoice info box, item table, tax-slab totals box, bank details
// + QR, terms/signatory) and shows a popup after Save with:
//   - View     -> opens the native PDF preview
//   - Share    -> opens the OS share sheet (WhatsApp, Google Drive, etc.)
//   - Print (Bluetooth) -> calls back into YOUR existing thermal-printer
//     flow (already implemented elsewhere) via the onBluetoothPrint hook.
//
// Company details (name/address/GSTIN/mobile/phone) are pulled automatically
// from SessionStore (saved at login) via buildInvoiceDataWithSessionCompany() â€”
// callers no longer need to pass them by hand.
//
// Needs these two packages in pubspec.yaml:
//   pdf: ^3.11.1
//   printing: ^5.13.1



// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// DATA MODELS â€” plain data your screen builds from _billItems + prefs.
// Kept separate from BillItem so this file doesn't need to know your
// model's exact shape; just map your fields into these in DirectSaleOfCustomer.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class InvoiceItemData {
  final String name;
  final String hsn; // TODO: BillItem currently has no hsn field â€” see note
  //      at the bottom of this file for the 1-line addition needed.
  final int qty;
  final int freeQty;
  final double mrp;
  final double rate;
  final double amount; // rate * qty (pre-discount, pre-tax "Amount" column)
  final double grossAmt; // taxable value after discount (the "Gross Amt" column)
  final double gstPercent;
  final double gstAmt;
  final double netAmount; // final line total (the last "Amount" column)

  InvoiceItemData({
    required this.name,
    required this.hsn,
    required this.qty,
    required this.freeQty,
    required this.mrp,
    required this.rate,
    required this.amount,
    required this.grossAmt,
    required this.gstPercent,
    required this.gstAmt,
    required this.netAmount,
  });
}

class InvoiceData {
  // â”€â”€ Company (usually saved to SharedPreferences at login) â”€â”€
  final String companyName;
  final String companyAddress;
  final String companyGstin;
  final String companyMobile;
  final String companyPhone;

  // â”€â”€ Invoice header â”€â”€
  final String customerName;
  final String customerGst;
  final String customerAddress;
  final String paymentType; // 'Cash' / 'Credit' / 'UPI' / 'Other'
  final String invoiceNo; // e.g. "B2C-269" or "X14"
  final DateTime invoiceDate;
  final String salesman;

  // â”€â”€ Items â”€â”€
  final List<InvoiceItemData> items;

  // â”€â”€ Totals â”€â”€
  final double roundOff;
  final double grandTotal;
  final double oldBalance;

  // â”€â”€ Bank + QR â”€â”€
  final String bankName;
  final String bankAccountNo;
  final String bankIfsc;
  final String bankBranch;

  /// Raw string encoded into the QR box (e.g. a UPI deep link
  /// "upi://pay?pa=...&pn=...&am=...&cu=INR", or just the invoice no if you
  /// don't do UPI QR). Leave empty to omit the QR box.
  final String qrData;

  InvoiceData({
    required this.companyName,
    required this.companyAddress,
    required this.companyGstin,
    required this.companyMobile,
    required this.companyPhone,
    required this.customerName,
    required this.customerGst,
    required this.customerAddress,
    required this.paymentType,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.salesman,
    required this.items,
    required this.roundOff,
    required this.grandTotal,
    this.oldBalance = 0,
    required this.bankName,
    required this.bankAccountNo,
    required this.bankIfsc,
    required this.bankBranch,
    this.qrData = '',
  });

  double get totalQty => items.fold(0, (sum, i) => sum + i.qty);
  double get totalGross => items.fold(0, (sum, i) => sum + i.grossAmt);
  double get totalGstAmt => items.fold(0, (sum, i) => sum + i.gstAmt);
  double get totalAmount => items.fold(0, (sum, i) => sum + i.netAmount);

  /// Groups items by GST% into the 4 slab rows the old invoice always
  /// shows (0/5/12/18), each with its own Gross and Tax total.
  Map<int, _TaxSlab> get taxSlabs {
    final slabs = <int, _TaxSlab>{
      0: _TaxSlab(),
      5: _TaxSlab(),
      12: _TaxSlab(),
      18: _TaxSlab(),
    };
    for (final item in items) {
      final key = slabs.containsKey(item.gstPercent.round())
          ? item.gstPercent.round()
          : 0; // fold any unexpected % into the 0% bucket rather than crash
      slabs[key]!.gross += item.grossAmt;
      slabs[key]!.tax += item.gstAmt;
    }
    return slabs;
  }
}

class _TaxSlab {
  double gross = 0;
  double tax = 0;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SESSION-BACKED BUILDER â€” pulls company* fields from SessionStore so
// DirectSaleOfCustomer only supplies sale-specific data.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Same shape as [InvoiceData]'s constructor, minus the company* fields â€”
/// those come from `SessionStore.getCompanyDetails()` automatically.
Future<InvoiceData> buildInvoiceDataWithSessionCompany({
  required String customerName,
  required String customerGst,
  required String customerAddress,
  required String paymentType,
  required String invoiceNo,
  required DateTime invoiceDate,
  required String salesman,
  required List<InvoiceItemData> items,
  required double roundOff,
  required double grandTotal,
  double oldBalance = 0,
  required String bankName,
  required String bankAccountNo,
  required String bankIfsc,
  required String bankBranch,
  String qrData = '',
}) async {
  final company = await SessionStore.getCompanyDetails();

  return InvoiceData(
    companyName: company.companyName,
    companyAddress: company.companyAddress,
    companyGstin: company.companyGstin,
    companyMobile: company.companyMobile,
    companyPhone: company.companyPhone,
    customerName: customerName,
    customerGst: customerGst,
    customerAddress: customerAddress,
    paymentType: paymentType,
    invoiceNo: invoiceNo,
    invoiceDate: invoiceDate,
    salesman: salesman,
    items: items,
    roundOff: roundOff,
    grandTotal: grandTotal,
    oldBalance: oldBalance,
    bankName: bankName,
    bankAccountNo: bankAccountNo,
    bankIfsc: bankIfsc,
    bankBranch: bankBranch,
    qrData: qrData,
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// NUMBER -> WORDS (Indian numbering, rupees only â€” matches
// "Rs :Rupees Sixty Five Only" from the old invoice)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String _amountInWords(double amount) {
  final rupees = amount.round();
  if (rupees == 0) return 'Rupees Zero Only';
  return 'Rupees ${_numberToWords(rupees)} Only';
}

String _numberToWords(int n) {
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety'
  ];

  String twoDigits(int v) {
    if (v < 20) return ones[v];
    return '${tens[v ~/ 10]}${v % 10 != 0 ? ' ${ones[v % 10]}' : ''}';
  }

  String threeDigits(int v) {
    if (v >= 100) {
      final rest = v % 100;
      return 'enter ${ones[v ~/ 100]} Hundred${rest != 0 ? ' ${twoDigits(rest)}' : ''}'
          .replaceFirst('enter ', '');
    }
    return twoDigits(v);
  }

  if (n == 0) return 'Zero';

  final crore = n ~/ 10000000;
  final lakh = (n ~/ 100000) % 100;
  final thousand = (n ~/ 1000) % 100;
  final hundred = n % 1000;

  final parts = <String>[];
  if (crore > 0) parts.add('${threeDigits(crore)} Crore');
  if (lakh > 0) parts.add('${twoDigits(lakh)} Lakh');
  if (thousand > 0) parts.add('${twoDigits(thousand)} Thousand');
  if (hundred > 0) parts.add(threeDigits(hundred));

  return parts.join(' ');
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PDF BUILD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Builds the invoice PDF bytes. Uses Noto Sans (downloaded/cached by the
/// `printing` package the first time) so the â‚¹ symbol renders correctly â€”
/// the PDF core fonts don't include it.
Future<Uint8List> buildInvoicePdfBytes(InvoiceData data) async {
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  // Border is for Container/BoxDecoration; TableBorder is the separate type
  // pw.Table itself expects â€” they are NOT interchangeable.
  final border = pw.Border.all(color: PdfColors.black, width: 0.6);
  final tableBorder = pw.TableBorder.all(color: PdfColors.black, width: 0.6);
  final cellPad = const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);

  pw.Widget headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: cellPad,
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
    );
  }

  pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: cellPad,
      child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  final slabs = data.taxSlabs;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // â”€â”€ Company header â”€â”€
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(data.companyName,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(data.companyAddress, style: const pw.TextStyle(fontSize: 9)),
                  if (data.companyGstin.isNotEmpty)
                    pw.Text(data.companyGstin, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (data.companyMobile.isNotEmpty)
                pw.Text('Mob: ${data.companyMobile}', style: const pw.TextStyle(fontSize: 9)),
              if (data.companyPhone.isNotEmpty)
                pw.Text('Ph: ${data.companyPhone}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('Tax Invoice',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),

        // â”€â”€ Customer / invoice info box â”€â”€
        pw.Container(
          decoration: pw.BoxDecoration(border: border),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer Name : ${data.customerName}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('GST No           : ${data.customerGst}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Address          : ${data.customerAddress}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Center(
                  child: pw.Text(data.paymentType, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Invoice No : ${data.invoiceNo}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                        'Date       : ${data.invoiceDate.day.toString().padLeft(2, '0')}-'
                        '${data.invoiceDate.month.toString().padLeft(2, '0')}-'
                        '${data.invoiceDate.year} '
                        '${data.invoiceDate.hour.toString().padLeft(2, '0')}:'
                        '${data.invoiceDate.minute.toString().padLeft(2, '0')}:'
                        '${data.invoiceDate.second.toString().padLeft(2, '0')}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Sales Man  : ${data.salesman}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // â”€â”€ Items table â”€â”€
        pw.Table(
          border: tableBorder,
          columnWidths: const {
            0: pw.FlexColumnWidth(0.5),
            1: pw.FlexColumnWidth(2.4),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(0.6),
            4: pw.FlexColumnWidth(0.6),
            5: pw.FlexColumnWidth(0.9),
            6: pw.FlexColumnWidth(0.9),
            7: pw.FlexColumnWidth(1),
            8: pw.FlexColumnWidth(1),
            9: pw.FlexColumnWidth(0.7),
            10: pw.FlexColumnWidth(0.9),
            11: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              headerCell('S.\nNo', align: pw.TextAlign.center),
              headerCell('Item Name'),
              headerCell('HSN\nCode', align: pw.TextAlign.center),
              headerCell('Qty', align: pw.TextAlign.center),
              headerCell('Free', align: pw.TextAlign.center),
              headerCell('MRP', align: pw.TextAlign.right),
              headerCell('Rate', align: pw.TextAlign.right),
              headerCell('Amount', align: pw.TextAlign.right),
              headerCell('Gross Amt', align: pw.TextAlign.right),
              headerCell('GST\n%', align: pw.TextAlign.center),
              headerCell('GST\nAmt', align: pw.TextAlign.right),
              headerCell('Amount', align: pw.TextAlign.right),
            ]),
            for (var i = 0; i < data.items.length; i++)
              pw.TableRow(children: [
                cell('${i + 1}', align: pw.TextAlign.center),
                cell(data.items[i].name),
                cell(data.items[i].hsn, align: pw.TextAlign.center),
                cell('${data.items[i].qty}', align: pw.TextAlign.center),
                cell('${data.items[i].freeQty}', align: pw.TextAlign.center),
                cell(data.items[i].mrp.toStringAsFixed(2), align: pw.TextAlign.right),
                cell(data.items[i].rate.toStringAsFixed(2), align: pw.TextAlign.right),
                cell(data.items[i].amount.toStringAsFixed(2), align: pw.TextAlign.right),
                cell(data.items[i].grossAmt.toStringAsFixed(2), align: pw.TextAlign.right),
                cell(data.items[i].gstPercent.toStringAsFixed(2), align: pw.TextAlign.center),
                cell(data.items[i].gstAmt.toStringAsFixed(2), align: pw.TextAlign.right),
                cell(data.items[i].netAmount.toStringAsFixed(2), align: pw.TextAlign.right),
              ]),
            // Totals row
            pw.TableRow(children: [
              cell(''),
              headerCell('No.of Items: ${data.items.length}'),
              cell(''),
              headerCell('${data.totalQty.toStringAsFixed(0)}', align: pw.TextAlign.center),
              cell(''),
              cell(''),
              cell(''),
              cell(''),
              headerCell(data.totalGross.toStringAsFixed(2), align: pw.TextAlign.right),
              cell(''),
              headerCell(data.totalGstAmt.toStringAsFixed(2), align: pw.TextAlign.right),
              headerCell(data.totalAmount.toStringAsFixed(2), align: pw.TextAlign.right),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),

        // â”€â”€ Amount in words + tax slabs + round off/grand total â”€â”€
        pw.Container(
          decoration: pw.BoxDecoration(border: border),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Rs : ${_amountInWords(data.grandTotal)}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    for (final percent in [0, 5, 12, 18])
                      pw.Text(
                        'Tax $percent%   : ${slabs[percent]!.tax.toStringAsFixed(2)}   '
                        'Gross $percent% : ${slabs[percent]!.gross.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    if (data.oldBalance != 0)
                      pw.Text('Old Balance : ${data.oldBalance.toStringAsFixed(3)}',
                          style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Round off : ${data.roundOff.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text('Grand Total : ${data.grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // â”€â”€ Bank details + QR â”€â”€
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                decoration: pw.BoxDecoration(border: border),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bank Details',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text('Bank         : ${data.bankName}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Account No   : ${data.bankAccountNo}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('IFSC Code    : ${data.bankIfsc}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Branch       : ${data.bankBranch}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            if (data.qrData.isNotEmpty)
              pw.Container(
                decoration: pw.BoxDecoration(border: border),
                padding: const pw.EdgeInsets.all(10),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: data.qrData,
                  width: 80,
                  height: 80,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 12),

        // â”€â”€ Terms + signatory â”€â”€
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Terms and Conditions',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Goods cannot be returned or exchanged without a valid invoice',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('For  ${data.companyName}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// VIEW / SHARE
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Opens the native PDF preview (pinch-zoom, its own print/share icons too).
Future<void> viewInvoicePdf(InvoiceData data) async {
  final bytes = await buildInvoicePdfBytes(data);
  await Printing.layoutPdf(
    onLayout: (format) async => bytes,
    name: 'Invoice_${data.invoiceNo}',
  );
}

/// Opens the OS share sheet (WhatsApp, Google Drive, Bluetooth, Mail, etc.)
/// with the generated PDF attached â€” a plain PDF-file share.
Future<void> shareInvoicePdf(InvoiceData data) async {
  final bytes = await buildInvoicePdfBytes(data);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'Invoice_${data.invoiceNo}.pdf',
  );
}

/// Renders the invoice's first (only) page to a PNG and shares THAT
/// instead of the PDF â€” this is what makes it show up as an image
/// (with a real thumbnail preview) in WhatsApp/etc., matching the old app.
Future<void> shareInvoiceAsImage(InvoiceData data) async {
  final pdfBytes = await buildInvoicePdfBytes(data);

  // Rasterize at a decent DPI so text stays sharp when shared as an image.
  final pages = Printing.raster(pdfBytes, dpi: 200);
  final firstPage = await pages.first;

  // IMPORTANT: PdfRaster renders with a transparent background. Left as
  // transparent, apps with a dark theme (WhatsApp dark mode, etc.) show
  // those pixels as solid black instead of white â€” which is exactly the
  // all-black preview you saw. Flatten it onto an opaque white canvas
  // first so the shared PNG always has a real white background.
  final pngBytes = await _flattenOntoWhitePng(firstPage);

  await Share.shareXFiles(
    [
      XFile.fromData(
        pngBytes,
        name: 'Invoice_${data.invoiceNo}.png',
        mimeType: 'image/png',
      ),
    ],
    text: 'Invoice ${data.invoiceNo}',
  );
}

/// Composites a rasterized PDF page onto an opaque white background and
/// re-encodes it as PNG, so no transparent pixels reach the receiving app.
Future<Uint8List> _flattenOntoWhitePng(PdfRaster raster) async {
  final ui.Image rasterImage = await raster.toImage();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Opaque white fill covering the whole page first...
  final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, rasterImage.width.toDouble(), rasterImage.height.toDouble()),
    paint,
  );
  // ...then the rendered page drawn on top of it.
  canvas.drawImage(rasterImage, ui.Offset.zero, ui.Paint());

  final picture = recorder.endRecording();
  final flattened = await picture.toImage(rasterImage.width, rasterImage.height);
  final byteData = await flattened.toByteData(format: ui.ImageByteFormat.png);

  rasterImage.dispose();
  flattened.dispose();

  return byteData!.buffer.asUint8List();
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POPUP â€” shown right after a successful save.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Call this from DirectSaleOfCustomer._saveBill() right after the bill is
/// saved (locally, and/or synced). [onBluetoothPrint] should call whatever
/// thermal-printer flow you already have wired up elsewhere in the app â€”
/// this file doesn't implement Bluetooth printing itself.
Future<void> showInvoiceActionsSheet(
  BuildContext context,
  InvoiceData data, {
  VoidCallback? onBluetoothPrint,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invoice ${data.invoiceNo}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  viewInvoicePdf(data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  shareInvoiceAsImage(data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Share as PDF'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  shareInvoicePdf(data);
                },
              ),
              if (onBluetoothPrint != null)
                ListTile(
                  leading: const Icon(Icons.bluetooth_outlined),
                  title: const Text('Print (Bluetooth)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onBluetoothPrint();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ONE THING STILL NEEDED IN YOUR MODEL:
//
// BillItem currently has no `hsnCode` field, but the invoice table needs
// it per line. Add it in two places:
//
// 1. Billmodels.dart â€” add a field to BillItem:
//      final String hsnCode;
//    and include it in the constructor / any copyWith.
//
// 2. SelectItemPage.dart â€” in _LineDraft.toBillItem(), pass it from the
//    product master:
//      hsnCode: product.hsn,
//
// Once that's in place, build InvoiceItemData.hsn from item.hsnCode when
// you map _billItems -> InvoiceData in DirectSaleOfCustomer.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
