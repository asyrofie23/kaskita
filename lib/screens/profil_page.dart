// =========================================================
// FILE: lib/screens/profil_page.dart
// =========================================================
import 'grup_detail_page.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'splash_screen.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  /// --- FUNGSI LOGIN GOOGLE ---
  Future<void> _loginGoogle(BuildContext context) async {
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final authClient = googleUser.authorizationClient;
      final clientAuth = await authClient.authorizeScopes(['email', 'profile']);
      final String? accessToken = clientAuth.accessToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      // Cek apakah user saat ini pakai akun Tamu (Anonim)
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          // JURUS 1: Coba upgrade akun tamu menjadi akun Google
          await currentUser.linkWithCredential(credential);
          debugPrint("Berhasil menyambungkan akun Tamu ke Google!");
        } on FirebaseAuthException catch (e) {
          // Jika akun Google sudah pernah terdaftar sebelumnya
          if (e.code == 'credential-already-in-use') {
            debugPrint("Akun Google sudah ada, beralih ke login biasa...");
            // JURUS 2: Hapus KTP Tamu, langsung login pakai Google yang sudah ada
            await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow; // Lempar error lain kalau ada
          }
        }
      } else {
        // Kalau bukan tamu, login Google biasa
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil Login!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Login: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// --- FUNGSI LOGOUT ---
  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil Logout')),
      );
      // Tendang balik ke Splash Screen biar dapat KTP Tamu baru
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  /// --- POP-UP BUAT CATATAN BERSAMA ---
  void _tampilDialogBuatCatatan(BuildContext context, bool isDark) {
    final TextEditingController namaGrupController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Buat Catatan Bersama', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kamu akan menjadi Admin. Silakan beri nama untuk grup catatan ini.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: namaGrupController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Misal: Kosan, Liburan Bali',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isLoading ? null : () async {
                    final String namaGrup = namaGrupController.text.trim();
                    if (namaGrup.isEmpty) return;

                    // 1. Cek apakah user adalah tamu
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || user.isAnonymous) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harus hubungkan ke Google dulu buat bikin grup!'), backgroundColor: Colors.red));
                      Navigator.pop(context);
                      return;
                    }

                    // 2. Nyalakan loading
                    setDialogState(() => isLoading = true);

                    try {
                      // 3. Generate Kode Acak (KAS-XXXXX)
                      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                      final rnd = Random();
                      String kode = 'KAS-';
                      for (var i = 0; i < 5; i++) {
                        kode += chars[rnd.nextInt(chars.length)];
                      }

                      // 4. Simpan ke Firestore di koleksi khusus 'grup_kas'
                      String namaUser = user.displayName ?? user.email?.split('@')[0] ?? 'Admin';
                      
                      await FirebaseFirestore.instance.collection('grup_kas').doc(kode).set({
                        'nama_grup': namaGrup,
                        'kode_undangan': kode,
                        'dibuat_pada': FieldValue.serverTimestamp(),
                        'admin_uid': user.uid,
                        'anggota': {
                          user.uid: 'Admin'
                        },
                        'nama_anggota': { // <--- TAMBAHAN: Simpan nama
                          user.uid: namaUser
                        },
                        'id_anggota': [user.uid]
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grup "$namaGrup" berhasil dibuat! Kode: $kode'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buat grup: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Buat Grup', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  /// --- POP-UP GABUNG CATATAN ---
  void _tampilDialogGabungCatatan(BuildContext context, bool isDark) {
    final TextEditingController kodeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Gabung Catatan', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Masukkan kode undangan dari Admin untuk bergabung ke dalam grup.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: kodeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters, // Biar otomatis huruf besar
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'KAS-XXXXX',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.normal, letterSpacing: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isLoading ? null : () async {
                    final String kode = kodeController.text.trim().toUpperCase();
                    if (kode.isEmpty) return;

                    // 1. Cek apakah user adalah tamu
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || user.isAnonymous) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harus hubungkan ke Google dulu buat gabung grup!'), backgroundColor: Colors.red));
                      Navigator.pop(context);
                      return;
                    }

                    // 2. Nyalakan loading
                    setDialogState(() => isLoading = true);

                    try {
                      // 3. Cari grup berdasarkan ID dokumen (kode undangan)
                      final docRef = FirebaseFirestore.instance.collection('grup_kas').doc(kode);
                      final docSnap = await docRef.get();

                      if (docSnap.exists) {
                        // 4. Grup ditemukan! Tambahkan UID dan Nama user
                        String namaUser = user.displayName ?? user.email?.split('@')[0] ?? 'Anggota';

                        await docRef.update({
                          'anggota.${user.uid}': 'Editor', 
                          'nama_anggota.${user.uid}': namaUser, // <--- TAMBAHAN: Simpan nama temenmu
                          'id_anggota': FieldValue.arrayUnion([user.uid])
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil bergabung ke grup!'), backgroundColor: Colors.green));
                        }
                      } else {
                        // Grup tidak ditemukan
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode tidak valid atau grup tidak ditemukan.'), backgroundColor: Colors.red));
                        }
                      }
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal bergabung: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Gabung', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

/// --- POP-UP TENTANG KASKITA ---
  void _tampilDialogTentang(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(25),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo Aplikasi
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, size: 50, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 15),
              // Nama Aplikasi & Versi
              Text('KasKita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 5),
              const Text('Versi 1.6.0', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)), // <--- Versi
              const SizedBox(height: 15),
              // Deskripsi
              Text(
                'Aplikasi pencatatan keuangan pintar dengan fitur kolaborasi kas bersama secara real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 20),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              const SizedBox(height: 10),
              // Credit Developer
              const Text('Dikembangkan oleh:', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 5),
              const Text(
                'AHMAD RIFQI AL ASYROFI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2, color: Color(0xFF2563EB)),
              ),
              const Text('202369040078', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 14,letterSpacing: 1.2, color: Colors.grey)),
              const SizedBox(height: 5),
          
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Profil & Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : Colors.grey),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ==========================================
            /// 1. KARTU IDENTITAS (PANTAU STATUS LOGIN)
            /// ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              // StreamBuilder memantau perubahan status login secara real-time
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  // Jika masih loading ngecek status
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Ambil data user
                  final User? user = snapshot.data;

                  // Jika user belum login, tampilkan tombol login
                  if (user == null) {
                    return _buildBelumLogin(context, textColor);
                  }

                  // Jika sudah login, tampilkan info profilnya
                  return _buildSudahLogin(context, user, textColor, isDark);
                },
              ),
            ),
            const SizedBox(height: 25),

            /// ==========================================
            /// 2. MENU CATATAN BERSAMA
            /// ==========================================
            const Text('Catatan Bersama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildMenuTile(Icons.group_add_outlined, 'Gabung Catatan via Kode', 'Masukkan kode undangan', textColor, isDark, onTap: () {
                    _tampilDialogGabungCatatan(context, isDark);
                  }),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  
                  // COLOKIN MESINNYA DI SINI
                  _buildMenuTile(Icons.add_box_outlined, 'Buat Catatan Bersama', 'Jadi admin dan undang teman', textColor, isDark, onTap: () {
                    _tampilDialogBuatCatatan(context, isDark);
                  }),
                ],
              ),
            ),
            /// ==========================================
            /// DAFTAR GRUP SAYA (TAMBAHAN BARU)
            /// ==========================================

            _buildDaftarGrupSaya(context, cardColor, textColor, isDark),

            /// ==========================================
            /// 3. PENGATURAN UMUM
            /// ==========================================
            const Text('Pengaturan Umum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildMenuTile(Icons.notifications_outlined, 'Notifikasi', 'Atur pengingat anggaran', textColor, isDark, onTap: () {}),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _buildMenuTile(Icons.download_outlined, 'Ekspor Laporan (PDF/CSV)', 'Unduh riwayat transaksi', textColor, isDark, onTap: () {}),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _buildMenuTile(Icons.info_outline, 'Tentang KasKita', 'Versi 1.6.0', textColor, isDark, onTap: () {
                    _tampilDialogTentang(context, isDark);}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// TAMPILAN JIKA BELUM LOGIN
  Widget _buildBelumLogin(BuildContext context, Color textColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 15),
        Text('Belum Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        const SizedBox(height: 5),
        const Text('Login untuk akses fitur Catatan Bersama', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            // Pakai icon bawaan internet biar cepat
            icon: Image.network('https://cdn-icons-png.flaticon.com/512/300/300221.png', height: 20), 
            label: const Text('Login dengan Google', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _loginGoogle(context), // PANGGIL FUNGSI LOGIN
          ),
        ),
      ],
    );
  }

  Widget _buildSudahLogin(BuildContext context, User user, Color textColor, bool isDark) {
    bool isGuest = user.isAnonymous;
    
    // Tentukan nama yang akan ditampilkan
    String namaTampil = 'Pengguna';
    if (isGuest) {
      namaTampil = 'Akun Tamu (Guest Mode)';
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      namaTampil = user.displayName!;
    } else if (user.email != null && user.email!.isNotEmpty) {
      namaTampil = user.email!.split('@')[0]; // Ambil dari email
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
        ),
        const SizedBox(height: 15),
        // GANTI BAGIAN TEKS NAMA INI
        Text(
          namaTampil,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
        ),
        const SizedBox(height: 5),
        // Ambil email dari akun Google/Tamu
        Text(
          isGuest ? 'Data disimpan lokal di perangkat ini' : (user.email ?? '-'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        if (isGuest) ...[
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Image.network(
                'https://cdn-icons-png.flaticon.com/512/300/300221.png',
                height: 20,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.link, color: Colors.white),
              ),
              label: const Text('Hubungkan ke Google', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _loginGoogle(context),
            ),
          ),
        ],
        
        // --- TAMBAHKAN IF (!isGuest) DI SINI ---
        if (!isGuest) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _logout(context), // PANGGIL FUNGSI LOGOUT
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, Color textColor, bool isDark, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
  /// --- TAMPILAN DAFTAR GRUP SAYA ---
  Widget _buildDaftarGrupSaya(BuildContext context, Color cardColor, Color textColor, bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink(); // Sembunyikan kalau mode tamu

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Grup Saya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          // Cari grup yang di dalam array 'id_anggota'-nya terdapat UID user saat ini
          stream: FirebaseFirestore.instance
              .collection('grup_kas')
              .where('id_anggota', arrayContains: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                child: const Text('Belum ada grup. Buat atau gabung sekarang!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              );
            }

            // Tampilkan list grup
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final namaGrup = data['nama_grup'] ?? 'Grup Tanpa Nama';
                final kode = data['kode_undangan'] ?? '-';
                final role = data['anggota'][user.uid] ?? 'Anggota';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                      child: const Icon(Icons.wallet, color: Color(0xFF2563EB)),
                    ),
                    title: Text(namaGrup, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text('Kode: $kode • Peran: $role', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    
                    onTap: () {
                      // BUKA HALAMAN DETAIL GRUP
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GrupDetailPage(
                            kodeGrup: kode,
                            namaGrup: namaGrup,
                            roleUser: role,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}