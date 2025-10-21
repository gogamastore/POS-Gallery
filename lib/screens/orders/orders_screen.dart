import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/staff_model.dart';
import '../../providers/order_provider.dart';
import '../../models/order.dart';
import '../../services/staff_service.dart';
import './create_order_screen.dart';
import './order_detail_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilter = ref.read(orderFilterProvider);
      if (currentFilter == 'delivered' || currentFilter == 'cancelled') {
        ref.read(orderFilterProvider.notifier).state = 'pending';
      }
    });

    final ordersAsyncValue = ref.watch(orderProvider);
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, textTheme),
            _buildSearchBar(ref),
            _buildFiltersContainer(context, ref),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(orderProvider.notifier).refresh(),
                child: ordersAsyncValue.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('Terjadi Kesalahan: $err')),
                  data: (_) {
                    if (filteredOrders.isEmpty) {
                      final activeFilter = ref.watch(orderFilterProvider);
                      final searchQuery = ref.watch(orderSearchQueryProvider);
                      return _buildEmptyState(activeFilter, searchQuery);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _buildOrderCard(context, ref, order);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesanan',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola pesanan yang sedang berjalan.',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateOrderScreen(),
                ),
              );
            },
            icon: const Icon(Ionicons.add_circle, size: 32),
            tooltip: 'Buat Pesanan',
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        onChanged: (value) {
          ref.read(orderSearchQueryProvider.notifier).state = value;
        },
        decoration: InputDecoration(
          hintText: 'Cari nama, No. Pesanan, atau SKU...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF7F8C8D)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFiltersContainer(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(orderFilterProvider);
    final counts = ref.watch(orderStatusCountsProvider);

    final statusFilters = [
      {'key': 'pending', 'label': 'Belum Proses'},
      {'key': 'processing', 'label': 'Perlu Dikirim'},
      {'key': 'shipped', 'label': 'Dikirim'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statusFilters.map((filter) {
            final key = filter['key']!;
            final label = filter['label']!;
            final count = counts[key] ?? 0;
            final isActive = activeFilter == key;

            return GestureDetector(
              onTap: () => ref.read(orderFilterProvider.notifier).state = key,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF5DADE2) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive
                          ? const Color(0xFF5DADE2)
                          : const Color(0xFFE0E6ED)),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFF7F8C8D),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            isActive ? Colors.white : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF5DADE2)
                              : const Color(0xFF7F8C8D),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProcessOrderDialog(BuildContext context, WidgetRef ref, Order order) {
    final formKey = GlobalKey<FormState>();
    String? selectedAdminName;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final adminUsersAsyncValue = ref.watch(adminUsersProvider);
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Validasi Pesanan'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pilih nama Anda untuk melanjutkan proses validasi.'),
                        const SizedBox(height: 24),
                        adminUsersAsyncValue.when(
                          data: (admins) => DropdownButtonFormField<String>(
                            hint: const Text('Pilih nama...'),
                            decoration: const InputDecoration(
                              labelText: 'Di Validasi oleh',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: selectedAdminName,
                            items: admins.map<DropdownMenuItem<String>>((Staff admin) {
                              return DropdownMenuItem<String>(
                                value: admin.name,
                                child: Text(admin.name),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedAdminName = newValue;
                              });
                            },
                            validator: (value) =>
                                value == null || value.isEmpty ? 'Harap pilih nama validator' : null,
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) =>
                              Center(child: Text('Gagal memuat admin: $err')),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(orderServiceProvider).updateOrderStatus(order.id, 'processing');
                            await ref.read(orderServiceProvider).setValidationTimestamp(order.id);
                            await ref.read(orderServiceProvider).setOrderValidator(order.id, selectedAdminName!);
                            
                            navigator.pop();
                            ref.read(orderProvider.notifier).refresh();

                          } catch (e) {
                            if(navigator.canPop()){
                              navigator.pop();
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final double totalValue = double.tryParse(order.total.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(orderId: order.id),
          ),
        ).then((_) => ref.read(orderProvider.notifier).refresh());
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(25),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customer,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50)),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('No. Pesanan ${order.id}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF7F8C8D))),
                        const SizedBox(height: 2),
                        Text(
                            DateFormat('dd/MM/yy, HH:mm')
                                .format(order.date.toDate()),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF7F8C8D))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withAlpha(33),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(order.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (order.products.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...order.products.take(2).map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text('• ${p.name} (${p.quantity}x)',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF34495E),
                                    height: 1.4),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          )),
                      if (order.products.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                              '... dan ${order.products.length - 2} produk lainnya',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F8C8D),
                                  fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getPaymentStatusColor(order.paymentStatus)),
                      ),
                      const SizedBox(width: 6),
                      Text(_getPaymentStatusText(order.paymentStatus),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color:
                                  _getPaymentStatusColor(order.paymentStatus))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Pesanan',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF7F8C8D))),
                      const SizedBox(height: 2),
                      Text(currencyFormatter.format(totalValue),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50))),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(thickness: 1, height: 1),
              ),
               Row(
                children: [
                  Expanded(
                    child: _buildPaymentButton(context, ref, order),
                  ),
                  const SizedBox(width: 8),
                  if (order.status != 'pending' && order.status != 'processing' && order.status != 'shipped') 
                    const Spacer(),

                  if (order.status == 'pending' || order.status == 'processing' || order.status == 'shipped')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (order.status == 'pending') {
                          _showProcessOrderDialog(context, ref, order);
                        } else {
                          final nextStatus = order.status == 'processing' ? 'shipped' : (order.status == 'shipped' ? 'delivered' : '');
                          if (nextStatus.isNotEmpty) {
                             ref.read(orderServiceProvider).updateOrderStatus(order.id, nextStatus).then((_) {
                               ref.read(orderProvider.notifier).refresh();
                             });
                          } 
                        }
                      },
                      icon: Icon(_getButtonIcon(order.status), color: Colors.white, size: 18),
                      label: Text(_getButtonText(order.status), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(order.status),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentButton(BuildContext context, WidgetRef ref, Order order) {
    final bool isUnpaid = order.paymentStatus.toLowerCase() == 'unpaid';
    final bool hasProof =
        order.paymentProofUrl != null && order.paymentProofUrl!.isNotEmpty;

    if (isUnpaid) {
      return TextButton.icon(
        onPressed: () async {
           final scaffoldMessenger = ScaffoldMessenger.of(context);
           final navigator = Navigator.of(context);

          final bool? confirmed = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Konfirmasi Pelunasan'),
              content:
                  const Text('Apakah pesanan ini sudah benar-benar lunas?'),
              actions: [
                TextButton(
                  onPressed: () => navigator.pop(false),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () => navigator.pop(true),
                  child: const Text('Ya, Lunas',
                      style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              await ref.read(orderServiceProvider).markOrderAsPaid(order.id);
              ref.read(orderProvider.notifier).refresh();
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                    content: Text('Pesanan ditandai lunas.'),
                    backgroundColor: Colors.green),
              );
            } catch (e) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                    content: Text('Gagal memperbarui: $e'),
                    backgroundColor: Colors.red),
              );
            }
          }
        },
        icon: const Icon(Ionicons.checkmark_circle,
            color: Color(0xFF27AE60), size: 18),
        label: const Text('Tandai Lunas',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      return TextButton.icon(
        onPressed: hasProof
            ? () async {
                final Uri url = Uri.parse(order.paymentProofUrl!);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Gagal membuka URL.')),
                    );
                }
              }
            : null,
        icon: Icon(Ionicons.receipt_outline,
            color: hasProof ? const Color(0xFF3498DB) : Colors.grey, size: 18),
        label: Text('Bukti Bayar',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasProof ? const Color(0xFF3498DB) : Colors.grey)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildEmptyState(String activeFilter, String searchQuery) {
    final bool isSearching = searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Ionicons.search_outline
                  : Ionicons.file_tray_outline,
              size: 64,
              color: const Color(0xFFBDC3C7),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Tidak Ada Hasil' : 'Tidak Ada Pesanan',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Tidak ditemukan pesanan yang cocok dengan "$searchQuery".'
                  : 'Saat ini tidak ada pesanan untuk kategori \'${_getStatusText(activeFilter)}\'.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(String status) {
    switch (status) {
      case 'shipped':
        return const Color(0xFF27AE60); // Green for 'Selesai'
      default:
        return const Color(0xFF5DADE2); // Default blue
    }
  }

  IconData _getButtonIcon(String status) {
    switch (status) {
      case 'shipped':
        return Ionicons.checkmark_done_circle; 
      default:
        return Ionicons.arrow_forward_circle_outline;
    }
  }


  String _getButtonText(String status) {
    switch (status) {
      case 'pending':
        return 'Proses Pesanan';
      case 'processing':
        return 'Kirim Pesanan';
      case 'shipped':
        return 'Selesai';
      default:
        return 'Detail';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return const Color(0xFF27AE60);
      case 'shipped':
        return const Color(0xFF3498DB);
      case 'processing':
        return const Color(0xFFF39C12);
      case 'pending':
        return const Color(0xFFE74C3C);
      case 'cancelled':
        return const Color(0xFF95A5A6);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'delivered':
        return 'Selesai';
      case 'shipped':
        return 'Dikirim';
      case 'processing':
        return 'Perlu Dikirim';
      case 'pending':
        return 'Belum Proses';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return const Color(0xFF27AE60);
      case 'unpaid':
        return const Color(0xFFE74C3C);
      case 'partial':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  String _getPaymentStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return 'Lunas';
      case 'unpaid':
        return 'Belum Lunas';
      case 'partial':
        return 'Sebagian';
      default:
        return 'N/A';
    }
  }
}
