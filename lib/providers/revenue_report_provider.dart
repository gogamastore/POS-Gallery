import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart' as app_order;
import 'sales_report_provider.dart' show reportServiceProvider;

// Rentang cepat untuk laporan pendapatan.
enum RevenueFilterType { today, yesterday, last7days, thisMonth, custom }

/// Filter kanal penjualan (meniru Laporan Penjualan). 'all' = default.
enum RevenueSourceFilter { all, pos, marketplace }

/// Opsi kasir untuk dropdown filter (dibangun dari order yang punya cashierId).
@immutable
class CashierOption {
  final String id;
  final String name;
  const CashierOption(this.id, this.name);
}

/// Rincian pendapatan per metode pembayaran. Menggabungkan POS + Marketplace:
///  • cash     ← 'cash' (POS tunai) + 'cod' (marketplace bayar di tempat)
///  • transfer ← 'bank_transfer'
///  • midtrans ← 'midtrans' + 'qris' (QRIS lama non-Midtrans)
///  • other    ← metode tak dikenal (ditampilkan hanya bila > 0)
@immutable
class PaymentBreakdown {
  final double cash;
  final double transfer;
  final double midtrans;
  final double other;

  const PaymentBreakdown({
    this.cash = 0,
    this.transfer = 0,
    this.midtrans = 0,
    this.other = 0,
  });

  double get total => cash + transfer + midtrans + other;

  PaymentBreakdown operator +(PaymentBreakdown o) => PaymentBreakdown(
        cash: cash + o.cash,
        transfer: transfer + o.transfer,
        midtrans: midtrans + o.midtrans,
        other: other + o.other,
      );

  /// Tambahkan satu pesanan ke bucket yang sesuai berdasarkan metode bayar.
  PaymentBreakdown addOrder(String method, double amount) {
    switch (_bucketOf(method)) {
      case _Bucket.cash:
        return PaymentBreakdown(
            cash: cash + amount,
            transfer: transfer,
            midtrans: midtrans,
            other: other);
      case _Bucket.transfer:
        return PaymentBreakdown(
            cash: cash,
            transfer: transfer + amount,
            midtrans: midtrans,
            other: other);
      case _Bucket.midtrans:
        return PaymentBreakdown(
            cash: cash,
            transfer: transfer,
            midtrans: midtrans + amount,
            other: other);
      case _Bucket.other:
        return PaymentBreakdown(
            cash: cash,
            transfer: transfer,
            midtrans: midtrans,
            other: other + amount);
    }
  }
}

enum _Bucket { cash, transfer, midtrans, other }

_Bucket _bucketOf(String method) {
  switch (method.toLowerCase()) {
    case 'cash':
    case 'cod':
    case 'tunai':
      return _Bucket.cash;
    case 'bank_transfer':
    case 'transfer':
      return _Bucket.transfer;
    case 'midtrans':
    case 'qris':
      return _Bucket.midtrans;
    default:
      return _Bucket.other;
  }
}

/// Ringkasan pendapatan satu hari.
@immutable
class DailyRevenue {
  final DateTime date; // tengah malam hari tsb (local)
  final double total;
  final int orderCount;
  final PaymentBreakdown breakdown;
  // Rincian laci kas per hari (dipakai Laporan Cashdrawer); 0 di Laporan
  // Pendapatan kecuali `expenses` yang juga dipakai di sana.
  final double startingCash; // modal awal shift yang dibuka hari itu
  final double expenses; // pengeluaran operasional hari itu

  const DailyRevenue({
    required this.date,
    required this.total,
    required this.orderCount,
    required this.breakdown,
    this.startingCash = 0,
    this.expenses = 0,
  });

  /// Pemasukan tunai hari itu = bucket cash.
  double get cashIncome => breakdown.cash;

  /// Modal akhir hari itu = modal awal + pemasukan tunai − pengeluaran.
  double get endingCash => startingCash + breakdown.cash - expenses;
}

@immutable
class RevenueReportState {
  final DateTimeRange? selectedDateRange;
  final List<DailyRevenue>? dailyData;
  final double totalRevenue;
  final int totalTransactions;
  final PaymentBreakdown totalBreakdown;
  // Modal awal kasir (jumlah startingCash shift di rentang) & total pengeluaran
  // (operational_expenses di rentang). Dipakai Laporan Cashdrawer (modal akhir)
  // & Laporan Pendapatan (pendapatan bersih).
  final double startingCash;
  final double totalExpenses;
  final bool isLoading;
  final String? errorMessage;
  final RevenueFilterType activeFilter;
  final RevenueSourceFilter sourceFilter;
  final String? cashierFilter; // cashierId; null = semua kasir
  final List<CashierOption> cashiers;

