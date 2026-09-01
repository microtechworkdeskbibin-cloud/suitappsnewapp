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
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final prefix = (widget.accountCode != null && widget.accountCode!.isNotEmpty)
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
    _chequeDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
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
              _chequeDateController.text = DateFormat('dd/MM/yyyy').format(date);
            } catch (e) {
              print('Error parsing cheque date: $e');
              _chequeDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
            }
          }
        }

        // Restore the previously-saved image, if any, so the edit page
        // shows the same cheque/GPay screenshot the user uploaded when
        // the receipt was first saved, instead of an empty upload box.
        if (receipt.chequeImageBase64 != null && receipt.chequeImageBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(receipt.chequeImageBase64!);
            if (mounted) setState(() => _chequeImageBytes = bytes);
          } catch (e) {
            print('Error decoding stored cheque image: $e');
          }
        }
        if (receipt.gpayImageBase64 != null && receipt.gpayImageBase64!.isNotEmpty) {
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
      imageQuality: 70, // compress a bit â€” base64 text in SQLite grows fast on full-res photos
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xFF2D4FA9)),
                title: Text('Camera', style: GoogleFonts.tenorSans()),
                onTap: () {
                  _pickImage(ImageSource.camera, forCheque: forCheque);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFF2D4FA9)),
                title: Text('Gallery', style: GoogleFonts.tenorSans()),
                onTap: () {
                  _pickImage(ImageSource.gallery, forCheque: forCheque);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
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
            colorScheme: ColorScheme.light(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Error', style: GoogleFonts.tenorSans(color: Colors.red)),
          content: Text(message, style: GoogleFonts.tenorSans()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: GoogleFonts.tenorSans(color: Color(0xFF2D4FA9))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Success', style: GoogleFonts.tenorSans(color: Colors.green)),
          content: Text('Receipt ${widget.receiptToEdit != null ? 'updated' : 'saved'} successfully!', style: GoogleFonts.tenorSans()),
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
              child: Text('OK', style: GoogleFonts.tenorSans(color: Color(0xFF2D4FA9))),
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
    _chequeDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
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

      // â”€â”€ Session values (saved at login time in SharedPreferences) â”€â”€
      // Tolerant read: tries the int getter first, then falls back to
      // parsing a String value, and tries a couple of common alternate
      // key spellings â€” same pattern used in DirectSaleOfCustomer._saveBill
      // so every screen agrees on where UserID / FYearID come from.
      final prefs = await SharedPreferences.getInstance();

      // â”€â”€ DEBUG: dump every SharedPreferences key/value once, so you can
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
        debugPrint('âš ï¸  UserID resolved to 0 â€” check the keys actually '
            'saved at login (see DirectSaleOfCustomer for the same check).');
      }
      if (fYearId == 0) {
        debugPrint('âš ï¸  FYearID resolved to 0 â€” check the keys actually '
            'saved at login.');
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
      // bytes for the currently-selected mode are kept â€” cash never writes
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
        'narration': _narrationController.text.isEmpty ? '' : _narrationController.text,
        'chequeNo': _selectedMode == PaymentMode.cheque ? _chequeNoController.text : '',
        'chequeDate': localChequeDate,
        'bankName': _selectedMode == PaymentMode.cheque ? _bankController.text : '',
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
        // database â€” every field change (amount, narration, etc.) was
        // silently discarded. DatabaseHelper.updateLocalReceipt already
        // exists and matches by suitAppsId; just call it.
        await DatabaseHelper.instance.updateLocalReceipt(localData);
      } else {
        localData['createdAt'] = now;
        localData['serverId'] = null;
      }

      // â”€â”€ DEBUG: print the exact payload being written/synced, so you can
      // confirm userId / fYearId (and everything else) are what you expect
      // before it hits the local DB or the sync service. Remove once
      // confirmed.
      debugPrint('ðŸ“¦ Receipt payload -> $localData');

      if (!isEditing) {
        await DatabaseHelper.instance.insertLocalReceipt(localData);
      }

      print('âœ… Receipt ${isEditing ? 'updated' : 'saved'} locally: $suitAppsId');

      // NEW: try to push this (and any other pending) receipt to the
      // server right away. It's fire-and-forget â€” if there's no network
      // this just no-ops, and the row stays isSynced = 0 until
      // ReceiptSyncService's connectivity listener picks it up later.
      // ignore: unawaited_futures
      ReceiptSyncService.instance.trySyncNow();

      _showSuccessDialog();
    } catch (e) {
      print('âŒ Error saving receipt: $e');
      _showErrorDialog('Failed to ${widget.receiptToEdit != null ? 'update' : 'save'} receipt.\n\nError: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.receiptToEdit != null;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 60,
          title: Text(
            isEditing ? 'Edit Receipt' : 'Receipt',
            style: GoogleFonts.tenorSans(
              fontSize: 20,
              color: const Color.fromARGB(255, 240, 232, 232),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ExistingCustomersPage()));
              },
              icon: Icon(Icons.exit_to_app, color: Colors.white),
            ),
          ],
          backgroundColor: const Color(0xFF2D4FA9),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Details Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D4FA9), Color(0xFF5E7DE3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.accountName?.toUpperCase() ?? 'N/A',
                              style: GoogleFonts.tenorSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'ADDRESS: ${widget.customerAddress?.toUpperCase() ?? 'N/A'}',
                              style: GoogleFonts.tenorSans(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'RECEIPT NO: ${_receiptNoController.text}',
                              style: GoogleFonts.tenorSans(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'DATE: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                              style: GoogleFonts.tenorSans(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.outstandingAmount != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'OUTSTANDING: â‚¹${widget.outstandingAmount!.toStringAsFixed(2)}',
                                style: GoogleFonts.tenorSans(
                                  color: Colors.yellowAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.receipt_long,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Payment Mode Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Payment Mode',
                        style: GoogleFonts.tenorSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D4FA9),
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMode>(
                        initialValue: _selectedMode,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode *',
                          labelStyle: GoogleFonts.tenorSans(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2D4FA9), width: 2),
                          ),
                          prefixIcon: Icon(Icons.payment, color: Color(0xFF2D4FA9)),
                        ),
                        items: PaymentMode.values.map((PaymentMode mode) {
                          return DropdownMenuItem<PaymentMode>(
                            value: mode,
                            child: Text(
                              mode.toString().split('.').last.toUpperCase(),
                              style: GoogleFonts.tenorSans(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (PaymentMode? value) {
                          setState(() {
                            _selectedMode = value;
                          });
                        },
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: Color(0xFF2D4FA9)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Conditional fields based on payment mode
              if (_selectedMode == PaymentMode.cheque) ...[
                _buildTextField(
                  controller: _chequeNoController,
                  label: 'Cheque No. *',
                  icon: Icons.receipt,
                ),
                _buildTextField(
                  controller: _bankController,
                  label: 'Bank Name *',
                  icon: Icons.account_balance,
                ),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: _buildTextField(
                    controller: _chequeDateController,
                    label: 'Cheque Date *',
                    icon: Icons.calendar_today,
                    enabled: false,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showImageSourceOptions(forCheque: true),
                        icon: Icon(Icons.image, size: 20),
                        label: Text(
                          'Upload Cheque Image',
                          style: GoogleFonts.tenorSans(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D4FA9),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_chequeImageBytes != null) ...[
                        SizedBox(height: 12),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _chequeImageBytes!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red, size: 30),
                                onPressed: () {
                                  setState(() {
                                    _chequeImageBytes = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_selectedMode == PaymentMode.gpay) ...[
                _buildTextField(
                  controller: _gpayController,
                  label: 'Transaction ID',
                  icon: Icons.payment,
                  hint: 'Enter GPay transaction ID',
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showImageSourceOptions(forCheque: false),
                        icon: Icon(Icons.image, size: 20),
                        label: Text(
                          'Upload GPay Screenshot',
                          style: GoogleFonts.tenorSans(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D4FA9),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_gpayImageBytes != null) ...[
                        SizedBox(height: 12),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _gpayImageBytes!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red, size: 30),
                                onPressed: () {
                                  setState(() {
                                    _gpayImageBytes = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              _buildTextField(
                controller: _amountController,
                label: 'Amount *',
                icon: Icons.currency_rupee,
                hint: 'Enter amount',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              _buildTextField(
                controller: _narrationController,
                label: 'Narration',
                icon: Icons.note,
                hint: 'Optional description',
                maxLines: 2,
              ),
              SizedBox(height: 20),
              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaving ? Colors.grey[400] : Colors.green,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            isEditing ? 'UPDATING...' : 'SAVING...',
                            style: GoogleFonts.tenorSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        isEditing ? 'UPDATE RECEIPT' : 'SAVE RECEIPT',
                        style: GoogleFonts.tenorSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              SizedBox(height: 12),
              // View Receipts Button
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerRecepitPage(
                        partyId: int.tryParse(widget.accountCode ?? '0') ?? 0, // Pass accountCode as int
                        partyName: widget.accountName,
                        customerAddress: widget.customerAddress,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  side: BorderSide(color: Color(0xFF2D4FA9), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'VIEW SAVED RECEIPTS',
                  style: GoogleFonts.tenorSans(
                    color: Color(0xFF2D4FA9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.tenorSans(color: Colors.grey[600]),
          hintStyle: GoogleFonts.tenorSans(color: Colors.grey[400]),
          filled: true,
          fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF2D4FA9), width: 2),
          ),
          prefixIcon: Icon(icon, color: Color(0xFF2D4FA9)),
        ),
        style: GoogleFonts.tenorSans(color: Colors.black87),
      ),
    );
  }
}
