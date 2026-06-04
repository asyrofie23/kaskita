// =========================================================
// FILE: lib/models/transaksi.dart
// =========================================================
// File ini mandiri, gunanya cuma jadi cetakan data transaksi
// supaya bisa dipakai di home_page.dart maupun riwayat_page.dart

// ==========================================
// 1. MODEL DATA TRANSAKSI
// ==========================================
// Ini adalah cetakan (blueprint) untuk data transaksi kita.
// Setiap ada transaksi baru, harus punya 5 data ini.
class Transaksi {
  final String judul;
  final String keterangan;
  final String kategori;
  final int nominal;
  final String waktu;
  final bool isPemasukan;

  Transaksi({
    required this.judul,
    required this.keterangan,
    required this.kategori,
    required this.nominal,
    required this.waktu,
    required this.isPemasukan,
  });
}
