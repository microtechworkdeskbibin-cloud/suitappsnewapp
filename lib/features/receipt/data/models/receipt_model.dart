class ReceiptModel {
  int? slno;
  String? rDate;
  int? partyID;
  String? CustomerName;
  int? amt;
  String? type;
  String? chkNo;
  String? chkDate;
  String? remark;
  int? companyid;
  int? isdeleted;
  int? routeID;
  int? approvalStatus;
  String? chequeApprovedDate;
  int? fYearID;
  int? drHead;
  int? userID;
  String? pBank;
  String? SuitAppId;
  // Base64-encoded image data, read straight from the local
  // chequeImagePath / gpayImagePath columns (see DatabaseHelper /
  // Receiptpage._saveReceipt, which base64-encodes the picked bytes
  // before writing them to those columns). Only populated by fromMap —
  // the server JSON response (fromJson) doesn't carry these.
  String? chequeImageBase64;
  String? gpayImageBase64;
  ////Billing///////
  int? billID;
  int? billNo;
  String? billDate;
  int? billAmount;
  int? pendingAmount;
  int? paidAmount;
  int? appliedAmount;
  int? extraAmount;

  ReceiptModel({
    this.slno,
    this.rDate,
    this.partyID,
    this.CustomerName,
    this.amt,
    this.type,
    this.chkNo,
    this.chkDate,
    this.remark,
    this.companyid,
    this.isdeleted,
    this.routeID,
    this.approvalStatus,
    this.chequeApprovedDate,
    this.fYearID,
    this.drHead,
    this.userID,
    this.pBank,
    String? suitappId,
    /////Billing//////
    this.billID,
    this.billNo,
    this.billDate,
    this.billAmount,
    this.pendingAmount,
    this.paidAmount,
    this.appliedAmount,
    this.extraAmount,
  });

  // Safe integer parsing
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  // Safe string parsing
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  ReceiptModel.fromJson(Map<String, dynamic> json) {
    try {
      slno = _parseInt(json['Slno']);
      rDate = _parseString(json['RDate']);
      partyID = _parseInt(json['PartyID']);
      CustomerName = _parseString(json['CustomerName']);
      amt = _parseInt(json['Amt']);
      type = _parseString(json['Type']);
      chkNo = _parseString(json['ChkNo']);
      chkDate = _parseString(json['ChkDate']);
      remark = _parseString(json['Remark']);
      companyid = _parseInt(json['Companyid']);
      isdeleted = _parseInt(json['Isdeleted']);
      routeID = _parseInt(json['RouteID']);
      approvalStatus = _parseInt(json['ApprovalStatus']);
      chequeApprovedDate = _parseString(json['ChequeApprovedDate']);
      fYearID = _parseInt(json['FYearID']);
      drHead = _parseInt(json['DrHead']);
      userID = _parseInt(json['UserID']);
      pBank = _parseString(json['PBank']);
      SuitAppId = _parseString(json['Vouchernum']);
      /////////Billing/////////
      billID = _parseInt(json['BillID']);
      billNo = _parseInt(json['BillNo']);
      billDate = _parseString(json['BillDate']);
      billAmount = _parseInt(json['BillAmount']);
      pendingAmount = _parseInt(json['PendingAmount']);
      paidAmount = _parseInt(json['PaidAmount']);
      appliedAmount = _parseInt(json['AppliedAmount']);
      extraAmount = _parseInt(json['ExtraAmount']);

    } catch (e) {
      print('Error parsing ReceiptModel: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  /// Builds a ReceiptModel from a row of the LOCAL sqlite `receipts` table
  /// (see DatabaseHelper._createReceiptsTable / insertLocalReceipt). Those
  /// column names ('accountCode', 'amount', 'paymentType', 'chequeNo',
  /// 'bankName', 'chequeDate', 'narration', 'createdAt', 'serverId', etc.)
  /// don't match the server JSON keys used by fromJson above, so this is a
  /// separate constructor rather than reusing it.
  ///
  /// Fields the local table doesn't store — companyid, isdeleted, fYearID,
  /// drHead, userID, and every Billing field (billID, billNo, billDate,
  /// billAmount, pendingAmount, paidAmount, appliedAmount, extraAmount) —
  /// are left null. Those only ever come from the server response
  /// (fromJson), not from a locally-saved receipt.
  ReceiptModel.fromMap(Map<String, dynamic> map) {
    try {
      slno = _parseInt(map['id']);
      rDate = _parseString(map['createdAt'] ?? map['updatedAt']);
      partyID = _parseInt(map['accountCode']);
      // FIXED: this mapping was missing entirely, so CustomerName was
      // always null for every locally-saved receipt and ReceiptListPage
      // showed 'N/A' on every card. The local `receipts` table stores the
      // name under 'accountName' (see DatabaseHelper.insertLocalReceipt /
      // Receiptpage._saveReceipt) — same source ReceiptCustModel.fromMap
      // already reads correctly for its partyName field.
      CustomerName = _parseString(map['accountName']);
      amt = _parseInt(map['amount']);
      type = _parseString(map['paymentType']);
      chkNo = _parseString(map['chequeNo']);
      chkDate = _parseString(map['chequeDate']);
      remark = _parseString(map['narration']);
      approvalStatus = _parseInt(map['approvalStatus']);
      pBank = _parseString(map['bankName']);
      routeID = _parseInt(map['rootId']);
      // No dedicated voucher-number column locally; fall back to the
      // server id once synced, otherwise the local suitAppsId.
      SuitAppId = _parseString(map['serverId'] ?? map['suitAppsId']);
      // FIXED: previously not read at all, so Receiptpage._loadEditData
      // had no way to restore a saved cheque/GPay image when editing —
      // the "Upload Image" section always looked empty even though the
      // base64 data was sitting in the local row. Empty-string columns
      // (never uploaded) are normalized to null so Receiptpage's
      // isNotEmpty check behaves correctly either way.
      final chequeImg = _parseString(map['chequeImagePath']);
      chequeImageBase64 = (chequeImg != null && chequeImg.isNotEmpty) ? chequeImg : null;
      final gpayImg = _parseString(map['gpayImagePath']);
      gpayImageBase64 = (gpayImg != null && gpayImg.isNotEmpty) ? gpayImg : null;
    } catch (e) {
      print('Error parsing ReceiptModel from local row: $e');
      print('Row data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Slno'] = slno;
    data['RDate'] = rDate;
    data['PartyID'] = partyID;
    data['CustomerName'] = CustomerName;
    data['Amt'] = amt;
    data['Type'] = type;
    data['ChkNo'] = chkNo;
    data['ChkDate'] = chkDate;
    data['Remark'] = remark;
    data['Companyid'] = companyid;
    data['Isdeleted'] = isdeleted;
    data['RouteID'] = routeID;
    data['ApprovalStatus'] = approvalStatus;
    data['ChequeApprovedDate'] = chequeApprovedDate;
    data['FYearID'] = fYearID;
    data['DrHead'] = drHead;
    data['UserID'] = userID;
    data['PBank'] = pBank;
    data['Vouchernum'] = SuitAppId;
    ////////Billing////////////
    data['BillID'] = billID;
    data['BillNo'] = billNo;
    data['BillDate'] = billDate;
    data['BillAmount'] = billAmount;
    data['PendingAmount'] = pendingAmount;
    data['PaidAmount'] = paidAmount;
    data['AppliedAmount'] = appliedAmount;
    data['ExtraAmount'] = extraAmount;
    return data;
  }
}