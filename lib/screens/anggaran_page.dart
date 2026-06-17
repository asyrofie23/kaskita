import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaksi.dart';
import '../models/anggaran.dart';


class AnggaranPage extends StatefulWidget {

  final List<Transaksi> semuaTransaksi;

  const AnggaranPage({super.key, required this.semuaTransaksi});

  @override
  State<AnggaranPage> createState() => _AnggaranPageState();
}

class _AnggaranPageState extends State<AnggaranPage> {
  // Format Rp
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

  // Menghitung jumlah uang yang telah dibelanjakan
  int _hitungTerpakai(String kategori) {
    int total = 0;
    for (var trx in widget.semuaTransaksi) {
      // Hanya menghitung transaksi pengeluaran
      if (!trx.isPemasukan) {
        // Hitung jika kategori cocok atau jika batas anggaran diset untuk "Semua Kategori"
        if (kategori == 'Semua Kategori' || trx.kategori == kategori) {
          total += trx.nominal;
        }
      }
    }
    return total;
  }

  // Dialog Konfirmasi sebelum menghapus data anggaran
  void _konfirmasiHapusAnggaran(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Batas Anggaran'),
          content: const Text('Apakah Anda yakin ingin menghapus batas anggaran ini?'),
          actions: [
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            // Tombol konfirmasi hapus
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog konfirmasi
                final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                try {
                  // Hapus dokumen berdasarkan ID dari sub-koleksi anggaran user
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('anggaran')
                      .doc(id)
                      .delete();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Batas anggaran berhasil dihapus')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus: $e')),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA); // Background halaman
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      // AppBar di bagian atas halaman
      appBar: AppBar(
        title: const Text('Batas Anggaran', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      // StreamBuilder untuk membaca database Firestore secara realtime
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest').collection('anggaran').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // Loading at waiting data
          }

          final docs = snapshot.data?.docs ?? [];

          // TAMPILAN KOSONG
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 15),
                  const Text('Belum ada batas anggaran dibuat', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 25),
                  // Tombol buat batasan "awal"
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _tampilFormAnggaran(context, isDark),
                    child: const Text('Buat Batas Anggaran', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          // TAMPILAN UTAMA - jika data anggaran tersedia di Firestore
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              // Membungkus data map dari Firestore menjadi model class Anggaran
              final anggaran = Anggaran(
                id: docs[index].id,
                nama: data['nama'] ?? '',
                limit: data['limit'] ?? 0,
                kategori: data['kategori'] ?? 'Semua Kategori',
                periode: data['periode'] ?? 'MONTHLY',
                peringatan: (data['peringatan'] ?? 80.0).toDouble(),
                rollover: data['rollover'] ?? false,
              );

              // Menghitung data keuangan yang terpakai dan sisa limit anggaran
              int terpakai = _hitungTerpakai(anggaran.kategori);
              int sisa = anggaran.limit - terpakai;
              double persenTerpakai = (terpakai / anggaran.limit).clamp(0.0, 1.0); // Membatasi nilai persen maksimal 1.0 (100%)

              // Logika warna bar indikator progres sesuai persentase terpakai
              Color barColor = persenTerpakai >= 1.0 
                  ? Colors.red
                  : (persenTerpakai >= (anggaran.peringatan / 100) ? Colors.orange : const Color(0xFF2563EB)); // Jingga/Biru jika aman

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Header Kartu (Berisi Nama Anggaran, Kategori, dan Tombol Menu Opsi)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(anggaran.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(anggaran.kategori, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        // Menu 3 Titik
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'edit') {
                              // edit
                              _tampilFormAnggaran(context, isDark, anggaranYangDiedit: anggaran);
                            } else if (value == 'hapus') {
                              // hapus
                              _konfirmasiHapusAnggaran(context, anggaran.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'hapus',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Hapus', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Informasi angka nominal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Terpakai: Rp ${_formatUang(terpakai)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                        Text('Sisa: Rp ${_formatUang(sisa > 0 ? sisa : 0)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // PROGRESS BAR
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: persenTerpakai,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // persentase
                    Text(
                      '${(persenTerpakai * 100).toStringAsFixed(0)}% terpakai dari Rp ${_formatUang(anggaran.limit)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // Tombol +
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).collection('anggaran').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            return FloatingActionButton(
              heroTag: null,
              backgroundColor: const Color(0xFF1D4ED8),
              onPressed: () => _tampilFormAnggaran(context, isDark),
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink(); // Sembunyikan jika kosong
        },
      ),
    );
  }

  // BOTTOM SHEET FORM - Untuk menambah atau mengedit data batas anggaran
  void _tampilFormAnggaran(BuildContext context, bool isDark, {Anggaran? anggaranYangDiedit}) {
    // Inisialisasi controller textfield dengan data lama (jika edit) atau kosong (jika buat baru)
    final TextEditingController namaController = TextEditingController(text: anggaranYangDiedit?.nama ?? '');
    final TextEditingController limitController = TextEditingController(
        text: anggaranYangDiedit != null ? anggaranYangDiedit.limit.toString() : '');
    String kategoriTerpilih = anggaranYangDiedit?.kategori ?? 'Semua Kategori';
    String periodeTerpilih = anggaranYangDiedit?.periode ?? 'MONTHLY';
    double nilaiPeringatan = anggaranYangDiedit?.peringatan ?? 80.0;
    bool isRollover = anggaranYangDiedit?.rollover ?? false;

    // Daftar pilihan kategori anggaran
    List<String> listKategori = ['Semua Kategori', 'Makan', 'Transportasi', 'Hiburan', 'Belanja'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Mengangkat sheet saat keyboard muncul
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tombol Back dan Judul Form
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                        Text(anggaranYangDiedit != null ? 'Edit Batas Anggaran' : 'Buat Batas Anggaran', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Input TextField Nama Anggaran
                    TextField(
                      controller: namaController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.pie_chart_outline),
                        hintText: 'Nama Anggaran',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Input TextField Nominal Uang Limit
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.money),
                        hintText: 'Batas Limit Pengeluaran',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Pilihan Dropdown Kategori Pengeluaran
                    const Text('Kategori Pengeluaran', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      value: kategoriTerpilih,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: listKategori.map((kat) => DropdownMenuItem(value: kat, child: Text(kat))).toList(),
                      onChanged: (val) => setSheetState(() => kategoriTerpilih = val!),
                    ),
                    const SizedBox(height: 15),

                    // Pilihan Dropdown Periode Anggaran (Bulanan / Mingguan)
                    const Text('Periode Anggaran', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      value: periodeTerpilih,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: ['MONTHLY', 'WEEKLY'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setSheetState(() => periodeTerpilih = val!),
                    ),
                    const SizedBox(height: 20),

                    // Slider untuk menetapkan persentase Peringatan Limit
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Peringatan Limit: ${nilaiPeringatan.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          const Text('Notifikasi peringatan akan muncul jika sisa limit Anda hampir habis.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Slider(
                            value: nilaiPeringatan,
                            min: 50,
                            max: 100,
                            divisions: 10,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) => setSheetState(() => nilaiPeringatan = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Switch Rollover Sisa Anggaran (apakah memindahkan sisa uang ke periode berikutnya)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rollover Sisa Anggaran', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Sisa anggaran bulan sebelumnya akan dipindahkan ke periode anggaran berikutnya.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Switch(
                          value: isRollover,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) => setSheetState(() => isRollover = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Tombol Simpan Aksi Form (Dinamis: Simpan Perubahan / Buat Anggaran)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (namaController.text.isEmpty || limitController.text.isEmpty) return;

                          // Ambil UID user aktif untuk path database Firestore
                          final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                          final data = {
                            'nama': namaController.text,
                            'limit': int.parse(limitController.text),
                            'kategori': kategoriTerpilih,
                            'periode': periodeTerpilih,
                            'peringatan': nilaiPeringatan,
                            'rollover': isRollover,
                          };

                          if (anggaranYangDiedit != null) {
                            // Update dokumen anggaran yang sudah ada
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('anggaran')
                                .doc(anggaranYangDiedit.id)
                                .update(data);
                          } else {
                            // Buat dokumen anggaran baru dan set waktu pembuatan
                            data['createdAt'] = FieldValue.serverTimestamp();
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('anggaran')
                                .add(data);
                          }

                          if (context.mounted) {
                            Navigator.pop(context); // Tutup bottom sheet form setelah selesai disimpan
                          }
                        },
                        child: Text(anggaranYangDiedit != null ? 'Simpan Perubahan' : 'Buat Anggaran', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
}
