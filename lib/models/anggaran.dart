
class Anggaran {
  final String id;          // ID dokumen unik dari Firestore
  final String nama;        // Nama anggaran (misal: "Bulanan Makan")
  final int limit;          // Batas limit uang (nominal rupiah)
  final String kategori;    // Kategori pengeluaran (misal: "Makan", "Semua Kategori")
  final String periode;     // Periode anggaran ("MONTHLY" bulanan atau "WEEKLY" mingguan)

  // Konstruktor untuk inisialisasi data anggaran
  Anggaran({
    required this.id,
    required this.nama,
    required this.limit,
    required this.kategori,
    required this.periode,
  });
}
