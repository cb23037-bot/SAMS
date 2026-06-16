import 'package:flutter/material.dart';

import '../app/app_controller.dart';

/// Two-step "Forgot password" flow:
///  1. Enter email → backend emails a 6-digit OTP.
///  2. Enter the OTP + a new password to complete the reset.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  /// Validates the email field (step 1, OTP request).
  final _emailFormKey = GlobalKey<FormState>();

  /// Validates the OTP + new password fields (step 2, password reset).
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// True once the OTP has been requested successfully. Switches the UI
  /// from [_buildEmailForm] to [_buildResetForm].
  bool _otpSent = false;

  /// True while an API call (send OTP / reset password) is in flight.
  /// Disables buttons and shows a spinner to prevent duplicate submissions.
  bool _loading = false;

  /// Error message from the last failed API call, shown in red. Null when
  /// there is no error to display.
  String? _error;

  /// Informational message (e.g. "code sent to ..."), shown in green.
  String? _info;

  /// Toggles visibility of the new password field.
  bool _obscurePassword = true;

  /// Toggles visibility of the confirm password field.
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Normalizes the entered username into a full university email address,
  /// appending the `@adab.umpsa.edu.my` domain if the user didn't type it.
  String get _fullEmail {
    final username = _emailController.text.trim().toLowerCase();
    return username.endsWith('@adab.umpsa.edu.my')
        ? username
        : '$username@adab.umpsa.edu.my';
  }

  /// Step 1: requests a 6-digit OTP be emailed to [_fullEmail].
  ///
  /// On success, flips [_otpSent] to true so the UI shows [_buildResetForm].
  /// Also used to "resend" the code from the reset form.
  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await widget.controller.apiService.forgotPassword(email: _fullEmail);
      setState(() {
        _otpSent = true;
        _info = 'A verification code has been sent to $_fullEmail.';
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2: submits the OTP and new password to complete the reset.
  ///
  /// On success, shows a confirmation snackbar and pops back to the login
  /// page so the user can sign in with their new password.
  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await widget.controller.apiService.resetPassword(
        email: _fullEmail,
        otp: _otpController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password has been reset successfully. Please sign in.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Builds the card containing a back button, title, instructional text,
  /// and either [_buildEmailForm] (step 1) or [_buildResetForm] (step 2)
  /// depending on [_otpSent].
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A1F3C88),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Forgot Password',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      _otpSent
                          ? 'Enter the verification code sent to your email along with your new password.'
                          : 'Enter your email address and we\'ll send you a verification code to reset your password.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _otpSent ? _buildResetForm() : _buildEmailForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1 UI: email input + "Send Verification Code" button.
  /// Shown until [_sendOtp] succeeds and [_otpSent] becomes true.
  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            decoration: _inputDecoration(
              hintText: 'Enter your username',
              icon: Icons.email_outlined,
              domainSuffix: '@adab.umpsa.edu.my',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username.';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Verification Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2 UI: OTP, new password, and confirm password fields, plus the
  /// "Reset Password" button and a "Resend code" link (re-triggers [_sendOtp]).
  /// Shown after [_sendOtp] succeeds.
  Widget _buildResetForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_info != null) ...[
            Text(_info!, style: const TextStyle(color: Color(0xFF0EAF4B), fontSize: 13)),
            const SizedBox(height: 16),
          ],
          const Text('Verification Code', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              hintText: 'Enter the 6-digit code',
              icon: Icons.pin_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the verification code.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('New Password', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration(
              hintText: 'Enter your new password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            // Enforce a minimum password length to match backend rules.
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a new password.';
              if (value.length < 8) return 'Password must be at least 8 characters.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: _inputDecoration(
              hintText: 'Re-enter your new password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            // Cross-field validation: must match the new password above.
            validator: (value) {
              if (value != _passwordController.text) return 'Passwords do not match.';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reset Password',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _sendOtp,
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared text field styling used by both the email and reset forms.
  /// [domainSuffix] displays a static hint (e.g. "@adab.umpsa.edu.my") so
  /// the user knows what domain will be appended to their typed username.
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffix,
    String? domainSuffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      suffixText: domainSuffix,
      suffixStyle: const TextStyle(color: Color(0xFF5B6B86), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
      ),
    );
  }
}
