import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/biteship_service.dart';
import '../../services/marketplace_order_actions.dart';
import '../../widgets/marketplace_order_badges.dart';
import 'marketplace_order_validation_screen.dart';

/// Detail pesanan marketplace — cerminan halaman web `dashboard/orders/[id]`.
/// Real-time: mendengarkan dokumen `orders/{id}`.
class MarketplaceOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const MarketplaceOrderDetailScreen({super.key, required this.orderId});

  @override
  State<MarketplaceOrderDetailScreen> createState() =>
      _MarketplaceOrderDetailScreenState();
}

class _MarketplaceOrderDetailScreenState
    extends State<MarketplaceOrderDetailScreen> {
  final _biteship = BiteshipService();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _processing = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  Future<void> _ship() async {
    setState(() => _processing = true);
    try {
      final res = await _biteship.createOrder(widget.orderId);
      if (!mounted) return;
      _snack(res.waybillId?.isNotEmpty == true
          ? 'Pengiriman diproses. Resi: ${res.waybillId}'
          : 'Pengiriman diproses. Driver sedang dicari.');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Gagal memproses pengiriman.', error: true);
    } catch (_) {
      _snack('Gagal memproses pengiriman.', error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content:
            const Text('Pesanan dibatalkan dan stok dikembalikan. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _processing = true);
    try {
      await MarketplaceOrderActions.cancelAndRestoreStock(widget.orderId);
      _snack('Pesanan dibatalkan & stok dikembalikan.');
    } catch (_) {
      _snack('Gagal membatalkan pesanan.', error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openTracking(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Validasi pesanan non-kurir (COD / Ambil di Tempat) — buka layar validasi
  /// scan/konfirmasi qty.
  void _validate(Map<String, dynamic> data) {
    final products = ((data['products'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final shippingFee = (data['shippingFee'] as num?)?.toDouble() ?? 0;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketplaceOrderValidationScreen(
        orderId: widget.orderId,
        products: products,
        shippingFee: shippingFee,
        paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Pesanan tidak ditemukan.'));
          }
          final data = snapshot.data!.data()!;
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final details = (data['customerDetails'] as Map<String, dynamic>?) ?? {};
    final customer =
        (details['name'] as String?) ?? data['customer'] as String? ?? 'N/A';
    final address = details['address'] as String? ?? '-';
    final whatsapp = details['whatsapp'] as String? ?? '-';
    final status = data['status'] as String? ?? 'pending';
    final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';
    final paymentMethod = data['paymentMethod'] as String? ?? '-';
    final products = (data['products'] as List?) ?? [];
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final shippingFee = (data['shippingFee'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final date = data['date'];
    final dateText = date is Timestamp
        ? DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date.toDate())
        : '-';

    final courier = (data['biteshipCourierName'] as String?) ??
        data['shippingMethod'] as String? ??
        '-';
    final service = data['biteshipServiceName'] as String?;
    final waybill = data['waybillId'] as String?;
    final trackingUrl = data['trackingUrl'] as String?;

    final statusLower = status.toLowerCase();
    // Kurir bila ada kode kurir Biteship (tidak null & tidak kosong).
    final courierCode = data['biteshipCourierCode'] as String?;
    final isCourier = courierCode != null && courierCode.isNotEmpty;

    // Di tab "Perlu Dikirim" (status Processing):
    //  • Kurir     → "Proses Pesanan" (Biteship) → jadi Shipped.
    //  • Non-kurir → "Validasi Pesanan" (COD/Ambil) → jadi Delivered.
    final canShip = isCourier && statusLower == 'processing';
    final canValidate = !isCourier && statusLower == 'processing';
    final canCancel =
        paymentStatus == 'pending_payment' || statusLower == 'processing';
    final canTrack =
        ['shipped', 'dikirim'].contains(statusLower) && (trackingUrl ?? '').isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text('#${widget.orderId.substring(0, widget.orderId.length < 8 ? widget.orderId.length : 8)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  OrderStatusBadge(status: status),
                ],
              ),
              Text(dateText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              // Pelanggan
              _card('Pelanggan', [
                _row('Nama', customer),
                _row('Alamat', address),
                _row('WhatsApp', whatsapp),
              ]),

              // Produk
              _sectionTitle('Produk (${products.length})'),
              ...products.map((p) => _productTile(p as Map)),
              const SizedBox(height: 8),

              // Ringkasan
              _card('Ringkasan', [
                _row('Subtotal', _currency.format(subtotal)),
                _row('Ongkir', _currency.format(shippingFee)),
                _row('Total', _currency.format(total), bold: true),
              ]),

              // Pembayaran
              _card('Pembayaran', [
                _row('Metode', paymentMethod),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status',
                        style: TextStyle(color: Colors.grey)),
                    PaymentStatusBadge(status: paymentStatus),
                  ],
                ),
              ]),

              // Pengiriman
              _card('Pengiriman', [
                _row('Kurir', service != null ? '$courier · $service' : courier),
                if ((waybill ?? '').isNotEmpty) _row('No. Resi', waybill!),
                if (canTrack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openTracking(trackingUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Lacak Pengiriman'),
                    ),
                  ),
              ]),
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Bar aksi bawah
        if (canShip || canValidate || canCancel)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Batalkan'),
                      ),
                    ),
                  // Kurir → Proses Pesanan (Biteship)
                  if (canShip) ...[
                    if (canCancel) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processing ? null : _ship,
                        icon: _processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.local_shipping, size: 18),
                        label: const Text('Proses Pesanan'),
                      ),
                    ),
                  ],
                  // Non-kurir (COD / Ambil di Tempat) → Validasi Pesanan
                  if (canValidate) ...[
                    if (canCancel) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _processing ? null : () => _validate(data),
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('Validasi Pesanan'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _productTile(Map p) {
    final name = p['name'] as String? ?? '';
    final qty = (p['quantity'] as num?)?.toInt() ?? 0;
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    // Normalisasi: checkout web menulis imageUrl, app pembeli menulis image.
    final img = (p['imageUrl'] as String?)?.isNotEmpty == true
        ? p['imageUrl'] as String
        : (p['image'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: img.isEmpty
                    ? Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported,
                            size: 20, color: Colors.grey))
                    : Image.network(img, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image,
                                  size: 20, color: Colors.grey),
                            )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('$qty × ${_currency.format(price)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(_currency.format(price * qty),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _card(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 4, top: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: bold ? 15 : 13)),
            ),
          ],
        ),
      );
}
