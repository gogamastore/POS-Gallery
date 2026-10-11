import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required StockMovementType type, 
    required String reason,
    required String userId,
  }) async {
     if (type != StockMovementType.adjustmentIn && type != StockMovementType.adjustmentOut) {
      throw ArgumentError('Tipe penyesuaian tidak valid. Harap gunakan adjustmentIn atau adjustmentOut.');
    }
    final String typeString = (type == StockMovementType.adjustmentIn) ? 'in' : 'out';

    final productRef = _db.collection('products').doc(productId);
    final adjustmentRef = _db.collection('stock_adjustments').doc();

    final int stockChange = typeString == 'in' ? quantity : -quantity;

    return _db.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw Exception("Produk tidak ditemukan!");
      }

      transaction.set(adjustmentRef, {
        'productId': productId,
        'quantity': quantity,
        'type': typeString,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'adjustedBy': userId,
      });

      transaction.update(productRef, {
        'stock': FieldValue.increment(stockChange),
      });
    });
  }

  Future<List<StockMovement>> getStockHistory(String productId) async {
    final productDoc = await _db.collection('products').doc(productId).get();
    if (!productDoc.exists) {
      throw Exception('Produk dengan ID $productId tidak ditemukan.');
    }
    final product = Product.fromFirestore(productDoc);
    final int currentStock = product.stock;

    final ordersFuture = _getOrderMovements(productId);
    final purchasesFuture = _getPurchaseMovements(productId);
    final adjustmentsFuture = _getAdjustmentMovements(productId);

    final results = await Future.wait([
      ordersFuture,
      purchasesFuture,
      adjustmentsFuture,
    ]);

    final List<StockMovement> allMovements = results.expand((x) => x).toList();
    allMovements.sort((a, b) => b.date.compareTo(a.date));

    int runningStock = currentStock;
    final List<StockMovement> calculatedMovements = [];

    for (final movement in allMovements) {
      movement.stockAfter = runningStock;
      movement.stockBefore = runningStock - movement.change; 
      runningStock = movement.stockBefore;
      calculatedMovements.add(movement);
    }

    return calculatedMovements;
  }

  // --- DISAMAKAN DENGAN LAPORAN ARUS STOK WEB ---
  // Web mencatat SETIAP pesanan yang BUKAN dibatalkan sebagai stok KELUAR
  // (termasuk belum bayar / pending_payment / COD, dan pengiriman "ambil di
  // toko"), lalu pesanan yang dibatalkan sebagai stok MASUK (dikembalikan).
  // Sebelumnya Flutter hanya membaca status 'success' sehingga banyak
  // pergerakan stok (mis. pesanan marketplace belum bayar / ambil di toko)
  // tidak tercatat. Satu kali baca koleksi `orders`, lalu dipisah jadi
  // penjualan vs pembatalan.
  Future<List<StockMovement>> _getOrderMovements(String productId) async {
    final querySnapshot = await _db
        .collection('orders')
        .orderBy('date', descending: true)
        .get();

    final List<StockMovement> movements = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      if (data['date'] == null || data['products'] == null) continue;

      final bool cancelled = _isCancelledStatus(data['status']);
      final String? source = data['source'] as String?;
      final List<dynamic> productList = data['products'];
      for (var productData in productList) {
        if (productData is! Map<String, dynamic>) continue;
        if (productData['productId'] != productId) continue;
        final int quantity = (productData['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) continue;

        if (cancelled) {
          movements.add(StockMovement(
            date: (data['date'] as Timestamp).toDate(),
            description: 'Pembatalan - Order #${doc.id.substring(0, 6)}',
            change: quantity, // stok kembali (masuk)
            type: StockMovementType.cancellation,
            referenceId: doc.id,
            source: source,
          ));
        } else {
          movements.add(StockMovement(
            date: (data['date'] as Timestamp).toDate(),
            description: 'Penjualan - Order #${doc.id.substring(0, 6)}',
            change: -quantity, // stok keluar
            type: StockMovementType.sale,
            referenceId: doc.id,
            source: source,
          ));
        }
      }
    }
    return movements;
  }

  /// Pesanan dianggap dibatalkan bila statusnya "cancelled"/"Cancelled"/
  /// "dibatalkan" (casing campur: marketplace memakai "Cancelled", POS
  /// memakai "cancelled"). Selain itu dihitung sebagai stok keluar.
  bool _isCancelledStatus(dynamic status) {
    final s = (status is String) ? status.toLowerCase().trim() : '';
    return s == 'cancelled' || s == 'canceled' || s == 'dibatalkan';
  }

  Future<List<StockMovement>> _getPurchaseMovements(String productId) async {
    final querySnapshot = await _db
        .collection('purchase_transactions')
        .orderBy('date', descending: true)
        .get();

    final List<StockMovement> movements = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      if (data['items'] == null || data['date'] == null) continue;

      final items = List<Map<String, dynamic>>.from(data['items']);
      for (var item in items) {
        if (item['productId'] == productId) {
          movements.add(StockMovement(
            date: (data['date'] as Timestamp).toDate(),
            description: 'Pembelian - Transaksi #${doc.id.substring(0, 6)}',
            change: item['quantity'] as int,
            type: StockMovementType.purchase,
            referenceId: doc.id,
          ));
        }
      }
    }
    return movements;
  }

  Future<List<StockMovement>> _getAdjustmentMovements(String productId) async {
    final querySnapshot = await _db
        .collection('stock_adjustments')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .get();

    final List<StockMovement> movements = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      if (data['createdAt'] == null) continue;

      final type = data['type'] as String;
      final quantity = data['quantity'] as int;
      final change = type == 'in' ? quantity : -quantity;
      movements.add(StockMovement(
        date: (data['createdAt'] as Timestamp).toDate(),
        description: data['reason'] as String? ?? 'Penyesuaian Manual',
        change: change,
        type: type == 'in'
            ? StockMovementType.adjustmentIn
            : StockMovementType.adjustmentOut,
        referenceId: doc.id,
      ));
    }
    return movements;
  }
}
