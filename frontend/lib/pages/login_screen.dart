import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'lecturer/lecturer_dashboard.dart';
import 'student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

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
      body: Row(
        children: [
          // Left panel — brand / hero
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2449), Color(0xFF1A3A6B), Color(0xFF1E4D8C)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('SAMS',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ]),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF5BC4A0), size: 20),
                          const SizedBox(height: 10),
                          const Text('Smart Attendance',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('GPS-verified attendance with real-time tracking',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, height: 1.5)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text('Student Academic\nManagement System',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          height: 1.6,
                        )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right panel — form
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFFF0F2F7),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome back',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F2449),
                              letterSpacing: -0.5,
                            )),
                          const SizedBox(height: 6),
                          Text('Sign in to your university account',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                          const SizedBox(height: 32),

                          _label('Email address'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDec(hint: 'you@university.edu.my', icon: Icons.alternate_email),
                          ),
                          const SizedBox(height: 18),

                          _label('Password'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: _inputDec(
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: Colors.grey[400],
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!,
                                  style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13))),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign In'),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Center(
                            child: Text('SAMS · University Attendance Portal',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D3748)));

  InputDecoration _inputDec({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
      suffixIcon: suffix,
    );
  }
}
