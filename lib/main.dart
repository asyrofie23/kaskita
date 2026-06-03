import 'package:flutter/material.dart';
import 'home_page.dart'; // Ini cara manggil file home_page.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasKita', // Update nama aplikasinya
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const HomePage(), // HomePage diambil dari file sebelah
    );
  }
}