import 'package:flutter/material.dart';
import '../../models/product.dart';

class StockFlowDetailScreen extends StatelessWidget {
  final Product product;
  final DateTimeRange dateRange;

  const StockFlowDetailScreen({
    super.key,
    required this.product,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Arus Stok: ${product.name}'), // PERBAIKAN: Menghapus const
      ),
      body: Center( // PERBAIKAN: Menghapus const
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Detail untuk produk: ${product.name}'),
            const SizedBox(height: 10),
            Text('Periode: ${dateRange.start.toString()} - ${dateRange.end.toString()}'),
           
          ],
        ),
      ),
    );
  }
}
