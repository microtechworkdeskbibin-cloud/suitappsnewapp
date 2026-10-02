import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/receipt/presentation/pages/customer_receipt_history_page.dart';
import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/customer/presentation/pages/existing_customers_page.dart';
import 'package:suitapps/features/receipt/data/models/receipt_model.dart';
import 'package:suitapps/features/receipt/data/datasources/receipt_sync_datasource.dart'; // adjust path to match your project

class Receiptpage extends StatefulWidget {
  final int? rootId;
  final String? accountCode;
  final String? accountName;
  final String? customerAddress;
  final double? outstandingAmount;
  final ReceiptModel? receiptToEdit;

  const Receiptpage({
    super.key,
    this.accountCode,
    required this.rootId,
    this.accountName,
    this.customerAddress,
    this.outstandingAmount,
    this.receiptToEdit,
  });

  @override
  State<Receiptpage> createState() => _ReceiptpageState();
}

enum PaymentMode { cash, cheque, gpay }

class _ReceiptpageState extends State<Receiptpage> {
  // ---- Design tokens -------------------------------------------------------
  static const Color _primary = Color(0xFF2D4FA9);
  static const Color _primaryLight = Color(0xFF5E7DE3);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _green = Color(0xFF2E9E4F);

  PaymentMode? _selectedMode = PaymentMode.cash;
  final TextEditingController _chequeNoController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _chequeDateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  final TextEditingController _gpayController = TextEditingController();
  final TextEditingController _receiptNoController = TextEditingController();

  // Image bytes held in memory for preview + save. These get base64-encoded
  // and written straight into the 'receipts' row (gpayImagePath /
  // chequeImagePath columns), so the image itself lives in the local DB
  // instead of a file path that could get wiped by the OS.
  Uint8List? _gpayImageBytes;
  Uint8List? _chequeImageBytes;
  bool _isSaving = false;

  int _suitAppsSeq = 0;

  String _nextSuitAppsId(DateTime now) {
    _suitAppsSeq++;
    final ts =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final prefix =
        (widget.accountCode != null && widget.accountCode!.isNotEmpty)
        ? widget.accountCode!
        : 'RCT';
    return '$prefix-$ts-$_suitAppsSeq';
  }

  // Tries prefs.getInt() for each key in order; if that key holds a
  // String instead (e.g. saved via setString by mistake at login), falls
  // back to int.tryParse on the String. Returns 0 if nothing matches.
  // Same helper used in DirectSaleOfCustomer._saveBill, kept in sync so
  // both screens agree on where UserID / FYearID come from.
  int _readIntPref(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final intValue = prefs.getInt(key);
      if (intValue != null) return intValue;

      final stringValue = prefs.getString(key);
      if (stringValue != null) {
        final parsed = int.tryParse(stringValue);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _chequeDateController.text = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.now());
    if (widget.receiptToEdit == null) {
      _generateReceiptNumber();
    }
    _loadEditData();
  }

