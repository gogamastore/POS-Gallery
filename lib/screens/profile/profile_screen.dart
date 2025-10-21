import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../operational/operational_transaction_screen.dart';
import 'profile_settings_screen.dart';
import 'reports_screen.dart';
import 'security_screen.dart';
import '../settings/settings_screen.dart';
import '../../models/user_model.dart';
import 'my_orders_screen.dart';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            children: [
              userDataState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
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
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Icon(Icons.person,
                                  size: 60, color: Colors.grey.shade600)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.edit_outlined,
                              title: 'Edit Profil',
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileSettingsScreen())),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.receipt_long_outlined,
                              title: 'Pesanan',
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const MyOrdersScreen())),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.auto_awesome,
                              title: 'AI Gogama',
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const AiStockSuggestionScreen()));
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.assessment_outlined,
                              title: 'Operasional',
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const OperationalTransactionScreen()));
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.store_outlined,
                              title: 'Pengaturan Toko',
                              onTap: () {
                                navigateToSettings(user);
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.bar_chart,
                              title: 'Pusat Laporan',
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ReportsScreen())),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildProfileMenuItem(
                              context,
                              icon: Icons.security,
                              title: 'Keamanan',
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SecurityScreen())),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text('Logout',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            await authService.signOut();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
