import 'package:flutter/material.dart';
import '../customers/customer_list_screen.dart';
import 'banners_screen.dart';
import 'promo_screen.dart';
import 'staff_management_screen.dart';
import 'supplier_management_screen.dart';
import 'trending_products_screen.dart';
import '../ai/ai_stock_suggestion_screen.dart'; // Import halaman AI

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
      ),
      body: ListView(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.people_alt_outlined,
            title: 'Manajemen Staff',
            subtitle: 'Atur staff dan hak akses',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffManagementScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Icons.local_shipping_outlined,
            title: 'Manajemen Supplier',
            subtitle: 'Kelola data supplier Anda',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupplierManagementScreen())),
          ),
          // --- MENU AI DITAMBAHKAN DI SINI ---
          _buildMenuItem(
            context,
            icon: Icons.auto_awesome, // Ikon AI
            title: 'Saran Stok (AI)',
            subtitle: 'Dapatkan rekomendasi stok menggunakan AI',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AiStockSuggestionScreen())),
          ),
          // ------------------------------------
          _buildMenuItem(
            context,
            icon: Icons.contacts_outlined,
            title: 'Daftar Customer',
            subtitle: 'Lihat dan kelola semua customer',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerListScreen())),
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.image_outlined,
            title: 'Banners',
            subtitle: 'Atur banner promosi di halaman utama',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BannersScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Icons.local_offer_outlined,
            title: 'Promo Toko',
            subtitle: 'Buat dan kelola promo yang sedang berjalan',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromoScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Icons.trending_up,
            title: 'Produk Trending',
            subtitle: 'Tentukan produk yang akan ditampilkan sebagai trending',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrendingProductsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
