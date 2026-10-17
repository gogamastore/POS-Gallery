import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/biteship_service.dart';
import '../../services/marketplace_order_actions.dart';
import '../../widgets/marketplace_order_badges.dart';
import 'marketplace_order_detail_screen.dart';

/// Halaman "Pesanan" — pesanan MARKETPLACE (`orders` dengan
/// `source == 'marketplace'`): dari web reseller & aplikasi pembeli, memakai
/// pengiriman Biteship & pembayaran Midtrans. Cerminan web `dashboard/orders`.
class MarketplaceOrdersScreen extends StatefulWidget {
  const MarketplaceOrdersScreen({super.key});

  @override
  State<MarketplaceOrdersScreen> createState() =>
      _MarketplaceOrdersScreenState();
}

class _MarketplaceOrdersScreenState extends State<MarketplaceOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _biteship = BiteshipService();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String? _processingId;

  // Filter tanggal (default 1 bulan terahir) + pencarian — meniru web.
  final _searchController = TextEditingController();
  String _searchTerm = '';
  DateTimeRange? _dateRange;

  static const _tabs = [
    'Belum Bayar',
    'Perlu Dikirim',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Default: 1 bulan terakhir (30 hari), semua status.
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30)),
      end: now,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      FirebaseFirestore.instance
          .collection('orders')
          .where('source', isEqualTo: 'marketplace')
          .orderBy('date', descending: true)
          .snapshots();

  // ── Klasifikasi per-tab (meniru web) ─────────────────────────────────
  bool _isToProcess(Map<String, dynamic> d) =>
      (d['paymentStatus'] as String? ?? '') == 'pending_payment';

  bool _isToShip(Map<String, dynamic> d) =>
      ['processing'].contains((d['status'] as String? ?? '').toLowerCase());

  bool _isShipped(Map<String, dynamic> d) {
    final s = (d['status'] as String? ?? '').toLowerCase();
    final pay = (d['paymentStatus'] as String? ?? '').toLowerCase();
    return ['shipped', 'dikirim'].contains(s) &&
        !['cancelled', 'failed'].contains(pay);
  }

  bool _isDelivered(Map<String, dynamic> d) =>
      ['delivered', 'selesai']
          .contains((d['status'] as String? ?? '').toLowerCase());

  bool _isCancelled(Map<String, dynamic> d) {
    final s = (d['status'] as String? ?? '').toLowerCase();
    final pay = (d['paymentStatus'] as String? ?? '').toLowerCase();
    return ['cancelled', 'failed'].contains(pay) ||
        ['cancelled', 'dibatalkan'].contains(s);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _forTab(
    int index,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) {
    bool Function(Map<String, dynamic>) test = switch (index) {
      0 => _isToProcess,
      1 => _isToShip,
      2 => _isShipped,
      3 => _isDelivered,
      _ => _isCancelled,
    };
    return all.where((d) => test(d.data())).toList();
  }

  // ── Filter tanggal + pencarian (diterapkan sebelum klasifikasi tab) ──
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) {
    final q = _searchTerm.trim().toLowerCase();
    return all.where((doc) {
      final d = doc.data();

      if (_dateRange != null) {
        final ts = d['date'];
        if (ts is! Timestamp) return false;
        final dt = ts.toDate();
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month,
            _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month,
            _dateRange!.end.day, 23, 59, 59, 999);
        if (dt.isBefore(start) || dt.isAfter(end)) return false;
      }

      if (q.isNotEmpty) {
        final details = (d['customerDetails'] as Map<String, dynamic>?) ?? {};
        final name = ((details['name'] as String?) ??
                (d['customer'] as String?) ??
                '')
            .toLowerCase();
        if (!name.contains(q) && !doc.id.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  // ── Aksi ─────────────────────────────────────────────────────────────
  Future<void> _shipOrder(String orderId) async {
    setState(() => _processingId = orderId);
    try {
      final res = await _biteship.createOrder(orderId);
      if (!mounted) return;
      final resi = res.waybillId?.isNotEmpty == true
          ? 'Resi: ${res.waybillId}'
          : 'Driver sedang dicari.';
      _snack('Pengiriman diproses. $resi');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) _snack(e.message ?? 'Gagal memproses pengiriman.', error: true);
    } catch (e) {
      if (mounted) _snack('Gagal memproses pengiriman.', error: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final ok = await _confirm(
      'Batalkan Pesanan',
      'Pesanan dibatalkan dan stok dikembalikan. Lanjutkan?',
    );
    if (ok != true) return;
    setState(() => _processingId = orderId);
    try {
      await MarketplaceOrderActions.cancelAndRestoreStock(orderId);
      if (mounted) _snack('Pesanan dibatalkan & stok dikembalikan.');
    } catch (e) {
      if (mounted) _snack('Gagal membatalkan pesanan.', error: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _openDetail(String orderId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketplaceOrderDetailScreen(orderId: orderId),
    ));
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final all = snapshot.data?.docs ?? [];
        // Terapkan filter tanggal + pencarian sebelum klasifikasi tab, agar
        // jumlah (count) tiap tab ikut mencerminkan hasil filter.
        final filtered = _applyFilters(all);
        final counts =
            List.generate(_tabs.length, (i) => _forTab(i, filtered).length);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pesanan'),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (var i = 0; i < _tabs.length; i++)
                  Tab(text: '${_tabs[i]} (${counts[i]})'),
              ],
            ),
          ),
          body: snapshot.hasError
              ? _ErrorView(message: snapshot.error.toString())
              : snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _buildFilterBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              for (var i = 0; i < _tabs.length; i++)
                                i == 1
                                    ? _buildToShipTab(_forTab(1, filtered))
                                    : _buildList(_forTab(i, filtered)),
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  // Tab "Perlu Dikirim": ringkasan pendapatan (tanpa ongkir) + total ongkir
  // dari SEMUA pesanan di tab ini tanpa melihat status bayar — pengiriman
  // Biteship sudah pasti dibayar di muka, sedangkan "Ambil di Tempat" tetap
  // dihitung meski COD (kas ditagih saat barang diambil).
  Widget _buildToShipTab(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double revenue = 0;
    double shipping = 0;
    for (final doc in docs) {
      final d = doc.data();
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      final ship = (d['shippingFee'] as num?)?.toDouble() ?? 0;
      shipping += ship;
      final rev = total - ship;
      revenue += rev < 0 ? 0 : rev;
    }
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final theme = Theme.of(context);

    Widget card(String title, String sub, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              card('Pendapatan', '(semua pesanan, tanpa ongkir)',
                  currency.format(revenue), Icons.payments, theme.colorScheme.primary),
              const SizedBox(width: 10),
              card('Total Ongkir', '(semua pesanan perlu dikirim)',
                  currency.format(shipping), Icons.local_shipping, Colors.cyan[700]!),
            ],
          ),
        ),
        Expanded(child: _buildList(docs)),
      ],
    );
  }

  Widget _buildFilterBar() {
    final df = DateFormat('dd MMM yyyy', 'id_ID');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchTerm = v),
            decoration: InputDecoration(
              hintText: 'Cari No. Pesanan / Nama...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateRange == null
                        ? 'Semua tanggal'
                        : '${df.format(_dateRange!.start)} - ${df.format(_dateRange!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_dateRange != null)
                TextButton(
                  onPressed: () => setState(() => _dateRange = null),
                  child: const Text('Semua'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('Tidak ada pesanan'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _OrderCard(
          doc: doc,
          currency: _currency,
          processing: _processingId == doc.id,
          onDetail: () => _openDetail(doc.id),
          onShip: () => _shipOrder(doc.id),
          onCancel: () => _cancelOrder(doc.id),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final NumberFormat currency;
  final bool processing;
  final VoidCallback onDetail;
  final VoidCallback onShip;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.doc,
    required this.currency,
    required this.processing,
    required this.onDetail,
    required this.onShip,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final details = (data['customerDetails'] as Map<String, dynamic>?) ?? {};
    final customer = (details['name'] as String?) ??
        data['customer'] as String? ??
        'N/A';
    final status = data['status'] as String? ?? 'pending';
    final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final shippingMethod = data['shippingMethod'] as String? ?? '';
    final products = (data['products'] as List?) ?? [];
    final date = data['date'];
    final dateText = date is Timestamp
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date.toDate())
        : '-';

    final statusLower = status.toLowerCase();
    final courierCode = data['biteshipCourierCode'] as String?;
    final isCourier = courierCode != null && courierCode.isNotEmpty;
    // Di status Processing (Perlu Dikirim): kurir → Proses Pesanan (Biteship),
    // non-kurir (COD/Ambil di Tempat) → Validasi Pesanan → Delivered.
    final canShip = isCourier && statusLower == 'processing';
    final canValidate = !isCourier && statusLower == 'processing';
    final canCancel =
        paymentStatus == 'pending_payment' || statusLower == 'processing';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(customer,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                  OrderStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '#${doc.id.substring(0, doc.id.length < 8 ? doc.id.length : 8)} · $dateText',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '${products.length} produk'
                '${shippingMethod.isNotEmpty ? ' · $shippingMethod' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PaymentStatusBadge(status: paymentStatus),
                  const Spacer(),
                  Text(currency.format(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (canShip || canValidate || canCancel) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canCancel)
                      TextButton(
                        onPressed: processing ? null : onCancel,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Batalkan'),
                      ),
                    if (canShip) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: processing ? null : onShip,
                        icon: processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.local_shipping, size: 18),
                        label: const Text('Proses Pesanan'),
                      ),
                    ],
                    // Non-kurir → buka detail untuk validasi (scan/konfirmasi).
                    if (canValidate) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onDetail,
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('Validasi Pesanan'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    // Firestore butuh composite index untuk where(source)+orderBy(date).
    final needsIndex = message.contains('index');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              needsIndex
                  ? 'Perlu membuat index Firestore.\nBuka tautan di log/console Firebase untuk membuatnya.'
                  : 'Gagal memuat pesanan',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
