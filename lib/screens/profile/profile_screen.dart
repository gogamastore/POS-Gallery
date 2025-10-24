import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart'; // Menggunakan Ionicons untuk konsistensi

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../operational/operational_transaction_screen.dart';
import 'profile_settings_screen.dart';
import 'reports_screen.dart';
import 'security_screen.dart';
import '../settings/settings_screen.dart';
import '../../models/user_model.dart';
import '../../screens/orders/orders_screen.dart';
import '../ai/ai_stock_suggestion_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final userDataState = ref.watch(userDataProvider);

    void navigateToSettings(UserModel? user) {
      if (user != null &&
          (user.position == 'Admin' || user.position == 'Owner')) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SettingsScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda tidak memiliki hak akses.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userDataProvider.future),
        child: Center( // 1. Menambahkan Center
          child: ConstrainedBox( // 2. Membatasi lebar maksimum
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView( // Mengganti SingleChildScrollView+Column dengan ListView
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              children: [
                userDataState.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 100.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (error, stack) =>
                      Center(child: Text('Gagal memuat profil: $error')),
                  data: (user) {
                    final displayName =
                        (user?.name != null && user!.name.isNotEmpty)
                            ? user.name
                            : (user?.email ?? 'Pengguna');
                    final photoUrl = user?.photoURL ?? '';

                    return Column(
                      children: [
                        // --- User Info Header ---
                        CircleAvatar(
                          radius: 50, // Sedikit lebih kecil
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Icon(Ionicons.person,
                                  size: 50, color: Colors.grey.shade600)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall // Ukuran lebih sesuai
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          user?.position ?? 'Staff',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // --- Menu Section ---
                        // Menggunakan gaya ListTile sederhana, tanpa Card
                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.create_outline,
                          title: 'Edit Profil',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfileSettingsScreen())),
                        ),
                        const Divider(height: 1),
                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.receipt_outline,
                          title: 'Pesanan',
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    const OrdersScreen()));
                          },
                        ),
                         const Divider(height: 1),
                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.sparkles_outline,
                          title: 'AI Gogama',
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    const AiStockSuggestionScreen()));
                          },
                        ),
                        const Divider(height: 1),
                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.wallet_outline,
                          title: 'Operasional',
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    const OperationalTransactionScreen()));
                          },
                        ),

                        const SizedBox(height: 16), // Spasi antar grup menu

                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.storefront_outline,
                          title: 'Pengaturan Toko',
                          onTap: () {
                            navigateToSettings(user);
                          },
                        ),
                        const Divider(height: 1),
                         _buildProfileMenuItem(
                          context,
                          icon: Ionicons.bar_chart_outline,
                          title: 'Pusat Laporan',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ReportsScreen())),
                        ),
                        const Divider(height: 1),
                        _buildProfileMenuItem(
                          context,
                          icon: Ionicons.shield_checkmark_outline,
                          title: 'Keamanan',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const SecurityScreen())),
                        ),
                       
                        const SizedBox(height: 32),
                        
                        // --- Logout Button ---
                        ElevatedButton.icon(
                          icon: const Icon(Ionicons.log_out_outline, color: Colors.white),
                          label: const Text('Logout',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50), // Tinggi tombol yang konsisten
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            await authService.signOut();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Menggunakan gaya yang konsisten dengan halaman lain
  Widget _buildProfileMenuItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
