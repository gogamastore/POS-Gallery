import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_item.freezed.dart';
part 'order_item.g.dart';

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    required String name,
    required int quantity,
    required double price,
    String? imageUrl,
    String? sku,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}
