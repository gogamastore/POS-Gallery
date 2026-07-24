import 'package:cloud_firestore/cloud_firestore.dart';

/// Aksi pesanan marketplace yang dipakai bersama oleh daftar & detail.
class MarketplaceOrderActions {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Batalkan pesanan & kembalikan stok — meniru web dashboard:
  /// status → 'Cancelled', paymentStatus → 'cancelled', stok tiap produk
  /// katalog dikembalikan (increment). Atomik lewat transaksi.
  static Future<void> cancelAndRestoreStock(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('Pesanan tidak ditemukan.');
      }

      final products = (orderSnap.data()!['products'] as List?) ?? [];
      final refs = <DocumentReference<Map<String, dynamic>>>[];
      final qtys = <int>[];
      for (final p in products) {
        final pid = (p as Map)['productId'] as String?;
        // Lewati produk non-katalog (POS menandai dengan prefix 'temp_').
        if (pid == null || pid.isEmpty || pid.startsWith('temp_')) continue;
        refs.add(_db.collection('products').doc(pid));
        qtys.add((p['quantity'] as num?)?.toInt() ?? 0);
      }

      // Semua read wajib sebelum write dalam transaksi.
      final snaps = await Future.wait(refs.map(tx.get));

      tx.update(orderRef, {
        'status': 'Cancelled',
        'paymentStatus': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var i = 0; i < refs.length; i++) {
        if (snaps[i].exists && qtys[i] > 0) {
          tx.update(refs[i], {'stock': FieldValue.increment(qtys[i])});
        }
      }
    });
  }

  /// Hapus pesanan (tanpa mengembalikan stok — sama seperti tombol Hapus web).
  static Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
  }
}
