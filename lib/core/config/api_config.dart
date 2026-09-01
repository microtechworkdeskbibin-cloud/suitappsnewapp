class ApiConfig {
  // Base URL for API endpoints


// static const String baseUrl = 'https://flutterapp.suitapp.in/api';
   static const String baseUrl = 'http://192.168.1.41:5000/api';


  // Full API base URL with version
  static const String apiBaseUrl = baseUrl;


  static const String insertreceipt = '/syncReceiptApp';
  // Common endpoints
  static const String loginEndpoint = '/login';
  static const String companiesUrl = '/companies';
  static const String insertLoginLogUrl = '/insertLoginLog';
  static const String getFYearIDUrl = '/getFYearID';
  // Allocation / bill numbers
  static const String getAllocationDetailsUrl = '/GetAllocationDetails';
  
  //suitapp
  static const String getrootNameUrl = '/GetRouteName';  
  static const String getCustomersUrl = '/GetCustomerDetails';
  static const String sendOtp = '/sendOtp';
  static const String resetPassword = '/resetPassword';
  static const String getAttendanceTypes = '/getAttendanceTypes';
  static const String insertEmployeeAttendance = '/insertEmployeeAttendance';
  static const String checkTodayAttendance = '/checkTodayAttendance';
  static const String getLeaveTypes = '/getLeaveTypes';
  static const String insertLeaveRequest = '/insertLeaveRequest';
  // static const String getLeaveRequests = '/getLeaveRequests';
  static const String getAllRootsByEmp = '/getAllRootsByEmp';
  //report history
  static const String getOutstanding = '/GetOutstanding';
  static const String getNotApprovalCheque = '/GetNotApprovalCheque';
  static const String getSalesHistory = '/GetSalesHistory';
  static const String getReceiptsHistoryByID = '/GetReceiptsHistoryByID';
  static const String getBillingReturnHistory = '/GetBillingReturnHistory';
  //odometer
  static const String insertOdometer = '/saveOdometer';

  // Item / Van sync endpoints
  static const String getItemCategoryUrl = '/GetItemCategory';
  static const String getVanItemsUrl = '/GetVanItems';


    // Billing / Van sync endpoints
  static const String insertBillingDetails = '/syncBillingDetailsApp';
  static const String insertBilling = '/syncBillingApp';

    // Order 
  static const String insertOrder = '/syncSaleOrderApp';


  static const String getPermissionsUrl = '/GetPermissions';
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
         