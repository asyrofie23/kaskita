import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- BOTTOM NAVIGATION & TOMBOL PLUS (FAB) ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1D4ED8),
        shape: const CircleBorder(),
        onPressed: () {
          _tampilFormTambahTransaksi(context);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavItem(Icons.home, 'Home', true),
              _buildBottomNavItem(Icons.list_alt, 'Riwayat', false),
              const SizedBox(width: 40), 
              _buildBottomNavItem(Icons.pie_chart_outline, 'Anggaran', false),
              _buildBottomNavItem(Icons.person_outline, 'Profil', false),
            ],
          ),
        ),
      ),

      // --- BODY HALAMAN UTAMA ---
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
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

              // 2. KARTU SALDO BIRU
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
                    const Text('Rp 50.000', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSaldoInfo(Icons.arrow_downward, 'Pemasukan', 'Rp 50 rb', Colors.greenAccent),
                        _buildSaldoInfo(Icons.arrow_upward, 'Pengeluaran', 'Rp 0,00', Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 3. MENU ACTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionItem(Icons.account_balance_wallet_outlined, 'Dompet', const Color(0xFFEEF2FF), Colors.blue),
                  _buildActionItem(Icons.track_changes, 'Target', const Color(0xFFECFDF5), Colors.green),
                  _buildActionItem(Icons.bar_chart, 'Laporan', const Color(0xFFFFFBEB), Colors.orange),
                  _buildActionItem(Icons.credit_score, 'Limit', const Color(0xFFF5F3FF), Colors.purple),
                ],
              ),
              const SizedBox(height: 30),

              // 4. JUDUL TRANSAKSI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Lihat Semua', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 15),

              // 5. ITEM TRANSAKSI
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.attach_money, color: Colors.green),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Freelance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('kiriman', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('+Rp 50.000', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('12:22', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FUNGSI FORM TAMBAH TRANSAKSI ---
  void _tampilFormTambahTransaksi(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
              const Center(
                child: Text('Tambah Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(height: 20),
              const Text('Nominal', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),
              const Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Misal: Beli makan siang',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Simpan Transaksi', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET BANTUAN ---
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

  Widget _buildActionItem(IconData icon, String title, Color bgColor, Color iconColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomNavItem(IconData icon, String title, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 26),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF2563EB) : Colors.grey)),
      ],
    );
  }
}