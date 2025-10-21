import './order.dart';

class CustomerReport {
  final String id;
  final String name;
  final int transactionCount;
  final double totalSpent;
  final double receivables;
  final List<Order> orders;

  CustomerReport({
    required this.id,
    required this.name,
    required this.transactionCount,
    required this.totalSpent,
    required this.receivables,
    required this.orders,
  });

  // Metode untuk membuat salinan objek dengan nilai yang diperbarui
  CustomerReport copyWith({
    int? transactionCount,
    double? totalSpent,
    double? receivables,
    List<Order>? orders,
  }) {
    return CustomerReport(
      id: id,
      name: name,
      transactionCount: transactionCount ?? this.transactionCount,
      totalSpent: totalSpent ?? this.totalSpent,
      receivables: receivables ?? this.receivables,
      orders: orders ?? this.orders,
    );
  }
}
