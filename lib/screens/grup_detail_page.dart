// =========================================================
// FILE: lib/screens/grup_detail_page.dart
// =========================================================
import 'home_page.dart' show SlidableTile;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GrupDetailPage extends StatefulWidget {
  final String kodeGrup;
  final String namaGrup;
  final String roleUser;

  const GrupDetailPage({
    super.key,
    required this.kodeGrup,
    required this.namaGrup,
    required this.roleUser,
  });

  @override
  State<GrupDetailPage> createState() => _GrupDetailPageState();
}

class _GrupDetailPageState extends State<GrupDetailPage> {
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();

  String _formatUang(int angka) {
    String str = angka.toString();
    String hasil = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      hasil = str[i] + hasil;
      count++;
      if (count % 3 == 0 && i != 0) hasil = '.$hasil';
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Cek apakah user punya hak untuk menambah/mengedit catatan
    bool bisaEdit = widget.roleUser == 'Admin' || widget.roleUser == 'Editor';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.namaGrup, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Kode: ${widget.kodeGrup} • Kamu: ${widget.roleUser}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              // PANGGIL FUNGSI POP-UP DI SINI
              _tampilDaftarAnggota(context);
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // MENGAMBIL DATA KHUSUS DARI FOLDER TRANSAKSI GRUP INI
        stream: FirebaseFirestore.instance
            .collection('grup_kas')
            .doc(widget.kodeGrup)
            .collection('transaksi')
            .orderBy('tanggal', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Hitung Saldo Bersama
          int totalPemasukan = 0;
          int totalPengeluaran = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final nominal = data['nominal'] ?? 0;
            if (data['isPemasukan'] == true) {
              totalPemasukan += nominal as int;
            } else {
              totalPengeluaran += nominal as int;
            }
          }
          int totalSaldo = totalPemasukan - totalPengeluaran;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KARTU SALDO BERSAMA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo Kas Bersama', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 10),
                      Text('Rp ${_formatUang(totalSaldo)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSaldoInfo(Icons.arrow_downward, 'Pemasukan', 'Rp ${_formatUang(totalPemasukan)}', Colors.greenAccent),
                          _buildSaldoInfo(Icons.arrow_upward, 'Pengeluaran', 'Rp ${_formatUang(totalPengeluaran)}', Colors.redAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),

                // LIST TRANSAKSI
                if (docs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Text('Belum ada iuran atau pengeluaran di grup ini.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final docId = doc.id; // Ambil ID dokumen buat diedit/dihapus
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isPemasukan = data['isPemasukan'] ?? true;
                      final String judul = data['judul'] ?? '';
                      final int nominal = data['nominal'] ?? 0;
                      final String pembuat = data['nama_pembuat'] ?? 'Anggota';
                      
                      String waktuTampil = '';
                      if (data['tanggal'] != null && data['tanggal'] is Timestamp) {
                        waktuTampil = DateFormat('dd MMM yyyy, HH:mm').format((data['tanggal'] as Timestamp).toDate());
                      }

                      // 1. Simpan UI Kotak Transaksi ke dalam variabel
                      Widget kontenTransaksi = Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPemasukan ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(isPemasukan ? Icons.arrow_downward : Icons.arrow_upward, color: isPemasukan ? Colors.green : Colors.red),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Oleh: $pembuat', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isPemasukan ? "+" : "-"}Rp ${_formatUang(nominal)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isPemasukan ? Colors.green : Colors.red, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(waktuTampil, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );

                      // 2. Kalau jabatannya Admin/Editor, bungkus pakai fitur Swipe!
                      if (bisaEdit) {
                        // Ambil tanggal asli dari database buat dimasukkan ke form Edit
                        DateTime tanggalAsli = DateTime.now();
                        if (data['tanggal'] != null && data['tanggal'] is Timestamp) {
                          tanggalAsli = (data['tanggal'] as Timestamp).toDate();
                        }

                        return SlidableTile(
                          key: Key(docId),
                          onEdit: () => _tampilFormTransaksiGrup(
                            context,
                            docId: docId,
                            judulAwal: judul,
                            nominalAwal: nominal,
                            isPemasukanAwal: isPemasukan,
                            tanggalAwal: tanggalAsli, // <--- TAMBAHAN BARU: Kirim tanggal aslinya
                          ),
                          onDelete: () => _konfirmasiHapusTransaksiGrup(context, docId, judul),
                          child: kontenTransaksi,
                        );
                      }

                      // 3. Kalau cuma Spectator, kembalikan kotak biasa (nggak bisa di-swipe)
                      return kontenTransaksi;
                    },
                  ),
              ],
            ),
          );
        },
      ),
      
      // TOMBOL PLUS HANYA MUNCUL JIKA USER ADALAH ADMIN ATAU EDITOR
      floatingActionButton: bisaEdit ? FloatingActionButton(
        backgroundColor: const Color(0xFF1D4ED8),
        onPressed: () => _tampilFormTransaksiGrup(context),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildSaldoInfo(IconData icon, String title, String amount, Color iconColor) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 16)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]),
      ],
    );
  }


  // --- FORM TAMBAH & EDIT TRANSAKSI GRUP ---
  void _tampilFormTransaksiGrup(BuildContext context, {String? docId, String? judulAwal, int? nominalAwal, bool? isPemasukanAwal, DateTime? tanggalAwal}) {
    final bool isEditMode = docId != null;
    bool isPemasukanTerpilih = isEditMode ? isPemasukanAwal! : true;
    DateTime tanggalTerpilih = tanggalAwal ?? DateTime.now(); // <--- Variabel tanggal
    
    if (isEditMode) {
      _judulController.text = judulAwal!;
      _nominalController.text = nominalAwal!.toString();
    } else {
      _judulController.clear();
      _nominalController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri biar rapi
                  children: [
                    Center(child: Text(isEditMode ? 'Edit Transaksi Grup' : 'Tambah Transaksi Grup', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Uang Masuk/Iuran'), 
                          selected: isPemasukanTerpilih, 
                          selectedColor: Colors.greenAccent.withOpacity(0.3), 
                          onSelected: (val) => setSheetState(() => isPemasukanTerpilih = true),
                        ),
                        const SizedBox(width: 15),
                        ChoiceChip(
                          label: const Text('Pengeluaran'), 
                          selected: !isPemasukanTerpilih, 
                          selectedColor: Colors.redAccent.withOpacity(0.3), 
                          onSelected: (val) => setSheetState(() => isPemasukanTerpilih = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text('Judul Transaksi', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(controller: _judulController, decoration: InputDecoration(hintText: 'Misal: Iuran Kas / Beli Galon', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 15),
                    const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(controller: _nominalController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: 'Rp ', hintText: '0', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 15),
                    
                    // --- UI KALENDER YANG SEMPAT HILANG ---
                    const Text('Tanggal Transaksi', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tanggalTerpilih,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          locale: const Locale('id', 'ID'),
                        );
                        if (picked != null && picked != tanggalTerpilih) {
                          setSheetState(() {
                            tanggalTerpilih = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggalTerpilih),
                              style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    // --- BATAS UI KALENDER ---

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () async {
                          if (_judulController.text.isEmpty || _nominalController.text.isEmpty) return;
                          
                          final grupRef = FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).collection('transaksi');

                          if (isEditMode) {
                            await grupRef.doc(docId).update({
                              'judul': _judulController.text,
                              'nominal': int.parse(_nominalController.text),
                              'isPemasukan': isPemasukanTerpilih,
                              'tanggal': Timestamp.fromDate(tanggalTerpilih), // <--- UPDATE DATA TANGGAL
                            });
                          } else {
                            final user = FirebaseAuth.instance.currentUser;
                            String namaPembuat = user?.displayName ?? user?.email?.split('@')[0] ?? 'Anggota';
                            
                            await grupRef.add({
                              'judul': _judulController.text,
                              'nominal': int.parse(_nominalController.text),
                              'isPemasukan': isPemasukanTerpilih,
                              'tanggal': Timestamp.fromDate(tanggalTerpilih), // <--- SIMPAN DATA TANGGAL
                              'uid_pembuat': user?.uid,
                              'nama_pembuat': namaPembuat,
                            });
                          }
                          
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(isEditMode ? 'Simpan Perubahan' : 'Simpan Transaksi', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- POP-UP DAFTAR ANGGOTA GRUP ---
  void _tampilDaftarAnggota(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              if (data == null || !data.containsKey('anggota')) {
                return const Center(child: Text('Data anggota tidak ditemukan.'));
              }

              final Map<String, dynamic> anggotaMap = data['anggota'];
              final String myRole = anggotaMap[myUid] ?? 'Anggota'; // Cek role diri sendiri
              final bool isAdmin = myRole == 'Admin'; // Cek apakah aku admin

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Text('Daftar Anggota Grup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 5),
                  Text('Kode Undangan: ${widget.kodeGrup}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  if (isAdmin)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Ketuk nama anggota untuk mengubah perannya.', style: TextStyle(fontSize: 12, color: Colors.orange)),
                    ),
                  const SizedBox(height: 15),
                  
                  // LIST ANGGOTA
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: anggotaMap.length,
                    itemBuilder: (context, index) {
                      String uidAnggota = anggotaMap.keys.elementAt(index);
                      String roleAnggota = anggotaMap[uidAnggota];
                      bool isMe = uidAnggota == myUid;
                      
                      // Ambil nama dari database (kalau grup lama belum ada datanya, pakai default)
                      final Map<String, dynamic> namaMap = data.containsKey('nama_anggota') ? data['nama_anggota'] : {};
                      String namaAsli = namaMap[uidAnggota] ?? 'Anggota Tim';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: roleAnggota == 'Admin' 
                              ? Colors.blueAccent.withOpacity(0.2) 
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            roleAnggota == 'Admin' ? Icons.admin_panel_settings : Icons.person,
                            color: roleAnggota == 'Admin' ? Colors.blueAccent : Colors.grey,
                          ),
                        ),
                        // NAMA SEKARANG MUNCUL DI SINI
                        title: Text(
                          isMe ? '$namaAsli (Kamu)' : namaAsli, 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(
                          'ID: ${uidAnggota.substring(0, 8)}...', 
                          style: const TextStyle(fontSize: 12, color: Colors.grey)
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: roleAnggota == 'Admin' 
                                ? Colors.blueAccent 
                                : (roleAnggota == 'Editor' ? Colors.green : Colors.orange),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            roleAnggota, 
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                          ),
                        ),
                        // KABEL UNTUK UBAH JABATAN & KICK
                        onTap: (isAdmin && !isMe) ? () {
                          _tampilDialogUbahRole(context, uidAnggota, roleAnggota, namaAsli, isDark); // <--- Tambah lemparan namaAsli
                        } : null,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // --- TAMBAHAN TOMBOL HAPUS GRUP (MUNCUL JIKA ADMIN) ---
                  if (isAdmin) ...[
                    Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Hapus Grup Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context); // Tutup daftar anggota dulu
                          _konfirmasiHapusGrup(context); // Panggil dialog kiamat
                        },
                      ),
                    ),
                  ],
                  // --- BATAS TOMBOL HAPUS GRUP ---

                ],
              );
            },
          ),
        );
      },
    );
  }
