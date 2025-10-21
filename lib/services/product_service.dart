import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/purchase_history_entry.dart';

class ProductService {
  final CollectionReference _productsCollection =
      FirebaseFirestore.instance.collection('products');
  final CollectionReference _purchaseHistoryCollection =
      FirebaseFirestore.instance.collection('purchase_history');

  Stream<List<Product>> getProducts() {
    return _productsCollection.orderBy('name').snapshots().map((snapshot) {
      final products = <Product>[];
      for (var doc in snapshot.docs) {
        try {
          products.add(Product.fromFirestore(doc));
        } catch (e) {
          print('Gagal mem-parsing produk dengan ID: ${doc.id}, error: $e');
        }
      }
      return products;
    });
  }

  Stream<Product?> getProductById(String productId) {
    return _productsCollection.doc(productId).snapshots().map((snapshot) {
      try {
        if (snapshot.exists) {
          return Product.fromFirestore(snapshot);
        }
      } catch (e) {
        print('Gagal mem-parsing produk dengan ID: $productId, error: $e');
      }
      return null;
    });
  }

  Stream<List<PurchaseHistoryEntry>> getPurchaseHistory(String productId) {
    return _purchaseHistoryCollection
        .where('productId', isEqualTo: productId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PurchaseHistoryEntry.fromFirestore(doc))
          .toList();
    });
  }

  Future<DocumentReference> addProduct(Product product) {
    final productData = product.toMap();
    // Hapus ID sisi klien & timestamp, biarkan Firestore yang mengatur
    productData.remove('id');
    productData.remove('createdAt');
    productData.remove('updatedAt');

    // Tambahkan timestamp sisi server untuk pembuatan dan pembaruan
    productData['createdAt'] = FieldValue.serverTimestamp();
    productData['updatedAt'] = FieldValue.serverTimestamp();

    return _productsCollection.add(productData);
  }

  Future<void> updateProduct(Product product) {
    final productData = product.toMap();
    // Hapus ID & createdAt agar tidak menimpa tanggal pembuatan
    productData.remove('id');
    productData.remove('createdAt');

    // Tambahkan timestamp sisi server hanya untuk pembaruan
    productData['updatedAt'] = FieldValue.serverTimestamp();

    return _productsCollection.doc(product.id).update(productData);
  }

  Future<void> deleteProduct(String productId) {
    return _productsCollection.doc(productId).delete();
  }
}
