import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart';
import '../services/shift_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
  }

  ShiftService get _s => ShiftService();

  @override
  Widget build(BuildContext context) {
    int totalDays = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int workDays = 0;
    int holidays = 0;
    int nightShifts = 0;
    int totalHours = 0;
    double totalMesai = 0;

    int gunduzCount = 0;
    int aksamCount = 0;
    int geceCount = 0;
    int tatilCount = 0;

    for (int i = 1; i <= totalDays; i++) {
      DateTime day = DateTime(_currentMonth.year, _currentMonth.month, i);
      String shift = _s.calculator?.getShiftType(day) ?? '';
      String tarihKey = "${day.year}-${day.month}-${day.day}";

      if (_s.mesaiKayitlari.containsKey(tarihKey)) {
        totalMesai += _s.mesaiKayitlari[tarihKey]!;
      }

      if (shift.contains('Tatil') || shift.contains('İstirahat')) {
        holidays++;
        tatilCount++;
      } else {
        workDays++;
        if (shift.contains('Gündüz')) {
          gunduzCount++;
          totalHours += 8;
        } else if (shift.contains('Akşam')) {
          aksamCount++;
          totalHours += 8;
        } else if (shift.contains('Gece')) {
          nightShifts++;
          geceCount++;
          totalHours += 8;
        } else if (shift.contains('Nöbet')) {
          nightShifts++;
          geceCount++;
          totalHours += 24;
        } else {
          totalHours += 8;
        }
      }
    }

    totalHours += totalMesai.toInt();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text('İstatistik', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 25),

          // Ay Seçici
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () {
                  setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
                }),
                Text(DateFormat('MMMM yyyy', 'tr_TR').format(_currentMonth),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () {
                  setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4 İstatistik Kartı
          Row(
            children: [
              Expanded(child: _buildStatCard(Icons.access_time_rounded, '$totalHours', 'Toplam Çalışma Saati', AppTheme.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(Icons.event_available_rounded, '$workDays', 'Çalışma Günü', const Color(0xFF42A5F5))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(Icons.hotel_rounded, '$holidays', 'Tatil Günü', const Color(0xFF66BB6A))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(Icons.nights_stay_rounded, '$nightShifts', 'Gece Vardiyası', const Color(0xFFAB47BC))),
            ],
          ),

          // Mesai varsa göster
          if (totalMesai > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.timer, color: Colors.greenAccent, size: 24),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${totalMesai.toStringAsFixed(1)} saat', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Toplam Ek Mesai', style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 25),

          // Vardiya Dağılımı Başlık
          const Text('Vardiya Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Pasta Grafik
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: _buildPieSections(gunduzCount, aksamCount, geceCount, tatilCount),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$totalHours', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          Text('saat', style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendPercent('Gündüz', gunduzCount, totalDays, const Color(0xFFFFB74D)),
                      const SizedBox(height: 10),
                      _buildLegendPercent('Akşam', aksamCount, totalDays, const Color(0xFFFF8A65)),
                      const SizedBox(height: 10),
                      _buildLegendPercent('Gece', geceCount, totalDays, const Color(0xFF42A5F5)),
                      const SizedBox(height: 10),
                      _buildLegendPercent('Tatil', tatilCount, totalDays, const Color(0xFF66BB6A)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(int gunduz, int aksam, int gece, int tatil) {
    final total = gunduz + aksam + gece + tatil;
    if (total == 0) {
      return [PieChartSectionData(value: 1, color: Colors.grey.withOpacity(0.3), showTitle: false, radius: 25)];
    }
    return [
      if (gunduz > 0) PieChartSectionData(value: gunduz.toDouble(), color: const Color(0xFFFFB74D), showTitle: false, radius: 25),
      if (aksam > 0) PieChartSectionData(value: aksam.toDouble(), color: const Color(0xFFFF8A65), showTitle: false, radius: 25),
      if (gece > 0) PieChartSectionData(value: gece.toDouble(), color: const Color(0xFF42A5F5), showTitle: false, radius: 25),
      if (tatil > 0) PieChartSectionData(value: tatil.toDouble(), color: const Color(0xFF66BB6A), showTitle: false, radius: 25),
    ];
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textGray)),
        ],
      ),
    );
  }

  Widget _buildLegendPercent(String label, int count, int total, Color color) {
    int percent = total == 0 ? 0 : (count * 100 / total).round();
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: AppTheme.textGray, fontSize: 13))),
        Text('%$percent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
