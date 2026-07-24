import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../models/customer_report.dart';
import '../models/expense_item.dart';
import '../models/order.dart';
import '../services/report_service.dart';

final reportServiceProvider = Provider((ref) => ReportService());

final customerReportProvider =
    FutureProvider.family<List<CustomerReport>, DateTimeRange>(
        (ref, dateRange) async {
  final reportService = ref.watch(reportServiceProvider);
  return await reportService.generateCustomerReport(
      startDate: dateRange.start, endDate: dateRange.end);
});

final operationalExpensesProvider = FutureProvider.family<List<ExpenseItem>, DateTimeRange>((ref, dateRange) async {
  final reportService = ref.watch(reportServiceProvider);
  return reportService.getOperationalExpenses(startDate: dateRange.start, endDate: dateRange.end);
});

final orderByIdProvider = FutureProvider.family<Order, String>((ref, orderId) async {
  final reportService = ref.watch(reportServiceProvider);
  return reportService.getOrderById(orderId);
});

