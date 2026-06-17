import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';


class GrafikPage extends StatefulWidget {
  const GrafikPage({super.key});

  @override
  State<GrafikPage> createState() => _GrafikPageState();
}

class _GrafikPageState extends State<GrafikPage> {
  // Flag toggle pilihan jenis data: true = Pengeluaran, false = Pemasukan
  bool _isPengeluaran = true; 
  
  DateTime _bulanAktif = DateTime.now();
  
  // Kontroler scroll horizontal
  late ScrollController _scrollBulanController;
  // Menyimpan daftar bulan
  final List<DateTime> _listBulan = [];

  @override
  void initState() {
    super.initState();
    _scrollBulanController = ScrollController();
    _siapkanDataBulan();

    // menuju bulan ini
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollBulanController.hasClients) {
        _scrollBulanController.jumpTo(_scrollBulanController.position.maxScrollExtent);
      }
    });
  }

  // Membuat daftar rentang 12 bulan ke belakang
  void _siapkanDataBulan() {
    DateTime now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      _listBulan.add(DateTime(now.year, now.month - i, 1));
    }
  }

  @override
  void dispose() {
    _scrollBulanController.dispose();
    super.dispose();
  }

  // format angka rp
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

  // Map database warna
  final Map<String, Color> _warnaKategori = {
    'Makan': const Color(0xFFEF4444),
    'Minum': const Color(0xFFF97316),
    'Transportasi': const Color(0xFFEAB308),
    'Belanja': const Color(0xFF06B6D4),
    'Hiburan': const Color(0xFF8B5CF6),
    'Gaji': const Color(0xFF22C55E),
    'Investasi': const Color(0xFF3B82F6),
    'Lainnya': const Color(0xFF9CA3AF),
  };

  // Map database ikon 
  final Map<String, IconData> _ikonKategori = {
    'Makan': Icons.restaurant,
    'Minum': Icons.local_cafe,
    'Transportasi': Icons.directions_car,
    'Belanja': Icons.shopping_bag,
    'Hiburan': Icons.sports_esports,
    'Gaji': Icons.payments,
    'Investasi': Icons.trending_up,
    'Lainnya': Icons.category,
  };

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
    Color textColor = isDark ? Colors.white : Colors.black87;

    // Batasan awal & akhir tanggal bulan aktif untuk filter query Firestore
    final startOfMonth = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    final endOfMonth = DateTime(_bulanAktif.year, _bulanAktif.month + 1, 1);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPengeluaran = !_isPengeluaran; // Ganti filter Pengeluaran <=> Pemasukan
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isPengeluaran ? 'Pengeluaran' : 'Pemasukan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: textColor), // Panah v
                    ],
                  ),
                ),
              ),
            ),

            // NAVIGASI PILIHAN BULAN
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
              ),
              child: ListView.builder(
                controller: _scrollBulanController,
                scrollDirection: Axis.horizontal,
                itemCount: _listBulan.length,
                itemBuilder: (context, index) {
                  DateTime bulanItem = _listBulan[index];
                  DateTime now = DateTime.now();
                  
                  bool isBulanIni = bulanItem.year == now.year && bulanItem.month == now.month;
                  bool isSelected = _bulanAktif.year == bulanItem.year && _bulanAktif.month == bulanItem.month;

                  String labelText = isBulanIni 
                      ? 'Bulan ini' 
                      : DateFormat('MMM yyyy', 'id_ID').format(bulanItem);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _bulanAktif = bulanItem; // Pilih bulan aktif yang baru
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? const Color(0xFFEAB308) : Colors.transparent, // Garis emas bawah penunjuk terpilih
                            width: 3,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labelText,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? textColor : Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // KONTEN GRAFIK MEMBACA DATA TRANSAKSI DARI FIRESTORE
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest')
                    .collection('transaksi')
                    .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                    .where('tanggal', isLessThan: Timestamp.fromDate(endOfMonth))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  
                  // Menampung total nilai transaksi dan pengelompokan berdasarkan kategori
                  double totalUang = 0;
                  Map<String, double> mapKategori = {};

                  // Pengulangan data dokumen hasil query dari Firestore
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    bool isPem = data['isPemasukan'] ?? true;
                    
                    // Filter berdasarkan tipe transaksi saat ini (Pemasukan atau Pengeluaran)
                    if (isPem == !_isPengeluaran) {
                      String kat = data['kategori'] ?? 'Lainnya';
                      double nominal = (data['nominal'] ?? 0).toDouble();
                      
                      totalUang += nominal; // Tambahkan nominal ke total uang
                      mapKategori[kat] = (mapKategori[kat] ?? 0) + nominal; // Kelompokkan total per kategori
                    }
                  }

                  // Tampilan jika data kosong pada filter bulan aktif
                  if (totalUang == 0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 15),
                          Text('Belum ada data ${_isPengeluaran ? "pengeluaran" : "pemasukan"}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  // Mengurutkan map kategori dari nominal terbesar ke nominal terkecil
                  var listKategori = mapKategori.entries.toList();
                  listKategori.sort((a, b) => b.value.compareTo(a.value));

                  // Membuat list segmen data warna untuk PieChart (Donut Chart)
                  List<PieChartSectionData> pieSections = [];
                  int colorIndex = 0;
                  List<Color> warnaCadangan = [Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan];

                  for (var entry in listKategori) {
                    Color sectionColor = _warnaKategori[entry.key] ?? warnaCadangan[colorIndex % warnaCadangan.length];
                    pieSections.add(
                      PieChartSectionData(
                        color: sectionColor,
                        value: entry.value,
                        title: '', 
                        radius: 35, 
                      ),
                    );
                    colorIndex++;
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        
                        // DIAGRAM LINGKARAN
                        SizedBox(
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 70,
                                  sections: pieSections,
                                  startDegreeOffset: 270,
                                ),
                              ),
                              // TOTAL TEKS
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                  Text(_formatUang(totalUang.toInt()), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor)),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),

                        // DAFTAR KATEGORI
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: listKategori.length,
                            itemBuilder: (context, index) {
                              var entry = listKategori[index];
                              double persentase = (entry.value / totalUang) * 100;
                              Color katColor = _warnaKategori[entry.key] ?? warnaCadangan[index % warnaCadangan.length];
                              IconData katIcon = _ikonKategori[entry.key] ?? Icons.category;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  children: [
                                    // Bulatan Ikon Kategori
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: katColor.withOpacity(0.2), shape: BoxShape.circle),
                                      child: Icon(katIcon, color: katColor, size: 20),
                                    ),
                                    const SizedBox(width: 15),
                                    // Bar Informasi Kategori, Persentase, dan Nominal Uang
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                                                  const SizedBox(width: 8),
                                                  Text('${persentase.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                ],
                                              ),
                                              Text(_formatUang(entry.value.toInt()), style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Bar Indikator Linear Horizontal Penunjuk Persentase
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: LinearProgressIndicator(
                                              value: persentase / 100,
                                              minHeight: 6,
                                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(katColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}