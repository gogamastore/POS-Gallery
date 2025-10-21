import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../models/purchase_cart_item.dart';
import '../../models/purchase_transaction.dart';
import '../../models/supplier.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid(); // _uuid sekarang akan digunakan lagi

  // --- METODE UNTUK TRANSAKSI BARU (DIKEMBALIKAN SEPENUHNYA) ---
  Future<void> processPurchaseTransaction({
    required List<PurchaseCartItem> items,
    required double totalAmount,
    required String paymentMethod,
    Supplier? supplier,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final String transactionId = _uuid.v4(); // Penggunaan _uuid

    final DocumentReference transactionRef = _firestore.collection('purchase_transactions').doc(transactionId);

    final List<Map<String, dynamic>> itemsArray = items.map((item) => {
      'productId': item.product.id,
      'productName': item.product.name,
      'quantity': item.quantity,
      'purchasePrice': item.purchasePrice,
      'subtotal': item.subtotal,
    }).toList();

    final transactionData = {
      'date': FieldValue.serverTimestamp(),
      'totalAmount': totalAmount.toInt(),
      'paymentMethod': paymentMethod,
      'supplierId': supplier?.id,
      'supplierName': supplier?.name,
      'items': itemsArray,
    };

    batch.set(transactionRef, transactionData);

    for (final item in items) {
      final String historyId = _uuid.v4(); // Penggunaan _uuid
      final DocumentReference historyRef = _firestore.collection('purchase_history').doc(historyId);

      final historyData = {
        'transactionId': transactionId,
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'purchasePrice': item.purchasePrice,
        'supplierName': supplier?.name,
        'purchaseDate': FieldValue.serverTimestamp(),
      };
      batch.set(historyRef, historyData);

      final DocumentReference productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {
        'stock': FieldValue.increment(item.quantity),
        'purchasePrice': item.purchasePrice,
      });
    }

    await batch.commit();
  }

  // --- METODE UNTUK EDIT TRANSAKSI (SUDAH BENAR) ---
  Future<void> updatePurchaseTransaction({
    required String transactionId,
    required List<PurchaseItem> originalItems,
    required List<dynamic> newItems,
    required double newTotalAmount,
  }) async {
    final WriteBatch batch = _firestore.batch();

    final Map<String, int> oldQuantities = {
      for (var item in originalItems) item.productId: item.quantity
    };
    final Map<String, int> newQuantities = {
      for (var item in newItems) item['productId']: item['quantity']
    };

    final Map<String, int> deltaQuantities = {};
    newQuantities.forEach((productId, newQty) {
      final oldQty = oldQuantities[productId] ?? 0;
      final delta = newQty - oldQty;
      if (delta != 0) {
        deltaQuantities[productId] = delta;
      }
    });
    oldQuantities.forEach((productId, oldQty) {
      if (!newQuantities.containsKey(productId)) {
        deltaQuantities[productId] = -oldQty;
      }
    });

    final Map<String, double> newPurchasePrices = {
      for (var item in newItems)
        item['productId']: (item['purchasePrice'] as num).toDouble()
    };

    deltaQuantities.forEach((productId, stockDelta) {
      final productRef = _firestore.collection('products').doc(productId);
      final Map<String, dynamic> updateData = {
        'stock': FieldValue.increment(stockDelta),
      };
      if (newPurchasePrices.containsKey(productId)) {
        updateData['purchasePrice'] = newPurchasePrices[productId];
      }
      batch.update(productRef, updateData);
    });

    final transactionRef = _firestore.collection('purchase_transactions').doc(transactionId);
    batch.update(transactionRef, {
      'items': newItems,
      'totalAmount': newTotalAmount,
      'lastModified': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
