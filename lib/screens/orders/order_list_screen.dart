import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/models/order.dart';
import 'package:myapp/providers/order_provider.dart';
import 'package:myapp/widgets/order_card.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // PERBAIKAN: Status disesuaikan dengan model dan provider yang baru.
  final List<String> _statuses = ['all', 'success', 'cancelled'];
  final Map<String, String> _statusLabels = {
    'all': 'SEMUA',
    'success': 'BERHASIL',
    'cancelled': 'DIBATALKAN',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN: Menggunakan `allOrdersProvider` untuk mendapatkan data dan menghitung jumlah.
    final allOrdersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjualan'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: allOrdersAsync.when(
            data: (orders) {
              // Hitung jumlah untuk setiap status dari data yang ada.
              final counts = {
                'all': orders.length,
                'success': orders.where((o) => o.status.toLowerCase() == 'success').length,
                'cancelled': orders.where((o) => o.status.toLowerCase() == 'cancelled').length,
              };
              return _statuses.map((status) {
                final label = _statusLabels[status] ?? status.toUpperCase();
                final count = counts[status] ?? 0;
                return Tab(text: '$label ($count)');
              }).toList();
            },
            // Saat loading atau error, tampilkan tab tanpa jumlah.
            loading: () => _statuses.map((status) => Tab(text: _statusLabels[status] ?? status.toUpperCase())).toList(),
            error: (e, s) => _statuses.map((status) => Tab(text: _statusLabels[status] ?? status.toUpperCase())).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // PERBAIKAN: Setiap tab sekarang akan menerima status dan memfilter datanya sendiri.
        children: _statuses.map((status) {
          return OrderListTab(status: status);
        }).toList(),
      ),
    );
  }
}

// Widget terpisah untuk konten setiap tab.
class OrderListTab extends ConsumerWidget {
  final String status;
  const OrderListTab({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERBAIKAN: Widget ini juga memantau `allOrdersProvider`.
    final allOrdersAsync = ref.watch(allOrdersProvider);

    return allOrdersAsync.when(
      data: (allOrders) {
        // Filter pesanan berdasarkan status yang diterima widget ini.
        final List<Order> filteredOrders;
        if (status == 'all') {
          filteredOrders = allOrders;
        } else {
          filteredOrders = allOrders.where((order) => order.status.toLowerCase() == status).toList();
        }

        if (filteredOrders.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan dengan status ini.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            // PERBAIKAN: Menggunakan provider yang benar untuk invalidasi.
            ref.invalidate(allOrdersProvider);
            await ref.read(allOrdersProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              return OrderCard(order: filteredOrders[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Gagal memuat pesanan: $e'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => ref.invalidate(allOrdersProvider),
                child: const Text('Coba Lagi'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
