import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profit_loss_data.dart';
import '../services/report_service.dart';
import 'report_service_provider.dart';

// State untuk menyimpan data laporan dan status loading/error
class ProfitLossState {
  final AsyncValue<ProfitLossData> data;
  final DateTime startDate;
  final DateTime endDate;

  ProfitLossState({
    required this.data,
    required this.startDate,
    required this.endDate,
  });

  ProfitLossState copyWith({
    AsyncValue<ProfitLossData>? data,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ProfitLossState(
      data: data ?? this.data,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

// StateNotifier untuk mengelola logika bisnis halaman
class ProfitLossNotifier extends StateNotifier<ProfitLossState> {
  final ReportService _reportService;

  ProfitLossNotifier(this._reportService) : super(ProfitLossState(
    // PERBAIKAN: Hapus 'const' dari sini karena ProfitLossData.empty() bukan const
    data: AsyncValue.data(ProfitLossData.empty()),
    startDate: DateTime.now().subtract(const Duration(days: 30)),
    endDate: DateTime.now(),
  ));

  // Method untuk mengambil data laporan berdasarkan rentang tanggal
  Future<void> generateReport() async {
    state = state.copyWith(data: const AsyncValue.loading());
    try {
      final result = await _reportService.getProfitLossData(
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(data: AsyncValue.data(result));
    } catch (e, stack) {
      state = state.copyWith(data: AsyncValue.error(e, stack));
    }
  }

  // Method untuk memperbarui tanggal awal
  void setStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  // Method untuk memperbarui tanggal akhir
  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: date);
  }
}

// Provider untuk ProfitLossNotifier
final profitLossProvider = StateNotifierProvider<ProfitLossNotifier, ProfitLossState>((ref) {
  final reportService = ref.watch(reportServiceProvider);
  return ProfitLossNotifier(reportService);
});
