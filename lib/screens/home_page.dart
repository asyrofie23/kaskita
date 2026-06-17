import 'grafik_page.dart'; // <--- TAMBAHKAN INI
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../models/transaksi.dart';
import '../main.dart'; 
import 'profil_page.dart';
import 'anggaran_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controller untuk input teks nama transaksi/judul
  final TextEditingController _judulController = TextEditingController();
  // Controller untuk input teks nominal uang
  final TextEditingController _nominalController = TextEditingController();
  // Index tab navigasi bawah yang sedang aktif (0: Home, 1: Grafik, 2: Anggaran, 3: Profil)
  int _pilihanTabSekarang = 0;
  // Controller untuk mengontrol halaman/view di PageView
  late PageController _pageController;
  
  // Variabel untuk menyimpan bulan yang sedang dipilih (Default: Bulan ini)
  DateTime _bulanAktif = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    // Inisialisasi page controller sesuai tab awal
    _pageController = PageController(initialPage: _pilihanTabSekarang);
  }

  // Fungsi format RP
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Hitung batas awal dan akhir bulan yang dipilih
    final startOfMonth = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    final endOfMonth = DateTime(_bulanAktif.year, _bulanAktif.month + 1, 1);

    return StreamBuilder<QuerySnapshot>(
      // Mengambil data transaksi pengguna ter-filter berdasarkan bulan yang dipilih secara real-time dari Firestore
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest')
          .collection('transaksi')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfMonth))
          .orderBy('tanggal', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        final docs = snapshot.data?.docs ?? [];
        // Memetakan dokumen Firestore ke objek transaksi
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
            kategori: (data != null && data.containsKey('kategori')) ? doc['kategori'] : 'Lainnya',
            nominal: doc['nominal'] ?? 0,
            waktu: waktuTampil,
            isPemasukan: doc['isPemasukan'] ?? true,
          );
        }).toList();

        // Menghitung total saldo
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
          backgroundColor: bgColor,
          // Tombol +
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            backgroundColor: const Color(0xFF1D4ED8),
            shape: const CircleBorder(),
            onPressed: () => _tampilFormTransaksi(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButtonAnimator: const NoAnimationFABAnimator(),
          // Bar navigasi bagian bawah dengan notch melengkung di tengah untuk FAB
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: cardColor, 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBottomNavItem(Icons.home, 'Home', 0),
                  _buildBottomNavItem(Icons.pie_chart, 'Grafik', 1), // Menu Riwayat diubah jadi Grafik
                  const SizedBox(width: 40),
                  _buildBottomNavItem(Icons.account_balance_wallet_outlined, 'Anggaran', 2),
                  _buildBottomNavItem(Icons.person_outline, 'Profil', 3),
                ],
              ),
            ),
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _pilihanTabSekarang = index;
              });
            },
            children: [
              _buildKontenHalamanUtama(listTransaksi, totalSaldo, totalPemasukan, totalPengeluaran, docs, isDark, cardColor),
              const GrafikPage(),
              AnggaranPage(semuaTransaksi: listTransaksi),
              const ProfilPage(),
            ],
          ),
        );
      },
    );
  }

  // Fungsi untuk membangun UI konten utama pada tab Home
  Widget _buildKontenHalamanUtama(List<Transaksi> listTransaksi, int totalSaldo, int totalPemasukan, int totalPengeluaran, List<QueryDocumentSnapshot> docs, bool isDark, Color cardColor) {
    final user = FirebaseAuth.instance.currentUser;
    String namaSapaan = 'Pengguna Baru'; 
    
    // Logika sapaan
    if (user != null && !user.isAnonymous) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        namaSapaan = user.displayName!.split(' ')[0];
      } else if (user.email != null && user.email!.isNotEmpty) {
        namaSapaan = user.email!.split('@')[0];
      } else {
        namaSapaan = 'Pengguna';
      }
    }

    return SafeArea(
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header n card
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selamat datang,', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text('$namaSapaan! 👋', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    Row(
                      children: [
                        // Tombol dark/light mode
                        IconButton(
                          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : Colors.grey),
                          onPressed: () {
                            themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                          },
                        ),
                        // notifikasi
                        // Mengambil jumlah notifikasi yang belum dibaca dari database secara real-time
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.uid ?? 'guest')
                              .collection('notifikasi')
                              .where('isRead', isEqualTo: false) // Hanya hitung yang belum dibaca
                              .snapshots(),
                          builder: (context, snapshot) {
                            int unreadCount = snapshot.data?.docs.length ?? 0;

                            return Stack(
                              children: [
                                // Tombol lonceng
                                IconButton(
                                  icon: const Icon(Icons.notifications_none, size: 28),
                                  color: isDark ? Colors.white : Colors.black87,
                                  onPressed: () {
                                    _tampilLaciNotifikasi(context, isDark);
                                  },
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount', 
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  )
                              ],
                            );
                          }
                        ),
                        // --- BATAS LONCENG ---
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // KARTU SALDO
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
                          

                          // Tombol <bulan>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month - 1, 1)),
                                  child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.chevron_left, color: Colors.white, size: 16)),
                                ),
                                Text(DateFormat('MMM yyyy', 'id_ID').format(_bulanAktif), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                GestureDetector(
                                  onTap: () => setState(() => _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month + 1, 1)),
                                  child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.chevron_right, color: Colors.white, size: 16)),
                                ),
                              ],
                            ),
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

                // JUDUL RIWAYAT
                const Text('Riwayat Bulan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),

          // transaksi
          Expanded(
            child: listTransaksi.isEmpty
                ? const Center(
                    child: Text('Belum ada transaksi di bulan ini, bre.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: listTransaksi.length,
                    itemBuilder: (context, index) {
                      final trx = listTransaksi[index];
                      final docId = docs[index].id;

                      // Slide
                      return SlidableTile(
                        key: Key(docId),
                        // Menangani aksi edit transaksi ketika digeser & diklik Edit
                        onEdit: () {
                          final rawTanggal = (docs[index].data() as Map<String, dynamic>?)?['tanggal'];
                          final DateTime initialDate = (rawTanggal != null && rawTanggal is Timestamp) 
                              ? rawTanggal.toDate() 
                              : DateTime.now();
                          _tampilFormTransaksi(
                            context, docId: docId, judulAwal: trx.judul, nominalAwal: trx.nominal, 
                            isPemasukanAwal: trx.isPemasukan, tanggalAwal: initialDate, kategoriAwal: trx.kategori,
                          );
                        },
                        // Menangani aksi hapus transaksi ketika digeser & diklik Hapus
                        onDelete: () => _konfirmasiHapusTransaksi(context, docId, trx.judul),
                        child: GestureDetector(
                          // Klik biasa pada item (edit)
                          onTap: () {
                            
                            final rawTanggal = (docs[index].data() as Map<String, dynamic>?)?['tanggal'];
                            final DateTime initialDate = (rawTanggal != null && rawTanggal is Timestamp) 
                                ? rawTanggal.toDate() 
                                : DateTime.now();
                            _tampilFormTransaksi(
                              context, docId: docId, judulAwal: trx.judul, nominalAwal: trx.nominal, 
                              isPemasukanAwal: trx.isPemasukan, tanggalAwal: initialDate, kategoriAwal: trx.kategori,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: trx.isPemasukan ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(trx.isPemasukan ? Icons.arrow_downward : Icons.arrow_upward, color: trx.isPemasukan ? Colors.green : Colors.red),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(trx.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(trx.kategori, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
          ),
        ],
      ),
    );
  }

  // Fungsi menampilkan bottomsheet form transaksi
  void _tampilFormTransaksi(BuildContext context, {String? docId, String? judulAwal, int? nominalAwal, bool? isPemasukanAwal, DateTime? tanggalAwal, String? kategoriAwal}) {
    final bool isEditMode = docId != null;

    if (isEditMode) {
      // Jika mode edit, isi form dengan data lama
      _judulController.text = judulAwal!;
      _nominalController.text = nominalAwal!.toString();
    } else {
      // Jika mode tambah baru, bersihkan input form
      _judulController.clear();
      _nominalController.clear();
    }
    bool isPemasukanTerpilih = isEditMode ? isPemasukanAwal! : true;
    
    
    DateTime now = DateTime.now();
    DateTime defaultDate = (_bulanAktif.year == now.year && _bulanAktif.month == now.month) ? now : DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    DateTime tanggalTerpilih = tanggalAwal ?? defaultDate;
    
    String kategoriTerpilih = kategoriAwal ?? 'Lainnya';

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
                  Center(child: Text(isEditMode ? 'Edit Catatan Kas' : 'Tambah Transaksi Baru', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Pemasukan'), 
                        selected: isPemasukanTerpilih, 
                        selectedColor: Colors.greenAccent.withOpacity(0.3), 
                        onSelected: (val) {
                          setSheetState(() {
                            isPemasukanTerpilih = true;
                            kategoriTerpilih = 'Gaji';
                          });
                        }
                      ),
                      const SizedBox(width: 15),
                      ChoiceChip(
                        label: const Text('Pengeluaran'), 
                        selected: !isPemasukanTerpilih, 
                        selectedColor: Colors.redAccent.withOpacity(0.3), 
                        onSelected: (val) {
                          setSheetState(() {
                            isPemasukanTerpilih = false;
                            kategoriTerpilih = 'Makan';
                          });
                        }
                      ),
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
                  const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest').collection('kategori').snapshots(),
                    builder: (context, snapshot) {
                      final List<String> defaultKategori = isPemasukanTerpilih ? ['Gaji', 'Freelance', 'Investasi', 'Hadiah', 'Lainnya'] : ['Makan', 'Minum', 'Transportasi', 'Belanja', 'Hiburan', 'Lainnya'];
                      List<String> listKategori = List.from(defaultKategori);

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data != null && data['isPemasukan'] == isPemasukanTerpilih && data['nama'] != null) {
                            final String nama = data['nama'];
                            if (!listKategori.contains(nama)) {
                              listKategori.add(nama);
                            }
                          }
                        }
                      }

                      if (!listKategori.contains(kategoriTerpilih)) {
                        kategoriTerpilih = listKategori.first;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: kategoriTerpilih,
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: listKategori.map((kat) {
                              return DropdownMenuItem<String>(value: kat, child: Text(kat));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  kategoriTerpilih = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => _tampilBottomSheetKelolaKategori(context, isPemasukanTerpilih, (kategoriBaru) {
                                  setSheetState(() { kategoriTerpilih = kategoriBaru; });
                                }),
                                icon: const Icon(Icons.settings_outlined, size: 18),
                                label: const Text('Kelola Kategori', style: TextStyle(fontSize: 13)),
                              ),
                              TextButton.icon(
                                onPressed: () => _tampilDialogTambahKategori(context, isPemasukanTerpilih, (kategoriBaru) {
                                  setSheetState(() { kategoriTerpilih = kategoriBaru; });
                                }),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah Baru', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 5),
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
                      onPressed: () async { //fungsi simpan Transaksi
                        if (_judulController.text.isEmpty || _nominalController.text.isEmpty) return;
                        final dataTransaksi = {
                          'judul': _judulController.text,
                          'keterangan': isPemasukanTerpilih ? 'kiriman' : 'keperluan',
                          'nominal': int.parse(_nominalController.text),
                          'isPemasukan': isPemasukanTerpilih,
                          'kategori': kategoriTerpilih,
                          'waktu': DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggalTerpilih),
                          'tanggal': Timestamp.fromDate(tanggalTerpilih),
                        };
                        
                        final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

                        if (isEditMode) {
                          await userDoc.collection('transaksi').doc(docId).update(dataTransaksi);
                        } else {
                          await userDoc.collection('transaksi').add(dataTransaksi);
                        }
                        
                        _judulController.clear();
                        _nominalController.clear();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
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

  // Fungsi pop-up nambah kategori baru
  void _tampilDialogTambahKategori(BuildContext context, bool isPemasukan, Function(String) onKategoriDitambahkan) {
    final TextEditingController kategoriController = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(isPemasukan ? 'Tambah Kategori Pemasukan' : 'Tambah Kategori Pengeluaran', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: TextField(
            controller: kategoriController,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(hintText: 'Nama kategori baru', hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
              onPressed: () async {
                final String nama = kategoriController.text.trim();
                if (nama.isNotEmpty) {
                  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                  await FirebaseFirestore.instance.collection('users').doc(uid).collection('kategori').add({'nama': nama, 'isPemasukan': isPemasukan, 'tanggal': FieldValue.serverTimestamp()});
                  onKategoriDitambahkan(nama);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Tambah', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Fungsi Bottomsheet untuk menampilkan daftar kategori untuk dikelola
  void _tampilBottomSheetKelolaKategori(BuildContext context, bool isPemasukan, Function(String) onKategoriTerpilih) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final Color textColor = isDark ? Colors.white : Colors.black87;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(color: sheetBgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest').collection('kategori').where('isPemasukan', isEqualTo: isPemasukan).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data?.docs ?? [];
                  final customDocs = docs.where((doc) { final data = doc.data() as Map<String, dynamic>?; return data != null && data['nama'] != null; }).toList();
                  customDocs.sort((a, b) { final String nameA = (a['nama'] as String).toLowerCase(); final String nameB = (b['nama'] as String).toLowerCase(); return nameA.compareTo(nameB); });

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Column(
                      children: [
                        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        Text(isPemasukan ? 'Kelola Kategori Pemasukan' : 'Kelola Kategori Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                        const SizedBox(height: 10),
                        const Text('Kategori bawaan sistem tidak dapat diubah atau dihapus.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                        const SizedBox(height: 15),
                        Expanded(
                          child: customDocs.isEmpty
                              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.category_outlined, size: 60, color: Colors.grey.withOpacity(0.5)), const SizedBox(height: 10), Text('Belum ada kategori custom.', style: TextStyle(color: Colors.grey[500]))]))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: customDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = customDocs[index];
                                    final docId = doc.id;
                                    final String nama = doc['nama'];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        title: Text(nama, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent), onPressed: () => _tampilDialogEditKategori(context, docId, nama)),
                                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _konfirmasiHapusKategori(context, docId, nama)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Dialog untuk mengedit nama kategori kustom di database
  void _tampilDialogEditKategori(BuildContext context, String docId, String namaLama) {
    final TextEditingController controller = TextEditingController(text: namaLama);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Edit Kategori', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller, autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(hintText: 'Nama kategori baru', hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final String namaBaru = controller.text.trim();
                if (namaBaru.isNotEmpty && namaBaru != namaLama) {
                  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                  await FirebaseFirestore.instance.collection('users').doc(uid).collection('kategori').doc(docId).update({'nama': namaBaru});
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Dialog konfirmasi untuk menghapus kategori kustom dari database
  void _konfirmasiHapusKategori(BuildContext context, String docId, String nama) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Hapus Kategori?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus kategori "$nama"? Transaksi lama dengan kategori ini tidak akan terpengaruh.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('kategori').doc(docId).delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Dialog konfirmasi penghapusan catatan transaksi pribadi dari database
  void _konfirmasiHapusTransaksi(BuildContext context, String docId, String judul) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Hapus Transaksi?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus transaksi "$judul"? Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async { //fungsi del
                final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('transaksi').doc(docId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$judul berhasil dihapus'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Widget helper untuk menyusun informasi nominal dan label di dalam kartu saldo
  Widget _buildSaldoInfo(IconData icon, String title, String amount, Color iconColor) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 16)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]),
      ],
    );
  }

  // Widget helper untuk merender setiap item/tombol menu navigasi di bagian bawah
  Widget _buildBottomNavItem(IconData icon, String title, int indexTarget) {
    final bool isSelected = _pilihanTabSekarang == indexTarget;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _pilihanTabSekarang = indexTarget);
          _pageController.animateToPage(
            indexTarget,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 26),
            const SizedBox(height: 4),
            Text(
              title, 
              style: TextStyle(
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LACI NOTIFIKASI
  // Fungsi Bottomsheet laci notif
  void _tampilLaciNotifikasi(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 15),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest')
                        .collection('notifikasi')
                        .orderBy('waktu', descending: true)
                        .limit(20) // Maksimal nampilin 20 notif terbaru
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('Belum ada notifikasi baru.', style: TextStyle(color: Colors.grey)));
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isRead = data['isRead'] ?? true;
                          
                          String waktuTampil = 'Baru saja';
                          if (data['waktu'] != null && data['waktu'] is Timestamp) {
                            waktuTampil = DateFormat('dd MMM HH:mm', 'id_ID').format((data['waktu'] as Timestamp).toDate());
                          }

                          return Container(
                            color: isRead ? Colors.transparent : (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isRead ? Colors.grey.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                child: Icon(Icons.notifications, color: isRead ? Colors.grey : Colors.blueAccent),
                              ),
                              title: Text(data['judul'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(data['pesan'] ?? '', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(waktuTampil, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              onTap: () {
                                // Ubah status jadi sudah dibaca kalau diklik
                                if (!isRead) {
                                  doc.reference.update({'isRead': true});
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Animator kustom untuk FloatingActionButton agar tidak memiliki efek animasi transisi berlebih
class NoAnimationFABAnimator extends FloatingActionButtonAnimator {
  const NoAnimationFABAnimator();
  @override Offset getOffset({required Offset begin, required Offset end, required double progress}) => end;
  @override Animation<double> getRotationAnimation({required Animation<double> parent}) => const AlwaysStoppedAnimation(0.0);
  @override Animation<double> getScaleAnimation({required Animation<double> parent}) => const AlwaysStoppedAnimation(1.0);
}

// Widget Stateful Custom SlidableTile untuk membungkus list item transaksi agar bisa digeser (slide)
class SlidableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const SlidableTile({super.key, required this.child, required this.onEdit, required this.onDelete});
  @override State<SlidableTile> createState() => _SlidableTileState();
}

class _SlidableTileState extends State<SlidableTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0.0;
  final double _actionsWidth = 140.0; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _controller.addListener(() { setState(() { _dragExtent = _controller.value * -_actionsWidth; }); });
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;
      if (_dragExtent > 0) _dragExtent = 0; else if (_dragExtent < -_actionsWidth - 30) _dragExtent = -_actionsWidth - 30;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final double dragPercent = (_dragExtent.abs() / _actionsWidth).clamp(0.0, 1.0);
    _controller.value = dragPercent;
    final double velocity = details.primaryVelocity ?? 0.0;
    if (velocity < -300) _open(); else if (velocity > 300) _close(); else if (_dragExtent.abs() > _actionsWidth / 2) _open(); else _close();
  }

  void _open() => _controller.animateTo(1.0, curve: Curves.easeOut);
  void _close() => _controller.animateTo(0.0, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final bool isOpen = _dragExtent.abs() > 10.0;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () { _close(); widget.onEdit(); },
                  child: Container(width: 70, height: double.infinity, color: const Color(0xFF2563EB), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, color: Colors.white, size: 24), SizedBox(height: 4), Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))])),
                ),
                GestureDetector(
                  onTap: () { _close(); widget.onDelete(); },
                  child: Container(width: 70, height: double.infinity, color: const Color(0xFFEF4444), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete, color: Colors.white, size: 24), SizedBox(height: 4), Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))])),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_dragExtent, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, onHorizontalDragUpdate: _onHorizontalDragUpdate, onHorizontalDragEnd: _onHorizontalDragEnd, onTap: isOpen ? _close : null,
            child: IgnorePointer(ignoring: isOpen, child: widget.child),
          ),
        ),
      ],
    );
  }
}