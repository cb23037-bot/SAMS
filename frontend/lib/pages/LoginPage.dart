import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import 'ForgotPasswordPage.dart';

/// Initial entry point of the app for unauthenticated users.
///
/// Lets the user pick a role (student or Pusat Adab staff), enter their
/// username/password, and signs in via [AppController.signIn]. On success,
/// [AppController] notifies its listeners and [SamsApp] swaps this page out
/// for the appropriate home page based on the logged-in user's role.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Key used to validate all form fields before attempting sign in.
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Selected user type: 'student', 'adab', 'lecturer', or 'faculty_registrar'.
  /// Must match the role stored in the database for the account, or
  /// [AppController.signIn] will reject it.
  String? _role;

  /// Toggles whether the password field shows plain text or dots.
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form, then attempts to sign in via [AppController].
  ///
  /// The entered username is normalized to a full university email address
  /// (appending the `@adab.umpsa.edu.my` domain if not already present) so
  /// users can type just their username. On failure, the exception message
  /// is shown in a snackbar with the "Exception: " prefix stripped.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _emailController.text.trim().toLowerCase();
    final email = username.endsWith('@adab.umpsa.edu.my')
        ? username
        : '$username@adab.umpsa.edu.my';

    try {
      await widget.controller.signIn(
        role: _role!,
        email: email,
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Builds the login card: logo/branding, role dropdown, email/password
  /// fields, "Forgot password?" link, and the Sign In button.
  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.isLoading;

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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    // ── Header / branding ───────────────────────────────
                    Image.asset(
                      'assets/images/umpsa_logo.png',
                      height: 90,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'UNIVERSITI MALAYSIA PAHANG\nAL-SULTAN ABDULLAH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F3F76),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'SA Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Student Academic System',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6B86),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Role selector ────────────────────────────────────
                    // Determines which role _submit() passes to signIn();
                    // disabled while a sign-in request is already in flight.
                    _Label(
                      title: 'User Type',
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        items: const [
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: 'adab',
                            child: Text('Pusat Adab'),
                          ),
                          DropdownMenuItem(
                            value: 'lecturer',
                            child: Text('Lecturer'),
                          ),
                          DropdownMenuItem(
                            value: 'faculty_registrar',
                            child: Text('Faculty Registrar'),
                          ),
                        ],
                        decoration: _inputDecoration(
                          hintText: 'Select your role',
                          icon: Icons.person_outline,
                        ),
                        validator: (value) =>
                            value == null ? 'Please select a role.' : null,
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _role = value),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Email field ───────────────────────────────────────
                    // Accepts a bare username; _submit() appends the
                    // university domain suffix shown here as a hint.
                    _Label(
                      title: 'Email',
                      child: TextFormField(
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
                    ),

                    const SizedBox(height: 16),

                    // ── Password field ───────────────────────────────────
                    _Label(
                      title: 'Password',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          hintText: 'Enter your password',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            // Toggles the obscureText flag so the user can
                            // reveal/hide what they typed.
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your password.' : null,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Forgot password link ─────────────────────────────
                    // Navigates to the OTP-based password reset flow.
                    Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordPage(controller: widget.controller),
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        )
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Sign in button ───────────────────────────────────
                    // Disabled and replaced with a spinner while
                    // AppController.isLoading is true (request in flight).
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E5BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Color.fromARGB(255, 255, 255, 255))
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shared text field styling used by all inputs on this page.
  ///
  /// [domainSuffix], if provided, is displayed as trailing static text
  /// (e.g. "@adab.umpsa.edu.my") to hint at the email format without the
  /// user needing to type it.
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

/// Small helper widget that renders a bold [title] above an input [child].
/// Used to keep the field labels in the login form consistent.
class _Label extends StatelessWidget {
  const _Label({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}