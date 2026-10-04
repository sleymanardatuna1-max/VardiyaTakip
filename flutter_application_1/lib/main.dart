import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'theme.dart';
import 'main_screen.dart';
import 'services/shift_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
const widgetChannel = MethodChannel('com.vardiya.widget/update');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  tz.initializeTimeZones(); 
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul')); 

  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await ShiftService().loadSettings();

  runApp(const VardiyaApp()); 
}

class VardiyaApp extends StatelessWidget {
  const VardiyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vardiya Takip',
      theme: AppTheme.darkTheme,
      home: const AuthYonetici(), 
    );
  }
}

class AuthYonetici extends StatelessWidget {
  const AuthYonetici({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        }
        if (snapshot.hasData) return const MainScreen();
        return const GirisEkrani();
      },
    );
  }
}

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Giriş başarısız oldu. Lütfen tekrar deneyin.')),
        );
      }
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _misafirOlarakGirisYap() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı kurulamadı. Lütfen tekrar deneyin.')),
        );
      }
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 100, color: AppTheme.primaryColor),
                const SizedBox(height: 30),
                const Text("Vardiya Takip", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Çalışma günlerinizi buluta kaydedin,\nhiçbir vardiyayı kaçırmayın.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5)),
                const SizedBox(height: 50),
                _yukleniyor 
                  ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            icon: const Icon(Icons.mail, color: Colors.redAccent), 
                            label: const Text("Google ile Giriş Yap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: _misafirOlarakGirisYap,
                            child: const Text("Giriş Yapmadan Devam Et", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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