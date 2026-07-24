import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_item.dart';
import '../../services/order_service.dart';

/// Ringkasan hasil validasi → konfirmasi & proses.
///
/// Memakai [OrderService.updateOrderDetails] (rekonsiliasi stok delta
/// `increment(oldQty - newQty)` + tulis produk/total/`kasir`) lalu set status
/// 'Processing'. TIDAK menulis `validatedAt` (laporan memfilter via `source`).
class MarketplaceValidationSummaryScreen extends StatefulWidget {
  final String orderId;
  final List<OrderItem> validatedItems;
  final double shippingFee;
  final String paymentStatus;

  const MarketplaceValidationSummaryScreen({
    super.key,
    required this.orderId,
    required this.validatedItems,
    required this.shippingFee,
    required this.paymentStatus,
  });

  @override
  State<MarketplaceValidationSummaryScreen> createState() =>
      _MarketplaceValidationSummaryScreenState();
}

class _MarketplaceValidationSummaryScreenState
    extends State<MarketplaceValidationSummaryScreen> {
  final _orderService = OrderService();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late final TextEditingController _kasirController;
  bool _processing = false;

  // Metode pembayaran (hanya relevan bila pesanan belum lunas), meniru
  // process_pos_screen: cash / bank_transfer / qris.
  String _paymentMethod = 'cash';

  /// Sudah lunas? (paid/settlement/lunas). Jika ya, pilihan metode pembayaran
  /// tidak ditampilkan dan status pembayaran tidak diubah.
  bool get _isPaid => ['paid', 'settlement', 'lunas']
      .contains(widget.paymentStatus.toLowerCase());

  double get _subtotal => widget.validatedItems
      .fold(0.0, (total, i) => total + i.price * i.quantity);
  double get _total => _subtotal + widget.shippingFee;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _kasirController = TextEditingController(
        text: user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? ''));
  }

  @override
  void dispose() {
    _kasirController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final kasir = _kasirController.text.trim();
    if (kasir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nama kasir/validator wajib diisi.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _processing = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Rekonsiliasi stok (delta) + tulis produk/total/kasir.
      await _orderService.updateOrderDetails(
        widget.orderId,
        widget.validatedItems,
        _subtotal,
        _total,
        validatorName: kasir,
      );
      // 2. Non-kurir (COD / Ambil di Tempat): validasi = pesanan selesai.
      await _orderService.updateOrderStatus(widget.orderId, 'Delivered');

      // 3. Catat waktu pesanan DIPROSES (validatedAt) — dipakai laporan
      //    penjualan agar memuat pesanan yang diproses hari ini, bukan
      //    tanggal pesanan dibuat pembeli. Sekaligus catat pembayaran POS
      //    bila pesanan belum lunas.
      final Map<String, dynamic> extra = {
        'validatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (!_isPaid) {
        extra['paymentStatus'] = 'paid';
        extra['paymentMethod'] = _paymentMethod;
      }
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update(extra);

      messenger.showSnackBar(const SnackBar(
        content: Text('Pesanan berhasil divalidasi & diselesaikan.'),
        backgroundColor: Colors.green,
      ));
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Gagal memproses: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan Validasi')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Kasir / Validator',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _kasirController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Nama kasir yang memvalidasi',
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Produk Tervalidasi',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ...widget.validatedItems.map((i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('x${i.quantity}')),
                      title: Text(i.name),
                      subtitle: Text(
                          '${_currency.format(i.price)} × ${i.quantity}'),
                      trailing: Text(
                          _currency.format(i.price * i.quantity),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                const Divider(),
                _totalRow('Subtotal', _subtotal),
                _totalRow('Ongkir', widget.shippingFee),
                _totalRow('Total', _total, bold: true),

                // Metode pembayaran — hanya bila pesanan BELUM lunas
                // (mis. COD/Unpaid). Bila sudah 'paid', bagian ini disembunyikan
                // dan status pembayaran tidak diubah.
                if (!_isPaid) ...[
                  const SizedBox(height: 20),
                  const Text('Metode Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final m in const [
                    ('cash', 'Cash'),
                    ('bank_transfer', 'Bank Transfer'),
                    ('qris', 'QRIS'),
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: m.$1,
                      groupValue: _paymentMethod,
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v ?? 'cash'),
                      title: Text(m.$2),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text('Sudah Lunas',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _processing ? null : _confirm,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: const Text('Konfirmasi & Proses'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
            Text(_currency.format(value),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}
