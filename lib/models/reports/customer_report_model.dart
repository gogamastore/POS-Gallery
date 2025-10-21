import 'order_model.dart';

class CustomerReport {
  final String id; // Customer ID
  final String name;
  int transactionCount;
  double totalSpent;
  double receivables;
  List<SimpleOrder> orders;

  CustomerReport({
    required this.id,
    required this.name,
    this.transactionCount = 0,
    this.totalSpent = 0,
    this.receivables = 0,
    required this.orders,
  });
}
