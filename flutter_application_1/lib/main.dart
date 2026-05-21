import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// MethodChannel ile native Android widget güncelleme
const _widgetChannel = MethodChannel('com.vardiya.widget/update');

// Bildirim eklentisini global olarak tanımlıyoruz
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // Uygulama başlamadan önce gerekli ayarları yüklüyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Başlatma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Saat Dilimi Ayarları
  tz.initializeTimeZones(); 
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul')); 

  // 3. Bildirim Ayarları
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // En son uygulamayı çalıştırıyoruz (Sadece bir kere yazılmalı)
  runApp(const VardiyaApp()); 
}

// --- VARDİYA SİSTEMLERİNİ TANIMLIYORUZ ---
enum VardiyaSistemi {
  sistem12_24, // 1 Gündüz, 1 Gece, 1 Tatil
  sistem12_36, // 1 Gündüz, 1 Gece, 2 Tatil
  sistem24_48, // 24 Saat Nöbet, 2 Tatil
  ikiGunduz_ikiGece_ikiTatil, // 2 Gündüz, 2 Gece, 2 Tatil
  ozelDuzen // YENİ EKLENEN ÖZEL SİSTEM
}

class VardiyaApp extends StatelessWidget {
  const VardiyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vardiya Takip',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthYonetici(), 
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  bool _aylikGorunumMu = false;
  ShiftCalculator? calculator;
  DateTime _secilenGun = DateTime.now();
  String _gununVardiyasi = "Hesaplanıyor...";
  
  // Mesaileri tarih bazlı saklamak için
  Map<String, double> _mesaiKayitlari = {};
  
  // YENİ: Özel döngüyü hafızada tutacak listemiz
  List<String> _kayitliOzelDongu = []; 
  
  final ScrollController _takvimScrollController = ScrollController();

  void _takvimiKaydir(bool sagaMi) {
    final c = _takvimScrollController;
    if (c.hasClients) {
      final kaydirmaMiktari = 70.0 * 3; // 3 gün kadar kaydır
      final hedef = sagaMi ? c.offset + kaydirmaMiktari : c.offset - kaydirmaMiktari;
      c.animateTo(
        hedef.clamp(0.0, c.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _hafizadanAyarlariYukle();
    _bildirimIzniIste();
  } 

  Future<void> _aylikTakvimiPdfYapVePaylas() async {
    if (calculator == null) return;

    // Yükleniyor bildirimi
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Görsel Takvim PDF olarak hazırlanıyor...'), duration: Duration(seconds: 1)),
    );

    final pdf = pw.Document();
    
    // Türkçe karakterleri bozmayan fontlar
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final blackFont = await PdfGoogleFonts.robotoBlack(); 

    final int yil = _secilenGun.year;
    final int ay = _secilenGun.month;
    
    final int aydakiGunSayisi = DateTime(yil, ay + 1, 0).day; 
    final int ilkGunHaftaninGunu = DateTime(yil, ay, 1).weekday; 

    // --- TAKVİM IZGARASINI OLUŞTURUYORUZ ---
    List<pw.TableRow> satirlar = [];
    final gunBasliklari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    satirlar.add(
      pw.TableRow(
        children: gunBasliklari.map((gun) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          alignment: pw.Alignment.center,
          color: PdfColors.blueGrey800,
          child: pw.Text(gun, style: pw.TextStyle(color: PdfColors.white, font: blackFont, fontSize: 13)),
        )).toList(),
      )
    );

    List<pw.Widget> suAnkiHafta = [];
    
    for (int i = 1; i < ilkGunHaftaninGunu; i++) {
      suAnkiHafta.add(pw.Container(color: PdfColors.grey100)); 
    }

    for (int gun = 1; gun <= aydakiGunSayisi; gun++) {
      DateTime islenenGun = DateTime(yil, ay, gun);
      
      String kisaVardiya = calculator!.getShiftType(islenenGun).split('\n')[0]; 

      PdfColor arkaplan = PdfColors.white;
      PdfColor yaziRengi = PdfColors.black;

      if (kisaVardiya.contains("Gündüz")) { 
        arkaplan = PdfColor.fromHex('#FFE0B2'); 
        yaziRengi = PdfColor.fromHex('#BF360C'); 
      } else if (kisaVardiya.contains("Gece")) { 
        arkaplan = PdfColor.fromHex('#C5CAE9'); 
        yaziRengi = PdfColor.fromHex('#1A237E'); 
      } else if (kisaVardiya.contains("Nöbet")) { 
        arkaplan = PdfColor.fromHex('#E1BEE7'); 
        yaziRengi = PdfColor.fromHex('#311B92'); 
      } else if (kisaVardiya.contains("Tatil")) { 
        arkaplan = PdfColor.fromHex('#C8E6C9'); 
        yaziRengi = PdfColor.fromHex('#1B5E20'); 
      }

      suAnkiHafta.add(
        pw.Container(
          height: 65, 
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: arkaplan,
            border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$gun', style: pw.TextStyle(font: blackFont, fontSize: 16, color: PdfColors.black)),
              pw.Center(
                child: pw.Text(kisaVardiya, style: pw.TextStyle(font: blackFont, fontSize: 13, color: yaziRengi)),
              ),
            ]
          )
        )
      );
      // arda 
      if (suAnkiHafta.length == 7) {
        satirlar.add(pw.TableRow(children: suAnkiHafta));
        suAnkiHafta = [];
      }
    }

