import 'home_page.dart' show SlidableTile;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GrupDetailPage extends StatefulWidget {
  final String kodeGrup;  // sebagai ID dokumen Firestore
  final String namaGrup;  // Nama representasi grup kas
  final String roleUser;  // Peran user aktif di dalam grup (Admin / Editor / Spectator)

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
  // Controller untuk menangani input form transaksi grup
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();

  // format Rp
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

    // Cek apakah user punya hak untuk menambah/mengedit catatan kas grup (Spectator dilarang)
    bool bisaEdit = widget.roleUser == 'Admin' || widget.roleUser == 'Editor';
    bool isAdmin = widget.roleUser == 'Admin';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // StreamBuilder memantau data dokumen grup untuk memperbarui nama grup secara realtime
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).snapshots(),
          builder: (context, snapshot) {
            String namaTampil = widget.namaGrup;
            if (snapshot.hasData && snapshot.data!.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              namaTampil = data['nama_grup'] ?? widget.namaGrup; // Gunakan nama ter-update dari database
            }

            // Jika Admin mengklik judul AppBar, buka dialog ubah nama grup
            return GestureDetector(
              onTap: isAdmin ? () => _tampilDialogUbahNamaGrup(context, namaTampil, isDark) : () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hanya Admin yang bisa mengubah nama grup.')));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(namaTampil, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                      ]
                    ],
                  ),
                  Text('Kode: ${widget.kodeGrup} • Kamu: ${widget.roleUser}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          // Tombol member view
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              _tampilDaftarAnggota(context);
            },
          )
        ],
      ),
      // StreamBuilder memantau list sub-koleksi transaksi grup kas secara realtime
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('grup_kas')
            .doc(widget.kodeGrup)
            .collection('transaksi')
            .orderBy('tanggal', descending: true) // Urutkan transaksi terbaru di atas
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Akumulasi data nominal masuk dan keluar untuk menghitung total saldo kas bersamamu
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          // Sub info baris: pemasukan (iuran) vs pengeluaran kas
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
                  ],
                ),
              ),

              // riwayat catatan
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text('Belum ada iuran atau pengeluaran di grup ini.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final docId = doc.id;
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isPemasukan = data['isPemasukan'] ?? true;
                          final String judul = data['judul'] ?? '';
                          final int nominal = data['nominal'] ?? 0;
                          final String pembuat = data['nama_pembuat'] ?? 'Anggota';
                          
                          String waktuTampil = '';
                          if (data['tanggal'] != null && data['tanggal'] is Timestamp) {
                            waktuTampil = DateFormat('dd MMM yyyy, HH:mm').format((data['tanggal'] as Timestamp).toDate());
                          }

                          // Kontainer dasar kartu item transaksi
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
                                // Ikon jenis kas (Masuk hijau / Keluar merah)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: isPemasukan ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                                  child: Icon(isPemasukan ? Icons.arrow_downward : Icons.arrow_upward, color: isPemasukan ? Colors.green : Colors.red),
                                ),
                                const SizedBox(width: 15),
                                // Judul dan Nama pencatat kas
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
                                // Nominal Rupiah & Waktu
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${isPemasukan ? "+" : "-"}Rp ${_formatUang(nominal)}', style: TextStyle(fontWeight: FontWeight.bold, color: isPemasukan ? Colors.green : Colors.red, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(waktuTampil, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );

                          // Jika role user diizinkan mengedit/menghapus, bungkus dengan SlidableTile (Slide kanan/kiri edit hapus)
                          if (bisaEdit) {
                            DateTime tanggalAsli = DateTime.now();
                            if (data['tanggal'] != null && data['tanggal'] is Timestamp) {
                              tanggalAsli = (data['tanggal'] as Timestamp).toDate();
                            }

                            return SlidableTile( // slide
                              key: Key(docId),
                              onEdit: () => _tampilFormTransaksiGrup(context, docId: docId, judulAwal: judul, nominalAwal: nominal, isPemasukanAwal: isPemasukan, tanggalAwal: tanggalAsli),
                              onDelete: () => _konfirmasiHapusTransaksiGrup(context, docId, judul),
                              child: kontenTransaksi,
                            );
                          }
                          return kontenTransaksi;
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // Tombol + mengambang untuk menambah
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

  //tambah n edit
  // bottomsheet tambah catatan
  void _tampilFormTransaksiGrup(BuildContext context, {String? docId, String? judulAwal, int? nominalAwal, bool? isPemasukanAwal, DateTime? tanggalAwal}) {
    final bool isEditMode = docId != null; // Status mode edit data vs tambah baru
    bool isPemasukanTerpilih = isEditMode ? isPemasukanAwal! : true;
    DateTime tanggalTerpilih = tanggalAwal ?? DateTime.now(); // Default tanggal hari ini
    
    // Set teks awal textfield jika sedang mengedit dokumen
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text(isEditMode ? 'Edit Transaksi Grup' : 'Tambah Transaksi Grup', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(height: 15),
                    // Pilihan jenis kas (Iuran masuk vs Pengeluaran keluar) menggunakan ChoiceChip
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
                    // TextField input Judul Transaksi
                    TextField(controller: _judulController, decoration: InputDecoration(hintText: 'Misal: Iuran Kas / Beli Galon', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 15),
                    const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    // TextField input Nominal rupiah angka
                    TextField(controller: _nominalController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: 'Rp ', hintText: '0', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 15),
                    
                    const Text('Tanggal Transaksi', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    // Tombol pengetuk kalender
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

                    const SizedBox(height: 25),
                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () async {
                          if (_judulController.text.isEmpty || _nominalController.text.isEmpty) return;
                          
                          // Referensi sub-koleksi transaksi di dalam grup kas bersangkutan
                          final grupRef = FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).collection('transaksi');
                          final user = FirebaseAuth.instance.currentUser;
                          String namaPembuat = user?.displayName ?? user?.email?.split('@')[0] ?? 'Anggota';

                          if (isEditMode) {
                            // Update dokumen transaksi lama
                            await grupRef.doc(docId).update({
                              'judul': _judulController.text,
                              'nominal': int.parse(_nominalController.text),
                              'isPemasukan': isPemasukanTerpilih,
                              'tanggal': Timestamp.fromDate(tanggalTerpilih), 
                            });
                          } else {
                            // Tambah dokumen transaksi baru
                            await grupRef.add({
                              'judul': _judulController.text,
                              'nominal': int.parse(_nominalController.text),
                              'isPemasukan': isPemasukanTerpilih,
                              'tanggal': Timestamp.fromDate(tanggalTerpilih), 
                              'uid_pembuat': user?.uid,
                              'nama_pembuat': namaPembuat,
                            });
                          }

                          // mesin notif
                          try {
                            final grupDoc = await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).get();
                            if (grupDoc.exists) {
                              List<dynamic> idAnggota = grupDoc.data()?['id_anggota'] ?? [];
                              
                              for (String targetUid in idAnggota) {
                                // Kirim notif ke semua anggota lain kecuali pembuat itu sendiri
                                if (targetUid != user?.uid) {
                                  await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('notifikasi').add({
                                    'judul': isEditMode ? 'Catatan Diedit' : 'Catatan Baru',
                                    'pesan': '$namaPembuat ${isEditMode ? 'mengedit' : 'menambahkan'} transaksi "${_judulController.text}" di grup ${widget.namaGrup}.',
                                    'waktu': FieldValue.serverTimestamp(),
                                    'isRead': false, // Titik merah tanda belum dibaca
                                  });
                                }
                              }
                            }
                          } catch (e) {
                            debugPrint('Gagal kirim notif: $e');
                          }
                          // ==========================================
                          
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

  // POP-UP DAFTAR ANGGOTA GRUP
  // Fungsi untuk menampilkan dialog Bottom Sheet berisi daftar anggota grup kas beserta perannya
  void _tampilDaftarAnggota(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            // Stream data grup kas secara real-time dari Firestore
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
              final String myRole = anggotaMap[myUid] ?? 'Anggota'; // Mengambil role pengguna aktif saat ini
              final bool isAdmin = myRole == 'Admin'; // Cek apakah pengguna saat ini berstatus Admin grup

              return SingleChildScrollView(
                child: Column(
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
                        
                        // Ambil nama asli anggota dari field nama_anggota jika tersedia
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
                          // Jika kita admin dan bukan menekan nama sendiri, ketuk untuk ubah jabatan atau keluarkan
                          onTap: (isAdmin && !isMe) ? () {
                            _tampilDialogUbahRole(context, uidAnggota, roleAnggota, namaAsli, isDark);
                          } : null,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    // TOMBOL HAPUS GRUP
                    if (isAdmin) ...[
                      Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
                      SizedBox(
                        width: double.infinity,
                        // Tombol bagi Admin untuk menghapus grup ini secara keseluruhan
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Hapus Grup Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context); // Tutup bottom sheet
                            _konfirmasiHapusGrup(context); // Buka dialog konfirmasi penghapusan grup
                          },
                        ),
                      ),
                    ],
                    // --- BATAS TOMBOL HAPUS GRUP ---

                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // FUNGSI HAPUS GRUP
  // Menampilkan dialog konfirmasi penghapusan grup secara permanen
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
              // Tombol untuk eksekusi penghapusan grup kas dan sub-koleksi transaksi
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog konfirmasi

                try {
                  final grupRef = FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup);
                  
                  // Ambil seluruh dokumen transaksi di dalam grup kas bersangkutan
                  final trxSnap = await grupRef.collection('transaksi').get();
                  
                  // Gunakan WriteBatch agar proses penghapusan semua transaksi dan dokumen grup berjalan sekaligus
                  final batch = FirebaseFirestore.instance.batch();
                  
                  for (var doc in trxSnap.docs) {
                    batch.delete(doc.reference); // Tambahkan penghapusan transaksi ke batch
                  }
                  
                  batch.delete(grupRef); // Tambahkan penghapusan dokumen grup ke batch
                  
                  await batch.commit(); // Jalankan transaksi batch Firestore

                  if (context.mounted) {
                    Navigator.pop(context); // Keluar dari halaman grup detail kembali ke Profil
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

  // POP-UP UBAH PERAN & KICK ANGGOTA
  // Dialog bagi admin untuk mengelola peran (Editor/Spectator) atau mengeluarkan anggota dari grup
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
              // Pilihan untuk mengubah peran menjadi Editor (bisa tulis/baca)
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.green),
                title: Text('Jadikan Editor', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: const Text('Bisa menambah & mengedit transaksi.', style: TextStyle(fontSize: 12)),
                trailing: roleSekarang == 'Editor' ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  Navigator.pop(context); 
                  // Update nilai field role anggota di Firestore
                  await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                    'anggota.$uidTarget': 'Editor'
                  });
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peran diubah menjadi Editor', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                },
              ),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              // Pilihan untuk mengubah peran menjadi Spectator (hanya bisa lihat)
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.orange),
                title: Text('Jadikan Spectator', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hanya bisa melihat riwayat.', style: TextStyle(fontSize: 12)),
                trailing: roleSekarang == 'Spectator' ? const Icon(Icons.check_circle, color: Colors.orange) : null,
                onTap: () async {
                  Navigator.pop(context); 
                  // Update nilai field role anggota di Firestore
                  await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                    'anggota.$uidTarget': 'Spectator'
                  });
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peran diubah menjadi Spectator', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                },
              ),
              Divider(color: isDark ? Colors.white24 : Colors.grey.shade200),
              
              // FITUR KICK
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Keluarkan dari Grup', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hapus anggota ini secara permanen.', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context); // Tutup dialog opsi peran
                  
                  // Tampilkan dialog konfirmasi penghapusan (kick) kedua agar tidak salah pencet
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
                            // Hapus UID anggota dari anggotaMap, nama_anggota, dan list id_anggota di Firestore
                            await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                              'anggota.$uidTarget': FieldValue.delete(),
                              'nama_anggota.$uidTarget': FieldValue.delete(), 
                              'id_anggota': FieldValue.arrayRemove([uidTarget]) 
                            });
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Tutup dialog konfirmasi
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

  // FUNGSI HAPUS TRANSAKSI GRUP
  // Dialog konfirmasi untuk menghapus satu catatan transaksi dalam grup kas
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
              // Eksekusi penghapusan dokumen transaksi dari Firestore
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('grup_kas')
                    .doc(widget.kodeGrup)
                    .collection('transaksi')
                    .doc(docId)
                    .delete();
                    
                if (context.mounted) {
                  Navigator.pop(context); // Tutup dialog
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

  // POP-UP UBAH NAMA GRUP
  // Menampilkan dialog input untuk mengubah nama grup kas di Firestore
  void _tampilDialogUbahNamaGrup(BuildContext context, String namaSekarang, bool isDark) {
    final TextEditingController controller = TextEditingController(text: namaSekarang);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Ubah Nama Grup', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama grup baru',
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  // Tombol simpan untuk mengirim nama grup baru ke Firestore
                  onPressed: isLoading ? null : () async {
                    final String namaBaru = controller.text.trim();
                    if (namaBaru.isEmpty || namaBaru == namaSekarang) return;

                    setDialogState(() => isLoading = true);

                    try {
                      // Update field nama_grup di database
                      await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).update({
                        'nama_grup': namaBaru
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama grup berhasil diubah!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah nama: $e'), backgroundColor: Colors.red));
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