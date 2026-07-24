import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/order.dart' as app_order;
import '../../models/product.dart'; // Impor model Product
import '../../services/report_service.dart';

// Enum untuk tipe filter
enum SalesReportFilterType { today, yesterday, last7days, thisMonth, custom }

/// Filter kanal penjualan. 'all' tampil pertama & jadi default.
enum SalesSourceFilter { all, pos, marketplace }

@immutable
class SalesReportState {
  final DateTimeRange? selectedDateRange;
  final List<app_order.Order>? reportData;
  final bool isLoading;
  final String? errorMessage;
  final SalesReportFilterType activeFilter;
  final SalesSourceFilter sourceFilter;

  // --- FIELD BARU UNTUK TOTAL LABA KOTOR & HPP ---
  final double totalGrossProfit;
  final double totalCogs;

  const SalesReportState({
    this.selectedDateRange,
    this.reportData,
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = SalesReportFilterType.today,
    this.sourceFilter = SalesSourceFilter.all,
    this.totalGrossProfit = 0.0, // Default value
    this.totalCogs = 0.0,      // Default value
  });

  SalesReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<app_order.Order>? reportData,
    bool? isLoading,
    String? errorMessage,
    SalesReportFilterType? activeFilter,
    SalesSourceFilter? sourceFilter,
    double? totalGrossProfit,
    double? totalCogs,
  }) {
    return SalesReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      reportData: reportData ?? this.reportData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      totalGrossProfit: totalGrossProfit ?? this.totalGrossProfit,
      totalCogs: totalCogs ?? this.totalCogs,
    );
  }
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  final ReportService _reportService;
  final FirebaseFirestore _db = FirebaseFirestore.instance; // Tambahkan instance Firestore

  SalesReportNotifier(this._reportService) : super(const SalesReportState());

  /// Hasil query + perhitungan HPP/laba, SEBELUM difilter kanal (source).
  /// Disimpan agar ganti filter Sumber tidak perlu query ulang ke Firestore.
  List<app_order.Order> _enrichedOrders = [];

  /// Ganti filter kanal penjualan (Semua / POS / Marketplace).
  void setSourceFilter(SalesSourceFilter source) {
    state = state.copyWith(sourceFilter: source, errorMessage: null);
    _applyFilters();
  }

  /// Turunkan reportData + metrik dari [_enrichedOrders] sesuai filter Sumber.
  void _applyFilters() {
    final filtered = _enrichedOrders.where((o) {
      switch (state.sourceFilter) {
        case SalesSourceFilter.all:
          return true;
        case SalesSourceFilter.pos:
          return o.source == 'pos';
        case SalesSourceFilter.marketplace:
          return o.source == 'marketplace';
      }
    }).toList();

    double cogs = 0;
    double gross = 0;
    for (final o in filtered) {
      cogs += o.cogs;
      gross += o.grossProfit;
    }

    state = state.copyWith(
      reportData: filtered,
      totalCogs: cogs,
      totalGrossProfit: gross,
      isLoading: false,
      errorMessage: null,
    );
  }

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange,
        activeFilter: SalesReportFilterType.custom);
  }

  void setFilter(SalesReportFilterType filter) {
    final now = DateTime.now();
    DateTimeRange newRange;

    switch (filter) {
      case SalesReportFilterType.today:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case SalesReportFilterType.yesterday:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(microseconds: 1));
        newRange = DateTimeRange(start: start, end: end);
        break;
      case SalesReportFilterType.last7days:
        newRange = DateTimeRange(
            start: now.subtract(const Duration(days: 6)), end: now);
        break;
      case SalesReportFilterType.thisMonth:
        newRange =
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case SalesReportFilterType.custom:
        return;
    }
    state = state.copyWith(
        selectedDateRange: newRange, activeFilter: filter, errorMessage: null);
    generateReport();
  }

  Future<void> generateReport() async {
    if (state.selectedDateRange == null) {
      setFilter(SalesReportFilterType.today);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orders = await _reportService.getOrdersByDateRange(
        startDate: state.selectedDateRange!.start,
        endDate: state.selectedDateRange!.end,
      );

      final productsSnapshot = await _db.collection('products').get();
      final productsMap = {
        for (var doc in productsSnapshot.docs)
          doc.id: Product.fromFirestore(doc)
      };

      final List<app_order.Order> ordersWithProfit = [];

      for (final order in orders) {
        double orderCogs = 0;
        
        for (final item in order.products) {
          final productId = item['productId'] as String?;
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          
          if (productId != null && productsMap.containsKey(productId)) {
            final productDetails = productsMap[productId]!;
            final purchasePrice = productDetails.purchasePrice ?? 0.0;
            orderCogs += purchasePrice * quantity;
          }
        }
        
        final orderGrossProfit = order.total.toDouble() - orderCogs;

        ordersWithProfit.add(order.copyWith(
          cogs: orderCogs,
          grossProfit: orderGrossProfit,
        ));
      }

      // Simpan hasil mentah, lalu turunkan daftar & metrik sesuai filter Sumber.
      _enrichedOrders = ordersWithProfit;
      _applyFilters();

    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' && e.message != null) {
        final urlMatch = RegExp(r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)\s').firstMatch(e.message!);
        if (urlMatch != null) {
          final url = urlMatch.group(1)!;
          final logMessage = '\n========================================\nSALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\n\n$url\n\n========================================\n';
          developer.log(logMessage, name: 'Firestore Index Trap', level: 1200);
          print(logMessage);
          state = state.copyWith(errorMessage: "INDEX DIPERLUKAN: Salin link dari log untuk membuat index Firestore.", isLoading: false);
          return;
        }
      }
      developer.log('Firebase error: ${e.toString()}', name: 'SalesReport', level: 1000);
      state = state.copyWith(errorMessage: "Error Firebase: ${e.message}", isLoading: false);
    } catch (e) {
      developer.log('Generic error: ${e.toString()}', name: 'SalesReport', level: 1000);
      state = state.copyWith(errorMessage: "Terjadi error: ${e.toString()}", isLoading: false);
    }
  }
}

final reportServiceProvider = Provider((ref) => ReportService());

final salesReportProvider =
    StateNotifierProvider<SalesReportNotifier, SalesReportState>((ref) {
  final reportService = ref.watch(reportServiceProvider);
  return SalesReportNotifier(reportService);
});
