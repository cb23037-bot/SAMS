// login_screen.dart — Boundary Screen
// Requirement ID : SAMS-PACK-401
// Responsibility : Entry point for all users. Authenticates the user by email
//                  and password, then routes to the correct dashboard based on role.
//
// Attributes:
//   email       String
//   password    String
//   userRole    String
//   authToken   String
//
// Methods:
//   render()              — Renders the login form with email and password fields.
//   validateCredentials() — Validates that email and password fields are not empty.
//   login(email,password) — Sends credentials to AuthController and receives token.
//   navigateToDashboard() — Routes lecturer → LecturerDashboard, student → StudentDashboard.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/animations.dart';
import 'lecturer/lecturer_dashboard.dart';
import 'student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryOpacity;
  late final Animation<double> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: kDurationSlow);
    _entryOpacity = CurvedAnimation(parent: _entryCtrl, curve: kEaseOut);
    _entrySlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: kEaseOut),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // login(email, password) — void
  // SAMS-PACK-401
  // validateCredentials() — IF email or password empty THEN DISPLAY error AND RETURN
  // CALL AuthController.login(email, password)
  // IF status == 200 THEN
  //   SAVE token via ApiService.saveToken()
  //   navigateToDashboard() — IF role == 'lecturer' THEN LecturerDashboard
  //                           ELSE IF role == 'student' THEN StudentDashboard
  // ELSE DISPLAY error message
  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.login(email, password);
      if (res['status'] == 200) {
        await ApiService.saveToken(res['token']);
        final user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
        if (!mounted) return;
        // navigateToDashboard() — SAMS-PACK-401: role-based routing
        if (user.role == 'lecturer') {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => LecturerDashboard(user: user)));
        } else if (user.role == 'student') {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => StudentDashboard(user: user)));
        } else {
          setState(() => _error = 'This portal is for lecturers and students only.');
        }
      } else {
        setState(() => _error = res['message'] ?? 'Login failed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Request failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _entryOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _entrySlide.value),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A1F3C88), blurRadius: 24, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand mark
                      Center(
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F6FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school, color: Color(0xFF1E5BFF), size: 28),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Center(
                        child: Text('SAMS',
                          style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: Color(0xFF111827), letterSpacing: -0.5,
                          )),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text('Student Academic Management System',
                          style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email field
                      _Label('Email address'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'you@umpsa.edu.my',
                          prefixIcon: const Icon(Icons.alternate_email),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFD),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password field
                      _Label('Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF5B6B86),
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFD),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      // Error banner
                      AnimatedSize(
                        duration: kDurationMedium,
                        curve: kEaseOut,
                        child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFCDD2)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!,
                                    style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13))),
                                ]),
                              ),
                            )
                          : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // Sign In button — SAMS-PACK-401
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5BFF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1E5BFF).withValues(alpha: 0.7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text('SAMS · University Attendance Portal',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)));
}
