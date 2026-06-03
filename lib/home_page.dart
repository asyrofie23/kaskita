import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'riwayat_page.dart';
import 'package:intl/intl.dart'; // PENTING: Untuk memformat tanggal dan waktu
import 'transaksi.dart';
import 'main.dart'; // WAJIB IMPORT INI: Untuk memanggil saklar themeNotifier

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();
  int _pilihanTabSekarang = 0;

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
  void dispose() {
    _judulController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DETEKSI TEMA SAAT INI (Berguna untuk mengubah warna container statis)
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transaksi')
          .orderBy('tanggal', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        List<Transaksi> listTransaksi = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          String waktuTampil = doc['waktu'] ?? '';

          if (data != null && data.containsKey('tanggal') && data['tanggal'] != null) {
            final rawTanggal = data['tanggal'];
            if (rawTanggal is Timestamp) {
              waktuTampil = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(rawTanggal.toDate());
            }
          }

          return Transaksi(
            judul: doc['judul'] ?? '',
            keterangan: doc['keterangan'] ?? '',
            nominal: doc['nominal'] ?? 0,
            waktu: waktuTampil,
            isPemasukan: doc['isPemasukan'] ?? true,
          );
        }).toList();

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
            onPressed: () => _tampilFormTransaksi(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: cardColor, 
            child: Padding(
      
              padding: const EdgeInsets.symmetric(horizontal: 10.0), 
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
              ? _buildKontenHalamanUtama(listTransaksi, totalSaldo, totalPemasukan, totalPengeluaran, docs, isDark, cardColor)
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

  Widget _buildKontenHalamanUtama(List<Transaksi> listTransaksi, int totalSaldo, int totalPemasukan, int totalPengeluaran, List<QueryDocumentSnapshot> docs, bool isDark, Color cardColor) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER DAN TOMBOL DARK MODE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selamat datang,', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    Text('Ahmed! 👋', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                Row(
                  children: [
                    // TOMBOL SAKLAR TEMA
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode, 
                        color: isDark ? Colors.orangeAccent : Colors.grey
                      ),
                      onPressed: () {
                        // Membalikkan keadaan tema (kalau gelap jadi terang, dan sebaliknya)
                        themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                      },
                    ),
                    const Icon(Icons.notifications_none, size: 28),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Kartu Saldo 
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
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
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

            // Judul Transaksi (Menu 4 item sudah dihapus)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Lihat Semua', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),

            // List View dengan Swipe to Delete
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
                      final docId = docs[index].id;

                      return Dismissible(
                        key: Key(docId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
                        ),
                        onDismissed: (direction) async {
                          await FirebaseFirestore.instance.collection('transaksi').doc(docId).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${trx.judul} berhasil dihapus'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () {
                            final rawTanggal = (docs[index].data() as Map<String, dynamic>?)?['tanggal'];
                            final DateTime initialDate = (rawTanggal != null && rawTanggal is Timestamp) 
                                ? rawTanggal.toDate() 
                                : DateTime.now();
                            _tampilFormTransaksi(
                              context, 
                              docId: docId, 
                              judulAwal: trx.judul, 
                              nominalAwal: trx.nominal, 
                              isPemasukanAwal: trx.isPemasukan,
                              tanggalAwal: initialDate,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardColor, // Background item mengikuti tema
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    // Ikon menyesuaikan, kalau dark mode background icon dikasih transparansi
                                    color: trx.isPemasukan ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
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
                                      style: TextStyle(fontWeight: FontWeight.bold, color: trx.isPemasukan ? Colors.green : Colors.red, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(trx.waktu, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
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

  void _tampilFormTransaksi(BuildContext context, {String? docId, String? judulAwal, int? nominalAwal, bool? isPemasukanAwal, DateTime? tanggalAwal}) {
    final bool isEditMode = docId != null;

    if (isEditMode) {
      _judulController.text = judulAwal!;
      _nominalController.text = nominalAwal!.toString();
    } else {
      _judulController.clear();
      _nominalController.clear();
    }
    bool isPemasukanTerpilih = isEditMode ? isPemasukanAwal! : true;
    DateTime tanggalTerpilih = tanggalAwal ?? DateTime.now();

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text(isEditMode ? 'Edit Catatan Kas' : 'Tambah Transaksi Baru', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(label: const Text('Pemasukan'), selected: isPemasukanTerpilih, selectedColor: Colors.greenAccent.withOpacity(0.3), onSelected: (val) => setSheetState(() => isPemasukanTerpilih = true)),
                      const SizedBox(width: 15),
                      ChoiceChip(label: const Text('Pengeluaran'), selected: !isPemasukanTerpilih, selectedColor: Colors.redAccent.withOpacity(0.3), onSelected: (val) => setSheetState(() => isPemasukanTerpilih = false)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text('Nama Transaksi / Judul', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(controller: _judulController, decoration: InputDecoration(hintText: 'Misal: Gaji, Jajan Bakso', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(controller: _nominalController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: 'Rp ', hintText: '0', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
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
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        if (_judulController.text.isEmpty || _nominalController.text.isEmpty) return;
                        final dataTransaksi = {
                          'judul': _judulController.text,
                          'keterangan': isPemasukanTerpilih ? 'kiriman' : 'keperluan',
                          'nominal': int.parse(_nominalController.text),
                          'isPemasukan': isPemasukanTerpilih,
                          'waktu': DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggalTerpilih),
                          'tanggal': Timestamp.fromDate(tanggalTerpilih),
                        };
                        
                        if (isEditMode) {
                          await FirebaseFirestore.instance.collection('transaksi').doc(docId).update(dataTransaksi);
                        } else {
                          await FirebaseFirestore.instance.collection('transaksi').add(dataTransaksi);
                        }
                        
                        _judulController.clear();
                        _nominalController.clear();
                        Navigator.pop(context);
                      },
                      child: Text(isEditMode ? 'Simpan Perubahan' : 'Simpan Transaksi', style: const TextStyle(color: Colors.white, fontSize: 16)),
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

  Widget _buildSaldoInfo(IconData icon, String title, String amount, Color iconColor) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 16)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]),
      ],
    );
  }

  Widget _buildBottomNavItem(IconData icon, String title, int indexTarget) {
    final bool isSelected = _pilihanTabSekarang == indexTarget;
    return GestureDetector(
      onTap: () => setState(() => _pilihanTabSekarang = indexTarget),
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