// --- FUNGSI HAPUS GRUP (KHUSUS ADMIN) ---
  void _konfirmasiHapusGrup(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Hapus Grup Permanen?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Text(
            'Tindakan ini akan menghapus grup "${widget.namaGrup}" beserta SELURUH catatan transaksi di dalamnya secara permanen. Lanjutkan?', 
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.5)
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // 1. Tutup dialog pop-up konfirmasi
                Navigator.pop(context);

                try {
                  final grupRef = FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup);
                  
                  // 2. Ambil semua data transaksi di dalam sub-folder grup ini
                  final trxSnap = await grupRef.collection('transaksi').get();
                  
                  // 3. Siapkan "Sapu Jagat" (Batch Delete) dari Firestore
                  final batch = FirebaseFirestore.instance.batch();
                  
                  // Sapu bersih semua dokumen transaksi
                  for (var doc in trxSnap.docs) {
                    batch.delete(doc.reference);
                  }
                  
                  // Sapu bersih folder utama grupnya
                  batch.delete(grupRef);
                  
                  // 4. Eksekusi sapu jagatnya sekarang!
                  await batch.commit();

                  if (context.mounted) {
                    // 5. Tendang user keluar dari halaman detail grup kembali ke Profil
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grup berhasil dihapus permanen!'), backgroundColor: Colors.red));
                  }
                } catch(e) {
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus grup: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Hapus Grup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]
        );
      }
    );
  }
  // --- POP-UP UBAH PERAN & KICK ANGGOTA ---
  void _tampilDialogUbahRole(BuildContext context, String uidTarget, String roleSekarang, String namaAnggota, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Kelola: $namaAnggota', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.green),
                title: Text('Jadikan Editor', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: const Text('Bisa menambah & mengedit transaksi.', style: TextStyle(fontSize: 12)),
                trailing: roleSekarang == 'Editor' ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  Navigator.pop(context); 
                  await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                    'anggota.$uidTarget': 'Editor'
                  });
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peran diubah menjadi Editor', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                },
              ),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.orange),
                title: Text('Jadikan Spectator', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hanya bisa melihat riwayat.', style: TextStyle(fontSize: 12)),
                trailing: roleSekarang == 'Spectator' ? const Icon(Icons.check_circle, color: Colors.orange) : null,
                onTap: () async {
                  Navigator.pop(context); 
                  await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                    'anggota.$uidTarget': 'Spectator'
                  });
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peran diubah menjadi Spectator', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                },
              ),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              
              // FITUR KICK (MENGHAPUS DARI DATABASE)
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Keluarkan dari Grup', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hapus anggota ini secara permanen.', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context); // Tutup menu pilihan
                  
                  // Munculkan konfirmasi terakhir biar ga salah pencet
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      title: Text('Keluarkan $namaAnggota?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      content: Text('Anggota ini tidak akan bisa lagi melihat grup dan catatan di dalamnya.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            // Hapus UID-nya dari 3 tempat sekaligus dengan jurus FieldValue.delete()
                            await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                              'anggota.$uidTarget': FieldValue.delete(),
                              'nama_anggota.$uidTarget': FieldValue.delete(), 
                              'id_anggota': FieldValue.arrayRemove([uidTarget]) 
                            });
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$namaAnggota berhasil dikeluarkan'), backgroundColor: Colors.red));
                            }
                          },
                          child: const Text('Keluarkan', style: TextStyle(color: Colors.white)),
                        )
                      ]
                    )
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // --- FUNGSI HAPUS TRANSAKSI GRUP ---
  void _konfirmasiHapusTransaksiGrup(BuildContext context, String docId, String judul) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Hapus Transaksi?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Yakin ingin menghapus "$judul" dari catatan bersama?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('grup_kas')
                    .doc(widget.kodeGrup)
                    .collection('transaksi')
                    .doc(docId)
                    .delete();
                    
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi grup dihapus'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}