class ReceiptCustModel {
  int? slno;
  String? rDate;
  int? partyID;
  String? partyName;
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
  String? vouchernum;

  ReceiptCustModel({
    this.slno,
    this.rDate,
    this.partyID,
    this.partyName,
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
    this.vouchernum,
  });

  factory ReceiptCustModel.fromJson(Map<String, dynamic> json) {
    return ReceiptCustModel(
      slno: json['Slno'],
      rDate: json['RDate'],
      partyID: json['PartyID'],
      partyName: json['PartyName'],
      amt: json['Amt'],
      type: json['Type'],
      chkNo: json['ChkNo'],
      chkDate: json['ChkDate'],
      remark: json['Remark'],
      companyid: json['Companyid'],
      isdeleted: json['Isdeleted'],
      routeID: json['RouteID'],
      approvalStatus: json['ApprovalStatus'],
      chequeApprovedDate: json['ChequeApprovedDate'],
      fYearID: json['FYearID'],
      drHead: json['DrHead'],
      userID: json['UserID'],
      pBank: json['PBank'],
      vouchernum: json['vouchernum'],
    );
  }

  /// Builds a ReceiptCustModel from a row of the LOCAL sqlite `receipts`
  /// table (see DatabaseHelper._createReceiptsTable / insertLocalReceipt).
  /// The local table's column names don't match the server JSON keys above
  /// (e.g. 'accountCode' instead of 'PartyID', 'amount' instead of 'Amt'),
  /// so this is a separate factory rather than reusing fromJson.
  ///
  /// partyName is populated from the local 'accountName' column, which
  /// Receiptpage._saveReceipt() writes per-row at save time — this lets a
  /// receipt still show the right customer name even if the caller (e.g.
  /// CustomerRecepitPage) doesn't have a partyName in its own widget
  /// context, or if it later differs from the row's original customer.
  ///
  /// Fields the local DB doesn't store (companyid, isdeleted, routeID,
  /// fYearID, drHead, userID, chequeApprovedDate) are left null.
  /// 
 factory ReceiptCustModel.fromMap(Map<String, dynamic> map) {
  return ReceiptCustModel(
    slno: map['id'] is int
        ? map['id'] as int
        : int.tryParse(map['id']?.toString() ?? ''),

    rDate: (map['createdAt'] ?? map['updatedAt'])?.toString(),

    partyID: int.tryParse(
      map['accountCode']?.toString() ?? '',
    ),

    // IMPORTANT
    partyName: map['accountName']?.toString(),

    amt: map['amount'] is num
        ? (map['amount'] as num).round()
        : int.tryParse(map['amount']?.toString() ?? ''),

    type: map['paymentType']?.toString(),
    chkNo: map['chequeNo']?.toString(),
    chkDate: map['chequeDate']?.toString(),
    remark: map['narration']?.toString(),

    approvalStatus: map['approvalStatus'] is int
        ? map['approvalStatus'] as int
        : int.tryParse(
            map['approvalStatus']?.toString() ?? '',
          ),

    pBank: map['bankName']?.toString(),

    vouchernum:
        (map['serverId'] ?? map['suitAppsId'])?.toString(),
  );
}
  // factory ReceiptCustModel.fromMap(Map<String, dynamic> map) {
  //   return ReceiptCustModel(
  //     slno: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
  //     rDate: (map['createdAt'] ?? map['updatedAt'])?.toString(),
  //     partyID: int.tryParse(map['accountCode']?.toString() ?? ''),
  //     partyName: (map['accountName']?.toString().isNotEmpty ?? false)
  //         ? map['accountName'].toString()
  //         : null,
  //     amt: map['amount'] is num
  //         ? (map['amount'] as num).round()
  //         : int.tryParse(map['amount']?.toString() ?? ''),
  //     type: map['paymentType']?.toString(),
  //     chkNo: map['chequeNo']?.toString(),
  //     chkDate: map['chequeDate']?.toString(),
  //     remark: map['narration']?.toString(),
  //     approvalStatus: map['approvalStatus'] is int
  //         ? map['approvalStatus'] as int
  //         : int.tryParse(map['approvalStatus']?.toString() ?? ''),
  //     pBank: map['bankName']?.toString(),
  //     // No dedicated voucher-number column locally; fall back to whichever
  //     // id the row has (server id once synced, otherwise the local one).
  //     vouchernum: (map['serverId'] ?? map['suitAppsId'])?.toString(),
  //   );
  // }

  get accountName => null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Slno'] = slno;
    data['RDate'] = rDate;
    data['PartyID'] = partyID;
    data['PartyName'] = partyName;
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
    data['vouchernum'] = vouchernum;
    return data;
  }
}

class GetReceiptResponse {
  List<ReceiptCustModel>? receipts;

  GetReceiptResponse({this.receipts});

  factory GetReceiptResponse.fromJson(Map<String, dynamic> json) {
    return GetReceiptResponse(
      receipts: json['receipts'] != null
          ? (json['receipts'] as List).map((v) => ReceiptCustModel.fromJson(v)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (receipts != null) {
      data['receipts'] = receipts!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}