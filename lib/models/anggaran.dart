// =========================================================
// FILE: lib/models/anggaran.dart
// =========================================================
class Anggaran {
  final String id;
  final String nama;
  final int limit;
  final String kategori;
  final String periode;
  final double peringatan;
  final bool rollover;

  Anggaran({
    required this.id,
    required this.nama,
    required this.limit,
    required this.kategori,
    required this.periode,
    required this.peringatan,
    required this.rollover,
  });
}
