import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/date_utils.dart';

// ─── Model ──────────────────────────────────────────────────────────
class StockAdjustmentEntry {
  final String id;
  final DateTime date;
  final String productName;
  final String sku;
  final String type; // 'in' | 'out'
  final int quantity;
  final int previousStock;
  final int newStock;
  final String reason;
  final String adjustedBy;

  StockAdjustmentEntry({
    required this.id,
    required this.date,
    required this.productName,
    required this.sku,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.adjustedBy,
  });

  bool get isIn => type == 'in';
}

// Kelompok penyesuaian per hari (untuk daftar ringkas di layar utama).
class _DayGroup {
  final DateTime date;
  final List<StockAdjustmentEntry> items;
  _DayGroup(this.date, this.items);

  int get count => items.length;
  int get totalIn =>
      items.where((e) => e.isIn).fold<int>(0, (s, e) => s + e.quantity);
  int get totalOut =>
      items.where((e) => !e.isIn).fold<int>(0, (s, e) => s + e.quantity);
}

// ─── Filter cepat ───────────────────────────────────────────────────
DateTimeRange rangeForQuickFilter(String key) {
  final now = DateTime.now();
  switch (key) {
    case 'today':
      return DateTimeRange(start: startOfDay(now), end: endOfDay(now));
    case 'yesterday':
      final y = now.subtract(const Duration(days: 1));
      return DateTimeRange(start: startOfDay(y), end: endOfDay(y));
    case 'thisWeek':
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(start: startOfDay(monday), end: endOfDay(now));
    case 'thisMonth':
    default:
      return DateTimeRange(
          start: startOfDay(DateTime(now.year, now.month, 1)),
          end: endOfDay(now));
  }
}

// ─── Providers ──────────────────────────────────────────────────────
final stockAdjQuickFilterProvider = StateProvider<String>((ref) => 'thisMonth');

// Nama unik agar tak bentrok dengan provider rentang tanggal laporan lain.
final stockAdjDateRangeProvider =
    StateProvider<DateTimeRange>((ref) => rangeForQuickFilter('thisMonth'));

final stockAdjustmentReportProvider =
    StreamProvider.family<List<StockAdjustmentEntry>, DateTimeRange>(
        (ref, range) {
  final db = FirebaseFirestore.instance;
  // REALTIME: dengarkan snapshots agar laporan langsung memperbarui saat ada
  // penyesuaian baru (tanpa perlu menutup aplikasi). Rentang cukup pada
  // `createdAt` (single-field range + orderBy field sama → tanpa indeks
  // gabungan).
  return db
      .collection('stock_adjustments')
      .where('createdAt', isGreaterThanOrEqualTo: range.start)
      .where('createdAt', isLessThanOrEqualTo: range.end)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
    // Catatan lama tak menyimpan productName/sku → ambil dari koleksi products
    // berdasarkan productId agar daftar tetap menampilkan nama produk.
    final missingIds = <String>{};
    for (final d in snapshot.docs) {
      final data = d.data();
      final pname = (data['productName'] ?? '').toString().trim();
      final pid = (data['productId'] ?? '').toString();
      if (pname.isEmpty && pid.isNotEmpty) missingIds.add(pid);
    }
    final productInfo = <String, Map<String, String>>{};
    await Future.wait(missingIds.map((pid) async {
      try {
        final pd = await db.collection('products').doc(pid).get();
        if (pd.exists) {
          final pdata = pd.data()!;
          productInfo[pid] = {
            'name': (pdata['name'] ?? '').toString(),
            'sku': (pdata['sku'] ?? '').toString(),
          };
        }
      } catch (_) {/* abaikan */}
    }));

    int toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final ts = data['createdAt'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      final pid = (data['productId'] ?? '').toString();
      final info = productInfo[pid];
      final pname = (data['productName'] ?? '').toString().trim();
      final name = pname.isNotEmpty
          ? pname
          : ((info?['name'] ?? '').isNotEmpty ? info!['name']! : 'Produk');
      final skuRaw = (data['sku'] ?? '').toString().trim();
      final sku = skuRaw.isNotEmpty ? skuRaw : (info?['sku'] ?? '');
      return StockAdjustmentEntry(
        id: doc.id,
        date: date,
        productName: name,
        sku: sku,
        type: data['type'] == 'out' ? 'out' : 'in',
        quantity: toInt(data['quantity']),
        previousStock: toInt(data['previousStock']),
        newStock: toInt(data['newStock']),
        reason: (data['reason'] ?? '').toString(),
        adjustedBy: (data['adjustedBy'] ?? '').toString(),
      );
    }).toList();
  });
});

