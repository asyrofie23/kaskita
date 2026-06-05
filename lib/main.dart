import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 1. BUAT VARIABEL GLOBAL TEMA
// Variabel ini bertindak sebagai "saklar" yang bisa diakses dari file mana saja
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. ValueListenableBuilder bertugas memantau perubahan saklar tema
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'KasKita',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('id', 'ID'),
            Locale('en', 'US'),
          ],
          locale: const Locale('id', 'ID'),
          
          // SETTINGAN WARNA MODE TERANG (LIGHT)
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.red,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA), 
          ),
          
          // SETTINGAN WARNA MODE GELAP (DARK)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.red,
            scaffoldBackgroundColor: const Color(0xFF121212), // Background jadi hitam
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E1E1E), // Warna pop-up form jadi abu gelap
            ),
          ),
          
          // Terapkan mode sesuai posisi saklar
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}