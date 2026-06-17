import 'grup_detail_page.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'splash_screen.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {

  // Proses masuk google
  Future<void> _loginGoogle(BuildContext context) async {
    try {
      // Inisialisasi Google Sign-In SDK
      await GoogleSignIn.instance.initialize();
      // Buka pop-up pilihan akun Google user
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return; // Batalkan jika user tidak jadi memilih akun

      // Dapatkan token otentikasi dari akun Google terpilih
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Berikan izin scope akses email dan profil dasar
      final authClient = googleUser.authorizationClient;
      final clientAuth = await authClient.authorizeScopes(['email', 'profile']);
      final String? accessToken = clientAuth.accessToken;

      // Konversi token menjadi OAuthCredential agar dikenali oleh Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      // Ambil data user yang sedang aktif saat ini (apakah akun Tamu/Anonim)
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          // Lakukan upgrade akun Tamu menjadi akun Google (menghubungkan data kas lokal ke akun Google)
          await currentUser.linkWithCredential(credential);
          debugPrint("Berhasil menyambungkan akun Tamu ke Google!");
        } on FirebaseAuthException catch (e) {
          // Jika email Google tersebut sudah pernah login sebelumnya di HP lain
          if (e.code == 'credential-already-in-use') {
            debugPrint("Akun Google sudah ada, beralih ke login biasa...");
            // Langsung login biasa menggunakan Google Credential (data lokal terhapus/ganti data Google)
            await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow; // Teruskan error lain jika terjadi hal di luar dugaan
          }
        }
      }

      // Buat/update profil fisik user di Firestore saat login dengan Google
      currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'uid': currentUser.uid,
          'email': currentUser.email,
          'nama': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Pengguna Google',
          'terakhir_aktif': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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

  // LOGOUT
  // Mengeluarkan sesi user dari Google dan Firebase Auth
  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn.instance.signOut(); // Logout dari Google
    await FirebaseAuth.instance.signOut(); // Logout dari Firebase
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil Logout')),
      );
      // Arahkan kembali user ke Splash Screen agar dibuatkan akun tamu baru otomatis
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  // PU catatan Bers.
  // Dialog form untuk membuat grup kas baru di mana pembuat otomatis menjadi Admin
  void _tampilDialogBuatCatatan(BuildContext context, bool isDark) {
    final TextEditingController namaGrupController = TextEditingController();
    bool isLoading = false; // Flag status loading untuk tombol submit

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
                  // Input nama grup kas
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
                // Tombol Batal
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                // Tombol Buat Grup (Mengirim data ke Firebase Firestore)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isLoading ? null : () async {
                    final String namaGrup = namaGrupController.text.trim();
                    if (namaGrup.isEmpty) return;

                    // 1. Cek status keanggotaan (Akun Tamu dilarang membuat grup)
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || user.isAnonymous) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harus hubungkan ke Google dulu buat bikin grup!'), backgroundColor: Colors.red));
                      Navigator.pop(context);
                      return;
                    }

                    // 2. Nyalakan status loading di dialog
                    setDialogState(() => isLoading = true);

                    try {
                      // 3. Generate Kode Undangan Acak (KAS-XXXXX)
                      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                      final rnd = Random();
                      String kode = 'KAS-';
                      for (var i = 0; i < 5; i++) {
                        kode += chars[rnd.nextInt(chars.length)];
                      }

                      // 4. Daftarkan dan simpan grup kas baru di database Firestore
                      String namaUser = user.displayName ?? user.email?.split('@')[0] ?? 'Admin';
                      
                      await FirebaseFirestore.instance.collection('grup_kas').doc(kode).set({
                        'nama_grup': namaGrup,
                        'kode_undangan': kode,
                        'dibuat_pada': FieldValue.serverTimestamp(),
                        'admin_uid': user.uid,
                        // Menentukan peran/role anggota (pembuat diset sebagai Admin)
                        'anggota': {
                          user.uid: 'Admin'
                        },
                        // Menyimpan nama representasi setiap anggota
                        'nama_anggota': { 
                          user.uid: namaUser
                        },
                        // Array untuk mempermudah query pencarian grup kas user
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
          },
        );
      },
    );
  }

  // Pu gabung
  // Dialog form untuk bergabung ke dalam grup kas yang sudah ada via kode undangan
  void _tampilDialogGabungCatatan(BuildContext context, bool isDark) {
    final TextEditingController kodeController = TextEditingController();
    bool isLoading = false; // Flag loading submit

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
                  // Input Kode Undangan (KAS-XXXXX)
                  TextField(
                    controller: kodeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters, // Otomatis input huruf kapital
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
                // Tombol Batal
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                // Tombol Gabung (Melakukan validasi kode & pendaftaran di Firestore)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isLoading ? null : () async {
                    final String kode = kodeController.text.trim().toUpperCase();
                    if (kode.isEmpty) return;

                    // 1. Validasi: Akun Tamu dilarang gabung grup kas kolaborasi
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || user.isAnonymous) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harus hubungkan ke Google dulu buat gabung grup!'), backgroundColor: Colors.red));
                      Navigator.pop(context);
                      return;
                    }

                    // 2. Aktifkan loading
                    setDialogState(() => isLoading = true);

                    try {
                      // 3. Cek ketersediaan dokumen grup berdasarkan ID kode di Firestore
                      final docRef = FirebaseFirestore.instance.collection('grup_kas').doc(kode);
                      final docSnap = await docRef.get();

                      if (docSnap.exists) {
                        // 4. Jika ditemukan: Tambahkan UID user sebagai Editor dan rekam namanya
                        String namaUser = user.displayName ?? user.email?.split('@')[0] ?? 'Anggota';

                        await docRef.update({
                          'anggota.${user.uid}': 'Editor', // Mengatur role baru sebagai Editor
                          'nama_anggota.${user.uid}': namaUser, // Rekam nama user di grup
                          'id_anggota': FieldValue.arrayUnion([user.uid]) // Tambah UID ke array indeks anggota
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil bergabung ke grup!'), backgroundColor: Colors.green));
                        }
                      } else {
                        // Grup tidak ditemukan (ID dokumen salah)
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

  // About
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
              // Logo Kaskita
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, size: 50, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 15),
            
              Text('KasKita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 5),
              const Text('Versi 2.0.0', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text(
                'Aplikasi pencatatan keuangan pintar dengan fitur kolaborasi kas bersama secara real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 20),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              const SizedBox(height: 10),
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
            // bottom close about
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
      // AppBar dengan judul dan tombol toggle saklar tema (Terang / Gelap)
      appBar: AppBar(
        title: const Text('Profil & Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [

          // button theme
          
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : Colors.grey),
            onPressed: () {
              // Mengubah nilai notifier global tema
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
            // KARTU IDENTITAS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              // StreamBuilder memantau status sesi login Firebase secara realtime
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final User? user = snapshot.data;

                  // Jika data user null (belum login sama sekali)
                  if (user == null) {
                    return _buildBelumLogin(context, textColor);
                  }

                  // Jika sudah terdeteksi login (baik Tamu maupun Google)
                  return _buildSudahLogin(context, user, textColor, isDark);
                },
              ),
            ),
            const SizedBox(height: 25),

            // FITUR CATATAN BERSAMA
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
                  // Listtile pemicu dialog gabung grup kas via kode
                  _buildMenuTile(Icons.group_add_outlined, 'Gabung Catatan via Kode', 'Masukkan kode undangan', textColor, isDark, onTap: () {
                    _tampilDialogGabungCatatan(context, isDark);
                  }),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  
                  // Listtile pemicu dialog buat grup kas baru
                  _buildMenuTile(Icons.add_box_outlined, 'Buat Catatan Bersama', 'Jadi admin dan undang teman', textColor, isDark, onTap: () {
                    _tampilDialogBuatCatatan(context, isDark);
                  }),
                ],
              ),
            ),

            // DAFTAR GRUP SAYA
            _buildDaftarGrupSaya(context, cardColor, textColor, isDark),

            // PENGATURAN UMUM
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

                  // Informasi pengembang aplikasi
                  _buildMenuTile(Icons.info_outline, 'Tentang KasKita', 'Versi 2.0.0', textColor, isDark, onTap: () {
                    _tampilDialogTentang(context, isDark);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WIDGET HELPER: TAMPILAN JIKA USER BELUM LOGIN
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
          // Tombol login menginisiasi otentikasi Google
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
            icon: Image.network('https://cdn-icons-png.flaticon.com/512/300/300221.png', height: 20), 
            label: const Text('Login dengan Google', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _loginGoogle(context),
          ),
        ),
      ],
    );
  }

  // WIDGET HELPER: TAMPILAN JIKA USER SUDAH LOGIN (Mendukung Akun Google dan Akun Tamu)
  Widget _buildSudahLogin(BuildContext context, User user, Color textColor, bool isDark) {
    bool isGuest = user.isAnonymous; // Cek apakah sesi aktif merupakan Akun Tamu
    
    // Logika penentuan nama panggilan yang dipajang di profil
    String namaTampil = 'Pengguna';
    if (isGuest) {
      namaTampil = 'Akun Tamu (Guest Mode)';
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      namaTampil = user.displayName!;
    } else if (user.email != null && user.email!.isNotEmpty) {
      namaTampil = user.email!.split('@')[0];
    }

    return Column(
      children: [
        // Deteksi klik pada area profil untuk mengubah nama panggilan (khusus non-tamu)
        GestureDetector(
          onTap: isGuest ? null : () => _tampilDialogUbahNama(context, isDark),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              // Foto profil user (lingkaran bulat)
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.edit, size: 50, color: Colors.white) : null,
              ),
               const SizedBox(height: 15),
               Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    namaTampil,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  if (!isGuest) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.edit, size: 16, color: isDark ? Colors.white70 : Colors.black54), // Ikon edit
                  ],
                ],
              ),
              const SizedBox(height: 5),
              // Email user atau status akun
              Text(
                isGuest ? 'Data disimpan lokal di perangkat ini' : (user.email ?? '-'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        // Jika statusnya Tamu, munculkan tombol ajakan upgrade akun ke Google
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
        
        // Jika statusnya terhubung Google, munculkan tombol Logout
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
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ],
    );
  }

  // WIDGET HELPER: Membuat baris menu pengaturan (ListTile) secara dinamis
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

  // Menampilkan list grup kas yang diikuti user dengan memanfaatkan query Firestore realtime
  Widget _buildDaftarGrupSaya(BuildContext context, Color cardColor, Color textColor, bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink(); // Sembunyikan jika akun Tamu

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Grup Saya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 10),
        // Query grup_kas di mana UID user terdaftar di array id_anggota
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('grup_kas')
              .where('id_anggota', arrayContains: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            // Jika user belum memiliki atau bergabung ke grup manapun
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                child: const Text('Belum ada grup. Buat atau gabung sekarang!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              );
            }

            // ListView daftar grup kas
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
                       // Navigasi masuk ke halaman Detail Grup
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

  // Dialog untuk mengubah nama user dan mensinkronisasikannya ke semua grup kas terkait
  void _tampilDialogUbahNama(BuildContext context, bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    // Prefill input dengan nama saat ini
    final TextEditingController _namaController = TextEditingController(
        text: user.displayName ?? user.email?.split('@')[0] ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Ubah Nama Panggilan', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nama ini akan terlihat oleh semua anggota di grup patunganmu.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                  const SizedBox(height: 15),
                  // Input nama baru
                  TextField(
                    controller: _namaController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Username', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
              actions: [
                // Tombol Batal
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                // Tombol Simpan (Melakukan update batch di Firebase Auth & Firestore)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isLoading ? null : () async {
                    final String namaBaru = _namaController.text.trim();
                    if (namaBaru.isEmpty || namaBaru == user.displayName) return;

                    setDialogState(() => isLoading = true);

                    try {
                      // 1. Update nama profil di Firebase Auth (akun utama)
                      await user.updateDisplayName(namaBaru);

                      // 2. Ambil seluruh grup kas di mana user terdaftar
                      final grupSnap = await FirebaseFirestore.instance
                          .collection('grup_kas')
                          .where('id_anggota', arrayContains: user.uid)
                          .get();

                      // 3. Gunakan Firestore Batch untuk meng-update nama secara serentak (atomic update)
                      final batch = FirebaseFirestore.instance.batch();
                      for (var doc in grupSnap.docs) {
                        batch.update(doc.reference, {
                          'nama_anggota.${user.uid}': namaBaru
                        });
                      }
                      
                      // Eksekusi seluruh batch update
                      await batch.commit();

                      if (context.mounted) {
                        Navigator.pop(context);
                        // Trigger rebuild UI halaman profil agar nama ter-update
                        setState(() {}); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama berhasil diubah dan disinkronisasi!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah nama: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }
}