import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/promotion_model.dart';

class PromoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Mengambil semua promosi dan menggabungkannya dengan data produk
  Future<List<Promotion>> getPromotions() async {
    try {
      // 1. Ambil semua data produk dan buat map untuk pencarian cepat
      final productsSnapshot = await _db.collection('products').get();
      final productsMap = { for (var doc in productsSnapshot.docs) doc.id: Product.fromFirestore(doc) };

      // 2. Ambil semua data promosi
      final promoSnapshot = await _db.collection('promotions').orderBy('endDate', descending: true).get();

      // 3. Gabungkan data promosi dengan data produk
      final List<Promotion> promotions = [];
      for (var doc in promoSnapshot.docs) {
        final data = doc.data();
        final product = productsMap[data['productId']];

        if (product != null) {
          promotions.add(Promotion(
            promoId: doc.id,
            product: product,
            discountPrice: (data['discountPrice'] as num).toDouble(),
            startDate: (data['startDate'] as Timestamp).toDate(),
            endDate: (data['endDate'] as Timestamp).toDate(),
          ));
        }
      }
      return promotions;
    } catch (e) {
      print('Error fetching promotions: $e');
      rethrow; // Lemparkan kembali error agar bisa ditangani di UI
    }
  }

  // Menambah promosi baru
  Future<void> addPromotion({
    required String productId,
    required double discountPrice,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _db.collection('promotions').add({
        'productId': productId,
        'discountPrice': discountPrice,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding promotion: $e');
      rethrow;
    }
  }

  // Menghapus promosi
  Future<void> deletePromotion(String promoId) async {
    try {
      await _db.collection('promotions').doc(promoId).delete();
    } catch (e) {
      print('Error deleting promotion: $e');
      rethrow;
    }
  }
}
