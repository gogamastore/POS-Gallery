import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:myapp/models/product.dart';
import 'package:myapp/services/ai_stock_service.dart';

part 'ai_stock_provider.freezed.dart';

@freezed
class AiStockState with _$AiStockState {
  const factory AiStockState({
    @Default([]) List<Product> products,
    @Default(true) bool isLoadingProducts,
    @Default(false) bool isGenerating,
    Product? selectedProduct,
    String? analysisPeriod,
    Map<String, dynamic>? suggestion,
    String? error,
  }) = _AiStockState;
}

class AiStockNotifier extends StateNotifier<AiStockState> {
  final AiStockService _aiStockService;

  AiStockNotifier(this._aiStockService) : super(const AiStockState()) {
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await _aiStockService.fetchProducts();
      state = state.copyWith(products: products, isLoadingProducts: false);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat produk: $e', isLoadingProducts: false);
    }
  }

  void selectProduct(Product? product) {
    state = state.copyWith(selectedProduct: product);
  }

  void selectAnalysisPeriod(String period) {
    state = state.copyWith(analysisPeriod: period);
  }

  Future<void> generateSuggestion() async {
    if (state.selectedProduct == null) {
      state = state.copyWith(error: 'Silakan pilih produk terlebih dahulu.');
      return;
    }

    final periodDays = int.tryParse(state.analysisPeriod ?? '30') ?? 30;

    state = state.copyWith(isGenerating: true, error: null, suggestion: null);

    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: periodDays));
      final salesData = await _aiStockService.getSalesDataForProduct(
        state.selectedProduct!.id,
        startDate,
        now,
      );

      final suggestionResult = await _aiStockService.getStockSuggestion(
        productName: state.selectedProduct!.name,
        currentStock: state.selectedProduct!.stock,
        salesData: salesData,
        analysisPeriod: '$periodDays hari terakhir',
      );

      state = state.copyWith(suggestion: suggestionResult, isGenerating: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isGenerating: false);
    } 
  }
}

final aiStockProvider = StateNotifierProvider<AiStockNotifier, AiStockState>((ref) {
  return AiStockNotifier(AiStockService());
});
