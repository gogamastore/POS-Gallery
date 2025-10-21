// lib/providers/supplier_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';

final supplierProvider = FutureProvider<List<Supplier>>((ref) async {
  return SupplierService().getSuppliers();
});