// ─── Layar utama: hanya daftar HARI ─────────────────────────────────
class StockAdjustmentReportScreen extends ConsumerWidget {
  const StockAdjustmentReportScreen({super.key});

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(stockAdjDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(stockAdjQuickFilterProvider.notifier).state = 'custom';
      ref.read(stockAdjDateRangeProvider.notifier).state = DateTimeRange(
        start: startOfDay(picked.start),
        end: endOfDay(picked.end),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(stockAdjDateRangeProvider);
    final quick = ref.watch(stockAdjQuickFilterProvider);
    final async = ref.watch(stockAdjustmentReportProvider(range));
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penyesuaian Stok')),
      body: async.when(
        data: (entries) {
          final count = entries.length;
          final totalIn =
              entries.where((e) => e.isIn).fold<int>(0, (s, e) => s + e.quantity);
          final totalOut = entries
              .where((e) => !e.isIn)
              .fold<int>(0, (s, e) => s + e.quantity);

          // Kelompokkan per hari (terbaru dulu).
          final Map<String, List<StockAdjustmentEntry>> byDay = {};
          for (final e in entries) {
            final key = DateFormat('yyyy-MM-dd').format(e.date);
            byDay.putIfAbsent(key, () => []).add(e);
          }
          final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
          final groups =
              dayKeys.map((k) => _DayGroup(byDay[k]!.first.date, byDay[k]!));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuickFilters(context, ref, quick),
              const SizedBox(height: 8),
              _buildDateFilter(context, ref, theme, range, quick),
              const SizedBox(height: 16),
              _buildSummary(theme, nf, count, totalIn, totalOut),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text('Tidak ada penyesuaian stok pada periode ini.'),
                  ),
                )
              else
                ...groups.map((g) => _buildDayTile(context, theme, nf, g)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildQuickFilters(
      BuildContext context, WidgetRef ref, String active) {
    const chips = [
      ['today', 'Hari Ini'],
      ['yesterday', 'Kemarin'],
      ['thisWeek', 'Minggu Ini'],
      ['thisMonth', 'Bulan Ini'],
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        final key = c[0];
        return ChoiceChip(
          label: Text(c[1]),
          selected: active == key,
          onSelected: (_) {
            ref.read(stockAdjQuickFilterProvider.notifier).state = key;
            ref.read(stockAdjDateRangeProvider.notifier).state =
                rangeForQuickFilter(key);
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateFilter(BuildContext context, WidgetRef ref, ThemeData theme,
      DateTimeRange range, String quick) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${DateFormat('dd MMM yyyy', 'id_ID').format(range.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(range.end)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _selectDateRange(context, ref),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Ubah'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
      ThemeData theme, NumberFormat nf, int count, int totalIn, int totalOut) {
    return Row(
      children: [
        _summaryCard(theme, 'Penyesuaian', nf.format(count),
            theme.colorScheme.primary),
        const SizedBox(width: 12),
        _summaryCard(theme, 'Stok Masuk', '+${nf.format(totalIn)}', Colors.green),
        const SizedBox(width: 12),
        _summaryCard(theme, 'Stok Keluar', '-${nf.format(totalOut)}', Colors.red),
      ],
    );
  }

  Widget _summaryCard(ThemeData theme, String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Satu baris = satu HARI. Ketuk untuk membuka halaman rincian produk.
  Widget _buildDayTile(
      BuildContext context, ThemeData theme, NumberFormat nf, _DayGroup g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withAlpha(26),
          child: Icon(Icons.calendar_today,
              color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(g.date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${g.count} penyesuaian'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+${nf.format(g.totalIn)}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('-${nf.format(g.totalOut)}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StockAdjustmentDayScreen(date: g.date, items: g.items),
            ),
          );
        },
      ),
    );
  }
}

// ─── Halaman rincian satu hari ──────────────────────────────────────
class StockAdjustmentDayScreen extends StatelessWidget {
  final DateTime date;
  final List<StockAdjustmentEntry> items;

  const StockAdjustmentDayScreen(
      {super.key, required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern('id_ID');
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('dd MMM yyyy', 'id_ID').format(date)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${items.length} penyesuaian',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ...items.map((e) => buildAdjustmentEntryCard(theme, nf, e)),
        ],
      ),
    );
  }
}

// Kartu rincian satu penyesuaian (dipakai halaman rincian per hari).
Widget buildAdjustmentEntryCard(
    ThemeData theme, NumberFormat nf, StockAdjustmentEntry e) {
  final color = e.isIn ? Colors.green : Colors.red;
  final hasStockInfo = !(e.previousStock == 0 && e.newStock == 0);
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (e.sku.isNotEmpty)
                      Text('SKU: ${e.sku}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.isIn ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14, color: color),
                    const SizedBox(width: 2),
                    Text(e.isIn ? 'Masuk' : 'Keluar',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${e.isIn ? '+' : '-'}${nf.format(e.quantity)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              if (hasStockInfo) ...[
                const SizedBox(width: 10),
                Text('${nf.format(e.previousStock)} → ${nf.format(e.newStock)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                children: [
                  const TextSpan(
                      text: 'Alasan: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: e.reason.isEmpty ? '—' : e.reason),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(e.adjustedBy.isEmpty ? '—' : e.adjustedBy,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(DateFormat('HH:mm', 'id_ID').format(e.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    ),
  );
}
