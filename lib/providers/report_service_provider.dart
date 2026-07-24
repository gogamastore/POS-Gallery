import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/report_service.dart';

// Provider sederhana untuk menyediakan instance dari ReportService
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});
