import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import package firebase
import 'firebase_options.dart'; // Import file yang baru aja terbuat
import 'home_page.dart'; 

// WAJIB: Ubah void main() jadi async
void main() async {
  // Wajib dipanggil sebelum inisialisasi Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Menyalakan mesin Firebase sesuai platform (Android/iOS)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasKita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), 
      ),
      home: const HomePage(),
    );
  }
}