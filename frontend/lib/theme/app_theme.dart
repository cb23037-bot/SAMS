import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAFD);
  static const Color textMain = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF5B6B86);
  static const Color primaryBlue = Color(0xFF1E5BFF);
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color primaryGreen = Colors.green;
}

class AppText {
  static const TextStyle heading = TextStyle(
    fontSize: 22, 
    fontWeight: FontWeight.w800, 
    color: AppColors.textMain
  );
  
  static const TextStyle subTitle = TextStyle(
    fontSize: 14, 
    color: AppColors.textSecondary
  );
}