    if (suAnkiHafta.isNotEmpty) {
      while (suAnkiHafta.length < 7) {
        suAnkiHafta.add(pw.Container(color: PdfColors.grey100));
      }
      satirlar.add(pw.TableRow(children: suAnkiHafta));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('${_ayIsmiGetir(ay)} $yil Vardiya Programı', 
                  style: pw.TextStyle(fontSize: 28, font: blackFont, color: PdfColors.black)),
              pw.SizedBox(height: 25),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700, width: 1.5), 
                children: satirlar,
              ),
              
              pw.SizedBox(height: 30),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _pdfBilgiKutusu('Gündüz', PdfColor.fromHex('#FFE0B2'), PdfColor.fromHex('#BF360C'), blackFont),
                  _pdfBilgiKutusu('Gece', PdfColor.fromHex('#C5CAE9'), PdfColor.fromHex('#1A237E'), blackFont),
                  _pdfBilgiKutusu('Nöbet', PdfColor.fromHex('#E1BEE7'), PdfColor.fromHex('#311B92'), blackFont),
                  _pdfBilgiKutusu('Tatil', PdfColor.fromHex('#C8E6C9'), PdfColor.fromHex('#1B5E20'), blackFont),
                ]
              ),

              pw.SizedBox(height: 40), 
              pw.Divider(color: PdfColors.grey600, thickness: 1), 
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Bu takvim "Vardiya Takip" uygulaması ile oluşturulmuştur.',
                  style: pw.TextStyle(
                    font: boldFont, 
                    fontSize: 12,   
                    color: PdfColors.grey800, 
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),

            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Vardiya_${_ayIsmiGetir(ay)}_$yil.pdf',
    );
  }

  pw.Widget _pdfBilgiKutusu(String metin, PdfColor arkaplan, PdfColor yaziRengi, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: arkaplan,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: yaziRengi, width: 1)
      ),
      child: pw.Text(metin, style: pw.TextStyle(font: boldFont, fontSize: 13, color: yaziRengi))
    );
  }

  void _bugunuOrtala() {
    if (_takvimScrollController.hasClients) {
      double ekranGenisligi = MediaQuery.of(context).size.width;
      double listeGenisligi = ekranGenisligi - 100; 
      double bugununPozisyonu = 30 * 75.0; 
      double ortaOffset = bugununPozisyonu - (listeGenisligi / 2) + 45.0;
      _takvimScrollController.jumpTo(ortaOffset);
    }
  }

  Future<void> _googleHesabiniBagla() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesabınız başarıyla bağlandı! Verileriniz güvende.'), backgroundColor: Colors.green),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await FirebaseAuth.instance.signInWithCredential(credential);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mevcut hesabınıza geçiş yapıldı!'), backgroundColor: Colors.blueAccent),
            );
          }
        } else {
          rethrow; 
        }
      }
      
      setState(() {}); 
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu. Lütfen bağlantınızı kontrol edip tekrar deneyin.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Widget'ı MethodChannel üzerinden günceller (home_widget paketi gerekmez)
  Future<void> _widgetGuncelle(String vardiyaMetni) async {
    try {
      String tur = 'tatil';
      if (vardiyaMetni.contains('Gündüz')) tur = 'gunduz';
      else if (vardiyaMetni.contains('Gece')) tur = 'gece';
      else if (vardiyaMetni.contains('Nöbet')) tur = 'nobet';

      // Saatleri içeren kısayol metin (örn: "08:00 - 20:00")
      String kisaMetin = vardiyaMetni.replaceAll('\n', ' ');

      await _widgetChannel.invokeMethod('updateWidget', {
        'vardiya': kisaMetin,
        'tur': tur,
      });
    } catch (e) {
      // Widget güncellenemedi (platform dışı ya da widget eklenmemiş) — sessizce geç
    }
  }

  Future<void> _bildirimIzniIste() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // --- HAFIZADAN AYARLARI VE ÖZEL DÖNGÜYÜ YÜKLE ---
  Future<void> _hafizadanAyarlariYukle() async {
    final prefs = await SharedPreferences.getInstance(); 

    final mesaiString = prefs.getString('mesai_verileri');
    if (mesaiString != null) {
      setState(() {
        _mesaiKayitlari = Map<String, double>.from(jsonDecode(mesaiString));
      });
    }

    final kayitliTarih = prefs.getString('baslangic_tarihi');
    final kayitliSistemIndex = prefs.getInt('vardiya_sistemi') ?? 0;
    
    // Özel Döngüyü hafızadan çekiyoruz
    final ozelDonguString = prefs.getString('ozel_dongu');
    if (ozelDonguString != null) {
      _kayitliOzelDongu = List<String>.from(jsonDecode(ozelDonguString));
    }

    VardiyaSistemi kayitliSistem = VardiyaSistemi.values[kayitliSistemIndex];

    setState(() {
      if (kayitliTarih != null) {
        calculator = ShiftCalculator(DateTime.parse(kayitliTarih), kayitliSistem, ozelDongu: _kayitliOzelDongu);
      } else {
        calculator = ShiftCalculator(DateTime.now(), VardiyaSistemi.sistem12_24);
      }
      _gununVardiyasi = calculator!.getShiftType(_secilenGun);
    });
    // --- WIDGET'A VERİ GÖNDERME KISMI ---
    _widgetGuncelle(_gununVardiyasi);

    WidgetsBinding.instance.addPostFrameCallback((_) => _bugunuOrtala());
  }
  

  String _sistemAdiGetir(VardiyaSistemi sistem) {
    switch (sistem) {
      case VardiyaSistemi.sistem12_24: return "12/24 (1 Gündüz, 1 Gece, 1 Tatil)";
      case VardiyaSistemi.sistem12_36: return "12/36 (1 Gündüz, 1 Gece, 2 Tatil)";
      case VardiyaSistemi.sistem24_48: return "24/48 (24 Saat Nöbet, 2 Tatil)";
      case VardiyaSistemi.ikiGunduz_ikiGece_ikiTatil: return "2'li Sistem (2 Gündüz, 2 Gece, 2 Tatil)";
      case VardiyaSistemi.ozelDuzen: return "Özel Vardiya (Kendin Yarat)";
    }
  }

  // --- AYARLAR MENÜSÜ ---
  void _ayarlariAc() {
    DateTime geciciTarih = calculator?.initialDayShift ?? DateTime.now();
    VardiyaSistemi geciciSistem = calculator?.sistem ?? VardiyaSistemi.sistem12_24;
    
    List<String> geciciOzelDongu = List.from(_kayitliOzelDongu);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(25),
              height: geciciSistem == VardiyaSistemi.ozelDuzen ? 650 : 480, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vardiya Ayarları", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  
                  Text("1. Vardiya Sisteminizi Seçin", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<VardiyaSistemi>(
                        isExpanded: true,
                        value: geciciSistem,
                        items: VardiyaSistemi.values.map((sistem) {
                          return DropdownMenuItem(value: sistem, child: Text(_sistemAdiGetir(sistem)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => geciciSistem = val);
                        },
                      ),
                    ),
                  ),
                  
                  // --- ÖZEL SİSTEM PANELİ ---
                  if (geciciSistem == VardiyaSistemi.ozelDuzen) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Özel Döngü Sıranız", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              InkWell(
                                onTap: () => setModalState(() => geciciOzelDongu.clear()),
                                child: const Text("Tümünü Temizle", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 5,
                            runSpacing: -5,
                            children: geciciOzelDongu.asMap().entries.map((e) => Chip(
                              label: Text("${e.key + 1}. ${e.value}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.white,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setModalState(() => geciciOzelDongu.removeAt(e.key)),
                            )).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ozelButon("Gündüz", Colors.orange, () => setModalState(() => geciciOzelDongu.add("Gündüz"))),
                              _ozelButon("Gece", Colors.indigo, () => setModalState(() => geciciOzelDongu.add("Gece"))),
                              _ozelButon("Tatil", Colors.green, () => setModalState(() => geciciOzelDongu.add("Tatil"))),
                              _ozelButon("Nöbet", Colors.purple, () => setModalState(() => geciciOzelDongu.add("Nöbet"))),
                            ],
                          )
                        ],
                      ),
                    )
                  ],

                  const SizedBox(height: 20),

                  Text("2. İlk Çalışma Gününüzü Seçin", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: Colors.grey.shade100,
                    title: Text("${geciciTarih.day} ${_ayIsmiGetir(geciciTarih.month)} ${geciciTarih.year}"),
                    trailing: const Icon(Icons.calendar_month, color: Colors.blue),
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

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: const Text("Kaydet ve Hesapla", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (geciciSistem == VardiyaSistemi.ozelDuzen && geciciOzelDongu.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen döngü sıranızı belirleyin!')));
                          return;
                        }

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('baslangic_tarihi', geciciTarih.toIso8601String());
                        await prefs.setInt('vardiya_sistemi', geciciSistem.index);
                        await prefs.setString('ozel_dongu', jsonEncode(geciciOzelDongu)); 

                        setState(() {
                          _kayitliOzelDongu = List.from(geciciOzelDongu);
                          calculator = ShiftCalculator(geciciTarih, geciciSistem, ozelDongu: _kayitliOzelDongu);
                          _gununVardiyasi = calculator!.getShiftType(_secilenGun);
                        });
                        _widgetGuncelle(_gununVardiyasi);

                        _gelecekBildirimleriKur();
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text("Hesaptan Çıkış Yap", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                        await GoogleSignIn().signOut();
                      },
                    ),
                  )
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
          border: Border.all(color: renk, width: 1)
        ),
        child: Text(text, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
      )
    );
  }

  void _mesaiGirisPaneliAc(DateTime tarih) {
    String tarihKey = "${tarih.year}-${tarih.month}-${tarih.day}";
    double mevcutMesai = _mesaiKayitlari[tarihKey] ?? 0.0;
    TextEditingController _controller = TextEditingController(text: mevcutMesai > 0 ? mevcutMesai.toString() : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tarih.day} ${_ayIsmiGetir(tarih.month)} Mesai Girişi", 
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Kaç saat ekstra çalıştınız?",
                border: OutlineInputBorder(),
                suffixText: "Saat",
              ),
            ),
            const SizedBox(height: 20),
           ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              double? yeniMesai = double.tryParse(_controller.text.replaceAll(',', '.'));
              
              setState(() {
                if (yeniMesai != null && yeniMesai > 0) {
                  _mesaiKayitlari[tarihKey] = yeniMesai;
                } else {
                  _mesaiKayitlari.remove(tarihKey);
                }
              });

              final prefs = await SharedPreferences.getInstance();
              String jsonMesai = jsonEncode(_mesaiKayitlari);
              await prefs.setString('mesai_verileri', jsonMesai);

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

  Widget _ustTakvimOlustur() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
            onPressed: () => _takvimiKaydir(false),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _takvimScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 90, 
              itemBuilder: (context, index) {
                DateTime simdi = DateTime.now();
                
                DateTime tarih = DateTime(simdi.year, simdi.month, simdi.day).add(Duration(days: index - 30));
                
                bool seciliMi = _isSameDay(_secilenGun, tarih);
                
                String buGununVardiyasi = calculator!.getShiftType(tarih);
                Color noktaRengi;
                if (buGununVardiyasi.contains("Gündüz")) noktaRengi = Colors.orangeAccent;
                else if (buGununVardiyasi.contains("Gece")) noktaRengi = Colors.indigoAccent;
                else if (buGununVardiyasi.contains("Nöbet")) noktaRengi = Colors.purpleAccent;
                else noktaRengi = Colors.greenAccent;

                String tarihKey = "${tarih.year}-${tarih.month}-${tarih.day}";
                bool mesaiVarMi = _mesaiKayitlari.containsKey(tarihKey);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _secilenGun = tarih;
                      _gununVardiyasi = calculator!.getShiftType(_secilenGun);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: seciliMi ? 80 : 65, 
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: seciliMi ? Colors.white : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(seciliMi ? 30 : 25), 
                      boxShadow: seciliMi
                          ? [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
                          : [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0), 
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _gunIsmiGetir(tarih.weekday),
                                style: TextStyle(color: seciliMi ? Colors.black87 : Colors.white70, fontWeight: FontWeight.w600, fontSize: seciliMi ? 14 : 12),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "${tarih.day}",
                                style: TextStyle(fontSize: seciliMi ? 28 : 22, color: seciliMi ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Container(width: seciliMi ? 10 : 8, height: seciliMi ? 10 : 8, decoration: BoxDecoration(color: noktaRengi, shape: BoxShape.circle))
                            ],
                          ),
                        ),

                        Positioned(
                          top: 6, 
                          right: 6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _secilenGun = tarih; 
                                _gununVardiyasi = calculator!.getShiftType(_secilenGun);
                              });
                              _mesaiGirisPaneliAc(tarih); 
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: mesaiVarMi ? Colors.green : Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: seciliMi ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                              ),
                              child: Icon(
                                mesaiVarMi ? Icons.check : Icons.add, 
                                size: 14, 
                                color: Colors.white
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
            onPressed: () => _takvimiKaydir(true),
          ),
        ],
      ),
    );
  }

  Widget _aylikTakvimOlustur() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _secilenGun,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white70),
          weekendStyle: TextStyle(color: Colors.white70),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, false),
          selectedBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, true),
          todayBuilder: (context, day, focusedDay) => _takvimHucresiOlustur(day, false, isToday: true),
        ),
        selectedDayPredicate: (day) => _isSameDay(_secilenGun, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _secilenGun = selectedDay;
            _gununVardiyasi = calculator!.getShiftType(_secilenGun);
          });
        },
        onDayLongPressed: (selectedDay, focusedDay) {
          setState(() {
            _secilenGun = selectedDay;
            _gununVardiyasi = calculator!.getShiftType(_secilenGun);
          });
          HapticFeedback.vibrate();
          _mesaiGirisPaneliAc(selectedDay);
        },
      ),
    );
  }

  Widget _takvimHucresiOlustur(DateTime day, bool isSelected, {bool isToday = false}) {
    String vardiya = calculator!.getShiftType(day);
    Color noktaRengi;
    
    if (vardiya.contains("Gündüz")) noktaRengi = Colors.orangeAccent;
    else if (vardiya.contains("Gece")) noktaRengi = Colors.indigoAccent;
    else if (vardiya.contains("Nöbet")) noktaRengi = Colors.purpleAccent;
    else noktaRengi = Colors.greenAccent;

    String tarihKey = "${day.year}-${day.month}-${day.day}";
    bool mesaiVarMi = _mesaiKayitlari.containsKey(tarihKey);

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : (isToday ? Colors.white.withOpacity(0.15) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 5)] : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: isSelected ? 16 : 14,
                ),
              ),
              const SizedBox(height: 3),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: noktaRengi, shape: BoxShape.circle)),
            ],
          ),
          
          if (mesaiVarMi)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(Icons.add, color: isSelected ? Colors.green : Colors.blueAccent, size: 12),
            ),
        ],
      ),
    );
  }

  Widget _ortaVardiyaGosterimi() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
      },
      key: ValueKey<String>(_gununVardiyasi),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_ikonGetir(_gununVardiyasi), size: 160, color: _ikonRengiGetir(_gununVardiyasi)),
          const SizedBox(height: 40),
          Text("${_secilenGun.day} ${_ayIsmiGetir(_secilenGun.month)} ${_secilenGun.year}", style: const TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(_gununVardiyasi, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, height: 1.2)),
          ),
        ],
      ),
    );
  }

  String _ayIsmiGetir(int ay) {
    const aylar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return aylar[ay - 1];
  }

  Future<void> _gelecekBildirimleriKur() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    for (int i = 0; i < 7; i++) {
      DateTime kontrolGunu = DateTime.now().add(Duration(days: i));
      String vardiya = calculator!.getShiftType(kontrolGunu);

      if (!vardiya.contains("Tatil")) {
        int baslangicSaati = vardiya.contains("Gündüz") ? 8 : 20;
        if (vardiya.contains("Nöbet")) baslangicSaati = 8; 
        
        DateTime bildirimZamani = DateTime(
          kontrolGunu.year, 
          kontrolGunu.month, 
          kontrolGunu.day, 
          baslangicSaati
        ).subtract(const Duration(hours: 2));

        if (bildirimZamani.isAfter(DateTime.now())) {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            i, 
            'Vardiya Hatırlatıcı',
            '$vardiya vardiyanız 2 saat sonra başlıyor!',
            tz.TZDateTime.from(bildirimZamani, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'vardiya_kanali', 
                'Vardiya Bildirimleri',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _gunIsmiGetir(int haftaninGunu) {
    const gunler = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return gunler[haftaninGunu - 1];
  }

  Color _arkaplanRengiGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return const Color(0xFF4CA1AF); 
    if (vardiya.contains("Gece")) return const Color(0xFF1A1A2E); 
    if (vardiya.contains("Nöbet")) return const Color(0xFF5E35B1); 
    if (vardiya.contains("Tatil")) return const Color(0xFF2C3E50); 
    return Colors.blueGrey;
  }

  IconData _ikonGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return Icons.wb_sunny;
    if (vardiya.contains("Gece")) return Icons.nightlight_round;
    if (vardiya.contains("Nöbet")) return Icons.local_hospital; 
    if (vardiya.contains("Tatil")) return Icons.weekend;
    return Icons.help_outline;
  }

  Color _ikonRengiGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return Colors.orangeAccent;
    if (vardiya.contains("Gece") || vardiya.contains("Nöbet")) return Colors.yellowAccent;
    if (vardiya.contains("Tatil")) return Colors.greenAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaplanRengiGetir(_gununVardiyasi),
      appBar: AppBar(
        title: Text(calculator != null ? _sistemAdiGetir(calculator!.sistem).split(' ')[0] : 'Vardiya Takip'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Aylık Takvimi Paylaş',
            onPressed: _aylikTakvimiPdfYapVePaylas,
          ),
          IconButton(
            icon: Icon(_aylikGorunumMu ? Icons.view_week : Icons.calendar_month),
            tooltip: 'Görünümü Değiştir',
            onPressed: () {
              setState(() {
                _aylikGorunumMu = !_aylikGorunumMu;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _ayarlariAc,
            tooltip: 'Ayarlar',
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A2E),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser?.photoURL ?? ""),
                backgroundColor: Colors.white,
                child: FirebaseAuth.instance.currentUser?.photoURL == null 
                    ? const Icon(Icons.person, size: 40, color: Colors.blueAccent) 
                    : null,
              ),
              accountName: Text(
                (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) 
                ? "Misafir Kullanıcı" 
                : (FirebaseAuth.instance.currentUser?.displayName ?? "Kullanıcı")
              ),
              accountEmail: Text(
                (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) 
                ? "Verileriniz sadece bu cihazda." 
                : (FirebaseAuth.instance.currentUser?.email ?? "")
              ),
            ),
            
            if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false)
              ListTile(
                leading: const Icon(Icons.cloud_sync, color: Colors.greenAccent),
                title: const Text("Verilerini Güvenceye Al", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text("Google Hesabını Bağla", style: TextStyle(color: Colors.white70, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _googleHesabiniBagla();
                },
              ),

            ListTile(
              leading: const Icon(Icons.calculate, color: Colors.white),
              title: const Text("Maaş ve Mesai Hesabı", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MaasHesaplaSayfasi(mesaiKayitlari: _mesaiKayitlari)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Colors.white70),
              title: const Text("Arkadaşla Çakıştır", style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.star, color: Colors.amber, size: 16),
              subtitle: const Text("Yakında / Premium", style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(), 
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: calculator == null 
        ? const Center(child: CircularProgressIndicator(color: Colors.white)) 
        : SafeArea(
            child: Column(
              children: [
                AnimatedCrossFade(
                  firstChild: _ustTakvimOlustur(),
                  secondChild: _aylikTakvimOlustur(),
                  crossFadeState: _aylikGorunumMu ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                Expanded(child: _ortaVardiyaGosterimi()),
              ],
            ),
          ),
    );
  }
}

// --- HESAPLAMA SINIFI ---
class ShiftCalculator {
  DateTime initialDayShift;
  VardiyaSistemi sistem; 
  List<String> ozelDongu; 

  ShiftCalculator(this.initialDayShift, this.sistem, {this.ozelDongu = const []});

  String getShiftType(DateTime targetDate) {
    DateTime start = DateTime(initialDayShift.year, initialDayShift.month, initialDayShift.day);
    DateTime target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    int difference = target.difference(start).inDays;

    if (sistem == VardiyaSistemi.ozelDuzen) {
      if (ozelDongu.isEmpty) return "Tatil\n(İstirahat)"; 
      
      int cycleLength = ozelDongu.length;
      int cycle = (difference % cycleLength + cycleLength) % cycleLength; 
      String shift = ozelDongu[cycle];
      
      if (shift == "Gündüz") return "Gündüz\n(08:00 - 20:00)";
      if (shift == "Gece") return "Gece\n(20:00 - 08:00)";
      if (shift == "Nöbet") return "24 Saat\nNöbet";
      return "Tatil\n(İstirahat)";
    }

    switch (sistem) {
      case VardiyaSistemi.sistem12_24: 
        int cycle = (difference % 3 + 3) % 3;
        if (cycle == 0) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 1) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.sistem12_36: 
        int cycle = (difference % 4 + 4) % 4;
        if (cycle == 0) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 1) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.sistem24_48: 
        int cycle = (difference % 3 + 3) % 3;
        if (cycle == 0) return "24 Saat\nNöbet";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.ikiGunduz_ikiGece_ikiTatil: 
        int cycle = (difference % 6 + 6) % 6;
        if (cycle == 0 || cycle == 1) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 2 || cycle == 3) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";
        
      default:
        return "Tatil\n(İstirahat)";
    }
  }
}

// --- GİRİŞ KONTROL YÖNETİCİSİ (KAPICI) ---
class AuthYonetici extends StatelessWidget {
  const AuthYonetici({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1A2E),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        
        if (snapshot.hasData) {
          return const AnaEkran();
        }
        
        return const GirisEkrani();
      },
    );
  }
}

