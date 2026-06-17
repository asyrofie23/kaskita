import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Controller untuk mengontrol jalannya animasi logo
  late AnimationController _controller;
  // Animasi untuk efek pudar (fade-in) logo dan teks
  late Animation<double> _fadeAnimation;
  // Animasi untuk efek pembesaran (zoom/scale-in) logo
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Menginisialisasi controller animasi dengan durasi 1.5 detik
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animasi perubahan opacity dari transparan ke penuh (0.0 ke 1.0)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Animasi pembesaran dari ukuran 80% ke 100% dengan efek membal (elastic out)
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Memulai jalannya animasi logo
    _controller.forward();

    // Panggil fungsi cek status masuk pengguna secara async
    _siapkanAkunLaluPindah();
  }

  // Fungsi untuk cek status login & buat akun tamu secara otomatis jika belum login
  Future<void> _siapkanAkunLaluPindah() async {
    try {
      // Tunggu animasi splash screen minimal 3 detik biar estetik
      await Future.delayed(const Duration(seconds: 3));

      // Cek apakah user sudah punya akun (Google / Anonim)
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      // Kalau benar-benar belum punya, buatkan akun Tamu (Anonim) diam-diam
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // Re-fetch user dan buat/update profil fisik di Firestore agar UID langsung terdaftar di dashboard
      currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'uid': currentUser.uid,
          'email': currentUser.email,
          'nama': currentUser.displayName ?? 'Tamu',
          'terakhir_aktif': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Setelah KTP siap, langsung pindah ke HomePage
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint('Error saat menyiapkan akun tamu: $e');
      // Tetap pindah ke HomePage walaupun error, biar user nggak stuck
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] // Gradasi Mode Gelap
                : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)], // Gradasi Mode Terang (Premium Blue)
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Konten Tengah (Logo & Teks)
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lingkaran Logo dengan Soft Glow
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(isDark ? 0.15 : 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nama Aplikasi
                    const Text(
                      'KasKita',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle Slogan
                    Text(
                      'Catat Kas Jadi Lebih Mudah',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Loading Indikator di Bagian Bawah
            Positioned(
              bottom: 40, // Agak diturunin dikit biar nggak terlalu mepet ke tengah
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Cari bagian ini dan ubah angkanya
                  const Text(
                    'v1.9.0', // <--- Versi
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70, // Sedikit dicerahkan biar estetik
                    ),
                  ),
                  const SizedBox(height: 8),
                  // WATERMARK DEVELOPER
                  Text(
                    '@ahmed_asyrofie',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8), // Sengaja dibikin lebih terang dikit biar eye-catching
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