  Future<void> _loadEditData() async {
    if (widget.receiptToEdit != null) {
      final receipt = widget.receiptToEdit!;
      _amountController.text = receipt.amt?.toString() ?? '';
      _narrationController.text = receipt.remark ?? '';

      PaymentMode? mode;
      switch (receipt.type?.toLowerCase()) {
        case 'cash':
          mode = PaymentMode.cash;
          break;
        case 'cheque':
          mode = PaymentMode.cheque;
          break;
        case 'upi':
        case 'gpay':
          mode = PaymentMode.gpay;
          break;
      }

      if (mode != null) {
        if (mounted) {
          setState(() {
            _selectedMode = mode;
          });
        }

        if (mode == PaymentMode.cheque) {
          _chequeNoController.text = receipt.chkNo ?? '';
          _bankController.text = receipt.pBank ?? '';
          if (receipt.chkDate != null) {
            try {
              final date = DateTime.parse(receipt.chkDate!);
              _chequeDateController.text = DateFormat(
                'dd/MM/yyyy',
              ).format(date);
            } catch (e) {
              print('Error parsing cheque date: $e');
              _chequeDateController.text = DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.now());
            }
          }
        }

        // Restore the previously-saved image, if any, so the edit page
        // shows the same cheque/GPay screenshot the user uploaded when
        // the receipt was first saved, instead of an empty upload box.
        if (receipt.chequeImageBase64 != null &&
            receipt.chequeImageBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(receipt.chequeImageBase64!);
            if (mounted) setState(() => _chequeImageBytes = bytes);
          } catch (e) {
            print('Error decoding stored cheque image: $e');
          }
        }
        if (receipt.gpayImageBase64 != null &&
            receipt.gpayImageBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(receipt.gpayImageBase64!);
            if (mounted) setState(() => _gpayImageBytes = bytes);
          } catch (e) {
            print('Error decoding stored gpay image: $e');
          }
        }
      }
    }
  }

  void _generateReceiptNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    _receiptNoController.text = 'RCP$timestamp';
  }

  Future<void> _pickImage(ImageSource source, {required bool forCheque}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality:
          70, // compress a bit - base64 text in SQLite grows fast on full-res photos
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (forCheque) {
          _chequeImageBytes = bytes;
        } else {
          _gpayImageBytes = bytes;
        }
      });
    }
  }

  void _showImageSourceOptions({required bool forCheque}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload from',
                  style: GoogleFonts.tenorSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _sourceTile(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () {
                          _pickImage(ImageSource.camera, forCheque: forCheque);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _sourceTile(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () {
                          _pickImage(ImageSource.gallery, forCheque: forCheque);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.tenorSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chequeNoController.dispose();
    _bankController.dispose();
    _chequeDateController.dispose();
    _amountController.dispose();
    _narrationController.dispose();
    _gpayController.dispose();
    _receiptNoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D4FA9),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _chequeDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  bool _validateForm() {
    if (widget.accountCode == null || widget.accountCode!.isEmpty) {
      _showErrorDialog('Account code is required');
      return false;
    }

    if (_amountController.text.isEmpty) {
      _showErrorDialog('Amount is required');
      return false;
    }

    double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorDialog('Please enter a valid amount');
      return false;
    }

    if (_selectedMode == PaymentMode.cheque) {
      if (_chequeNoController.text.isEmpty) {
        _showErrorDialog('Cheque number is required');
        return false;
      }
      if (_bankController.text.isEmpty) {
        _showErrorDialog('Bank name is required');
        return false;
      }
      if (_chequeDateController.text.isEmpty) {
        _showErrorDialog('Cheque date is required');
        return false;
      }
    }
    return true;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.red.withOpacity(0.12),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: GoogleFonts.tenorSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.tenorSans(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.tenorSans(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _green.withOpacity(0.12),
                child: const Icon(Icons.check_circle, color: _green, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Success',
                style: GoogleFonts.tenorSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Receipt ${widget.receiptToEdit != null ? 'updated' : 'saved'} successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.tenorSans(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.receiptToEdit != null) {
                  Navigator.of(context).pop();
                } else {
                  _clearForm();
                }
              },
              child: Text(
                'OK',
                style: GoogleFonts.tenorSans(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearForm() {
    _amountController.clear();
    _narrationController.clear();
    _chequeNoController.clear();
    _bankController.clear();
    _gpayController.clear();
    _chequeDateController.text = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.now());
    _generateReceiptNumber();
    setState(() {
      _selectedMode = PaymentMode.cash;
      _gpayImageBytes = null;
      _chequeImageBytes = null;
    });
  }

  Future<void> _saveReceipt() async {
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final nowDt = DateTime.now();
      final now = nowDt.toIso8601String();

      // -- Session values (saved at login time in SharedPreferences) --
      // Tolerant read: tries the int getter first, then falls back to
      // parsing a String value, and tries a couple of common alternate
      // key spellings - same pattern used in DirectSaleOfCustomer._saveBill
      // so every screen agrees on where UserID / FYearID come from.
      final prefs = await SharedPreferences.getInstance();

      // -- DEBUG: dump every SharedPreferences key/value once, so you can
      // see the *exact* key names and types actually stored at login.
      // If 'UserID' / 'FYearID' aren't in this list (or show up under a
      // different casing, e.g. 'UserId'), that's why they're coming
      // through as 0 below. Remove this block once confirmed.
      for (final key in prefs.getKeys().toList()..sort()) {
        final value = prefs.get(key);
        debugPrint('prefs: $key = $value (${value.runtimeType})');
      }

      final userId = _readIntPref(prefs, ['UserID', 'UserId', 'User_ID']);
      final fYearId = _readIntPref(prefs, ['FYearID', 'FYearId', 'FyearID']);

      if (userId == 0) {
        debugPrint(
          'WARNING: UserID resolved to 0 - check the keys actually '
          'saved at login (see DirectSaleOfCustomer for the same check).',
        );
      }
      if (fYearId == 0) {
        debugPrint(
          'WARNING: FYearID resolved to 0 - check the keys actually '
          'saved at login.',
        );
      }

      final bool isEditing = widget.receiptToEdit != null;
      final String suitAppsId = isEditing
          ? (widget.receiptToEdit!.SuitAppId ?? _nextSuitAppsId(nowDt))
          : _nextSuitAppsId(nowDt);

      // Convert payment mode to a local string
      String localPaymentType;
      switch (_selectedMode) {
        case PaymentMode.cash:
          localPaymentType = 'cash';
          break;
        case PaymentMode.cheque:
          localPaymentType = 'cheque';
          break;
        case PaymentMode.gpay:
          localPaymentType = 'gpay';
          break;
        default:
          localPaymentType = 'cash';
      }

      // Parse amount
      double amount = double.parse(_amountController.text);

      final localChequeDate = _chequeDateController.text;

      // Base64-encode the picked image bytes so the actual image data (not
      // just a file path) is what gets written into the DB row. Only the
      // bytes for the currently-selected mode are kept - cash never writes
      // an image, cheque never writes the gpay bytes and vice versa.
      final String chequeImageBase64 =
          (_selectedMode == PaymentMode.cheque && _chequeImageBytes != null)
          ? base64Encode(_chequeImageBytes!)
          : '';
      final String gpayImageBase64 =
          (_selectedMode == PaymentMode.gpay && _gpayImageBytes != null)
          ? base64Encode(_gpayImageBytes!)
          : '';

      // Determine ApprovalStatus
      int approvalStatus = localPaymentType == 'cash' ? 1 : 0;

      // Save/Update local. gpayImagePath / chequeImagePath now hold the
      // base64-encoded image data itself, not a filesystem path.
      final localData = {
        'suitAppsId': suitAppsId,
        'rootId': widget.rootId,
        'accountCode': widget.accountCode!,
        'accountName': widget.accountName ?? '',
        'customerAddress': widget.customerAddress ?? '',
        'amount': amount,
        'paymentType': localPaymentType,
        'narration': _narrationController.text.isEmpty
            ? ''
            : _narrationController.text,
        'chequeNo': _selectedMode == PaymentMode.cheque
            ? _chequeNoController.text
            : '',
        'chequeDate': localChequeDate,
        'bankName': _selectedMode == PaymentMode.cheque
            ? _bankController.text
            : '',
        'chequeImagePath': chequeImageBase64,
        'gpayImagePath': gpayImageBase64,
        'approvalStatus': approvalStatus,
        'userId': userId,
        'fYearId': fYearId,
        'isSynced': 0,
        'updatedAt': now,
      };

      if (isEditing) {
        // FIXED: this branch previously did nothing (the actual update
        // call was commented out), so editing a receipt built the
        // payload and printed the debug log but never touched the
        // database - every field change (amount, narration, etc.) was
        // silently discarded. DatabaseHelper.updateLocalReceipt already
        // exists and matches by suitAppsId; just call it.
        await DatabaseHelper.instance.updateLocalReceipt(localData);
      } else {
        localData['createdAt'] = now;
        localData['serverId'] = null;
      }

      // -- DEBUG: print the exact payload being written/synced, so you can
      // confirm userId / fYearId (and everything else) are what you expect
      // before it hits the local DB or the sync service. Remove once
      // confirmed.
      debugPrint('Receipt payload -> $localData');

      if (!isEditing) {
        await DatabaseHelper.instance.insertLocalReceipt(localData);
      }

      print('Receipt ${isEditing ? 'updated' : 'saved'} locally: $suitAppsId');

      // NEW: try to push this (and any other pending) receipt to the
      // server right away. It's fire-and-forget - if there's no network
      // this just no-ops, and the row stays isSynced = 0 until
      // ReceiptSyncService's connectivity listener picks it up later.
      // ignore: unawaited_futures
      ReceiptSyncService.instance.trySyncNow();

      _showSuccessDialog();
    } catch (e) {
      print('Error saving receipt: $e');
      _showErrorDialog(
        'Failed to ${widget.receiptToEdit != null ? 'update' : 'save'} receipt.\n\nError: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // ===========================================================================
  //                                   UI
  // ===========================================================================
  // ===========================================================================
  //                                  UI
  // ===========================================================================

  String _modeLabel(PaymentMode m) {
    switch (m) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.cheque:
        return 'Cheque';
      case PaymentMode.gpay:
        return 'GPay';
    }
  }

  IconData _modeIcon(PaymentMode m) {
    switch (m) {
      case PaymentMode.cash:
        return Icons.payments_outlined;
      case PaymentMode.cheque:
        return Icons.receipt_long_outlined;
      case PaymentMode.gpay:
        return Icons.phone_android;
    }
  }

  String _formatMoney(num v) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 2,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.receiptToEdit != null;

    return Scaffold(
      backgroundColor: _bg,

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        toolbarHeight: 54,
        elevation: 0,
        backgroundColor: _primary,
        titleSpacing: 0,
        title: Text(
          isEditing ? 'Edit Receipt' : 'New Receipt',
          style: GoogleFonts.tenorSans(fontSize: 19, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExistingCustomersPage(),
                ),
              );
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer information
              _buildHeaderCard(),

              const SizedBox(height: 18),

              // Payment Mode
              _sectionTitle('Payment mode'),

              const SizedBox(height: 9),

              _buildModeSelector(),

              const SizedBox(height: 18),

              // Payment Details
              _sectionTitle('Payment details'),

              const SizedBox(height: 8),

              // ----------------------------------------------------
              // CHEQUE FIELDS
              // ----------------------------------------------------
              if (_selectedMode == PaymentMode.cheque) ...[
                _buildTextField(
                  controller: _chequeNoController,
                  label: 'Cheque No. *',
                  icon: Icons.confirmation_number_outlined,
                ),

                _buildTextField(
                  controller: _bankController,
                  label: 'Bank Name *',
                  icon: Icons.account_balance_outlined,
                ),

                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: _buildTextField(
                    controller: _chequeDateController,
                    label: 'Cheque Date *',
                    icon: Icons.event_outlined,
                    enabled: false,
                  ),
                ),

                _buildImageUpload(
                  title: 'Cheque image',
                  bytes: _chequeImageBytes,
                  forCheque: true,
                  onRemove: () {
                    setState(() {
                      _chequeImageBytes = null;
                    });
                  },
                ),
              ],

              // ----------------------------------------------------
              // GPAY FIELDS
              // ----------------------------------------------------
              if (_selectedMode == PaymentMode.gpay) ...[
                _buildTextField(
                  controller: _gpayController,
                  label: 'Transaction ID',
                  icon: Icons.tag,
                  hint: 'Enter GPay transaction ID',
                ),

                _buildImageUpload(
                  title: 'GPay screenshot',
                  bytes: _gpayImageBytes,
                  forCheque: false,
                  onRemove: () {
                    setState(() {
                      _gpayImageBytes = null;
                    });
                  },
                ),
              ],

              // ----------------------------------------------------
              // AMOUNT
              // ----------------------------------------------------
              _buildAmountField(),

              // ----------------------------------------------------
              // NARRATION
              // ----------------------------------------------------
              _buildTextField(
                controller: _narrationController,
                label: 'Narration',
                icon: Icons.notes,
                hint: 'Optional description',
                maxLines: 2,
              ),

              const SizedBox(height: 5),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomBar(isEditing),
    );
  }

  // ===========================================================================
  // HEADER CARD - COMPACT
  // ===========================================================================

  Widget _buildHeaderCard() {
    final address = widget.customerAddress;

    return Container(
      width: double.infinity,

      // Reduced from 20
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        // Reduced radius
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================================
          // CUSTOMER
          // ========================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.accountName?.toUpperCase() ?? 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tenorSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(width: 4),

                          Expanded(
                            child: Text(
                              address.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.tenorSans(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Reduced space
          const SizedBox(height: 14),

          // ========================================================
          // RECEIPT NO + DATE
          // ========================================================
          Row(
            children: [
              _headerTile(
                'Receipt No',
                _receiptNoController.text.isEmpty
                    ? '-'
                    : _receiptNoController.text,
                Icons.tag,
              ),

              const SizedBox(width: 8),

              _headerTile(
                'Date',
                DateFormat('dd/MM/yyyy').format(DateTime.now()),
                Icons.calendar_today_outlined,
              ),
            ],
          ),

          // ========================================================
          // OUTSTANDING
          // ========================================================
          if (widget.outstandingAmount != null) ...[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,

              // Smaller height
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Outstanding',
                    style: GoogleFonts.tenorSans(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),

                  Text(
                    _formatMoney(widget.outstandingAmount!),
                    style: GoogleFonts.tenorSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.outstandingAmount! > 0
                          ? Colors.red[700]
                          : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // RECEIPT NO / DATE SMALL BOX
  // ===========================================================================

  Widget _headerTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white70),

            const SizedBox(width: 7),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.tenorSans(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tenorSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 17,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(width: 8),

        Text(
          text,
          style: GoogleFonts.tenorSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PAYMENT MODE - SMALLER BOX
  // ===========================================================================

  Widget _buildModeSelector() {
    final modes = PaymentMode.values;

    return Row(
      children: List.generate(modes.length, (i) {
        final m = modes[i];
        final selected = _selectedMode == m;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == modes.length - 1 ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () {
                setState(() {
                  _selectedMode = m;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),

                // MAIN CHANGE
                // smaller vertical padding
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),

                decoration: BoxDecoration(
                  color: selected ? _primary : Colors.white,

                  borderRadius: BorderRadius.circular(13),

                  border: Border.all(
                    color: selected ? _primary : Colors.grey.shade300,
                  ),

                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _primary.withOpacity(0.20),
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modeIcon(m),

                      // reduced 26 -> 22
                      size: 22,

                      color: selected ? Colors.white : _primary,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _modeLabel(m),
                      style: GoogleFonts.tenorSans(
                        // reduced
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ===========================================================================
  // IMAGE UPLOAD - COMPACT
  // ===========================================================================

  Widget _buildImageUpload({
    required String title,
    required Uint8List? bytes,
    required bool forCheque,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),

      child: bytes == null
          ? InkWell(
              onTap: () {
                _showImageSourceOptions(forCheque: forCheque);
              },
              borderRadius: BorderRadius.circular(13),

              child: Container(
                width: double.infinity,

                // Reduced from 24
                padding: const EdgeInsets.symmetric(vertical: 15),

                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.05),

                  borderRadius: BorderRadius.circular(13),

                  border: Border.all(
                    color: _primary.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: _primary,
                        size: 23,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Upload $title',
                      style: GoogleFonts.tenorSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),

                    const SizedBox(height: 1),

                    Text(
                      'Camera or gallery',
                      style: GoogleFonts.tenorSans(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.memory(
                    bytes,

                    // Reduced from 190
                    height: 150,

                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned(
                  top: 6,
                  right: 6,
                  child: Row(
                    children: [
                      _imageAction(Icons.edit, () {
                        _showImageSourceOptions(forCheque: forCheque);
                      }),

                      const SizedBox(width: 6),

                      _imageAction(
                        Icons.delete_outline,
                        onRemove,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // IMAGE ACTION
  // ===========================================================================

  Widget _imageAction(
    IconData icon,
    VoidCallback onTap, {
    Color color = _primary,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ===========================================================================
  // AMOUNT FIELD - SMALLER
  // ===========================================================================

  Widget _buildAmountField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: _amountController,

        keyboardType: const TextInputType.numberWithOptions(decimal: true),

        style: GoogleFonts.tenorSans(
          // Reduced from 26
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: _primary,
        ),

        decoration:
            _decoration(
              label: 'Amount *',
              icon: Icons.currency_rupee,
              hint: '0.00',
            ).copyWith(
              // Smaller amount box
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM BAR - COMPACT
  // ===========================================================================

  Widget _buildBottomBar(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),

      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: Row(
          children: [
            // =====================================================
            // SAVED BUTTON
            // =====================================================
            Expanded(
              flex: 2,

              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerRecepitPage(
                        partyId: int.tryParse(widget.accountCode ?? '0') ?? 0,
                        partyName: widget.accountName,
                        customerAddress: widget.customerAddress,
                      ),
                    ),
                  );
                },

                icon: const Icon(Icons.history, size: 18),

                label: Text(
                  'Saved',
                  style: GoogleFonts.tenorSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,

                  // Reduced from 54
                  minimumSize: const Size(0, 46),

                  side: const BorderSide(color: _primary, width: 1.4),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // =====================================================
            // SAVE BUTTON
            // =====================================================
            Expanded(
              flex: 3,

              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReceipt,

                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: Colors.grey[400],
                  foregroundColor: Colors.white,

                  // Reduced from 54
                  minimumSize: const Size(0, 46),

                  elevation: 2,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            isEditing ? 'UPDATING...' : 'SAVING...',
                            style: GoogleFonts.tenorSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 19),

                          const SizedBox(width: 6),

                          Flexible(
                            child: Text(
                              isEditing ? 'UPDATE RECEIPT' : 'SAVE RECEIPT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.tenorSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TEXT FIELD DECORATION - COMPACT
  // ===========================================================================

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      labelStyle: GoogleFonts.tenorSans(color: Colors.grey[600], fontSize: 13),

      hintStyle: GoogleFonts.tenorSans(color: Colors.grey[400], fontSize: 13),

      filled: true,

      fillColor: enabled ? Colors.white : Colors.grey[100],

      // =========================================================
      // MAIN FIELD HEIGHT CHANGE
      // =========================================================
      isDense: true,

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      prefixIcon: Icon(icon, color: _primary, size: 21),

      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
    );
  }

  // ===========================================================================
  // NORMAL TEXT FIELD - COMPACT
  // ===========================================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Padding(
      // Reduced from vertical 8
      padding: const EdgeInsets.symmetric(vertical: 5),

      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,

        decoration: _decoration(
          label: label,
          icon: icon,
          hint: hint,
          enabled: enabled,
        ),

        style: GoogleFonts.tenorSans(color: Colors.black87, fontSize: 14),
      ),
    );
  }
}
