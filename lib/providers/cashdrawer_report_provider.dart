import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart' as app_order;
import 'sales_report_provider.dart' show reportServiceProvider;
// Pakai ulang tipe & state dari Laporan Pendapatan (model sama, termasuk
// filter kasir & sumber) agar konsisten.
import 'revenue_report_provider.dart'
    show
        PaymentBreakdown,
        DailyRevenue,
        CashierOption,
        RevenueSourceFilter,
        RevenueFilterType,
        RevenueReportState;

/// Laporan Cashdrawer — sama seperti Laporan Pendapatan, TAPI hanya transaksi
/// yang melewati laci kas toko:
///   • semua pesanan POS (`source == 'pos'`), dan
///   • pesanan MARKETPLACE dengan metode "Ambil di Toko" (dibayar di kasir).
/// Pesanan marketplace yang dikirim kurir TIDAK masuk (uangnya tidak lewat
/// laci kas). Mendukung filter kasir & sumber seperti Laporan Pendapatan.
class CashdrawerReportNotifier extends StateNotifier<RevenueReportState> {
  final Ref _ref;

  CashdrawerReportNotifier(this._ref) : super(const RevenueReportState());

  List<app_order.Order> _rawOrders = [];

  /// Pengeluaran operasional & shift (modal awal) mentah untuk rentang ini.
  List<({DateTime date, String? cashierId, double amount})> _rawExpenses = [];
  List<
      ({
        DateTime date,
        DateTime? endTime,
        String? cashierId,
        double startingCash
      })> _rawShifts = [];

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

  Future<
      List<
          ({
            DateTime date,
            DateTime? endTime,
            String? cashierId,
            double startingCash
          })>> _fetchShifts(DateTime start, DateTime end) async {
    final endInclusive =
        DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final snap = await FirebaseFirestore.instance
        .collection('cashdrawers')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endInclusive))
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return (
        date: (data['startTime'] as Timestamp?)?.toDate() ?? start,
        endTime: (data['endTime'] as Timestamp?)?.toDate(),
        cashierId: data['cashierId'] as String?,
        startingCash: (data['startingCash'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// Transaksi yang masuk laci kas: POS, atau marketplace "Ambil di Toko".
  static bool _isDrawerOrder(app_order.Order o) {
    if (o.source == 'pos') return true;
    if (o.source == 'marketplace') {
      return (o.shippingMethod ?? '').trim().toLowerCase() == 'ambil di toko';
    }
    return false;
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

      // Pra-filter: hanya transaksi yang masuk laci kas.
      _rawOrders = orders.where(_isDrawerOrder).toList();
      try {
        _rawExpenses = await _fetchExpenses(
            state.selectedDateRange!.start, state.selectedDateRange!.end);
        _rawShifts = await _fetchShifts(
            state.selectedDateRange!.start, state.selectedDateRange!.end);
      } catch (_) {
        _rawExpenses = [];
        _rawShifts = [];
      }

      final Map<String, String> cashierMap = {};
      for (final o in _rawOrders) {
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
              name: 'Firestore Index Trap (Cashdrawer)',
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

    // Shift yang relevan (ikut filter kasir).
    final shifts = _rawShifts
        .where((s) => cashier == null || s.cashierId == cashier)
        .toList();

    // Modal awal (startingCash shift) — total + per hari (hari shift dibuka).
    double startingCash = 0;
    final Map<DateTime, double> startByDay = {};
    for (final s in shifts) {
      startingCash += s.startingCash;
      final dk = DateTime(s.date.year, s.date.month, s.date.day);
      startByDay[dk] = (startByDay[dk] ?? 0) + s.startingCash;
    }

    // PENGELUARAN hanya dihitung bila terjadi SELAMA jam shift aktif
    // (waktu pengeluaran ∈ [shift.start, shift.end]) DAN kasirnya sama. Bila
    // ada 2 shift bergantian dalam sehari, tiap pengeluaran masuk ke shift yang
    // benar — shift ke-2 hanya mendapat pengeluaran setelah ia dibuka.
    // Pengeluaran di luar jam shift tidak dihitung.
    final rangeEnd = state.selectedDateRange?.end ?? DateTime.now();
    double totalExpenses = 0;
    final Map<DateTime, double> expByDay = {};
    for (final e in _rawExpenses) {
      if (cashier != null && e.cashierId != cashier) continue;
      for (final s in shifts) {
        if (s.cashierId != e.cashierId) continue;
        final end = s.endTime ?? rangeEnd;
        if (!e.date.isBefore(s.date) && !e.date.isAfter(end)) {
          totalExpenses += e.amount;
          final dk = DateTime(s.date.year, s.date.month, s.date.day);
          expByDay[dk] = (expByDay[dk] ?? 0) + e.amount;
          break; // satu pengeluaran → satu shift
        }
      }
    }

    final daily = byDay.entries
        .map((e) => DailyRevenue(
              date: e.key,
              total: e.value.total,
              orderCount: e.value.count,
              breakdown: e.value.breakdown,
              startingCash: startByDay[e.key] ?? 0,
              expenses: expByDay[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    state = state.copyWith(
      dailyData: daily,
      totalRevenue: totalRevenue,
      totalTransactions: filtered.length,
      totalBreakdown: totalBreakdown,
      startingCash: startingCash,
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

final cashdrawerReportProvider =
    StateNotifierProvider<CashdrawerReportNotifier, RevenueReportState>((ref) {
  return CashdrawerReportNotifier(ref);
});
