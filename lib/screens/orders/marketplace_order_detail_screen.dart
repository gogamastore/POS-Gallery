import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_chat_service.dart';
import '../../services/biteship_service.dart';
import '../../services/marketplace_order_actions.dart';
import '../../services/order_service.dart';
import '../../widgets/marketplace_order_badges.dart';
import '../chat/admin_chat_screen.dart';
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
  final _chatService = AdminChatService();
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
      // Kunci modal (purchasePrice) tiap produk saat pesanan diproses untuk
      // dikirim → laporan penjualan pakai modal ini, akurat & tak berubah oleh
      // restok. Idempoten: bila sudah punya snapshot, tidak menimpa.
      await OrderService().snapshotPurchasePrices(widget.orderId);
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

  // ── Hubungi Pembeli (Obrolan / WhatsApp) ──────────────────────
  // WhatsApp diambil dari profil user (user/{customerId}.whatsapp) yang sudah
  // diverifikasi pembeli — BUKAN dari customerDetails pesanan.
  String _statusLabel(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return 'Menunggu Pembayaran';
    if (s == 'processing') return 'Perlu Dikirim';
    if (s == 'shipped' || s == 'dikirim') return 'Dalam Pengiriman';
    if (s == 'delivered' || s == 'selesai') return 'Pesanan Selesai';
    if (s == 'cancelled' || s == 'dibatalkan') return 'Pesanan Dibatalkan';
    return status;
  }

  void _showContactSheet(Map<String, dynamic> data) {
    final details = (data['customerDetails'] as Map<String, dynamic>?) ?? {};
    final customerId =
        (data['customerId'] ?? data['userId'] ?? '').toString();
    final buyerName = (details['name'] as String?) ??
        data['customer'] as String? ??
        'Pembeli';
    if (customerId.isEmpty || customerId == 'guest') {
      _snack('Pesanan tanpa akun pembeli (guest), tidak bisa dihubungi.',
          error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Hubungi Pembeli',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.chat_bubble_outline,
                    color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Obrolan'),
              subtitle: const Text('Balas chat pembeli di aplikasi'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      AdminChatScreen(userId: customerId, title: buyerName),
                ));
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: 0.12),
                child: const Icon(Icons.chat, color: Colors.green),
              ),
              title: const Text('WhatsApp'),
              subtitle: const Text('Nomor WhatsApp terverifikasi pembeli'),
              onTap: () {
                Navigator.pop(ctx);
                _contactViaWhatsapp(customerId, buyerName, data);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _contactViaWhatsapp(
      String customerId, String buyerName, Map<String, dynamic> data) async {
    final profile = await _chatService.fetchBuyerProfile(customerId);
    if (!mounted) return;
    final wa = profile?.whatsapp ?? '';
    if (wa.isEmpty) {
      _snack('Pembeli belum memiliki WhatsApp terverifikasi.', error: true);
      return;
    }
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final id = widget.orderId;
    final shortId =
        id.substring(0, id.length < 8 ? id.length : 8).toUpperCase();
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final status = data['status'] as String? ?? 'pending';
    final text = 'Halo $buyerName, ini admin Manafidh Store 👋\n\n'
        'Kami menghubungi Anda terkait pesanan #$shortId.\n'
        'Total: ${_currency.format(total)}\n'
        'Status: ${_statusLabel(status)}\n\n';
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack('Tidak dapat membuka WhatsApp.', error: true);
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
    // Berat total pesanan = Σ (weightGram × qty). Fallback 200gr/produk bila
    // beratnya belum diisi — sama seperti perhitungan ongkir di checkout.
    final totalWeightGram = products.fold<int>(0, (acc, p) {
      final m = p as Map;
      final w = (m['weightGram'] as num?)?.toInt() ?? 0;
      final q = (m['quantity'] as num?)?.toInt() ?? 0;
      return acc + (w > 0 ? w : 200) * q;
    });
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final shippingFee = (data['shippingFee'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final voucherDiscount = (data['voucherDiscount'] as num?)?.toDouble() ?? 0;
    final voucherCode = data['voucherCode'] as String?;
    final adminFee = (data['adminFee'] as num?)?.toDouble() ?? 0;
    final serviceFee = (data['serviceFee'] as num?)?.toDouble() ?? 0;
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
                if (voucherDiscount > 0)
                  _row(
                    'Voucher${voucherCode != null ? ' ($voucherCode)' : ''}',
                    '- ${_currency.format(voucherDiscount)}',
                    valueColor: Colors.green,
                  ),
                if (adminFee > 0)
                  _row('Biaya Admin', _currency.format(adminFee)),
                if (serviceFee > 0)
                  _row('Biaya Layanan', _currency.format(serviceFee)),
                _row('Berat Total Pesanan', '$totalWeightGram gram'),
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

        // Bar aksi bawah — "Hubungi" selalu ada; aksi lain sesuai status.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showContactSheet(data),
                    icon: const Icon(Icons.headset_mic_outlined),
                    label: const Text('Hubungi'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                if (canShip || canValidate || canCancel) ...[
                  const SizedBox(height: 10),
                  Row(
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
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
                            icon:
                                const Icon(Icons.fact_check_outlined, size: 18),
                            label: const Text('Validasi Pesanan'),
                          ),
                        ),
                      ],
                    ],
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

  Widget _row(String label, String value, {bool bold = false, Color? valueColor}) => Padding(
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
                      color: valueColor,
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: bold ? 15 : 13)),
            ),
          ],
        ),
      );
}