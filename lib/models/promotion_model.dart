import '../models/product.dart';

class Promotion {
  final String promoId;
  final Product product;
  final double discountPrice;
  final DateTime startDate;
  final DateTime endDate;

  Promotion({
    required this.promoId,
    required this.product,
    required this.discountPrice,
    required this.startDate,
    required this.endDate,
  });
}
