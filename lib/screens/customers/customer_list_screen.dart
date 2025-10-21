import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/app_user.dart';
import '../../providers/customer_provider.dart';
import 'add_customer_screen.dart'; // Impor halaman baru

// --- UBAH MENJADI STATEFUL WIDGET UNTUK PENCARIAN ---
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCustomerDetails(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Ionicons.person_circle_outline, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(user.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Ionicons.at_outline, 'Email', user.email),
              if (user.whatsapp != null && user.whatsapp!.isNotEmpty)
                _buildDetailRow(
                    Ionicons.logo_whatsapp, 'WhatsApp', user.whatsapp!),
              if (user.role != null)
                _buildDetailRow(Ionicons.ribbon_outline, 'Role', user.role!),
              if (user.shopName != null)
                _buildDetailRow(
                    Ionicons.storefront_outline, 'Nama Toko', user.shopName!),
              if (user.address != null)
                _buildDetailRow(
                    Ionicons.location_outline, 'Alamat', user.address!,
                    maxLines: 3),
              _buildDetailRow(
                Ionicons.calendar_outline,
                'Tanggal Daftar',
                DateFormat('dd MMMM yyyy', 'id_ID')
                    .format(user.createdAt.toDate()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(user); // Return the selected user
            },
            child: const Text('Pilih Customer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Customer'),
      ),
      // --- TAMBAHKAN TOMBOL AKSI APUNG ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigasi ke halaman tambah dan tunggu hasilnya
          final bool? customerAdded =
              await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
          );
          // Jika customer berhasil ditambahkan, segarkan daftar
          if (customerAdded == true) {
            ref.invalidate(customerListProvider);
          }
        },
        label: const Text('Tambah Customer'),
        icon: const Icon(Ionicons.add),
      ),
      body: Column(
        children: [
          // --- TAMBAHKAN KOLOM PENCARIAN ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau no. whatsapp...',
                prefixIcon: const Icon(Ionicons.search_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Gagal memuat data: $err')),
              data: (customers) {
                // --- LOGIKA FILTER PENCARIAN ---
                final filteredCustomers = customers.where((user) {
                  final name = user.name.toLowerCase();
                  final whatsapp = user.whatsapp?.toLowerCase() ?? '';
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || whatsapp.contains(query);
                }).toList();

                if (filteredCustomers.isEmpty) {
                  return const Center(
                      child: Text('Customer tidak ditemukan.'));
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.only(bottom: 80), // Padding untuk FAB
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final user = filteredCustomers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColorLight,
                        child: user.photoURL != null &&
                                user.photoURL!.isNotEmpty
                            ? ClipOval(child: Image.network(user.photoURL!,
                                fit: BoxFit.cover))
                            : const Icon(Ionicons.person, color: Colors.white),
                      ),
                      title: Text(user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(user.whatsapp ?? 'No WhatsApp'),
                      onTap: () => _showCustomerDetails(context, user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