// --- ŞIK GİRİŞ EKRANI TASARIMI VE MANTIĞI ---
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  bool _yukleniyor = false;

  Future<void> _googleIleGirisYap() async {
    setState(() => _yukleniyor = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _yukleniyor = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      
    } catch (e) {
      print("Giriş Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giriş başarısız oldu. Lütfen tekrar deneyin.')),
      );
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _misafirOlarakGirisYap() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      print("Misafir Girişi Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı kurulamadı. Lütfen tekrar deneyin.')),
      );
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 100, color: Colors.blueAccent),
                const SizedBox(height: 30),
                
                const Text(
                  "Vardiya Takip",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Çalışma günlerinizi buluta kaydedin,\nhiçbir vardiyayı kaçırmayın.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 50),

                _yukleniyor 
                  ? const CircularProgressIndicator(color: Colors.blueAccent)
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.mail, color: Colors.redAccent), 
                            label: const Text(
                              "Google ile Giriş Yap",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _googleIleGirisYap,
                          ),
                        ),
                        
                        const SizedBox(height: 15),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: _misafirOlarakGirisYap,
                            child: const Text(
                              "Giriş Yapmadan Devam Et",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(title: const Text("Ekstra Ücret Hesabı")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent, width: 2),
              ),
              child: Column(
                children: [
                  const Text("BU AYKİ TOPLAM EK KAZANÇ", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text("${toplamKazanc.toStringAsFixed(2)} ₺", 
                         style: const TextStyle(color: Colors.greenAccent, fontSize: 36, fontWeight: FontWeight.bold)),
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
          decoration: InputDecoration(
            suffixText: suffix, 
            suffixStyle: const TextStyle(color: Colors.white54)
          ),
          onChanged: (String s) {
            double val = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
            onChanged(val);
          },
        ),
      ),
    );
  }
}