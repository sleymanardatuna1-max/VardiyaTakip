import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme.dart';
import '../models.dart';
import '../services/shift_service.dart';
import '../services/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const SettingsScreen({super.key, required this.onRefresh});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _scanning = false;
  ShiftService get _s => ShiftService();

  // --- FOTOĞRAFTAN VARDİYA ÇIKAR ---
  void _scanImage() async {
    setState(() => _scanning = true);
    try {
      List<String>? newCycle = await AIService.extractShiftFromImage();
      if (!mounted) return;

      if (newCycle == null) {
        setState(() => _scanning = false);
        return;
      }
      if (newCycle.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vardiya döngüsü anlaşılamadı. Daha net bir fotoğraf seçin.')),
        );
        setState(() => _scanning = false);
        return;
      }

      DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime(2030),
        helpText: 'VARDIYANIN BAŞLADIĞI İLK GÜNÜ SEÇİN',
        cancelText: 'İPTAL',
        confirmText: 'TAKVİME UYGULA',
      );

      if (selectedDate != null) {
        await _s.saveSettings(selectedDate, VardiyaSistemi.ozelDuzen, newCycle);
        _s.widgetGuncelle();
        _s.gelecekBildirimleriKur();
        widget.onRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Takvim fotoğraftan başarıyla oluşturuldu!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  // --- AYARLAR MENÜSÜ (Tam orijinal) ---
  void _ayarlariAc() {
    DateTime geciciTarih = _s.calculator?.initialDayShift ?? DateTime.now();
    VardiyaSistemi geciciSistem = _s.calculator?.sistem ?? VardiyaSistemi.sistem12_24;
    List<String> geciciOzelDongu = List.from(_s.kayitliOzelDongu);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(25),
              height: geciciSistem == VardiyaSistemi.ozelDuzen ? 650 : 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vardiya Ayarları", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 25),

                  // 1. Vardiya Sistemi Seçimi
                  Text("1. Vardiya Sisteminizi Seçin", style: TextStyle(color: AppTheme.textGray, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<VardiyaSistemi>(
                        isExpanded: true,
                        dropdownColor: AppTheme.cardColor,
                        value: geciciSistem,
                        items: VardiyaSistemi.values.map((sistem) {
                          return DropdownMenuItem(
                            value: sistem,
                            child: Text(_s.sistemAdiGetir(sistem), style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => geciciSistem = val);
                        },
                      ),
                    ),
                  ),

                  // Özel Sistem Paneli
                  if (geciciSistem == VardiyaSistemi.ozelDuzen) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Özel Döngü Sıranız", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              InkWell(
                                onTap: () => setModalState(() => geciciOzelDongu.clear()),
                                child: const Text("Tümünü Temizle", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 5,
                            runSpacing: -5,
                            children: geciciOzelDongu.asMap().entries.map((e) => Chip(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              label: Text("${e.key + 1}. ${e.value}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white54),
                              onDeleted: () => setModalState(() => geciciOzelDongu.removeAt(e.key)),
                            )).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ozelButon("Gündüz", const Color(0xFFFFB74D), () => setModalState(() => geciciOzelDongu.add("Gündüz"))),
                              _ozelButon("Akşam", const Color(0xFFFF8A65), () => setModalState(() => geciciOzelDongu.add("Akşam"))),
                              _ozelButon("Gece", const Color(0xFF42A5F5), () => setModalState(() => geciciOzelDongu.add("Gece"))),
                              _ozelButon("Tatil", const Color(0xFF66BB6A), () => setModalState(() => geciciOzelDongu.add("Tatil"))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2. İlk Çalışma Günü Seçimi
                  Text("2. İlk Çalışma Gününüzü Seçin", style: TextStyle(color: AppTheme.textGray, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withOpacity(0.08),
                    title: Text("${geciciTarih.day} ${_s.ayIsmiGetir(geciciTarih.month)} ${geciciTarih.year}", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                    onTap: () async {
                      DateTime? secilen = await showDatePicker(
                        context: context,
                        initialDate: geciciTarih,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: "İlk Vardiya Gününüzü Seçin",
                      );
                      if (secilen != null) setModalState(() => geciciTarih = secilen);
                    },
                  ),
                  const Spacer(),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Kaydet ve Hesapla", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (geciciSistem == VardiyaSistemi.ozelDuzen && geciciOzelDongu.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen döngü sıranızı belirleyin!')));
                          return;
                        }
                        await _s.saveSettings(geciciTarih, geciciSistem, geciciOzelDongu);
                        _s.widgetGuncelle();
                        _s.gelecekBildirimleriKur();
                        widget.onRefresh();
                        setState(() {});
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _ozelButon(String text, Color renk, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: renk, width: 1),
        ),
        child: Text(text, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  // --- PDF EXPORT ---
  Future<void> _aylikTakvimiPdfYapVePaylas() async {
    if (_s.calculator == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF hazırlanıyor...'), duration: Duration(seconds: 1)),
    );

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final blackFont = await PdfGoogleFonts.robotoBlack();

    DateTime now = DateTime.now();
    final int yil = now.year;
    final int ay = now.month;
    final int aydakiGunSayisi = DateTime(yil, ay + 1, 0).day;
    final int ilkGunHaftaninGunu = DateTime(yil, ay, 1).weekday;

    List<pw.TableRow> satirlar = [];
    final gunBasliklari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    satirlar.add(pw.TableRow(
      children: gunBasliklari.map((gun) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        alignment: pw.Alignment.center,
        color: PdfColors.blueGrey800,
        child: pw.Text(gun, style: pw.TextStyle(color: PdfColors.white, font: blackFont, fontSize: 13)),
      )).toList(),
    ));

    List<pw.Widget> suAnkiHafta = [];
    for (int i = 1; i < ilkGunHaftaninGunu; i++) {
      suAnkiHafta.add(pw.Container(color: PdfColors.grey100));
    }

    for (int gun = 1; gun <= aydakiGunSayisi; gun++) {
      DateTime islenenGun = DateTime(yil, ay, gun);
      String kisaVardiya = _s.calculator!.getShiftType(islenenGun).split('\n')[0];

      PdfColor arkaplan = PdfColors.white;
      PdfColor yaziRengi = PdfColors.black;

      if (kisaVardiya.contains("Gündüz")) { arkaplan = PdfColor.fromHex('#FFE0B2'); yaziRengi = PdfColor.fromHex('#BF360C'); }
      else if (kisaVardiya.contains("Gece")) { arkaplan = PdfColor.fromHex('#C5CAE9'); yaziRengi = PdfColor.fromHex('#1A237E'); }
      else if (kisaVardiya.contains("Nöbet")) { arkaplan = PdfColor.fromHex('#E1BEE7'); yaziRengi = PdfColor.fromHex('#311B92'); }
      else if (kisaVardiya.contains("Tatil")) { arkaplan = PdfColor.fromHex('#C8E6C9'); yaziRengi = PdfColor.fromHex('#1B5E20'); }

      suAnkiHafta.add(pw.Container(
        height: 65,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(color: arkaplan, border: pw.Border.all(color: PdfColors.grey500, width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$gun', style: pw.TextStyle(font: blackFont, fontSize: 16, color: PdfColors.black)),
            pw.Center(child: pw.Text(kisaVardiya, style: pw.TextStyle(font: blackFont, fontSize: 13, color: yaziRengi))),
          ],
        ),
      ));

      if (suAnkiHafta.length == 7) {
        satirlar.add(pw.TableRow(children: suAnkiHafta));
        suAnkiHafta = [];
      }
    }

    if (suAnkiHafta.isNotEmpty) {
      while (suAnkiHafta.length < 7) suAnkiHafta.add(pw.Container(color: PdfColors.grey100));
      satirlar.add(pw.TableRow(children: suAnkiHafta));
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('${_s.ayIsmiGetir(ay)} $yil Vardiya Programı', style: pw.TextStyle(fontSize: 28, font: blackFont, color: PdfColors.black)),
            pw.SizedBox(height: 25),
            pw.Table(border: pw.TableBorder.all(color: PdfColors.grey700, width: 1.5), children: satirlar),
            pw.SizedBox(height: 40),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Bu takvim "Vardiya Takip" uygulaması ile oluşturulmuştur.',
                style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic)),
            ),
          ],
        );
      },
    ));

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Vardiya_${_s.ayIsmiGetir(ay)}_$yil.pdf');
  }

  // --- GOOGLE HESABI BAĞLA ---
  Future<void> _googleHesabiniBagla() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      try {
        await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hesabınız başarıyla bağlandı!'), backgroundColor: Colors.green));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mevcut hesabınıza geçiş yapıldı!'), backgroundColor: Colors.blueAccent));
        } else { rethrow; }
      }
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bir hata oluştu.'), backgroundColor: Colors.redAccent));
    }
  }

  // --- MAAŞ HESAPLAMA SAYFASI ---
  void _maasHesaplaAc() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MaasHesaplaSayfasi(mesaiKayitlari: _s.mesaiKayitlari)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isAnonymous = user?.isAnonymous ?? true;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          const Center(child: Text('Vardiya Ayarları', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 25),

          // Profil Kartı
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? const Icon(Icons.person, color: AppTheme.primaryColor) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isAnonymous ? 'Misafir Kullanıcı' : (user?.displayName ?? 'Kullanıcı'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(isAnonymous ? 'Verileriniz sadece bu cihazda.' : (user?.email ?? ''),
                          style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Google Hesap Bağlama
          if (isAnonymous)
            _buildSettingsTile(Icons.cloud_sync, 'Verilerini Güvenceye Al', 'Google hesabını bağla', Colors.greenAccent, _googleHesabiniBagla),

          // Fotoğraf Tara
          _buildSettingsTile(
            Icons.camera_alt_rounded,
            'Çizelge Fotoğrafını Tara',
            'Fotoğraftaki vardiyalarını otomatik olarak oluştur.',
            AppTheme.primaryColor,
            _scanning ? null : _scanImage,
            trailing: _scanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2)) : null,
          ),

          // Vardiya Sistemi Ayarla
          _buildSettingsTile(Icons.tune_rounded, 'Vardiya Sistemini Seç', 'Döngünüzü düzenleyin', const Color(0xFF42A5F5), _ayarlariAc),

          // PDF Paylaş
          _buildSettingsTile(Icons.picture_as_pdf_rounded, 'Aylık Takvimi Paylaş', 'PDF olarak oluştur ve paylaş', const Color(0xFFFF8A65), _aylikTakvimiPdfYapVePaylas),

          // Maaş Hesaplama
          _buildSettingsTile(Icons.calculate_rounded, 'Maaş ve Mesai Hesabı', 'Ekstra ücretlerinizi hesaplayın', const Color(0xFFAB47BC), _maasHesaplaAc),

          const SizedBox(height: 15),

          // Vardiya Renkleri
          const Text('Vardiya Renkleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildColorRow(const Color(0xFFFFB74D), Icons.wb_sunny, 'Gündüz', '08:00 - 16:00'),
          _buildColorRow(const Color(0xFFFF8A65), Icons.wb_twilight, 'Akşam', '16:00 - 00:00'),
          _buildColorRow(const Color(0xFF42A5F5), Icons.nightlight_round, 'Gece', '00:00 - 08:00'),
          _buildColorRow(const Color(0xFF66BB6A), Icons.weekend, 'Tatil', 'İstirahat'),

          const SizedBox(height: 30),

          // Çıkış Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Hesaptan Çıkış Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, Color color, VoidCallback? onTap, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorRow(Color color, IconData icon, String name, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(time, style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- MAAŞ HESAPLAMA SAYFASI (Orijinal) ---
class MaasHesaplaSayfasi extends StatefulWidget {
  final Map<String, double> mesaiKayitlari;
  const MaasHesaplaSayfasi({super.key, required this.mesaiKayitlari});

  @override
  State<MaasHesaplaSayfasi> createState() => _MaasHesaplaSayfasiState();
}

class _MaasHesaplaSayfasiState extends State<MaasHesaplaSayfasi> {
  double _saatlikUcret = 250.0;
  double _mesaiCarpan = 1.5;
  late TextEditingController _ucretController;
  late TextEditingController _carpanController;

  @override
  void initState() {
    super.initState();
    _ucretController = TextEditingController(text: _saatlikUcret.toString());
    _carpanController = TextEditingController(text: _mesaiCarpan.toString());
    _ayarlariYukle();
  }

  @override
  void dispose() {
    _ucretController.dispose();
    _carpanController.dispose();
    super.dispose();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _saatlikUcret = prefs.getDouble('saatlik_ucret') ?? 250.0;
      _mesaiCarpan = prefs.getDouble('mesai_carpan') ?? 1.5;
      _ucretController.text = _saatlikUcret.toString();
      _carpanController.text = _mesaiCarpan.toString();
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('saatlik_ucret', _saatlikUcret);
    await prefs.setDouble('mesai_carpan', _mesaiCarpan);
  }

  double _toplamHesapla() {
    double toplamSaat = 0;
    for (double saat in widget.mesaiKayitlari.values) {
      toplamSaat += saat;
    }
    return toplamSaat * _saatlikUcret * _mesaiCarpan;
  }

  @override
  Widget build(BuildContext context) {
    double toplamKazanc = _toplamHesapla();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text("Ekstra Ücret Hesabı")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: Column(
                children: [
                  Text("BU AYKİ TOPLAM EK KAZANÇ", style: TextStyle(color: AppTheme.textGray, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text("${toplamKazanc.toStringAsFixed(2)} ₺",
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _ayarSatiri("Saatlik Ücret (Net)", _ucretController, "₺", (double val) {
              setState(() => _saatlikUcret = val);
              _ayarlariKaydet();
            }),
            _ayarSatiri("Mesai Katsayısı (1.5, 2.0 vb.)", _carpanController, "x", (double val) {
              setState(() => _mesaiCarpan = val);
              _ayarlariKaydet();
            }),
          ],
        ),
      ),
    );
  }

  Widget _ayarSatiri(String baslik, TextEditingController controller, String suffix, void Function(double) onChanged) {
    return ListTile(
      title: Text(baslik, style: const TextStyle(color: Colors.white)),
      trailing: SizedBox(
        width: 80,
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: suffix, suffixStyle: const TextStyle(color: Colors.white54)),
          onChanged: (String s) {
            double val = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
            onChanged(val);
          },
        ),
      ),
    );
  }
}
