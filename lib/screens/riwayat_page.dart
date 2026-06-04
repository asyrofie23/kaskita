// =========================================================
// FILE: lib/screens/riwayat_page.dart
// =========================================================
import 'package:flutter/material.dart';
import '../models/transaksi.dart'; // Import model transaksinya

class RiwayatPage extends StatefulWidget {
  // Kita minta kiriman data 'listTransaksi' dari home_page.dart lewat constructor ini
  final List<Transaksi> semuaTransaksi;
  final Function(int index)? onEditTransaksi;

  const RiwayatPage({
    super.key,
    required this.semuaTransaksi,
    this.onEditTransaksi,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  /// Kunci Filter: 
  /// 'Semua', 'Pemasukan', atau 'Pengeluaran'
  String _filterTerpilih = 'Semua';

  /// Helper untuk format titik ribuan uang (sama kayak di Home)
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
    /// --- DETEKSI TEMA SAAT INI ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    /// --- LOGIKA MENYARING (FILTER) DATA ---
    /// widget.semuaTransaksi artinya kita mengambil data yang dikirim dari class atasnya
    List<Transaksi> listYangDitampilkan = [];
    
    if (_filterTerpilih == 'Semua') {
      listYangDitampilkan = widget.semuaTransaksi;
    } else if (_filterTerpilih == 'Pemasukan') {
      // .where() itu fungsi bawaan Dart buat nge-filter isi list
      listYangDitampilkan = widget.semuaTransaksi.where((trx) => trx.isPemasukan).toList();
    } else {
      listYangDitampilkan = widget.semuaTransaksi.where((trx) => !trx.isPemasukan).toList();
    }

    return SafeArea(
      child: Column(
        children: [
          // CUSTOM HEADER UNTUK MENGGANTIKAN APPBAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Kas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.history_toggle_off, color: isDark ? Colors.white70 : Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 15),

          /// 1. TOMBOL-TOMBOL FILTER (ChoiceChip)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterButton('Semua', isDark),
              const SizedBox(width: 10),
              _buildFilterButton('Pemasukan', isDark),
              const SizedBox(width: 10),
              _buildFilterButton('Pengeluaran', isDark),
            ],
          ),
          const SizedBox(height: 15),

          /// 2. DAFTAR RIWAYAT TRANSAKSI
          Expanded(
            child: listYangDitampilkan.isEmpty
                ? const Center(child: Text('Belum ada transaksi di kategori ini, bre.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: listYangDitampilkan.length,
                    itemBuilder: (context, index) {
                      final trx = listYangDitampilkan[index];
                      return GestureDetector(
                        onTap: () {
                          if (widget.onEditTransaksi != null) {
                            final originalIndex = widget.semuaTransaksi.indexOf(trx);
                            if (originalIndex != -1) {
                              widget.onEditTransaksi!(originalIndex);
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: trx.isPemasukan ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  trx.isPemasukan ? Icons.arrow_downward : Icons.arrow_upward,
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
                                    Text(trx.kategori, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
          ),
        ],
      ),
    );
  }

  /// Widget Helper buat bikin Tombol Filter gampang diklik
  Widget _buildFilterButton(String namaFilter, bool isDark) {
    final bool isSelected = _filterTerpilih == namaFilter;
    return ChoiceChip(
      label: Text(namaFilter),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filterTerpilih = namaFilter; // Ganti filter aktif lalu render ulang layar
          });
        }
      },
    );
  }
}
