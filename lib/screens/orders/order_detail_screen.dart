import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart'; // PERBAIKAN: Impor provider produk
import '../../utils/formatter.dart';
import '../pos/process_pos_screen.dart';
import 'edit_order_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  // Fungsi untuk memproses pesanan
  Future<void> _processOrder(BuildContext context, WidgetRef ref, Order order) async {
    // 1. Bersihkan keranjang yang ada
    ref.read(posCartProvider.notifier).clearCart();

    // 2. Ambil semua data produk yang relevan
    // PERBAIKAN: Menggunakan allProductsProvider dan menangani state AsyncValue
    final productsAsyncValue = ref.read(allProductsProvider);
    final allProducts = productsAsyncValue.asData?.value;

    // PERBAIKAN: Menambahkan null check
    if (allProducts == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data produk. Silakan coba lagi.')),
      );
      return;
    }

    // 3. Isi keranjang dengan item dari pesanan
    for (var orderProduct in order.products) {
      try {
        // PERBAIKAN: Menggunakan firstWhere dengan benar dan menangani error
        final product = allProducts.firstWhere((p) => p.id == orderProduct['productId']);

        // PERBAIKAN: Menggunakan addItem dengan argumen yang benar
        ref.read(posCartProvider.notifier).addItem(
              product,
              orderProduct['quantity'] as int,
              (orderProduct['price'] as num).toDouble(),
            );
      } catch (e) {
        // Tangani kasus di mana produk dari pesanan lama tidak ditemukan lagi
        print('Produk dengan ID ${orderProduct['productId']} tidak ditemukan lagi.');
        continue;
      }
    }

    // 4. Hapus pesanan lama yang statusnya 'processing'
    await ref.read(orderActionsProvider.notifier).deleteOrder(order.id!);

    // 5. PERBAIKAN: Menambahkan pengecekan 'mounted' sebelum navigasi
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ProcessPosScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailsProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          orderAsync.when(
            data: (order) => order != null
                ? IconButton(
                    icon: const Icon(Ionicons.create_outline),
                    tooltip: 'Edit Pesanan',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditOrderScreen(order: order),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          )
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pesanan tidak ditemukan.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailsProvider(orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  context,
                  title: 'Informasi Pelanggan',
                  icon: Ionicons.person_circle_outline,
                  children: [
                    _buildDetailRow(
                        'Nama', order.customerDetails?['name'] ?? 'N/A'),
                    _buildDetailRow(
                        'Alamat', order.customerDetails?['address'] ?? 'N/A'),
                    _buildWhatsAppRow(
                        context, order.customerDetails?['whatsapp']),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Detail Pesanan',
                  icon: Ionicons.receipt_outline,
                  children: [
                    _buildDetailRow(
                        'ID Pesanan', order.id?.substring(0, 8) ?? 'N/A'),
                    _buildDetailRow(
                        'Tanggal',
                        DateFormat('d MMMM y, HH:mm', 'id_ID')
                            .format(order.date.toDate())),
                    _buildDetailRow('Status', order.status),
                    _buildDetailRow('Kasir', order.kasir),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Produk Dipesan',
                  icon: Ionicons.cube_outline,
                  children: [
                    for (var product in order.products)
                      _buildProductTile(product),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Ringkasan Pembayaran',
                  icon: Ionicons.card_outline,
                  children: [
                    _buildDetailRow('Metode Pembayaran', order.paymentMethod),
                    _buildDetailRow('Status Pembayaran', order.paymentStatus),
                    const Divider(height: 20),
                    _buildTotalRow('Subtotal', formatCurrency(order.subtotal.toDouble())),
                    _buildTotalRow('Total', formatCurrency(order.total.toDouble()),
                        isTotal: true),
                  ],
                ),
                if (order.status.toLowerCase() != 'cancelled' &&
                    order.status.toLowerCase() != 'success')
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      children: [
                        if (order.status.toLowerCase() == 'processing')
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Ionicons.play_circle_outline),
                              label: const Text('Proses'),
                              onPressed: () => _processOrder(context, ref, order),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (order.status.toLowerCase() == 'processing')
                          const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Ionicons.close_circle_outline),
                            label: const Text('Batalkan'),
                            onPressed: () => _showCancelConfirmation(context, ref, order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Gagal memuat detail: $e')),
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 18 : 16,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 6 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  style.copyWith(color: isTotal ? null : Colors.grey.shade600)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> product) {
    final imageUrl = product['imageUrl'] as String?;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Ionicons.image_outline, size: 50),
                  ),
                )
              : const Icon(Ionicons.cube_outline, size: 40),
      title: Text(product['name'] ?? 'Nama Produk Tidak Ada'),
      subtitle:
          Text('${product['quantity']} x ${formatCurrency((product['price'] as num).toDouble())}'),
      trailing: Text(
        formatCurrency((product['quantity'] as int) *
            (product['price'] as num).toDouble()),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildWhatsAppRow(BuildContext context, String? whatsappNumber) {
    if (whatsappNumber == null || whatsappNumber.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('WhatsApp', style: TextStyle(color: Colors.grey.shade600)),
          TextButton.icon(
            icon: const Icon(Ionicons.logo_whatsapp, size: 18),
            label: Text(whatsappNumber),
            onPressed: () async {
              final url = Uri.parse('https://wa.me/$whatsappNumber');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          )
        ],
      ),
    );
  }

  void _showCancelConfirmation(
      BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text(
            'Apakah Anda yakin ingin membatalkan pesanan ini? Stok produk akan dikembalikan jika sebelumnya sudah dikurangi.'),
        actions: [
          TextButton(
            child: const Text('Tidak'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Ya, Batalkan'),
            onPressed: () {
              ref
                  .read(orderActionsProvider.notifier)
                  .updateOrderStatus(order.id!, 'Cancelled');
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
