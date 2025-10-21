import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/app_user.dart';
import '../../models/customer_order.dart';
import '../../models/order_creation_product.dart';
import '../../models/order_product.dart';
import '../../providers/order_provider.dart';

class ConfirmOrderScreen extends ConsumerStatefulWidget {
  final AppUser selectedCustomer;
  final List<OrderProduct> products;
  final double subtotal;

  const ConfirmOrderScreen({
    super.key,
    required this.selectedCustomer,
    required this.products,
    required this.subtotal,
  });

  @override
  ConsumerState<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends ConsumerState<ConfirmOrderScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _shippingFeeController;

  String _shippingMethod = 'pickup';
  String _paymentMethod = 'cod';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.selectedCustomer.name);
    _addressController = TextEditingController(text: widget.selectedCustomer.address ?? '');
    _whatsappController = TextEditingController(text: widget.selectedCustomer.whatsapp ?? '');
    _shippingFeeController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _whatsappController.dispose();
    _shippingFeeController.dispose();
    super.dispose();
  }

  double get _total {
    final shippingFee = double.tryParse(_shippingFeeController.text) ?? 0;
    return widget.subtotal + shippingFee;
  }

  Future<void> _finalizeOrder() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final List<OrderCreationProduct> productsForCreation = widget.products.map((p) {
        return OrderCreationProduct(
          productId: p.productId,
          name: p.name,
          quantity: p.quantity,
          price: p.price,
          sku: p.sku,
          imageUrl: p.imageUrl,
        );
      }).toList();

      final shippingFee = double.tryParse(_shippingFeeController.text) ?? 0.0;

      String status;
      String paymentStatus;

      if (_paymentMethod == 'cod') {
        status = 'Pending';
        paymentStatus = 'Unpaid';
      } else { // Asumsi 'bank_transfer'
        status = 'Pending';
        paymentStatus = 'Unpaid';
      }

      final finalOrder = CustomerOrder(
        customer: _nameController.text,
        customerDetails: CustomerDetails(
          name: _nameController.text,
          address: _addressController.text,
          whatsapp: _whatsappController.text,
        ),
        products: productsForCreation,
        total: _total.toInt(), // Perbaikan format Total
        shippingFee: shippingFee,
        shippingMethod: _shippingMethod == 'pickup' ? 'Ambil di Toko' : 'Pengiriman oleh Kurir',
        status: status, // Perbaikan logika status
        paymentMethod: _paymentMethod,
        paymentStatus: paymentStatus, // Perbaikan logika status pembayaran
        paymentProofUrl: null,
      );

      final success = await ref.read(orderProvider.notifier).createCustomerOrder(finalOrder.toFirestore());

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan berhasil dibuat!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan pesanan. Silakan coba lagi.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error tak terduga: $e'), backgroundColor: Colors.red),
        );
      }
      debugPrint('Error di _finalizeOrder: $e\n$s');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pesanan'),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: _finalizeOrder,
                tooltip: 'Selesaikan Pesanan'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionCard(
            title: '1. Rincian Produk',
            child: _buildProductList(currencyFormat),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '2. Detail Pelanggan',
            child: Column(
              children: [
                TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama Pelanggan')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Alamat Lengkap')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _whatsappController,
                    decoration: const InputDecoration(labelText: 'Nomor WhatsApp')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '3. Opsi Pengiriman',
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Jemput Sendiri'),
                  value: 'pickup',
                  groupValue: _shippingMethod,
                  onChanged: (value) {
                    setState(() {
                      _shippingMethod = value!;
                      _shippingFeeController.text = '0';
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Ekspedisi / Kurir'),
                  value: 'expedition',
                  groupValue: _shippingMethod,
                  onChanged: (value) => setState(() => _shippingMethod = value!),
                ),
                if (_shippingMethod == 'expedition')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      controller: _shippingFeeController,
                      decoration: const InputDecoration(
                          labelText: 'Biaya Pengiriman', prefixText: 'Rp '),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '4. Metode Pembayaran',
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Bayar di Tempat (COD)'),
                  value: 'cod',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Transfer Bank'),
                  value: 'bank_transfer',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildTotalsSummary(currencyFormat),
        ],
      ),
    );
  }

  Widget _buildProductList(NumberFormat currencyFormat) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        final product = widget.products[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl ?? '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image_not_supported),
            ),
          ),
          title: Text(product.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${product.quantity} x ${currencyFormat.format(product.price)}'),
          trailing: Text(
            currencyFormat.format(product.quantity * product.price),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSummary(NumberFormat currencyFormat) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Ringkasan Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _totalRow('Subtotal Produk', currencyFormat.format(widget.subtotal)),
            _totalRow('Biaya Kirim', currencyFormat.format(double.tryParse(_shippingFeeController.text) ?? 0)),
            const Divider(thickness: 1.5, height: 20),
            _totalRow('Grand Total', currencyFormat.format(_total), isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String title, String amount, {bool isTotal = false}) {
    final style = TextStyle(
        fontSize: isTotal ? 18 : 16,
        fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(title, style: style), Text(amount, style: style)],
      ),
    );
  }
}