  const RevenueReportState({
    this.selectedDateRange,
    this.dailyData,
    this.totalRevenue = 0,
    this.totalTransactions = 0,
    this.totalBreakdown = const PaymentBreakdown(),
    this.startingCash = 0,
    this.totalExpenses = 0,
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = RevenueFilterType.thisMonth,
    this.sourceFilter = RevenueSourceFilter.all,
    this.cashierFilter,
    this.cashiers = const [],
  });

  /// Pemasukan tunai (uang yang masuk laci kas) = bucket cash.
  double get cashIncome => totalBreakdown.cash;

  /// Modal akhir laci kas = modal awal + pemasukan tunai − pengeluaran.
  /// QRIS & Transfer TIDAK ikut (tidak menambah uang tunai di laci).
  double get endingCash => startingCash + totalBreakdown.cash - totalExpenses;

  /// Pendapatan bersih = total penjualan − total pengeluaran.
  double get netIncome => totalRevenue - totalExpenses;

  RevenueReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<DailyRevenue>? dailyData,
    double? totalRevenue,
    int? totalTransactions,
    PaymentBreakdown? totalBreakdown,
    double? startingCash,
    double? totalExpenses,
    bool? isLoading,
    String? errorMessage,
    RevenueFilterType? activeFilter,
    RevenueSourceFilter? sourceFilter,
    String? cashierFilter,
    bool clearCashierFilter = false,
    List<CashierOption>? cashiers,
  }) {
    return RevenueReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      dailyData: dailyData ?? this.dailyData,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalBreakdown: totalBreakdown ?? this.totalBreakdown,
      startingCash: startingCash ?? this.startingCash,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      cashierFilter:
          clearCashierFilter ? null : (cashierFilter ?? this.cashierFilter),
      cashiers: cashiers ?? this.cashiers,
    );
  }
}

class RevenueReportNotifier extends StateNotifier<RevenueReportState> {
  final Ref _ref;

  RevenueReportNotifier(this._ref) : super(const RevenueReportState());

  /// Hasil query mentah (sebelum filter kanal/kasir). Disimpan agar ganti
  /// filter tidak perlu query ulang ke Firestore.
  List<app_order.Order> _rawOrders = [];

  /// Pengeluaran operasional mentah (date + cashierId + amount) untuk rentang.
  List<({DateTime date, String? cashierId, double amount})> _rawExpenses = [];

