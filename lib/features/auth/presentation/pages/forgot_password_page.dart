import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:suitapps/core/config/api_config.dart';

// class ForgotPasswordPage extends StatefulWidget {
//   const ForgotPasswordPage({super.key});

//   @override
//   State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
// }

// class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
//   final emailCtrl = TextEditingController();
//   final otpCtrl = TextEditingController();
//   final passCtrl = TextEditingController();

//   bool otpSent = false;
//   bool loading = false;

//   Future<void> sendOtp() async {
//     setState(() => loading = true);

//     final res = await http.post(
//       Uri.parse('${ApiConfig.baseUrl}/sendOtp'),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"Email": emailCtrl.text.trim()}),
//     );

//     setState(() => loading = false);

//     final data = jsonDecode(res.body);

//     if (data["Success"] == 1) {
//       setState(() => {otpSent = true});

//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("OTP sent to email")));
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(data["Message"])));
//     }
//   }

//   Future<void> resetPassword() async {
//     setState(() => loading = true);

//     final res = await http.post(
//       Uri.parse('${ApiConfig.baseUrl}/resetPassword'),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "Email": emailCtrl.text.trim(),
//         "OTP": otpCtrl.text.trim(),
//         "NewPassword": passCtrl.text,
//       }),
//     );

//     setState(() => loading = false);

//     final data = jsonDecode(res.body);

//     if (data["Success"] == 1) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text("Success"),
//           content: const Text("Password changed"),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 Navigator.pop(context);
//               },
//               child: const Text("OK"),
//             ),
//           ],
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(data["Message"])));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Forgot Password")),

//       body: Padding(
//         padding: const EdgeInsets.all(20),

//         child: Column(
//           children: [
//             TextField(
//               controller: emailCtrl,
//               decoration: const InputDecoration(labelText: "Email"),
//             ),

//             if (otpSent) ...[
//               TextField(
//                 controller: otpCtrl,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(labelText: "OTP"),
//               ),

//               TextField(
//                 controller: passCtrl,
//                 obscureText: true,
//                 decoration: const InputDecoration(labelText: "New Password"),
//               ),

//               const SizedBox(height: 20),

//               ElevatedButton(
//                 onPressed: loading ? null : resetPassword,
//                 child: const Text("Reset Password"),
//               ),
//             ] else
//               ElevatedButton(
//                 onPressed: loading ? null : sendOtp,
//                 child: const Text("Send OTP"),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool otpSent = false;
  bool loading = false;
  bool obscurePass = true;

  // â”€â”€ Design tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _primaryBlue = Color(0xFF1433C3);
  static const _secondaryBlue = Color(0xFF6F7FDB);
  static const _background = Color(0xFFF5F7FB);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _errorColor = Color(0xFFDC2626);
  static const _primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primaryBlue, _secondaryBlue],
  );

  Future<void> sendOtp() async {
    setState(() => loading = true);
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/sendOtp'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"Email": emailCtrl.text.trim()}),
    );
    setState(() => loading = false);
    final data = jsonDecode(res.body);
    if (data["Success"] == 1) {
      setState(() => otpSent = true);
      _showSnack("Code sent â€” check your inbox", isError: false);
    } else {
      _showSnack(data["Message"], isError: true);
    }
  }

  Future<void> resetPassword() async {
    setState(() => loading = true);
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/resetPassword'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "Email": emailCtrl.text.trim(),
        "OTP": otpCtrl.text.trim(),
        "NewPassword": passCtrl.text,
      }),
    );
    setState(() => loading = false);
    final data = jsonDecode(res.body);
    if (data["Success"] == 1) {
      _showSuccessDialog();
    } else {
      _showSnack(data["Message"], isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
        backgroundColor: isError ? _errorColor : _primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: _primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Password updated',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              const SizedBox(height: 8),
              const Text('You can now sign in with your new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: _textSecondary)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  label: 'Back to Sign In',
                  gradient: _primaryGradient,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildHero(),
            const SizedBox(height: 16),
            _buildStepIndicator(),
            const SizedBox(height: 16),
            _buildCard(),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Hero â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: _primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Reset your password',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          otpSent
              ? 'Check your inbox. Enter the code and your new password below.'
              : "Enter your email and we'll send you a one-time code to get back in.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // â”€â”€ Step Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(label: 'Email', active: true),
        _StepLine(done: otpSent),
        _StepDot(label: 'Verify OTP', active: otpSent),
        _StepLine(done: false),
        _StepDot(label: 'New Password', active: otpSent),
      ],
    );
  }

  // â”€â”€ Main Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            label: 'EMAIL ADDRESS',
            hint: 'you@example.com',
            controller: emailCtrl,
            icon: Icons.mail_outline_rounded,
            enabled: !otpSent,
            keyboardType: TextInputType.emailAddress,
          ),
          if (otpSent) ...[
            const SizedBox(height: 16),
            _OtpHint(),
            const SizedBox(height: 16),
            _buildField(
              label: 'ONE-TIME CODE',
              hint: '5-digit code',
              controller: otpCtrl,
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDivider('NEW PASSWORD'),
            const SizedBox(height: 16),
            _buildPasswordField(),
          ],
          const SizedBox(height: 20),
          _GradientButton(
            label: otpSent ? 'Reset Password' : 'Send Code',
            gradient: _primaryGradient,
            loading: loading,
            icon: otpSent
                ? Icons.check_circle_outline_rounded
                : Icons.send_rounded,
            onTap: loading ? null : (otpSent ? resetPassword : sendOtp),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontFamily: 'Inter', fontSize: 14, color: _textSecondary),
            prefixIcon:
                Icon(icon, size: 16, color: _textSecondary),
            filled: true,
            fillColor: enabled ? _background : _border.withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NEW PASSWORD',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: passCtrl,
          obscureText: obscurePass,
          style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'At least 8 characters',
            hintStyle: const TextStyle(
                fontFamily: 'Inter', fontSize: 14, color: _textSecondary),
            prefixIcon:
                const Icon(Icons.lock_outline_rounded, size: 16, color: _textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: _textSecondary,
              ),
              onPressed: () => setState(() => obscurePass = !obscurePass),
            ),
            filled: true,
            fillColor: _background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary)),
        ),
        const Expanded(child: Divider(color: _border, thickness: 1)),
      ],
    );
  }
}

// â”€â”€ Supporting widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  const _StepDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                active ? const Color(0xFF1433C3) : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active
                ? const Color(0xFF1433C3)
                : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 32,
        height: 1.5,
        color: done
            ? const Color(0xFF1433C3)
            : const Color(0xFFE5E7EB),
      ),
    );
  }
}

class _OtpHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFF1433C3)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'A 5-digit code was sent to your email. It expires in 5 minutes.',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1433C3),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.gradient,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1433C3).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
