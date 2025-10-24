import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/order.dart' as app_order; // PERBAIKAN: Menambahkan prefiks
import '../../services/report_service.dart';

// Enum untuk tipe filter
enum SalesReportFilterType { today, yesterday, last7days, thisMonth, custom }

@immutable
class SalesReportState {
  final DateTimeRange? selectedDateRange;
  final List<app_order.Order>? reportData; // PERBAIKAN: Menggunakan prefiks
  final bool isLoading;
  final String? errorMessage;
  final SalesReportFilterType activeFilter;

  const SalesReportState({
    this.selectedDateRange,
    this.reportData,
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = SalesReportFilterType.today,
  });

  SalesReportState copyWith({
    DateTimeRange? selectedDateRange,
    List<app_order.Order>? reportData, // PERBAIKAN: Menggunakan prefiks
    bool? isLoading,
    String? errorMessage,
    SalesReportFilterType? activeFilter,
  }) {
    return SalesReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      reportData: reportData ?? this.reportData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  final ReportService _reportService;

  SalesReportNotifier(this._reportService) : super(const SalesReportState());

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
      
      state = state.copyWith(
        reportData: orders,
        isLoading: false,
        errorMessage: null,
      );

    } on FirebaseException catch (e) {
       if (e.code == 'failed-precondition' && e.message != null) {
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)')
            .firstMatch(e.message!);
        if (urlMatch != null) {
          final url = urlMatch.group(1)!;
          developer.log(
            '\n========================================\n'
            'SALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\n\n'
            '$url\n\n'
            '========================================\n',
            name: 'Firestore Index Trap',
            level: 1200,
          );
          state = state.copyWith(
              errorMessage:
                  "INDEX DIPERLUKAN: Salin link dari log untuk membuat index Firestore.",
              isLoading: false);
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
