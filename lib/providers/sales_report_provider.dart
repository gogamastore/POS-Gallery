import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sales_report_data.dart';

// Enum untuk tipe filter
enum SalesReportFilterType { today, yesterday, last7days, thisMonth, custom }

@immutable
class SalesReportState {
  final DateTimeRange? selectedDateRange;
  final SalesReportData? reportData;
  final bool isLoading;
  final String? errorMessage;
  final SalesReportFilterType activeFilter;

  const SalesReportState({
    this.selectedDateRange,
    this.reportData,
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = SalesReportFilterType.today, // Default ke hari ini
  });

  SalesReportState copyWith({
    DateTimeRange? selectedDateRange,
    SalesReportData? reportData,
    bool? isLoading,
    String? errorMessage,
    SalesReportFilterType? activeFilter,
  }) {
    return SalesReportState(
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      reportData: reportData ?? this.reportData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SalesReportNotifier() : super(const SalesReportState());

  void setDateRange(DateTimeRange dateRange) {
    state = state.copyWith(
        selectedDateRange: dateRange,
        activeFilter: SalesReportFilterType.custom);
  }

  void setFilter(SalesReportFilterType filter) {
    final now = DateTime.now();
    DateTimeRange newRange;

    switch (filter) {
      case SalesReportFilterType.today:
        newRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case SalesReportFilterType.yesterday:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(microseconds: 1));
        newRange = DateTimeRange(start: start, end: end);
        break;
      case SalesReportFilterType.last7days:
        newRange = DateTimeRange(
            start: now.subtract(const Duration(days: 6)), end: now);
        break;
      case SalesReportFilterType.thisMonth:
        newRange =
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case SalesReportFilterType.custom:
        // Dikelola oleh setDateRange
        return;
    }
    state = state.copyWith(
        selectedDateRange: newRange, activeFilter: filter, errorMessage: null);
    generateReport();
  }

  Future<Map<String, DocumentSnapshot>> _fetchDetailsInChunks(
      String collection, Set<String> ids) async {
    final details = <String, DocumentSnapshot>{};
    if (ids.isEmpty) {
      return details;
    }

    final idList = ids.toList();
    const chunkSize = 30;

    for (var i = 0; i < idList.length; i += chunkSize) {
      final chunk = idList.sublist(
          i, i + chunkSize > idList.length ? idList.length : i + chunkSize);
      final snapshot = await _firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (var doc in snapshot.docs) {
        details[doc.id] = doc;
      }
    }
    return details;
  }

  Future<void> generateReport() async {
    if (state.selectedDateRange == null) {
      setFilter(SalesReportFilterType.today);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final start = state.selectedDateRange!.start;
      final end = state.selectedDateRange!.end;

      final startDate = Timestamp.fromDate(
          DateTime(start.year, start.month, start.day, 0, 0, 0));
      final endDate = Timestamp.fromDate(
          DateTime(end.year, end.month, end.day, 23, 59, 59));

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('status', whereIn: [
            'processing',
            'Processing',
            'shipped',
            'Shipped',
            'delivered',
            'Delivered',
            'completed',
            'Completed'
          ])
          .where('validatedAt', isGreaterThanOrEqualTo: startDate)
          .where('validatedAt', isLessThanOrEqualTo: endDate)
          .orderBy('validatedAt', descending: true)
          .get();

      final relevantDocs = ordersSnapshot.docs;

      if (relevantDocs.isEmpty) {
        state = state.copyWith(
            reportData:
                SalesReportData(totalRevenue: 0, totalCogs: 0, orders: []),
            isLoading: false);
        return;
      }

      final productIds = relevantDocs
          .expand((doc) => (doc.data()['products'] as List<dynamic>)
              .map<String>((item) => item['productId'] as String))
          .toSet();
      final customerIds = relevantDocs
          .map((doc) => doc.data()['customerId'] as String?)
          .whereType<String>()
          .toSet();

      final productDetails =
          await _fetchDetailsInChunks('products', productIds);
      final customerDetails = await _fetchDetailsInChunks('user', customerIds);

      double totalRevenue = 0;
      double totalCogs = 0;
      List<SalesReportOrder> salesOrders = [];

      for (var orderDoc in relevantDocs) {
        try {
          final orderData = orderDoc.data();
          final customerId = orderData['customerId'] as String?;
          final customerName = (customerDetails[customerId]?.data()
                  as Map<String, dynamic>?)?['name'] as String? ??
              orderData['customer'] as String? ??
              'Pelanggan Langsung';

          List<SalesReportItem> items = [];
          double orderRevenue = 0;
          double orderCogs = 0;

          final orderTimestamp = orderData['validatedAt'] as Timestamp? ??
              orderData['date'] as Timestamp;

          for (var item in (orderData['products'] as List<dynamic>)) {
            final productId = item['productId'] as String;
            final productDoc = productDetails[productId];
            if (productDoc != null && productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final salePrice = (item['price'] as num).toDouble();
              final quantity = (item['quantity'] as num).toInt();
              final purchasePrice =
                  (productData['purchasePrice'] as num?)?.toDouble() ?? 0.0;
              items.add(SalesReportItem(
                  productId: productId,
                  productName: productData['name'] ?? 'N/A',
                  quantity: quantity,
                  salePrice: salePrice,
                  purchasePrice: purchasePrice));
              orderRevenue += salePrice * quantity;
              orderCogs += purchasePrice * quantity;
            }
          }

          salesOrders.add(SalesReportOrder(
              orderId: orderDoc.id,
              orderDate: orderTimestamp,
              customerName: customerName,
              customerId: customerId,
              status: orderData['status'] as String,
              paymentStatus: orderData['paymentStatus'] as String? ?? 'unpaid',
              items: items,
              totalRevenue: orderRevenue,
              totalCogs: orderCogs));

          totalRevenue += orderRevenue;
          totalCogs += orderCogs;
        } catch (e, stackTrace) {
          developer.log(
            'Skipping order due to processing error. Order ID: ${orderDoc.id}',
            name: 'sales_report_provider',
            level: 900,
            error: e,
            stackTrace: stackTrace,
          );
          continue;
        }
      }

      state = state.copyWith(
          reportData: SalesReportData(
              totalRevenue: totalRevenue,
              totalCogs: totalCogs,
              orders: salesOrders),
          isLoading: false,
          errorMessage: null);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' && e.message != null) {
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)')
            .firstMatch(e.message!);
        if (urlMatch != null) {
          final url = urlMatch.group(1)!;
          developer.log(
            '\n========================================\n'
            'SALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\n\n'
            '$url\n\n'
            '========================================\n',
            name: 'Firestore Index Trap',
            level: 1200,
          );
          state = state.copyWith(
              errorMessage:
                  "INDEX DIPERLUKAN: Salin link dari log untuk membuat index Firestore.",
              isLoading: false);
          return;
        }
      }
      // Handle other Firebase errors
      developer.log('Firebase error: ${e.toString()}',
          name: 'SalesReport', level: 1000);
      state = state.copyWith(
          errorMessage: "Error Firebase: ${e.message}", isLoading: false);
    } catch (e) {
      developer.log('Generic error: ${e.toString()}',
          name: 'SalesReport', level: 1000);
      state = state.copyWith(
          errorMessage:
              "Terjadi error kritis yang tidak terduga. Silakan coba lagi.",
          isLoading: false);
    }
  }
}

final salesReportProvider =
    StateNotifierProvider<SalesReportNotifier, SalesReportState>(
        (ref) => SalesReportNotifier());
