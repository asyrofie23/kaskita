// =========================================================
// FILE: lib/screens/anggaran_page.dart
// =========================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaksi.dart';
import '../models/anggaran.dart';

class AnggaranPage extends StatefulWidget {
  // Kita butuh data transaksi untuk menghitung "Terpakai" otomatis
  final List<Transaksi> semuaTransaksi;

  const AnggaranPage({super.key, required this.semuaTransaksi});

  @override
  State<AnggaranPage> createState() => _AnggaranPageState();
}

class _AnggaranPageState extends State<AnggaranPage> {
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

  // Fungsi untuk menghitung berapa uang yang sudah terpakai di kategori tertentu
  int _hitungTerpakai(String kategori) {
    int total = 0;
    for (var trx in widget.semuaTransaksi) {
      // Hanya hitung pengeluaran
      if (!trx.isPemasukan) {
        if (kategori == 'Semua Kategori' || trx.kategori == kategori) {
          total += trx.nominal;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA); // Warna bg menyesuaikan gambar
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Batas Anggaran', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('anggaran').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // TAMPILAN KOSONG (Gambar Pertama)
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 15),
                  const Text('Belum ada batas anggaran dibuat', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 25),
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

          // TAMPILAN JIKA ADA ANGGARAN (Gambar Ketiga)
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final anggaran = Anggaran(
                id: docs[index].id,
                nama: data['nama'] ?? '',
                limit: data['limit'] ?? 0,
                kategori: data['kategori'] ?? 'Semua Kategori',
                periode: data['periode'] ?? 'MONTHLY',
                peringatan: (data['peringatan'] ?? 80.0).toDouble(),
                rollover: data['rollover'] ?? false,
              );

              // Hitung matematis progres
              int terpakai = _hitungTerpakai(anggaran.kategori);
              int sisa = anggaran.limit - terpakai;
              double persenTerpakai = (terpakai / anggaran.limit).clamp(0.0, 1.0); // clamp biar gak tembus 100% di UI

              // Tentukan warna bar (kalau udah lewat limit merah, kalau belum biru/hijau)
              Color barColor = persenTerpakai >= 1.0 
                  ? Colors.red 
                  : (persenTerpakai >= (anggaran.peringatan / 100) ? Colors.orange : const Color(0xFF2563EB));

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(anggaran.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(anggaran.kategori, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
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
      // Tombol Plus Mengambang di kanan bawah
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('anggaran').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            return FloatingActionButton(
              heroTag: null,
              backgroundColor: const Color(0xFF1D4ED8),
              onPressed: () => _tampilFormAnggaran(context, isDark),
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink(); // Sembunyikan kalau masih kosong (karena udah ada tombol gede di tengah)
        },
      ),
    );
  }

  // FORM BOTTOM SHEET (Gambar Kedua)
  void _tampilFormAnggaran(BuildContext context, bool isDark) {
    final TextEditingController namaController = TextEditingController();
    final TextEditingController limitController = TextEditingController();
    String kategoriTerpilih = 'Semua Kategori';
    String periodeTerpilih = 'MONTHLY';
    double nilaiPeringatan = 80.0;
    bool isRollover = false;

    // List kategori statis (Bisa diganti dinamis nanti)
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
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                        const Text('Buat Batas Anggaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Input Nama Anggaran
                    TextField(
                      controller: namaController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.pie_chart_outline),
                        hintText: 'Nama Anggaran (misal: Bulanan Makan)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Input Limit
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

                    // Kategori
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

                    // Periode
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

                    // Peringatan Limit (Slider)
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

                    // Rollover Switch
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

                    // Tombol Simpan
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

                          // Simpan ke Firestore
                          await FirebaseFirestore.instance.collection('anggaran').add({
                            'nama': namaController.text,
                            'limit': int.parse(limitController.text),
                            'kategori': kategoriTerpilih,
                            'periode': periodeTerpilih,
                            'peringatan': nilaiPeringatan,
                            'rollover': isRollover,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          Navigator.pop(context);
                        },
                        child: const Text('Buat Anggaran', style: TextStyle(color: Colors.white, fontSize: 16)),
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
