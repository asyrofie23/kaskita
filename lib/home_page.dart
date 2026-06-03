import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // IMPORT PENTING: Untuk akses Firestore
import 'riwayat_page.dart';
import 'transaksi.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controller untuk menangkap ketikan user
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();

  int _pilihanTabSekarang = 0;

  /// --- HELPER FORMAT RUPIAH ---
  String _formatUang(int angka) {
    String str = angka.toString();
    String hasil = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      hasil = str[i] + hasil;
      count++;
      if (count % 3 == 0 && i != 0) {
        hasil = '.$hasil';
      }
    }
    return hasil;
  }

  @override
  void dispose() {
    _judulController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// ==========================================
    /// STREAMBUILDER: SENSOR UTAMA DATABASE
    /// ==========================================
    /// Widget ini memantau koleksi bernama 'transaksi' di Cloud Firestore.
    /// .orderBy('tanggal', descending: true) membuat data terbaru selalu di atas.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transaksi')
          .orderBy('tanggal', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Tampilkan indikator loading kalau data dari cloud belum beres diambil
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Ambil semua dokumen dokumen transaksi dari database
        final docs = snapshot.data?.docs ?? [];

        // 3. Konversi data mentah dari Firestore menjadi List<Transaksi> agar bisa dibaca UI kita
        List<Transaksi> listTransaksi = docs.map((doc) {
          return Transaksi(
            judul: doc['judul'] ?? '',
            keterangan: doc['keterangan'] ?? '',
            nominal: doc['nominal'] ?? 0,
            waktu: doc['waktu'] ?? '',
            isPemasukan: doc['isPemasukan'] ?? true,
          );
        }).toList();

        // 4. Hitung matematika keuangan langsung dari data real-time database
        int totalPemasukan = 0;
        int totalPengeluaran = 0;
        for (var trx in listTransaksi) {
          if (trx.isPemasukan) {
            totalPemasukan += trx.nominal;
          } else {
            totalPengeluaran += trx.nominal;
          }
        }
        int totalSaldo = totalPemasukan - totalPengeluaran;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF1D4ED8),
            shape: const CircleBorder(),
            // Buka form tanpa parameter = Mode Tambah
            onPressed: () => _tampilFormTransaksi(context), 
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBottomNavItem(Icons.home, 'Home', 0),
                  _buildBottomNavItem(Icons.list_alt, 'Riwayat', 1),
                  const SizedBox(width: 40),
                  _buildBottomNavItem(Icons.pie_chart_outline, 'Anggaran', 2),
                  _buildBottomNavItem(Icons.person_outline, 'Profil', 3),
                ],
              ),
            ),
          ),
          body: _pilihanTabSekarang == 0
              ? _buildKontenHalamanUtama(listTransaksi, totalSaldo, totalPemasukan, totalPengeluaran, docs)
              : _pilihanTabSekarang == 1
                  ? RiwayatPage(semuaTransaksi: listTransaksi)
                  : Center(
                      child: Text(
                        'Halaman ${_pilihanTabSekarang == 2 ? "Anggaran" : "Profil"} Sementara',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
        );
      },
    );
  }

  /// ==========================================
  /// DASHBOARD KONTEN UTAMA
  /// ==========================================
  Widget _buildKontenHalamanUtama(List<Transaksi> listTransaksi, int totalSaldo, int totalPemasukan, int totalPengeluaran, List<QueryDocumentSnapshot> docs) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header sapaan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Selamat datang,', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    Text('Ahmed! 👋', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                const Icon(Icons.notifications_none, size: 28),
              ],
            ),
            const SizedBox(height: 20),

            // Kartu Saldo Biru
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Juni 2026', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
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

            // Judul List Transaksi Terbaru
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Lihat Semua', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),

            // Tampilkan tulisan jika database kosong melompong
            listTransaksi.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Text('Belum ada transaksi, bre. Yuk tambah!'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: listTransaksi.length,
                    itemBuilder: (context, index) {
                      final trx = listTransaksi[index];
                      final docId = docs[index].id; // Mengambil ID unik dokumen dari Firebase untuk kebutuhan EDIT

                      return GestureDetector(
                        onTap: () {
                          // Kirim parameter data ke form untuk "Mode Edit"
                          _tampilFormTransaksi(
                            context,
                            docId: docId,
                            judulAwal: trx.judul,
                            nominalAwal: trx.nominal,
                            isPemasukanAwal: trx.isPemasukan,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: trx.isPemasukan ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  trx.isPemasukan ? Icons.attach_money : Icons.money_off,
                                  color: trx.isPemasukan ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(trx.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(trx.keterangan, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${trx.isPemasukan ? "+" : "-"}Rp ${_formatUang(trx.nominal)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: trx.isPemasukan ? Colors.green : Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(trx.waktu, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  /// ==========================================
  /// FORM TRANSAKSI FIRESTORE (TAMBAH & EDIT)
  /// ==========================================
  void _tampilFormTransaksi(BuildContext context, {String? docId, String? judulAwal, int? nominalAwal, bool? isPemasukanAwal}) {
    final bool isEditMode = docId != null;

    if (isEditMode) {
      _judulController.text = judulAwal!;
      _nominalController.text = nominalAwal!.toString();
    } else {
      _judulController.clear();
      _nominalController.clear();
    }

    bool isPemasukanTerpilih = isEditMode ? isPemasukanAwal! : true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      isEditMode ? 'Edit Catatan Kas' : 'Tambah Transaksi Baru',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Pemasukan'),
                        selected: isPemasukanTerpilih,
                        selectedColor: Colors.greenAccent.withOpacity(0.3),
                        onSelected: (val) {
                          setSheetState(() => isPemasukanTerpilih = true);
                        },
                      ),
                      const SizedBox(width: 15),
                      ChoiceChip(
                        label: const Text('Pengeluaran'),
                        selected: !isPemasukanTerpilih,
                        selectedColor: Colors.redAccent.withOpacity(0.3),
                        onSelected: (val) {
                          setSheetState(() => isPemasukanTerpilih = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text('Nama Transaksi / Judul', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _judulController,
                    decoration: InputDecoration(
                      hintText: 'Misal: Gaji, Jajan Bakso',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nominalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        if (_judulController.text.isEmpty || _nominalController.text.isEmpty) {
                          return;
                        }

                        // Wadah map data yang akan dikirim ke server Google Firebase
                        final Map<String, dynamic> dataTransaksi = {
                          'judul': _judulController.text,
                          'keterangan': isPemasukanTerpilih ? 'kiriman' : 'keperluan',
                          'nominal': int.parse(_nominalController.text),
                          'isPemasukan': isPemasukanTerpilih,
                          'waktu': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        };

                        if (isEditMode) {
                          /// PERINTAH FIRESTORE UNTUK UPDATE DATA
                          await FirebaseFirestore.instance
                              .collection('transaksi')
                              .doc(docId)
                              .update(dataTransaksi);
                        } else {
                          /// PERINTAH FIRESTORE UNTUK MENAMBAH DATA BARU
                          // Tambahkan data timestamp waktu server buat pengurutan sorting otomatis
                          dataTransaksi['tanggal'] = FieldValue.serverTimestamp();
                          
                          await FirebaseFirestore.instance
                              .collection('transaksi')
                              .add(dataTransaksi);
                        }

                        _judulController.clear();
                        _nominalController.clear();
                        Navigator.pop(context);
                      },
                      child: Text(
                        isEditMode ? 'Simpan Perubahan' : 'Simpan Transaksi',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// --- WIDGET REUSABLE NAVBAR & SALDO INFO ---
  Widget _buildSaldoInfo(IconData icon, String title, String amount, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavItem(IconData icon, String title, int indexTarget) {
    final bool isSelected = _pilihanTabSekarang == indexTarget;
    return GestureDetector(
      onTap: () {
        setState(() {
          _pilihanTabSekarang = indexTarget;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF2563EB) : Colors.grey)),
        ],
      ),
    );
  }
}