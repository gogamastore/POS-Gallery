import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart' as models;
import '../../models/order_item.dart';
import '../../models/user_model.dart';
import '../../providers/shift_provider.dart' show cashiersProvider;
import '../../services/midtrans_service.dart';
import '../../services/order_service.dart';
import '../pos/midtrans_payment_screen.dart';
import 'print_page_screen.dart';

/// Ringkasan hasil validasi → konfirmasi & proses.
///
/// Memakai [OrderService.updateOrderDetails] (rekonsiliasi stok delta
/// `increment(oldQty - newQty)` + tulis produk/total/`kasir`) lalu set status.
/// Kasir/validator WAJIB dipilih dari daftar user role 'admin' (disimpan sebagai
/// `kasir` + `cashierId`). Pembayaran: Cash / Transfer Bank (tandai lunas) atau
/// Midtrans (QRIS) — membuat transaksi Snap QRIS-only lalu menunggu webhook.
class MarketplaceValidationSummaryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MarketplaceValidationSummaryScreen> createState() =>
      _MarketplaceValidationSummaryScreenState();
}

class _MarketplaceValidationSummaryScreenState
    extends ConsumerState<MarketplaceValidationSummaryScreen> {
  final _orderService = OrderService();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _processing = false;

  // Kasir/validator yang dipilih (wajib) dari daftar role 'admin'.
  UserModel? _selectedCashier;

  // Metode pembayaran (hanya relevan bila pesanan belum lunas):
  // cash / bank_transfer (tandai lunas) atau midtrans (Midtrans QRIS).
  String _paymentMethod = 'cash';

  /// Sudah lunas? (paid/settlement/lunas). Jika ya, pilihan metode pembayaran
  /// tidak ditampilkan dan status pembayaran tidak diubah.
  bool get _isPaid => ['paid', 'settlement', 'lunas']
      .contains(widget.paymentStatus.toLowerCase());

  // Voucher & biaya dari dokumen order ASLI — dipertahankan saat validasi agar
  // total tetap konsisten (tidak menghapus potongan/biaya dari pesanan pembeli).
  double _voucherDiscount = 0;
  String? _voucherCode;
  double _adminFee = 0;
  double _serviceFee = 0;

  double get _subtotal => widget.validatedItems
      .fold(0.0, (total, i) => total + i.price * i.quantity);
  double get _total =>
      _subtotal + widget.shippingFee - _voucherDiscount + _adminFee + _serviceFee;

  @override
  void initState() {
    super.initState();
    _loadOrderExtras();
  }

  /// Ambil voucher & biaya dari dokumen order asli agar tetap disertakan di
  /// total & ringkasan validasi.
  Future<void> _loadOrderExtras() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final d = snap.data();
      if (d != null && mounted) {
        setState(() {
          _voucherDiscount = (d['voucherDiscount'] as num?)?.toDouble() ?? 0;
          _voucherCode = d['voucherCode'] as String?;
          _adminFee = (d['adminFee'] as num?)?.toDouble() ?? 0;
          _serviceFee = (d['serviceFee'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {
      // diamkan — biaya/voucher opsional
    }
  }

  Future<void> _confirm() async {
    final cashier = _selectedCashier;
    if (cashier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih kasir/validator terlebih dahulu.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _processing = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final bool isMidtrans = !_isPaid && _paymentMethod == 'midtrans';

    try {
      // 1. Rekonsiliasi stok (delta) + tulis produk/total/kasir.
      await _orderService.updateOrderDetails(
        widget.orderId,
        widget.validatedItems,
        _subtotal,
        _total,
        validatorName: cashier.name,
      );

      if (isMidtrans) {
        // Validasi DULU tanpa menandai lunas/selesai (status tetap 'Processing').
        // Kunci modal + catat validatedAt, cashierId, metode 'midtrans'.
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({
          'validatedAt': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'cashierId': cashier.uid,
          'paymentMethod': 'midtrans',
        });
        await _orderService.snapshotPurchasePrices(widget.orderId);

        // Buat transaksi Midtrans QRIS-only lalu buka layar pembayaran.
        // Webhook menandai lunas; layar pembayaran men-set status 'Delivered'.
        final redirectUrl = await MidtransService()
            .createSnapTransaction(widget.orderId, qrisOnly: true);
        if (!mounted) return;
        await navigator.push(MaterialPageRoute(
          builder: (_) => MidtransPaymentScreen(
            orderId: widget.orderId,
            redirectUrl: redirectUrl,
            totalAmount: _total,
            cancelOrderOnExit: false,
            completeStatusOnPaid: 'Delivered',
          ),
        ));
        // Lunas → layar pembayaran lanjut ke struk (layar ini ikut tertutup).
        // Batal/tutup → kembali ke sini, kasir bisa pilih metode lain.
        if (mounted) setState(() => _processing = false);
        return;
      }

      // 2. Non-Midtrans (cash/transfer, atau sudah lunas): langsung selesai.
      await _orderService.updateOrderStatus(widget.orderId, 'Delivered');

      final Map<String, dynamic> extra = {
        'validatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'cashierId': cashier.uid,
      };
      if (!_isPaid) {
        extra['paymentStatus'] = 'paid';
        extra['paymentMethod'] = _paymentMethod;
      }
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update(extra);

      await _orderService.snapshotPurchasePrices(widget.orderId);

      messenger.showSnackBar(const SnackBar(
        content: Text('Pesanan berhasil divalidasi & diselesaikan.'),
        backgroundColor: Colors.green,
      ));

      // Lanjut ke halaman cetak struk/label (seperti alur POS). Ambil order
      // terbaru dari Firestore agar PrintPageScreen punya data lengkap.
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .get();
        if (doc.exists && mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  PrintPageScreen(order: models.Order.fromFirestore(doc)),
            ),
            (route) => route.isFirst,
          );
          return;
        }
      } catch (_) {
        // Gagal memuat untuk cetak — cukup kembali ke daftar.
      }
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
                const Text('Kasir / Validator *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCashierDropdown(),
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
                if (_voucherDiscount > 0)
                  _totalRow(
                    'Voucher${_voucherCode != null ? ' ($_voucherCode)' : ''}',
                    -_voucherDiscount,
                    valueColor: Colors.green,
                  ),
                if (_adminFee > 0) _totalRow('Biaya Admin', _adminFee),
                if (_serviceFee > 0) _totalRow('Biaya Layanan', _serviceFee),
                _totalRow('Total', _total, bold: true),

                // Metode pembayaran — hanya bila pesanan BELUM lunas
                // (mis. COD/Unpaid). Bila sudah 'paid', bagian ini disembunyikan.
                if (!_isPaid) ...[
                  const SizedBox(height: 20),
                  const Text('Metode Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final m in const [
                    ('cash', 'Cash / Tunai'),
                    ('bank_transfer', 'Transfer Bank'),
                    ('midtrans', 'Midtrans (QRIS)'),
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
                  if (_paymentMethod == 'midtrans')
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        'Pembeli membayar via QRIS. Layar pembayaran menunggu '
                        'konfirmasi otomatis dari Midtrans.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
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
                  onPressed: (_processing || _selectedCashier == null)
                      ? null
                      : _confirm,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(!_isPaid && _paymentMethod == 'midtrans'
                          ? Icons.qr_code
                          : Icons.check_circle),
                  label: Text(!_isPaid && _paymentMethod == 'midtrans'
                      ? 'Proses & Bayar QRIS'
                      : 'Konfirmasi & Proses'),
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

  Widget _buildCashierDropdown() {
    final cashiersAsync = ref.watch(cashiersProvider);
    return cashiersAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
        child: Text('Memuat daftar kasir...'),
      ),
      error: (e, _) => InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.error_outline, color: Colors.red),
        ),
        child: Text('Gagal memuat kasir: $e'),
      ),
      data: (cashiers) {
        if (cashiers.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_off_outlined),
            ),
            child: Text('Tidak ada user ber-role admin.'),
          );
        }
        // Jaga agar nilai terpilih tetap valid bila daftar berubah.
        final selectedUid = _selectedCashier?.uid;
        final valid =
            cashiers.any((c) => c.uid == selectedUid) ? selectedUid : null;
        return DropdownButtonFormField<String>(
          initialValue: valid,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            hintText: 'Pilih kasir yang memvalidasi',
          ),
          items: cashiers
              .map((c) => DropdownMenuItem<String>(
                    value: c.uid,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (uid) => setState(() {
            _selectedCashier =
                cashiers.firstWhere((c) => c.uid == uid);
          }),
        );
      },
    );
  }

  Widget _totalRow(String label, double value,
          {bool bold = false, Color? valueColor}) =>
      Padding(
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
                    color: valueColor,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}
