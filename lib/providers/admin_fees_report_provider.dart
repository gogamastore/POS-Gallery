import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart' as app_order;
import 'sales_report_provider.dart' show reportServiceProvider;

/// Rentang cepat untuk Laporan Biaya Admin & Layanan.
enum FeeFilterType { today, yesterday, last7days, thisMonth, custom }

/// Rincian biaya per jenis (dari pesanan marketplace):
///  • admin   ← adminFee
///  • service ← serviceFee
///  • payment ← paymentFee (biaya layanan metode pembayaran)
@immutable
class FeeBreakdown {
  final double admin;
  final double service;
  final double payment;

  const FeeBreakdown({this.admin = 0, this.service = 0, this.payment = 0});

  double get total => admin + service + payment;

  FeeBreakdown operator +(FeeBreakdown o) => FeeBreakdown(
        admin: admin + o.admin,
        service: service + o.service,
        payment: payment + o.payment,
      );
}

/// Ringkasan biaya satu hari.
@immutable
class DailyFees {
  final DateTime date;
  final double total;
  final int orderCount;
  final FeeBreakdown breakdown;

  const DailyFees({
    required this.date,
    required this.total,
    required this.orderCount,
    required this.breakdown,
  });
}

@immutable
class FeeReportState {
  final DateTimeRange? selectedDateRange;
  final List<DailyFees>? dailyData;
  final double totalFees;
  final int totalTransactions;
  final FeeBreakdown totalBreakdown;
  final bool isLoading;
  final String? errorMessage;
  final FeeFilterType activeFilter;

  const FeeReportState({
    this.selectedDateRange,
    this.dailyData,
    this.totalFees = 0,
    this.totalTransactions = 0,
    this.totalBreakdown = const FeeBreakdown(),
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = FeeFilterType.thisMonth,
  });

  FeeReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<DailyFees>? dailyData,
    double? totalFees,
    int? totalTransactions,
    FeeBreakdown? totalBreakdown,
    bool? isLoading,
    String? errorMessage,
    FeeFilterType? activeFilter,
  }) {
    return FeeReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      dailyData: dailyData ?? this.dailyData,
      totalFees: totalFees ?? this.totalFees,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalBreakdown: totalBreakdown ?? this.totalBreakdown,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class FeeReportNotifier extends StateNotifier<FeeReportState> {
  final Ref _ref;

  FeeReportNotifier(this._ref) : super(const FeeReportState());

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange, activeFilter: FeeFilterType.custom);
  }

  void setFilter(FeeFilterType filter) {
    final now = DateTime.now();
    DateTimeRange newRange;
    switch (filter) {
      case FeeFilterType.today:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case FeeFilterType.yesterday:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(microseconds: 1));
        newRange = DateTimeRange(start: start, end: end);
        break;
      case FeeFilterType.last7days:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6)),
            end: now);
        break;
      case FeeFilterType.thisMonth:
        newRange =
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case FeeFilterType.custom:
        return;
    }
    state = state.copyWith(
        selectedDateRange: newRange, activeFilter: filter, errorMessage: null);
    generateReport();
  }

  Future<void> generateReport() async {
    if (state.selectedDateRange == null) {
      setFilter(FeeFilterType.thisMonth);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orders = await _ref.read(reportServiceProvider).getOrdersByDateRange(
            startDate: state.selectedDateRange!.start,
            endDate: state.selectedDateRange!.end,
          );

      final Map<DateTime, _DayAccumulator> byDay = {};
      FeeBreakdown grand = const FeeBreakdown();
      int txCount = 0;

      for (final app_order.Order order in orders) {
        // Hanya pesanan pembeli marketplace yang memang punya biaya.
        if (order.source != 'marketplace') continue;
        final admin = (order.adminFee ?? 0).toDouble();
        final service = (order.serviceFee ?? 0).toDouble();
        final payment = (order.paymentFee ?? 0).toDouble();
        final orderTotal = admin + service + payment;
        if (orderTotal <= 0) continue;

        final ts = order.validatedAt ?? order.date;
        final d = ts.toDate();
        final dayKey = DateTime(d.year, d.month, d.day);

        final acc = byDay.putIfAbsent(dayKey, () => _DayAccumulator());
        acc.breakdown = acc.breakdown +
            FeeBreakdown(admin: admin, service: service, payment: payment);
        acc.count += 1;

        grand = grand +
            FeeBreakdown(admin: admin, service: service, payment: payment);
        txCount += 1;
      }

      final daily = byDay.entries
          .map((e) => DailyFees(
                date: e.key,
                total: e.value.breakdown.total,
                orderCount: e.value.count,
                breakdown: e.value.breakdown,
              ))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // terbaru dulu

      state = state.copyWith(
        dailyData: daily,
        totalFees: grand.total,
        totalTransactions: txCount,
        totalBreakdown: grand,
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
              name: 'Firestore Index Trap (Biaya Admin)',
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
  int count = 0;
  FeeBreakdown breakdown = const FeeBreakdown();
}

final adminFeesReportProvider =
    StateNotifierProvider<FeeReportNotifier, FeeReportState>((ref) {
  return FeeReportNotifier(ref);
});
