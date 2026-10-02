class ApiConfig {
  // ============================================================
  // BASE URL
  // ============================================================

  // Production
  // static const String baseUrl =
  //     'https://suitapptestapp.suitappssfa.com/api';

  // Production
  // static const String baseUrl ='https://flutterapp.suitapp.in/api';

  // Local development
  static const String baseUrl = 'http://192.168.1.36:5000/api';

  static const String apiBaseUrl = baseUrl;

  // ============================================================
  // TSM / SALES HEAD DASHBOARD
  // ============================================================

  static const String tsmDashboardBase = '/TSMDashboard';

  // GET:
  // /api/TSMDashboard/userHierarchy
  static const String getUserHierarchy = '$tsmDashboardBase/userHierarchy';

  // GET:
  // /api/TSMDashboard/dashboard
  static const String getTSMDashboard = '$tsmDashboardBase/dashboard';

  // ============================================================
  // LOGIN
  // ============================================================

  static const String loginEndpoint = '/login';

  static const String companiesUrl = '/companies';

  static const String insertLoginLogUrl = '/insertLoginLog';

  static const String getFYearIDUrl = '/getFYearID';

  // ============================================================
  // ALLOCATION / BILL
  // ============================================================

  static const String getAllocationDetailsUrl = '/GetAllocationDetails';

  // ============================================================
  // SUITAPP
  // ============================================================

  static const String getrootNameUrl = '/GetRouteName';

  static const String getCustomersUrl = '/GetCustomerDetails';

  static const String sendOtp = '/sendOtp';

  static const String resetPassword = '/resetPassword';

  // ============================================================
  // ATTENDANCE
  // ============================================================

  static const String getAttendanceTypes = '/getAttendanceTypes';

  static const String insertEmployeeAttendance = '/insertEmployeeAttendance';

  static const String checkTodayAttendance = '/checkTodayAttendance';

  // ============================================================
  // LEAVE
  // ============================================================

  static const String getLeaveTypes = '/getLeaveTypes';

  static const String insertLeaveRequest = '/insertLeaveRequest';

  static const String getAllRootsByEmp = '/getAllRootsByEmp';

  // ============================================================
  // REPORT HISTORY
  // ============================================================

  static const String getOutstanding = '/GetOutstanding';

  static const String getNotApprovalCheque = '/GetNotApprovalCheque';

  static const String getSalesHistory = '/GetSalesHistory';

  static const String getReceiptsHistoryByID = '/GetReceiptsHistoryByID';

  static const String getBillingReturnHistory = '/GetBillingReturnHistory';

  // ============================================================
  // ODOMETER
  // ============================================================

  static const String insertOdometer = '/saveOdometer';

  // ============================================================
  // ITEM / VAN SYNC
  // ============================================================

  static const String getItemCategoryUrl = '/GetItemCategory';

  static const String getVanItemsUrl = '/GetVanItems';

  // ============================================================
  // BILLING
  // ============================================================

  static const String insertBillingDetails = '/syncBillingDetailsApp';

  static const String insertBilling = '/syncBillingApp';

  // ============================================================
  // ORDER
  // ============================================================

  static const String insertOrder = '/syncSaleOrderApp';

  // ============================================================
  // CUSTOMER
  // ============================================================

  static const String insertCustomer = '/InsertUpdateCustomer';

  static const String getDistributorsUrl = '/GetDistributors';

  static const String getDistributorsByUserUrl = '/GetDistributorByUser';

  static const String getDistributorCustomerOrdersUrl =
      '/GetDistributorCustomerOrders';

  // ============================================================
  // RECEIPT
  // ============================================================

  static const String insertreceipt = '/syncReceiptApp';

  // ============================================================
  // PERMISSIONS
  // ============================================================

  static const String getPermissionsUrl = '/GetPermissions';

  // ============================================================
  // TIMEOUT
  // ============================================================

  static const Duration connectionTimeout = Duration(seconds: 30);

  static const Duration receiveTimeout = Duration(seconds: 30);
}
