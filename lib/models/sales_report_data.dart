import 'package:cloud_firestore/cloud_firestore.dart';

class SalesReportData {
  final double totalRevenue;
  final double totalCogs; // Cost of Goods Sold
  final List<SalesReportOrder> orders;

  SalesReportData({
    required this.totalRevenue,
    required this.totalCogs,
    required this.orders,
  });

  double get grossProfit => totalRevenue - totalCogs;
  int get totalTransactions => orders.length;
}

class SalesReportOrder {
  final String orderId;
  final Timestamp orderDate;
  final String customerName;
  final String? customerId;
  final String status;
  final String paymentStatus; // <<< TAMBAHKAN FIELD INI
  final List<SalesReportItem> items;
  final double totalRevenue;
  final double totalCogs;

  SalesReportOrder({
    required this.orderId,
    required this.orderDate,
    required this.customerName,
    required this.customerId,
    required this.status,
    required this.paymentStatus, // <<< TAMBAHKAN DI KONSTRUKTOR
    required this.items,
    required this.totalRevenue,
    required this.totalCogs,
  });

  double get grossProfit => totalRevenue - totalCogs;
}

class SalesReportItem {
  final String productId;
  final String productName;
  final int quantity;
  final double salePrice;
  final double purchasePrice;

  SalesReportItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.salePrice,
    required this.purchasePrice,
  });

  double get totalSale => salePrice * quantity;
  double get totalCost => purchasePrice * quantity;
}
