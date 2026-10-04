import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/home_screen.dart';
import 'package:flutter_application_1/screens/calendar_screen.dart';
import 'package:flutter_application_1/screens/stats_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Çocuk ekranlar state değiştiğinde bunu çağırır
  void refreshAll() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onRefresh: refreshAll),
      CalendarScreen(onRefresh: refreshAll),
      const StatsScreen(),
      SettingsScreen(onRefresh: refreshAll),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Takvim'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'İstatistik'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ayarlar'),
          ],
        ),
      ),
    );
  }
}
