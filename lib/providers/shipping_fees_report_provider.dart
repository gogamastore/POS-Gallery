import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart' as app_order;
import 'sales_report_provider.dart' show reportServiceProvider;

/// Rentang cepat untuk Laporan Rincian Biaya Pengiriman.
enum ShipFilterType { today, yesterday, last7days, thisMonth, custom }

/// Ringkasan ongkir satu hari.
@immutable
class DailyShipping {
  final DateTime date;
  final double total;
  final int orderCount;
  final Map<String, double> byCourier; // nama kurir → total ongkir

  const DailyShipping({
    required this.date,
    required this.total,
    required this.orderCount,
    required this.byCourier,
  });
}

@immutable
class ShipReportState {
  final DateTimeRange? selectedDateRange;
  final List<DailyShipping>? dailyData;
  final double totalShipping;
  final int totalTransactions;
  final bool isLoading;
  final String? errorMessage;
  final ShipFilterType activeFilter;

  const ShipReportState({
    this.selectedDateRange,
    this.dailyData,
    this.totalShipping = 0,
    this.totalTransactions = 0,
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = ShipFilterType.thisMonth,
  });

  ShipReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<DailyShipping>? dailyData,
    double? totalShipping,
    int? totalTransactions,
    bool? isLoading,
    String? errorMessage,
    ShipFilterType? activeFilter,
  }) {
    return ShipReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      dailyData: dailyData ?? this.dailyData,
      totalShipping: totalShipping ?? this.totalShipping,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class ShipReportNotifier extends StateNotifier<ShipReportState> {
  final Ref _ref;

  ShipReportNotifier(this._ref) : super(const ShipReportState());

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange, activeFilter: ShipFilterType.custom);
  }

  void setFilter(ShipFilterType filter) {
    final now = DateTime.now();
    DateTimeRange newRange;
    switch (filter) {
      case ShipFilterType.today:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case ShipFilterType.yesterday:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(microseconds: 1));
        newRange = DateTimeRange(start: start, end: end);
        break;
      case ShipFilterType.last7days:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6)),
            end: now);
        break;
      case ShipFilterType.thisMonth:
        newRange =
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case ShipFilterType.custom:
        return;
    }
    state = state.copyWith(
        selectedDateRange: newRange, activeFilter: filter, errorMessage: null);
    generateReport();
  }

  Future<void> generateReport() async {
    if (state.selectedDateRange == null) {
      setFilter(ShipFilterType.thisMonth);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orders = await _ref.read(reportServiceProvider).getOrdersByDateRange(
            startDate: state.selectedDateRange!.start,
            endDate: state.selectedDateRange!.end,
          );

      final Map<DateTime, _DayAccumulator> byDay = {};
      double grand = 0;
      int txCount = 0;

      for (final app_order.Order order in orders) {
        if (order.source != 'marketplace') continue; // hanya pesanan pembeli
        final ship = (order.shippingFee ?? 0).toDouble();
        if (ship <= 0) continue;

        final ts = order.validatedAt ?? order.date;
        final d = ts.toDate();
        final dayKey = DateTime(d.year, d.month, d.day);
        final courier = (order.shippingMethod != null &&
                order.shippingMethod!.trim().isNotEmpty)
            ? order.shippingMethod!
            : 'Ambil di Tempat';

        final acc = byDay.putIfAbsent(dayKey, () => _DayAccumulator());
        acc.total += ship;
        acc.count += 1;
        acc.byCourier[courier] = (acc.byCourier[courier] ?? 0) + ship;

        grand += ship;
        txCount += 1;
      }

      final daily = byDay.entries
          .map((e) => DailyShipping(
                date: e.key,
                total: e.value.total,
                orderCount: e.value.count,
                byCourier: e.value.byCourier,
              ))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // terbaru dulu

      state = state.copyWith(
        dailyData: daily,
        totalShipping: grand,
        totalTransactions: txCount,
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
              name: 'Firestore Index Trap (Biaya Pengiriman)',
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
  double total = 0;
  final Map<String, double> byCourier = {};
}

final shippingFeesReportProvider =
    StateNotifierProvider<ShipReportNotifier, ShipReportState>((ref) {
  return ShipReportNotifier(ref);
});
