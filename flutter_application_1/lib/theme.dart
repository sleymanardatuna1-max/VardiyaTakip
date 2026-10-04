import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgColor = Color(0xFF0F172A); // Dark teal/blue
  static const Color primaryColor = Color(0xFF38E58A); // Bright green
  static const Color cardColor = Color(0xFF1E293B);
  static const Color textWhite = Colors.white;
  static const Color textGray = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: primaryColor,
      cardColor: cardColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textGray,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textWhite),
        bodyMedium: TextStyle(color: textWhite),
      ),
    );
  }

  static Color getShiftColor(String shiftName) {
    if (shiftName.contains('Gündüz')) return Colors.orangeAccent;
    if (shiftName.contains('Akşam')) return Colors.orange;
    if (shiftName.contains('Gece')) return Colors.blueAccent;
    if (shiftName.contains('Tatil')) return Colors.grey;
    return Colors.white;
  }
}
