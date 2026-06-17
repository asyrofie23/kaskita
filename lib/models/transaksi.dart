

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
