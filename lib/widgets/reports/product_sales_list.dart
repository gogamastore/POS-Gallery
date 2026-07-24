import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_sales_data.dart';
import 'product_sales_history_dialog.dart';

class ProductSalesList extends StatelessWidget {
  final List<ProductSalesData> reportData;
  final DateTime startDate;
  final DateTime endDate;

  // --- PERBAIKAN DI SINI: Gunakan sintaksis konstruktor gaya lama ---
  const ProductSalesList({
    super.key, // Tambahkan parameter key
    required this.reportData,
    required this.startDate,
    required this.endDate,
  }); // Teruskan key ke super-constructor
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reportData.length,
      itemBuilder: (context, index) {
        final item = reportData[index];
        final product = item.product;
        final imageUrl = product.image ?? '';

        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => ProductSalesHistoryDialog(
                productId: product.id,
                productName: product.name,
                startDate: startDate,
                endDate: endDate,
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product.sku ?? '-'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.totalSold.toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Terjual',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
