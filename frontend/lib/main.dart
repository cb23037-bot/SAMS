import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'pages/LoginPage.dart';
import 'pages/pusat_adab/SystemPage.dart';
import 'pages/student/HomePage.dart';
import 'services/api_service.dart';
import 'pages/faculty_registrar/dashboard_page.dart';

void main() {
  runApp(const SamsApp());
}

class SamsApp extends StatefulWidget {
  const SamsApp({super.key});

  @override
  State<SamsApp> createState() => _SamsAppState();
}

class _SamsAppState extends State<SamsApp> {
  // Declare these as late so they are initialized in initState
  late final ApiService _apiService;
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    // 1. Initialize API service first
    _apiService = ApiService();
    
    // 2. Initialize Controller
    _controller = AppController(apiService: _apiService);
    
    // 3. Link the controller back to the service
    _apiService.setController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildHome() {
    if (!_controller.isAuthenticated || _controller.currentUser == null) {
      return LoginPage(controller: _controller);
    }

    if (_controller.currentUser!.isPusatAdab) {
      return PusatAdabDashboardPage(controller: _controller);
    }
    if (_controller.currentUser!.isFacultyRegistrar) {
      return FacultyRegistrarDashboard(controller: _controller);
    }

    return StudentHomePage(controller: _controller);
  }
}