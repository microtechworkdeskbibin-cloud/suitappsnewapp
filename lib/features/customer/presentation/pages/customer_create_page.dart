import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:suitapps/features/customer/data/models/customer_model.dart';
import 'package:suitapps/features/customer/data/datasources/customer_local_datasource.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage>
    with TickerProviderStateMixin {
  // â”€â”€â”€ Design System â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const Color primary = Color.fromARGB(255, 35, 0, 196);
  static const Color primaryLight = Color(0xFF6F7FDB);
  static const Color bgColor = Color(0xFFF5F7FB);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFF59E0B);

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Border Radius
  static const double radiusCard = 16;
  static const double radiusButton = 12;
  static const double radiusField = 12;
  static const double radiusBadge = 10;

  // Shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // â”€â”€â”€ Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _autoValidate = false;

  final _gstinCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();

  String? _customerType;
  String? _rateType;
  String? _customerCategory;

  File? _selectedImage;
  final List<File> _additionalImages = [];
  final _picker = ImagePicker();

  final List<String> _types = ['Type1', 'Type2'];
  final List<String> _rateTypes = ['Rate1', 'Rate2'];
  final List<String> _categories = ['Retail', 'Wholesale'];

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _gstinCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _pinCtrl.dispose();
    _placeCtrl.dispose();
    _discountCtrl.dispose();
    _creditDaysCtrl.dispose();
    super.dispose();
  }

  // â”€â”€â”€ Image Picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Future<void> _pickImage() async {
  //   final XFile? image = await _picker.pickImage(
  //     source: ImageSource.gallery,
  //     imageQuality: 80,
  //   );
  //   if (image != null) {
  //     setState(() => _selectedImage = File(image.path));
  //   }
  // }
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  //multiple images
  Future<void> _addAdditionalImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image != null) {
      setState(() {
        _additionalImages.add(File(image.path));
      });
    }
  }

  // â”€â”€â”€ Validators â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  String? _validateCustomerName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Customer Name is required';
    if (v.trim().length < 3) return 'Minimum 3 characters required';
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'Address is required';
    if (v.trim().length < 5) return 'Minimum 5 characters required';
    return null;
  }

  String? _validateGSTIN(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final regex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    );
    if (!regex.hasMatch(v.trim().toUpperCase())) {
      return 'Enter a valid 15-character GSTIN (e.g. 22AAAAA0000A1Z5)';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validateMobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validatePin(String? v) {
    if (v == null || v.trim().isEmpty) return 'PIN code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
      return 'Enter a valid 6-digit PIN';
    }
    return null;
  }

  String? _validateDiscount(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d < 0 || d > 100) return 'Must be between 0 and 100';
    return null;
  }

  String? _validateCreditDays(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = int.tryParse(v.trim());
    if (d == null || d < 0 || d > 365) return 'Must be between 0 and 365';
    return null;
  }

  // â”€â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _save() async {
    setState(() => _autoValidate = true);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showSnack('Please fill in the required fields.', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final exists = await CustomerService().customerExists(
        _mobileCtrl.text.trim(),
      );

      if (exists) {
        _showSnack(
          'Customer already exists with this mobile number',
          isError: true,
        );
        setState(() => _isSaving = false);
        return;
      }
      final customer = CustomerModel(
        gstinNo: _gstinCtrl.text.trim().toUpperCase(),
        customerName: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        type: _customerType ?? '',
        customerType: _customerCategory ?? '',
        rateType: _rateType ?? '',
        email: _emailCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        pinNo: _pinCtrl.text.trim(),
        place: _placeCtrl.text.trim(),
        discountPercentage: _discountCtrl.text.trim(),
        creditDays: _creditDaysCtrl.text.trim(),
        imagePath: _selectedImage?.path ?? '',
        additionalImages: _additionalImages.map((e) => e.path).toList(),
      );
      final id = await CustomerService().insertCustomer(customer);
      debugPrint('Customer saved with ID: $id');
      if (!mounted) return;
      _showSnack('Customer saved successfully!', isError: false);
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
      if (!mounted) return;
      _showSnack('Failed to save customer.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: sm),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? errorColor : successColor,
      ),
    );
  }

  // â”€â”€â”€ UI Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Shared InputDecoration
  InputDecoration _inputDec(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      filled: true,
      fillColor: bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: errorColor,
      ),
    );
  }

  /// Label with optional required star
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: xs + 2),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  /// Text field with label above
  Widget _field(
    String labelText, {
    required TextEditingController ctrl,
    String? hint,
    bool isRequired = false,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(labelText, required: isRequired),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          textCapitalization: capitalization,
          inputFormatters: formatters,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
          decoration: _inputDec('', hint: hint, prefixIcon: prefixIcon),
        ),
      ],
    );
  }

  /// Dropdown with label above
  Widget _dropdown({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isRequired = false,
    String? Function(String?)? validator,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(labelText, required: isRequired),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: _inputDec('', prefixIcon: prefixIcon),
          autovalidateMode: _autoValidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          validator: validator,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textSecondary,
            size: 20,
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
          dropdownColor: cardBg,
          borderRadius: BorderRadius.circular(radiusCard),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Section header with icon badge
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: lg),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(radiusBadge),
            ),
            child: Icon(icon, color: primary, size: 16),
          ),
          const SizedBox(width: md),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Card container
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(radiusCard),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }

  /// Vertical gap between fields
  Widget _gap([double size = md]) => SizedBox(height: size);

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(lg, lg, lg, xxl),
            children: [
              _buildProfileCard(),
              _gap(sm),
              _buildGSTINCard(),
              _gap(sm),
              _buildCustomerInfoCard(),
              _gap(sm),
              _buildContactCard(),
              _gap(sm),
              _buildAddressCard(),
              _gap(sm),
              // _buildFinancialCard(),
              // _gap(lg),
              // _buildSaveButton(),
              _buildFinancialCard(),
              _gap(sm),

              _buildAdditionalImagesCard(),

              _gap(lg),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'New Customer',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  // â”€â”€â”€ Profile Card â€” compact horizontal avatar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildProfileCard() {
    return _card(
      child: GestureDetector(
        onTap: _pickImage,
        child: Row(
          children: [
            // Avatar â€” 56Ã—56
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          size: 26,
                          color: primary,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedImage == null ? 'Upload Photo' : 'Change Photo',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: xs),
                Text(
                  'Tap avatar to take a photo',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ GSTIN Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildGSTINCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('GST Information', Icons.receipt_long_rounded),
          _field(
            'GSTIN Number',
            ctrl: _gstinCtrl,
            hint: '22AAAAA0000A1Z5',
            capitalization: TextCapitalization.characters,
            formatters: [
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(15),
            ],
            prefixIcon: const Icon(
              Icons.tag_rounded,
              size: 18,
              color: textSecondary,
            ),
            validator: _validateGSTIN,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Customer Info Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCustomerInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Customer Details', Icons.person_rounded),
          _field(
            'Customer Name',
            isRequired: true,
            ctrl: _nameCtrl,
            capitalization: TextCapitalization.words,
            prefixIcon: const Icon(
              Icons.badge_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: _validateCustomerName,
          ),
          _gap(),
          _field(
            'Address',
            isRequired: true,
            ctrl: _addressCtrl,
            maxLines: 3,
            keyboard: TextInputType.multiline,
            capitalization: TextCapitalization.sentences,
            prefixIcon: const Icon(
              Icons.home_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: _validateAddress,
          ),
          _gap(),
          _dropdown(
            labelText: 'Type',
            value: _customerType,
            items: _types,
            prefixIcon: const Icon(
              Icons.category_outlined,
              size: 18,
              color: textSecondary,
            ),
            onChanged: (v) => setState(() => _customerType = v),
          ),
          _gap(),
          // Category + Rate Type â€” 2-column row
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  labelText: 'Category',
                  value: _customerCategory,
                  items: _categories,
                  onChanged: (v) => setState(() => _customerCategory = v),
                ),
              ),
              const SizedBox(width: sm),
              Expanded(
                child: _dropdown(
                  labelText: 'Rate Type',
                  value: _rateType,
                  items: _rateTypes,
                  onChanged: (v) => setState(() => _rateType = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Contact Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildContactCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Contact Information', Icons.contact_phone_rounded),
          _field(
            'Email Address',
            ctrl: _emailCtrl,
            keyboard: TextInputType.emailAddress,
            prefixIcon: const Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: textSecondary,
            ),
            validator: _validateEmail,
          ),
          _gap(),
          // Mobile + Phone â€” 2-column row
          _field(
            'Mobile',
            isRequired: true,
            ctrl: _mobileCtrl,
            keyboard: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixIcon: const Icon(
              Icons.smartphone_rounded,
              size: 18,
              color: textSecondary,
            ),
            validator: _validateMobile,
          ),

          _gap(),

          _field(
            'Phone',
            ctrl: _phoneCtrl,
            keyboard: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixIcon: const Icon(
              Icons.phone_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: _validatePhone,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Address Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAddressCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Location Details', Icons.location_on_rounded),
          // City + PIN â€” 2-column row
          _field(
            'City',
            isRequired: true,
            ctrl: _cityCtrl,
            capitalization: TextCapitalization.words,
            prefixIcon: const Icon(
              Icons.location_city_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: (v) => _required(v, 'City'),
          ),

          _gap(),

          _field(
            'PIN Code',
            isRequired: true,
            ctrl: _pinCtrl,
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            prefixIcon: const Icon(
              Icons.pin_drop_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: _validatePin,
          ),
          _gap(),
          _field(
            'Country',
            ctrl: _countryCtrl,
            capitalization: TextCapitalization.words,
            prefixIcon: const Icon(
              Icons.public_rounded,
              size: 18,
              color: textSecondary,
            ),
          ),
          _gap(),
          _field(
            'Place',
            isRequired: true,
            ctrl: _placeCtrl,
            capitalization: TextCapitalization.words,
            prefixIcon: const Icon(
              Icons.place_outlined,
              size: 18,
              color: textSecondary,
            ),
            validator: (v) => _required(v, 'Place'),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Financial Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFinancialCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Financial Settings',
            Icons.account_balance_wallet_outlined,
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Discount %',
                  ctrl: _discountCtrl,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  prefixIcon: const Icon(
                    Icons.percent_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  validator: _validateDiscount,
                ),
              ),
              const SizedBox(width: sm),
              Expanded(
                child: _field(
                  'Credit Days',
                  ctrl: _creditDaysCtrl,
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  prefixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: textSecondary,
                  ),
                  validator: _validateCreditDays,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalImagesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Additional Images', Icons.photo_library_outlined),

          ElevatedButton.icon(
            onPressed: _addAdditionalImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture Image'),
          ),

          const SizedBox(height: 12),

          if (_additionalImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                _additionalImages.length,
                (index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _additionalImages[index],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _additionalImages.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Save Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryLight.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 18),
                  SizedBox(width: sm),
                  Text(
                    'Save Customer',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// â”€â”€â”€ Formatter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
