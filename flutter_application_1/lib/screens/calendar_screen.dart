import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart';
import '../services/shift_service.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const CalendarScreen({super.key, required this.onRefresh});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _aylikGorunumMu = true;
  final ScrollController _scrollController = ScrollController();

  ShiftService get _s => ShiftService();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
    WidgetsBinding.instance.addPostFrameCallback((_) => _bugunuOrtala());
  }

  void _bugunuOrtala() {
    if (_scrollController.hasClients) {
      double ekranGenisligi = MediaQuery.of(context).size.width;
      double listeGenisligi = ekranGenisligi - 100;
      double bugununPozisyonu = 30 * 75.0;
      double ortaOffset = bugununPozisyonu - (listeGenisligi / 2) + 45.0;
      _scrollController.jumpTo(ortaOffset.clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  void _takvimiKaydir(bool sagaMi) {
    if (_scrollController.hasClients) {
      final kaydirmaMiktari = 70.0 * 3;
      final hedef = sagaMi ? _scrollController.offset + kaydirmaMiktari : _scrollController.offset - kaydirmaMiktari;
      _scrollController.animateTo(
        hedef.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _mesaiGirisPaneliAc(DateTime tarih) {
    String tarihKey = "${tarih.year}-${tarih.month}-${tarih.day}";
    double mevcutMesai = _s.mesaiKayitlari[tarihKey] ?? 0.0;
    TextEditingController controller = TextEditingController(text: mevcutMesai > 0 ? mevcutMesai.toString() : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tarih.day} ${_s.ayIsmiGetir(tarih.month)} Mesai Girişi",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Kaç saat ekstra çalıştınız?",
                labelStyle: TextStyle(color: AppTheme.textGray),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.textGray)),
                suffixText: "Saat",
                suffixStyle: TextStyle(color: AppTheme.textGray),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                double? yeniMesai = double.tryParse(controller.text.replaceAll(',', '.'));
                await _s.saveMesai(tarihKey, yeniMesai);
                setState(() {});
                widget.onRefresh();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String secilenVardiya = _s.calculator?.getShiftType(_selectedDay) ?? 'Bilinmiyor';

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Takvim', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_aylikGorunumMu ? Icons.view_week : Icons.calendar_month, color: Colors.white),
                      tooltip: 'Görünümü Değiştir',
                      onPressed: () {
                        setState(() => _aylikGorunumMu = !_aylikGorunumMu);
                        if (!_aylikGorunumMu) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _bugunuOrtala());
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Takvim Görünümü
          AnimatedCrossFade(
            firstChild: _haftalikTakvim(),
            secondChild: _aylikTakvim(),
            crossFadeState: _aylikGorunumMu ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem('Gündüz', const Color(0xFFFFB74D)),
                _legendItem('Akşam', const Color(0xFFFF8A65)),
                _legendItem('Gece', const Color(0xFF42A5F5)),
                _legendItem('Tatil', const Color(0xFF66BB6A)),
              ],
            ),
          ),

          // Seçili gün kartı
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd MMMM yyyy • EEEE', 'tr_TR').format(_selectedDay), style: TextStyle(color: AppTheme.textGray, fontSize: 13)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(_s.ikonGetir(secilenVardiya), size: 50, color: _s.ikonRengiGetir(secilenVardiya)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(secilenVardiya.split('\n')[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            if (secilenVardiya.contains('\n'))
                              Text(secilenVardiya.split('\n')[1], style: TextStyle(fontSize: 14, color: AppTheme.textGray)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Mesai Ekle Butonu
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(_s.mesaiKayitlari.containsKey("${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}")
                          ? 'Mesai Düzenle (+${_s.mesaiKayitlari["${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}"]} saat)'
                          : 'Ek Mesai Saati Ekle'),
                      onPressed: () => _mesaiGirisPaneliAc(_selectedDay),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _haftalikTakvim() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28), onPressed: () => _takvimiKaydir(false)),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 90,
              itemBuilder: (context, index) {
                DateTime simdi = DateTime.now();
                DateTime tarih = DateTime(simdi.year, simdi.month, simdi.day).add(Duration(days: index - 30));
                bool seciliMi = tarih.day == _selectedDay.day && tarih.month == _selectedDay.month && tarih.year == _selectedDay.year;
                String vardiya = _s.calculator?.getShiftType(tarih) ?? '';
                Color noktaRengi = _s.noktaRengiGetir(vardiya);
                String tarihKey = "${tarih.year}-${tarih.month}-${tarih.day}";
                bool mesaiVarMi = _s.mesaiKayitlari.containsKey(tarihKey);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = tarih;
                      _focusedDay = tarih;
                    });
                  },
                  onLongPress: () {
                    HapticFeedback.vibrate();
                    setState(() {
                      _selectedDay = tarih;
                      _focusedDay = tarih;
                    });
                    _mesaiGirisPaneliAc(tarih);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: seciliMi ? 75 : 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: seciliMi ? AppTheme.primaryColor : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(seciliMi ? 25 : 20),
                      boxShadow: seciliMi ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_s.gunIsmiGetir(tarih.weekday), style: TextStyle(color: seciliMi ? Colors.black54 : Colors.white54, fontWeight: FontWeight.w600, fontSize: 11)),
                            const SizedBox(height: 3),
                            Text("${tarih.day}", style: TextStyle(fontSize: seciliMi ? 24 : 18, color: seciliMi ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Container(width: seciliMi ? 8 : 6, height: seciliMi ? 8 : 6, decoration: BoxDecoration(color: seciliMi ? Colors.black45 : noktaRengi, shape: BoxShape.circle)),
                          ],
                        ),
                        if (mesaiVarMi)
                          Positioned(top: 5, right: 5, child: Icon(Icons.timer, size: 12, color: seciliMi ? Colors.black54 : Colors.greenAccent)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28), onPressed: () => _takvimiKaydir(true)),
        ],
      ),
    );
  }

  Widget _aylikTakvim() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textGray),
          weekendStyle: TextStyle(color: AppTheme.textGray),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, false),
          selectedBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, true),
          todayBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, false, isToday: true),
        ),
        selectedDayPredicate: (day) => day.day == _selectedDay.day && day.month == _selectedDay.month && day.year == _selectedDay.year,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onDayLongPressed: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          HapticFeedback.vibrate();
          _mesaiGirisPaneliAc(selectedDay);
        },
      ),
    );
  }

  Widget _takvimHucresiOlustur(DateTime day, bool isSelected, {bool isToday = false}) {
    String vardiya = _s.calculator?.getShiftType(day) ?? '';
    Color noktaRengi = _s.noktaRengiGetir(vardiya);
    String tarihKey = "${day.year}-${day.month}-${day.day}";
    bool mesaiVarMi = _s.mesaiKayitlari.containsKey(tarihKey);

    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : (isToday ? Colors.white.withOpacity(0.1) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.day}', style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: isSelected ? 14 : 13,
              )),
              const SizedBox(height: 3),
              Container(width: 5, height: 5, decoration: BoxDecoration(color: isSelected ? Colors.black54 : noktaRengi, shape: BoxShape.circle)),
            ],
          ),
          if (mesaiVarMi)
            Positioned(top: 2, right: 2, child: Icon(Icons.timer, color: isSelected ? Colors.black54 : Colors.greenAccent, size: 10)),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textGray)),
      ],
    );
  }
}
