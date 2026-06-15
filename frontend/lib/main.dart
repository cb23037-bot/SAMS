import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'pages/LoginPage.dart';
import 'pages/pusat_adab/SystemPage.dart';
import 'pages/lecturer/lecturer_dashboard.dart';
import 'pages/faculty_registrar/dashboard_page.dart';
import 'pages/student/student_dashboard.dart';
import 'services/api_service.dart';

/// App entry point. Boots a single [SamsApp] widget which owns the
/// [AppController] for the entire session.
void main() {
  runApp(const SamsApp());
}

/// Root widget of the SA Management app.
///
/// Holds the single [AppController] instance (created once in [initState])
/// and rebuilds the whole app whenever it calls `notifyListeners()` — this
/// is how login/logout state changes propagate to [_buildHome].
class SamsApp extends StatefulWidget {
  const SamsApp({super.key});

  @override
  State<SamsApp> createState() => _SamsAppState();
}

class _SamsAppState extends State<SamsApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    // ApiService is created once here and injected into AppController,
    // so every page reaches the network layer through one shared instance.
    _controller = AppController(apiService: ApiService());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds MaterialApp whenever AppController calls
    // notifyListeners() (e.g. after sign in/out), so _buildHome() always
    // reflects the current auth state.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SA Management',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFEAF3FF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E5BFF),
              surface: const Color(0xFFEAF3FF),
            ),
            fontFamily: 'Segoe UI',
          ),
          home: _buildHome(),
        );
      },
    );
  }

  /// Decides which top-level page to show based on auth state and role:
  /// - Not logged in → [LoginPage]
  /// - Logged in as Pusat Adab staff → [PusatAdabDashboardPage]
  /// - Logged in as lecturer → [LecturerDashboardPage]
  /// - Logged in as Faculty Registrar staff → [FacultyRegistrarDashboard]
  /// - Logged in as student → [StudentHomePage]
  Widget _buildHome() {
    if (!_controller.isAuthenticated || _controller.currentUser == null) {
      return LoginPage(controller: _controller);
    }

    final user = _controller.currentUser!;
    if (user.isPusatAdab) {
      return PusatAdabDashboardPage(controller: _controller);
    }
    if (user.isLecturer) {
      return LecturerDashboardPage(controller: _controller);
    }
    if (user.isFacultyRegistrar) {
      return FacultyRegistrarDashboard(controller: _controller);
    }

    return StudentHomePage(controller: _controller);
  }
}
