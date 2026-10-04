import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart' as app_order;
import 'sales_report_provider.dart' show reportServiceProvider;

// Rentang cepat untuk laporan pendapatan.
enum RevenueFilterType { today, yesterday, last7days, thisMonth, custom }

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

  const DailyRevenue({
    required this.date,
    required this.total,
    required this.orderCount,
    required this.breakdown,
  });
}

@immutable
class RevenueReportState {
  final DateTimeRange? selectedDateRange;
  final List<DailyRevenue>? dailyData;
  final double totalRevenue;
  final int totalTransactions;
  final PaymentBreakdown totalBreakdown;
  final bool isLoading;
  final String? errorMessage;
  final RevenueFilterType activeFilter;

  const RevenueReportState({
    this.selectedDateRange,
    this.dailyData,
    this.totalRevenue = 0,
    this.totalTransactions = 0,
    this.totalBreakdown = const PaymentBreakdown(),
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = RevenueFilterType.thisMonth,
  });

  RevenueReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<DailyRevenue>? dailyData,
    double? totalRevenue,
    int? totalTransactions,
    PaymentBreakdown? totalBreakdown,
    bool? isLoading,
    String? errorMessage,
    RevenueFilterType? activeFilter,
  }) {
    return RevenueReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      dailyData: dailyData ?? this.dailyData,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalBreakdown: totalBreakdown ?? this.totalBreakdown,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class RevenueReportNotifier extends StateNotifier<RevenueReportState> {
  final Ref _ref;

  RevenueReportNotifier(this._ref) : super(const RevenueReportState());

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange, activeFilter: RevenueFilterType.custom);
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

      // Kelompokkan per hari (pakai validatedAt → fallback date), hitung total,
      // jumlah transaksi, dan rincian per metode bayar.
      final Map<DateTime, _DayAccumulator> byDay = {};
      double totalRevenue = 0;
      PaymentBreakdown totalBreakdown = const PaymentBreakdown();

      for (final app_order.Order order in orders) {
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

      final daily = byDay.entries
          .map((e) => DailyRevenue(
                date: e.key,
                total: e.value.total,
                orderCount: e.value.count,
                breakdown: e.value.breakdown,
              ))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // terbaru dulu

      state = state.copyWith(
        dailyData: daily,
        totalRevenue: totalRevenue,
        totalTransactions: orders.length,
        totalBreakdown: totalBreakdown,
        isLoading: false,
        errorMessage: null,
      );
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
