import 'transaksi.dart'; // Import model baru
import 'riwayat_page.dart'; // Import halaman riwayat baru
import 'package:flutter/material.dart';


/// ==========================================
/// 2. STATEFUL WIDGET UTAMA
/// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// --- CONTROLLER FORM ---
  /// Digunakan untuk menangkap teks/angka yang diketik user di keyboard HP
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();

  /// --- STATE / VARIABLE DATA ---
  /// _pilihanTabSekarang bertugas mencatat halaman mana yang lagi aktif (0 = Home, 1 = Riwayat, dst)
  int _pilihanTabSekarang = 0;

  /// List data transaksi awal (default) sebelum ditambah user
  List<Transaksi> listTransaksi = [
    Transaksi(
      judul: 'Freelance',
      keterangan: 'kiriman',
      nominal: 50000,
      waktu: '12:22',
      isPemasukan: true,
    ),
  ];

  /// ==========================================
  /// 3. LOGIKA MATEMATIKA & HELPER
  /// ==========================================
  
  /// Fungsi cerdik untuk mengubah angka biasa jadi berformat titik (Contoh: 50000 -> 50.000)
  /// Ini biar tampilan aplikasi kita sinkron dengan desain di image_d9d2da.png
  String _formatUang(int angka) {
    String str = angka.toString();
    String hasil = '';
    int count = 0;

    // Looping mundur dari angka paling belakang untuk disisipkan titik tiap 3 digit
    for (int i = str.length - 1; i >= 0; i--) {
      hasil = str[i] + hasil;
      count++;
      if (count % 3 == 0 && i != 0) {
        hasil = '.$hasil';
      }
    }
    return hasil;
  }

  /// Menghitung sisa saldo bersih (Pemasukan dikurangi Pengeluaran)
  int get totalSaldo {
    int saldo = 0;
    for (var trx in listTransaksi) {
      if (trx.isPemasukan) {
        saldo += trx.nominal;
      } else {
        saldo -= trx.nominal;
      }
    }
    return saldo;
  }

  /// Menghitung total semua uang masuk
  int get totalPemasukan {
    return listTransaksi
        .where((trx) => trx.isPemasukan)
        .fold(0, (sum, trx) => sum + trx.nominal);
  }

  /// Menghitung total semua uang keluar
  int get totalPengeluaran {
    return listTransaksi
        .where((trx) => !trx.isPemasukan)
        .fold(0, (sum, trx) => sum + trx.nominal);
  }

  @override
  void dispose() {
    // Menghapus controller dari memori kalau halaman ditutup biar HP gak lemot
    _judulController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  /// ==========================================
  /// 4. BUILD UI UTAMA
  /// ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// TOMBOL PLUS (Floating Action Button)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1D4ED8),
        shape: const CircleBorder(),
        onPressed: () => _tampilFormTransaksi(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// BOTTOM NAVIGATION BAR (Menu Bawah)
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
              const SizedBox(width: 40), // Spasi kosong penahan tempat Tombol Plus
              _buildBottomNavItem(Icons.pie_chart_outline, 'Anggaran', 2),
              _buildBottomNavItem(Icons.person_outline, 'Profil', 3),
            ],
          ),
        ),
      ),

      /// KONDISI PERALIHAN HALAMAN
      /// Jika _pilihanTabSekarang berangka 0, munculkan konten Home asli.
      /// Jika selain 0, tampilkan halaman tiruan sementara.
      /// KONDISI PERALIHAN HALAMAN YANG BARU
      body: _pilihanTabSekarang == 0
          ? _buildKontenHalamanUtama()
          : _pilihanTabSekarang == 1
              ? RiwayatPage(
                  semuaTransaksi: listTransaksi,
                  onEditTransaksi: (index) {
                    _tampilFormTransaksi(context, index: index);
                  },
                )
              : Center(
                  child: Text(
                    'Halaman ${_pilihanTabSekarang == 2 ? "Anggaran" : "Profil"} Sementara',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
    );
  }

  /// ==========================================
  /// 5. KONTEN HALAMAN UTAMA (DASHBOARD)
  /// ==========================================
  Widget _buildKontenHalamanUtama() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 1. HEADER (Greeting)
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

            /// 2. KARTU SALDO BIRU ELEGAN
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
                  // Menampilkan total saldo yang sudah diformat dengan titik ribuan
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

            /// 4. JUDUL TRANSAKSI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Lihat Semua', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),

            /// 5. LIST TRANSAKSI YANG AKAN BERTAMBAH TERUS
            /// Menggunakan ListView.builder agar hemat RAM saat merender baris data
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Mematikan scroll internal list biar gak bentrok sama halaman utama
              itemCount: listTransaksi.length,
              itemBuilder: (context, index) {
                final trx = listTransaksi[index];
                return GestureDetector(
                  onTap: () {
                    _tampilFormTransaksi(context, index: index);
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
                        // Lingkaran Icon (Hijau untuk Pemasukan, Merah untuk Pengeluaran)
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
                        // Teks Judul dan Keterangan
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
                        // Teks Nominal Uang dan Jam
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
  /// 6. FORM INPUT BOTTOM SHEET (POP-UP BAWAH)
  /// ==========================================
  void _tampilFormTransaksi(BuildContext context, {int? index}) {
    final bool isEditMode = index != null;

    if (isEditMode) {
      _judulController.text = listTransaksi[index].judul;
      _nominalController.text = listTransaksi[index].nominal.toString();
    } else {
      _judulController.clear();
      _nominalController.clear();
    }

    bool isPemasukanTerpilih = isEditMode ? listTransaksi[index].isPemasukan : true;

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
                      isEditMode ? 'Edit Transaksi' : 'Tambah Transaksi Baru',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // PILIHAN TOMBOL PEMASUKAN / PENGELUARAN
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
                    keyboardType: TextInputType.number, // Biar keyboard otomatis memunculkan angka saja
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // TOMBOL SIMPAN DATA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        // Proteksi dasar: kalau inputan kosong, jangan dieksekusi
                        if (_judulController.text.isEmpty || _nominalController.text.isEmpty) {
                          return;
                        }

                        // Memasukkan/mengupdate inputan user
                        setState(() {
                          if (isEditMode) {
                            listTransaksi[index] = Transaksi(
                              judul: _judulController.text,
                              keterangan: isPemasukanTerpilih ? 'kiriman' : 'keperluan',
                              nominal: int.parse(_nominalController.text),
                              waktu: listTransaksi[index].waktu,
                              isPemasukan: isPemasukanTerpilih,
                            );
                          } else {
                            listTransaksi.add(
                              Transaksi(
                                judul: _judulController.text,
                                keterangan: isPemasukanTerpilih ? 'kiriman' : 'keperluan',
                                nominal: int.parse(_nominalController.text), 
                                waktu: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                isPemasukan: isPemasukanTerpilih,
                              ),
                            );
                          }
                        });

                        // Mengosongkan form ketikan lagi agar pas dibuka berikutnya sudah bersih
                        _judulController.clear();
                        _nominalController.clear();

                        Navigator.pop(context); // Menutup pop-up bottom sheet
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

  /// ==========================================
  /// 7. WIDGET REUSABLE HELPER (KOMPONEN PEMBANTU)
  /// ==========================================
  
  // Widget kecil untuk menampilkan info rincian pemasukan & pengeluaran di dalam kartu biru
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

  // Widget kecil untuk menggambar item tombol pada Navigasi Menu Bawah
  Widget _buildBottomNavItem(IconData icon, String title, int indexTarget) {
    final bool isSelected = _pilihanTabSekarang == indexTarget;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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