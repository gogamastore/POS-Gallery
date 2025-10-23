import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/pos_cart_item.dart';
import '../../providers/pos_provider.dart';
import 'edit_pos_cart_item_dialog.dart';
import 'process_pos_screen.dart';

class PosCartScreen extends ConsumerStatefulWidget {
  const PosCartScreen({super.key});

  @override
  PosCartScreenState createState() => PosCartScreenState();
}

class PosCartScreenState extends ConsumerState<PosCartScreen> {

  void _showEditCartItemDialog(PosCartItem item) {
    showDialog(
      context: context,
      builder: (context) => EditPosCartItemDialog(cartItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(posCartProvider);
    final totalAmount = ref.watch(posTotalProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Penjualan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: cartItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Keranjang Anda masih kosong.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tambahkan produk dari halaman penjualan.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return _buildCartItemCard(context, ref, item, currencyFormatter);
              },
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : _buildSummaryBottomBar(context, currencyFormatter.format(totalAmount)),
    );
  }

  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, PosCartItem item, NumberFormat currencyFormatter) {
    return InkWell(
      onTap: () => _showEditCartItemDialog(item),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: (item.product.image != null && item.product.image!.isNotEmpty)
                    ? Image.network(
                        item.product.image!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFE0E6ED),
                        child: const Icon(Icons.image_not_supported, color: Color(0xFFBDC3C7)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (item.product.sku != null && item.product.sku!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text('SKU: ${item.product.sku}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.quantity} x ${currencyFormatter.format(item.PosPrice)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      ref.read(posCartProvider.notifier).removeItem(item.product.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.product.name} dihapus dari keranjang.'), duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(item.subtotal),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBottomBar(BuildContext context, String formattedTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Penjualan', style: TextStyle(color: Colors.grey)),
              Text(formattedTotal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProcessPosScreen()));
            },
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Lanjutkan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
