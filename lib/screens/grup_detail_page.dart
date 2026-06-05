// =========================================================
// FILE: lib/screens/grup_detail_page.dart
// =========================================================
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Kelola Anggota coming soon!')));
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
                      final data = docs[index].data() as Map<String, dynamic>;
                      final bool isPemasukan = data['isPemasukan'] ?? true;
                      final String judul = data['judul'] ?? '';
                      final int nominal = data['nominal'] ?? 0;
                      final String pembuat = data['nama_pembuat'] ?? 'Anggota';
                      
                      String waktuTampil = '';
                      if (data['tanggal'] != null && data['tanggal'] is Timestamp) {
                        waktuTampil = DateFormat('dd MMM yyyy, HH:mm').format((data['tanggal'] as Timestamp).toDate());
                      }

                      return Container(
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

  // --- FORM TAMBAH TRANSAKSI GRUP ---
  void _tampilFormTransaksiGrup(BuildContext context) {
    bool isPemasukanTerpilih = true;
    _judulController.clear();
    _nominalController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tambah Transaksi Grup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    TextField(controller: _judulController, decoration: InputDecoration(hintText: 'Judul (misal: Iuran Kas / Beli Galon)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 15),
                    TextField(controller: _nominalController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: 'Rp ', hintText: '0', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () async {
                          if (_judulController.text.isEmpty || _nominalController.text.isEmpty) return;
                          
                          final user = FirebaseAuth.instance.currentUser;
                          String namaPembuat = user?.displayName ?? user?.email?.split('@')[0] ?? 'Anggota';

                          // Simpan transaksi ke dalam folder grup
                          await FirebaseFirestore.instance.collection('grup_kas').doc(widget.kodeGrup).collection('transaksi').add({
                            'judul': _judulController.text,
                            'nominal': int.parse(_nominalController.text),
                            'isPemasukan': isPemasukanTerpilih,
                            'tanggal': FieldValue.serverTimestamp(),
                            'uid_pembuat': user?.uid,
                            'nama_pembuat': namaPembuat,
                          });
                          
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Simpan Transaksi', style: TextStyle(color: Colors.white, fontSize: 16)),
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