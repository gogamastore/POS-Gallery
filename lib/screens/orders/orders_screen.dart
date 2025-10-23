// lib/screens/orders/orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/order.dart';
import '../../providers/order_provider.dart';
import 'order_detail_screen.dart';
// PERBAIKAN: Import yang tidak ada dihapus.
import '../../utils/formatter.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final currentFilter = ref.watch(orderFilterProvider);

    void onFilterChanged(String filter) {
      ref.read(orderFilterProvider.notifier).state = filter;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(context, currentFilter, onFilterChanged),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allOrdersProvider);
                await ref.read(allOrdersProvider.future);
              },
              child: filteredOrders.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    // PERBAIKAN: Mengganti EmptyState dengan widget standar.
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Ionicons.receipt_outline,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Belum ada pesanan.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderCard(order: order);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                // PERBAIKAN: Mengganti ErrorState dengan widget standar.
                error: (e, s) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Ionicons.cloud_offline_outline,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                            'Gagal memuat pesanan.\nCoba periksa koneksi internet Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Ionicons.refresh_outline),
                          label: const Text('Coba Lagi'),
                          onPressed: () => ref.invalidate(allOrdersProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(
      BuildContext context, String currentFilter, ValueChanged<String> onTap) {
    final filters = {
      'Proses': 'processing',
      'Berhasil': 'success',
      'Dibatalkan': 'cancelled'
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.entries.map((entry) {
          final isSelected = currentFilter == entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onTap(entry.value);
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN: Menghapus garis bawah dari nama fungsi lokal.
    String getButtonText() {
      return 'Detail';
    }

    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'success':
          return const Color(0xFF27AE60);
        case 'cancelled':
          return const Color(0xFF95A5A6);
        default:
          return const Color(0xFFF39C12);
      }
    }

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(orderId: order.id!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${order.id?.substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow(Ionicons.person_outline, 'Pelanggan',
                  order.customerDetails?['name'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  Ionicons.calendar_outline,
                  'Tanggal',
                  DateFormat('d MMMM y, HH:mm', 'id_ID')
                      .format(order.date.toDate())),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    formatCurrency(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepPurple,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              OrderDetailScreen(orderId: order.id!),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(getButtonText()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
