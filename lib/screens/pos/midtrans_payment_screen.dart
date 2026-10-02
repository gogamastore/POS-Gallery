import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../providers/pos_provider.dart';
import '../../services/pos_service.dart';
import '../orders/print_page_screen.dart';

/// Menunggu pembeli membayar transaksi kasir lewat Midtrans Snap.
///
/// Halaman Snap dibuka di WebView (Android) atau browser (Windows/web).
/// Layar ini TIDAK memutuskan lunas sendiri: webhook Midtrans di server
/// menuntaskan pesanan, dan layar ini memantau `orders/{id}` secara real-time.
///   paid   → kosongkan keranjang, lanjut ke struk
///   failed → kembali ke Proses Penjualan (keranjang tetap ada)
class MidtransPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String redirectUrl;
  final double totalAmount;

  const MidtransPaymentScreen({
    super.key,
    required this.orderId,
    required this.redirectUrl,
    required this.totalAmount,
  });

  @override
  ConsumerState<MidtransPaymentScreen> createState() =>
      _MidtransPaymentScreenState();
}

class _MidtransPaymentScreenState extends ConsumerState<MidtransPaymentScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String _paymentStatus = 'pending_payment';
  bool _finished = false;
  bool _isCancelling = false;

  // WebView in-app hanya didukung (dan bisa ditutup otomatis) di Android.
  bool get _usesInAppWebView =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(_onOrderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPaymentPage());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openPaymentPage() async {
    try {
      final opened = await launchUrl(
        Uri.parse(widget.redirectUrl),
        mode: _usesInAppWebView
            ? LaunchMode.inAppWebView
            : LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('URL tidak dapat dibuka');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka halaman pembayaran: $e')),
      );
    }
  }

  Future<void> _closePaymentPage() async {
    if (!_usesInAppWebView) return;
    try {
      await closeInAppWebView();
    } catch (_) {
      // WebView sudah tertutup.
    }
  }

  void _onOrderChanged(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null || _finished || !mounted) return;

    final paymentStatus = data['paymentStatus'] as String? ?? '';
    if (paymentStatus == 'paid') {
      _finished = true;
      _onPaid(Order.fromFirestore(snapshot));
    } else if (paymentStatus == 'failed') {
      _finished = true;
      _onFailed();
    } else {
      setState(() => _paymentStatus = paymentStatus);
    }
  }

  Future<void> _onPaid(Order order) async {
    ref.read(posCartProvider.notifier).clearCart();
    await _closePaymentPage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pembayaran Midtrans diterima!')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => PrintPageScreen(order: order)),
      (route) => route.isFirst,
    );
  }

  Future<void> _onFailed() async {
    await _closePaymentPage();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembayaran Gagal'),
        content: const Text(
            'Pembayaran dibatalkan, ditolak, atau melewati batas waktu. '
            'Keranjang masih tersimpan — silakan pilih metode pembayaran lain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) _leave();
  }

  /// Kembali ke Proses Penjualan, sekaligus menutup dialog yang masih terbuka.
  void _leave() {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  Future<void> _confirmCancel() async {
    if (_isCancelling || _finished) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pembayaran?'),
        content: const Text(
            'Transaksi Midtrans ini akan dibatalkan. Keranjang tetap tersimpan '
            'sehingga Anda bisa memilih metode pembayaran lain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _finished) return;

    setState(() => _isCancelling = true);
    try {
      final cancelled =
          await PosService().cancelPendingMidtransOrder(widget.orderId);
      // false = ternyata sudah lunas; stream akan membawa ke halaman struk.
      if (!cancelled || !mounted || _finished) return;
      _finished = true;
      _leave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan transaksi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final statusText = _paymentStatus == 'fraud'
        ? 'Pembayaran ditahan Midtrans untuk ditinjau. Periksa dashboard Midtrans.'
        : 'Menunggu pembeli menyelesaikan pembayaran...';
    final instructionText = _usesInAppWebView
        ? 'Tunjukkan halaman pembayaran (QRIS / Virtual Account) kepada pembeli.'
        : 'Halaman pembayaran terbuka di browser. Tunjukkan QRIS / Virtual '
            'Account kepada pembeli.';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Pembayaran Midtrans',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: const Color(0xFF2C3E50),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmCancel,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Ionicons.qr_code_outline,
                            size: 64, color: Color(0xFF27AE60)),
                        const SizedBox(height: 16),
                        const Text('Total Pembayaran',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(widget.totalAmount),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF27AE60)),
                        ),
                        const Divider(height: 32),
                        Text(statusText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text(
                          '$instructionText\nLayar ini otomatis lanjut ke struk '
                          'setelah pembayaran diterima. Batas waktu: 30 menit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.grey[400]),
                            ),
                            const SizedBox(width: 8),
                            Text('Memantau status pembayaran...',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Ionicons.open_outline),
                          label: const Text('Buka Halaman Pembayaran'),
                          onPressed: _openPaymentPage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: _isCancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Ionicons.close_circle_outline),
                          label: const Text('Batalkan Transaksi'),
                          onPressed: _isCancelling ? null : _confirmCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
