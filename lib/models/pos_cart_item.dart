import 'product.dart';

class PosCartItem {
  final Product product;
  final int quantity;
  final double PosPrice; // Sesuai dengan nama yang Anda gunakan di file lain

  PosCartItem({
    required this.product,
    required this.quantity,
    required this.PosPrice,
  });

  double get subtotal => quantity * PosPrice;

  PosCartItem copyWith({
    Product? product,
    int? quantity,
    double? PosPrice,
  }) {
    return PosCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      PosPrice: PosPrice ?? this.PosPrice,
    );
  }
}
