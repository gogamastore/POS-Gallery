import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];

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
    final statusOrderCounts = ref.watch(orderStatusCountsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statuses.map((status) {
            final count = statusOrderCounts[status] ?? 0;
            return Tab(text: '${status.toUpperCase()} ($count)');
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) {
          return OrderListTab(status: status);
        }).toList(),
      ),
    );
  }
}

class OrderListTab extends ConsumerWidget {
  final String status;

  const OrderListTab({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsyncValue = ref.watch(ordersByStatusProvider(status));

    return ordersAsyncValue.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text('Tidak ada pesanan dengan status $status.'),
          );
        }
        return RefreshIndicator(
          // --- PERBAIKAN FINAL & PASTI BENAR: Panggil metode refresh() di Notifier ---
          onRefresh: () => ref.read(orderProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return OrderCard(order: orders[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Gagal memuat pesanan: $err')),
    );
  }
}
