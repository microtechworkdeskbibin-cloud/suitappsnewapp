import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _kIsLoggedIn = 'isLoggedIn';
  static const _kLoginDate = 'loginDate';
  static const _kSessionId = 'sessionId';
  static const _kUser = 'user';

  static const _kSelectedCompanyId = 'SelectedCompanyId';
  static const _kSelectedCompanyName = 'SelectedCompanyName';

  // â”€â”€ NEW: full company details for invoice PDF â”€â”€
  static const _kSelectedCompanyAddress = 'SelectedCompanyAddress';
  static const _kSelectedCompanyGstin = 'SelectedCompanyGstin'; // TinNo
  static const _kSelectedCompanyMobile = 'SelectedCompanyMobile';
  static const _kSelectedCompanyPhone = 'SelectedCompanyPhone';
  static const _kSelectedCompanyCode = 'SelectedCompanyCode';

  static String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static Future<bool> isValidForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
    final savedDate = prefs.getString(_kLoginDate) ?? '';
    return isLoggedIn && savedDate == today();
  }

  static Future<Map<String, dynamic>> getUserDecoded() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_kUser) ?? '{}';
    try {
      return jsonDecode(userStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<String> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSessionId) ?? '';
  }

  static Future<Map<String, String>> getCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "id": prefs.getString(_kSelectedCompanyId) ?? '',
      "name": prefs.getString(_kSelectedCompanyName) ?? '',
    };
  }

  // â”€â”€ NEW: save full company details â”€â”€
  // Call this at login / company selection, right where you currently
  // save _kSelectedCompanyId / _kSelectedCompanyName. Pass in the raw
  // fields from the /api/companies response (see your screenshot):
  // CompanyId, CompanyName, Address, TinNo, MobileNO, TelephoneNo, CompanyCode.
  static Future<void> saveCompanyDetails({
    required String companyId,
    required String companyName,
    required String address,
    required String tinNo,
    required String mobileNo,
    required String telephoneNo,
    required String companyCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedCompanyId, companyId);
    await prefs.setString(_kSelectedCompanyName, companyName);
    await prefs.setString(_kSelectedCompanyAddress, address);
    await prefs.setString(_kSelectedCompanyGstin, tinNo);
    await prefs.setString(_kSelectedCompanyMobile, mobileNo);
    await prefs.setString(_kSelectedCompanyPhone, telephoneNo);
    await prefs.setString(_kSelectedCompanyCode, companyCode);
  }

  // â”€â”€ NEW: read full company details for the invoice PDF â”€â”€
  static Future<CompanySessionDetails> getCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanySessionDetails(
      companyId: prefs.getString(_kSelectedCompanyId) ?? '',
      companyName: prefs.getString(_kSelectedCompanyName) ?? '',
      companyAddress: prefs.getString(_kSelectedCompanyAddress) ?? '',
      companyGstin: prefs.getString(_kSelectedCompanyGstin) ?? '',
      companyMobile: prefs.getString(_kSelectedCompanyMobile) ?? '',
      companyPhone: prefs.getString(_kSelectedCompanyPhone) ?? '',
      companyCode: prefs.getString(_kSelectedCompanyCode) ?? '',
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kLoginDate);
    await prefs.remove(_kSessionId);
    await prefs.remove(_kUser);

    await prefs.remove(_kSelectedCompanyId);
    await prefs.remove(_kSelectedCompanyName);

    // NEW: clear the extended company fields too
    await prefs.remove(_kSelectedCompanyAddress);
    await prefs.remove(_kSelectedCompanyGstin);
    await prefs.remove(_kSelectedCompanyMobile);
    await prefs.remove(_kSelectedCompanyPhone);
    await prefs.remove(_kSelectedCompanyCode);

    // (Optional) keep other keys if you want, or remove them too.
    await prefs.remove('CompanyID');
    await prefs.remove('Username');
    await prefs.remove('Name');
    await prefs.remove('UserId');
    await prefs.remove('UserRoleId');
  }
}

/// Plain data bag returned by SessionStore.getCompanyDetails() â€”
/// used directly by invoice_pdf_service.dart to fill InvoiceData's
/// company* fields without that file needing to know about SharedPreferences.
class CompanySessionDetails {
  final String companyId;
  final String companyName;
  final String companyAddress;
  final String companyGstin;
  final String companyMobile;
  final String companyPhone;
  final String companyCode;

  CompanySessionDetails({
    required this.companyId,
    required this.companyName,
    required this.companyAddress,
    required this.companyGstin,
    required this.companyMobile,
    required this.companyPhone,
    required this.companyCode,
  });
}
