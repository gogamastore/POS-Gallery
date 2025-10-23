import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart' as app_order;
import '../models/product.dart';
import '../models/expense_item.dart';
import '../models/customer_report.dart';
import '../models/profit_loss_data.dart';
import '../models/purchase.dart';
import '../models/receivable_data.dart';
import '../models/product_sales_data.dart';
import '../models/product_sales_history.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- FUNGSI LAPORAN LABA RUGI ---
  Future<ProfitLossData> getProfitLossData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ordersSnapshot = await _db
        .collection('orders')
        .where('validatedAt', isGreaterThanOrEqualTo: startDate)
        .where('validatedAt', isLessThanOrEqualTo: endDate)
        .where('status', isEqualTo: 'success') // Hanya pesanan sukses
        .get();

    double totalRevenue = 0;
    double totalCOGS = 0;

    for (var doc in ordersSnapshot.docs) {
      final order = app_order.Order.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      
      totalRevenue += order.total;

      for (var item in order.products) {
        try {
          final productId = item['id'] as String?;
          final quantity = (item['quantity'] as num? ?? 0);
          
          if (productId != null) {
            final productDoc = await _db.collection('products').doc(productId).get();
            if (productDoc.exists) {
              final product = Product.fromFirestore(productDoc);
              totalCOGS += (product.purchasePrice ?? 0.0) * quantity;
            }
          }
        } catch (e) {
          // Lanjutkan jika ada error pada satu item
        }
      }
    }

    final expensesSnapshot = await _db
        .collection('operational_expenses')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();

    double totalOperationalExpenses = 0;
    for (var doc in expensesSnapshot.docs) {
      final expense = ExpenseItem.fromFirestore(doc);
      totalOperationalExpenses += expense.amount;
    }

    final double grossProfit = totalRevenue - totalCOGS;
    final double netProfit = grossProfit - totalOperationalExpenses;

    return ProfitLossData(
      totalRevenue: totalRevenue,
      totalCOGS: totalCOGS,
      grossProfit: grossProfit,
      totalOperationalExpenses: totalOperationalExpenses,
      netProfit: netProfit,
    );
  }

  Future<List<ExpenseItem>> getOperationalExpenses({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final querySnapshot = await _db
        .collection('operational_expenses')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();

    return querySnapshot.docs.map((doc) => ExpenseItem.fromFirestore(doc)).toList();
  }

  Future<List<CustomerReport>> generateCustomerReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final DateTime inclusiveStartDate = DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime exclusiveEndDate = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

    final querySnapshot = await _db
        .collection('orders')
        .where('date', isGreaterThanOrEqualTo: inclusiveStartDate)
        .where('date', isLessThan: exclusiveEndDate)
        .get();

    final reportMap = <String, CustomerReport>{};

    for (var doc in querySnapshot.docs) {
      final order = app_order.Order.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      
      final customerId = order.customerDetails?['id'] as String?;
      final customerName = order.customerDetails?['name'] as String?;
      
      if (customerId == null || customerName == null) continue;

      final total = order.total;

      reportMap.putIfAbsent(
        customerId,
        () => CustomerReport(
          id: customerId,
          name: customerName,
          transactionCount: 0,
          totalSpent: 0,
          receivables: 0,
          orders: [],
        ),
      );

      final report = reportMap[customerId]!;
      final isUnpaid = order.paymentStatus.toLowerCase() == 'unpaid';
      
      final isValidStatus = ['processing', 'success'].contains(order.status.toLowerCase());
      final newReceivables = report.receivables + (isUnpaid && isValidStatus ? total : 0);

      reportMap[customerId] = report.copyWith(
        transactionCount: report.transactionCount + 1,
        totalSpent: report.totalSpent + total,
        receivables: newReceivables,
        orders: [...report.orders, order]..sort((a, b) => b.date.compareTo(a.date)),
      );
    }

    final reportList = reportMap.values.toList();
    reportList.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return reportList;
  }

  Future<void> markOrderAsPaid(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'paymentStatus': 'paid'});
  }

  Future<app_order.Order> getOrderById(String orderId) async {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        // PERBAIKAN: Menghapus cast yang tidak perlu
        return app_order.Order.fromFirestore(doc);
      }
      throw Exception('Pesanan tidak ditemukan.');
  }

  Future<void> processPurchasePayment({
    required String purchaseId,
    required String paymentMethod,
    String? notes,
  }) async {
    await _db.collection('purchase_transactions').doc(purchaseId).update({
      'paymentStatus': 'paid',
      'paymentMethod': paymentMethod,
      'paymentNotes': notes,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Purchase>> generatePayableReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = _db
        .collection('purchase_transactions')
        .where('paymentMethod', whereIn: ['credit', 'Credit'])
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate.add(const Duration(days: 1)));

    final snapshot = await query.get();
    final List<Purchase> payableList = snapshot.docs.map((doc) => Purchase.fromMap(doc.id, doc.data())).toList();
    payableList.sort((a, b) => a.date.compareTo(b.date));
    return payableList;
  }

  Future<List<ReceivableData>> generateReceivableReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = _db
        .collection('orders')
        .where('paymentStatus', whereIn: ['unpaid', 'Unpaid'])
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate.add(const Duration(days: 1)));

    final snapshot = await query.get();
    final List<ReceivableData> receivableList = [];
    
    const validOrderStates = ['processing', 'success'];

    for (var doc in snapshot.docs) {
      final order = app_order.Order.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      if (validOrderStates.contains(order.status.toLowerCase())) {
        receivableList.add(
          ReceivableData(
            orderId: order.id ?? '',
            customerName: order.customerDetails?['name'] ?? 'N/A',
            orderDate: order.date.toDate(),
            orderStatus: order.status,
            totalReceivable: order.total,
          ),
        );
      }
    }
    receivableList.sort((a, b) => a.orderDate.compareTo(b.orderDate));
    return receivableList;
  }

  Future<List<ProductSalesData>> generateProductSalesReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = _db
        .collection('orders')
        .where('status', whereIn: ['processing', 'success'])
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate.add(const Duration(days: 1)));
    
    final allOrderDocs = await query.get();

    final productsSnapshot = await _db.collection('products').get();
    final productsMap = { for (var doc in productsSnapshot.docs) doc.id: Product.fromFirestore(doc) };

    final salesAggregation = <String, int>{};

    for (var orderDoc in allOrderDocs.docs) {
      final orderData = app_order.Order.fromFirestore(orderDoc as DocumentSnapshot<Map<String, dynamic>>);
      for (var productInOrder in orderData.products) {
        final productId = productInOrder['id'] as String?;
        final quantity = (productInOrder['quantity'] as num? ?? 0).toInt();
        if (productId != null) {
          salesAggregation.update(productId, (value) => value + quantity, ifAbsent: () => quantity);
        }
      }
    }

    final List<ProductSalesData> reportData = [];
    salesAggregation.forEach((productId, totalSold) {
      final product = productsMap[productId];
      if (product != null) {
        reportData.add(ProductSalesData(product: product, totalSold: totalSold));
      }
    });

    reportData.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    return reportData;
  }

  Future<List<ProductSalesHistory>> getProductSalesHistory({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = _db
        .collection('orders')
        .where('productIds', arrayContains: productId)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate.add(const Duration(days: 1)));

    final allOrderDocs = await query.get();
    final List<ProductSalesHistory> history = [];

    for (var orderDoc in allOrderDocs.docs) {
      final orderData = app_order.Order.fromFirestore(orderDoc as DocumentSnapshot<Map<String, dynamic>>);
      
      DateTime transactionDate;
      if (orderData.validatedAt != null) {
        transactionDate = orderData.validatedAt!.toDate();
      } else {
        transactionDate = orderData.date.toDate();
      }

      for (var item in orderData.products) {
        if (item['id'] == productId) {
          history.add(
            ProductSalesHistory(
              orderId: orderDoc.id,
              customerName: orderData.customerDetails?['name'] ?? 'N/A',
              orderDate: transactionDate,
              quantity: (item['quantity'] as num? ?? 0).toInt(),
            ),
          );
        }
      }
    }

    history.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    return history;
  }
}