  /// Ambil pengeluaran (operational_expenses) dalam rentang tanggal. Query
  /// satu field range → tidak butuh index komposit.
  Future<List<({DateTime date, String? cashierId, double amount})>>
      _fetchExpenses(DateTime start, DateTime end) async {
    final endInclusive =
        DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final snap = await FirebaseFirestore.instance
        .collection('operational_expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endInclusive))
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return (
        date: (data['date'] as Timestamp?)?.toDate() ?? start,
        cashierId: data['cashierId'] as String?,
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange, activeFilter: RevenueFilterType.custom);
  }

  void setSourceFilter(RevenueSourceFilter source) {
    state = state.copyWith(sourceFilter: source, errorMessage: null);
    _applyAndAggregate();
  }

  void setCashierFilter(String? cashierId) {
    state = state.copyWith(
        cashierFilter: cashierId,
        clearCashierFilter: cashierId == null,
        errorMessage: null);
    _applyAndAggregate();
  }

  void setFilter(RevenueFilterType filter) {
    final now = DateTime.now();
    DateTimeRange newRange;

    switch (filter) {
      case RevenueFilterType.today:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case RevenueFilterType.yesterday:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(microseconds: 1));
        newRange = DateTimeRange(start: start, end: end);
        break;
      case RevenueFilterType.last7days:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6)),
            end: now);
        break;
      case RevenueFilterType.thisMonth:
        newRange =
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case RevenueFilterType.custom:
        return;
    }
    state = state.copyWith(
        selectedDateRange: newRange, activeFilter: filter, errorMessage: null);
    generateReport();
  }

  Future<void> generateReport() async {
    if (state.selectedDateRange == null) {
      setFilter(RevenueFilterType.thisMonth);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orders = await _ref.read(reportServiceProvider).getOrdersByDateRange(
            startDate: state.selectedDateRange!.start,
            endDate: state.selectedDateRange!.end,
          );

      _rawOrders = orders;
      try {
        _rawExpenses = await _fetchExpenses(
            state.selectedDateRange!.start, state.selectedDateRange!.end);
      } catch (_) {
        _rawExpenses = [];
      }

      // Bangun daftar kasir dari order yang punya cashierId (tampilkan nama
      // kasir bila ada, fallback ke id).
      final Map<String, String> cashierMap = {};
      for (final o in orders) {
        final cid = o.cashierId;
        if (cid != null && cid.isNotEmpty) {
          cashierMap.putIfAbsent(
              cid,
              () => (o.kasir.trim().isNotEmpty && o.kasir != 'N/A')
                  ? o.kasir
                  : cid);
        }
      }
      final cashiers = cashierMap.entries
          .map((e) => CashierOption(e.key, e.value))
          .toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Pertahankan pilihan kasir bila masih ada di rentang baru; jika tidak,
      // reset ke "Semua".
      final keepCashier = state.cashierFilter != null &&
          cashiers.any((c) => c.id == state.cashierFilter);
      state = state.copyWith(
          cashiers: cashiers, clearCashierFilter: !keepCashier);

      _applyAndAggregate();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' && e.message != null) {
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)\s')
            .firstMatch(e.message!);
        if (urlMatch != null) {
          developer.log(
              '\nSALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\n\n${urlMatch.group(1)}\n',
              name: 'Firestore Index Trap (Pendapatan)',
              level: 1200);
          state = state.copyWith(
              errorMessage:
                  'INDEX DIPERLUKAN: Salin link dari log untuk membuat index Firestore.',
              isLoading: false);
          return;
        }
      }
      state = state.copyWith(
          errorMessage: 'Error Firebase: ${e.message}', isLoading: false);
    } catch (e) {
      state = state.copyWith(
          errorMessage: 'Terjadi error: ${e.toString()}', isLoading: false);
    }
  }

  /// Terapkan filter kanal (source) + kasir ke [_rawOrders], lalu agregasi
  /// per hari. Tidak query ulang ke Firestore.
  void _applyAndAggregate() {
    final src = state.sourceFilter;
    final cashier = state.cashierFilter;

    final filtered = _rawOrders.where((o) {
      switch (src) {
        case RevenueSourceFilter.pos:
          if (o.source != 'pos') return false;
          break;
        case RevenueSourceFilter.marketplace:
          if (o.source != 'marketplace') return false;
          break;
        case RevenueSourceFilter.all:
          break;
      }
      if (cashier != null && o.cashierId != cashier) return false;
      return true;
    }).toList();

    final Map<DateTime, _DayAccumulator> byDay = {};
    double totalRevenue = 0;
    PaymentBreakdown totalBreakdown = const PaymentBreakdown();

    for (final app_order.Order order in filtered) {
      final Timestamp ts = order.validatedAt ?? order.date;
      final d = ts.toDate();
      final dayKey = DateTime(d.year, d.month, d.day);
      final amount = order.total.toDouble();

      final acc = byDay.putIfAbsent(dayKey, () => _DayAccumulator());
      acc.total += amount;
      acc.count += 1;
      acc.breakdown = acc.breakdown.addOrder(order.paymentMethod, amount);

      totalRevenue += amount;
      totalBreakdown = totalBreakdown.addOrder(order.paymentMethod, amount);
    }

    // Total pengeluaran (ikut filter kasir; tidak terpengaruh filter kanal
    // karena pengeluaran bersifat operasional, bukan per-pesanan). Sekaligus
    // dibukukan per hari agar muncul di rincian harian.
    double totalExpenses = 0;
    final Map<DateTime, double> expByDay = {};
    for (final e in _rawExpenses) {
      if (cashier != null && e.cashierId != cashier) continue;
      totalExpenses += e.amount;
      final dk = DateTime(e.date.year, e.date.month, e.date.day);
      expByDay[dk] = (expByDay[dk] ?? 0) + e.amount;
    }

    final daily = byDay.entries
        .map((e) => DailyRevenue(
              date: e.key,
              total: e.value.total,
              orderCount: e.value.count,
              breakdown: e.value.breakdown,
              expenses: expByDay[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // terbaru dulu

    state = state.copyWith(
      dailyData: daily,
      totalRevenue: totalRevenue,
      totalTransactions: filtered.length,
      totalBreakdown: totalBreakdown,
      totalExpenses: totalExpenses,
      isLoading: false,
      errorMessage: null,
    );
  }
}

class _DayAccumulator {
  double total = 0;
  int count = 0;
  PaymentBreakdown breakdown = const PaymentBreakdown();
}

final revenueReportProvider =
    StateNotifierProvider<RevenueReportNotifier, RevenueReportState>((ref) {
  return RevenueReportNotifier(ref);
});
