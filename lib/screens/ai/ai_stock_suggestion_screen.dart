import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/models/product.dart';
import 'package:myapp/providers/ai_stock_provider.dart';
import 'package:myapp/widgets/ai_suggestion_result_card.dart';
import 'package:myapp/widgets/select_product_dialog.dart';

class AiStockSuggestionScreen extends ConsumerWidget {
  const AiStockSuggestionScreen({super.key});

  Future<void> _showSelectProductDialog(BuildContext context, List<Product> products, Function(Product) onProductSelected) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return SelectProductDialog(
          products: products,
          onProductSelected: onProductSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiStockProvider);
    final notifier = ref.read(aiStockProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saran Stok (AI)'),
      ),
      body: state.isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildInputSection(context, notifier, state),
                const SizedBox(height: 24),
                if (state.isGenerating)
                  const Center(child: CircularProgressIndicator()),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (state.suggestion != null)
                  AiSuggestionResultCard(suggestionData: state.suggestion!)
              ],
            ),
    );
  }

  Widget _buildInputSection(BuildContext context, AiStockNotifier notifier, AiStockState state) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Pilih Produk & Periode Analisis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // PERUBAHAN: Mengganti Dropdown dengan TextFormField yang memicu dialog
            GestureDetector(
              onTap: () => _showSelectProductDialog(context, state.products, (product) {
                notifier.selectProduct(product);
              }),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(text: state.selectedProduct?.name ?? ''),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Produk',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: state.analysisPeriod ?? '30',
              decoration: const InputDecoration(
                labelText: 'Periode Analisis Penjualan',
                border: OutlineInputBorder(),
              ),
              items: ['7', '30', '90'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text('$value hari terakhir'),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  notifier.selectAnalysisPeriod(newValue);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Suggestion'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: state.isGenerating ? null : () => notifier.generateSuggestion(),
            ),
          ],
        ),
      ),
    );
  }
}
