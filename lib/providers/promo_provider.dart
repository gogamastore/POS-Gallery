import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/promotion_model.dart';
import '../services/promo_service.dart';

// 1. Provider untuk service itu sendiri
final promoServiceProvider = Provider<PromoService>((ref) => PromoService());

// 2. StateNotifier untuk mengelola state promosi (tambah/hapus/refresh)
class PromoNotifier extends StateNotifier<AsyncValue<List<Promotion>>> {
  final PromoService _promoService;

  PromoNotifier(this._promoService) : super(const AsyncValue.loading()) {
    fetchPromotions();
  }

  Future<void> fetchPromotions() async {
    state = const AsyncValue.loading();
    try {
      final promotions = await _promoService.getPromotions();
      state = AsyncValue.data(promotions);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addPromotion({
    required String productId,
    required double discountPrice,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Opsi 1: Tampilkan loading di UI sementara aksi berjalan
    // state = const AsyncValue.loading(); 
    try {
      await _promoService.addPromotion(
        productId: productId,
        discountPrice: discountPrice,
        startDate: startDate,
        endDate: endDate,
      );
      await fetchPromotions(); // Ambil ulang data setelah berhasil
    } catch (e) {
      // Jika gagal, state akan kembali ke data sebelumnya secara otomatis
      // jika kita tidak mengubah state di sini. Atau kita bisa set state error.
      print("Failed to add promotion: $e");
      // Mungkin kita mau melempar error agar UI bisa menampilkannya
      rethrow;
    }
  }

  Future<void> deletePromotion(String promoId) async {
    try {
      await _promoService.deletePromotion(promoId);
      // Perbarui state dengan menghapus item secara lokal (lebih cepat)
      state = state.whenData((promotions) => 
          promotions.where((p) => p.promoId != promoId).toList()
      );
    } catch (e) {
      print("Failed to delete promotion: $e");
      // Jika gagal, kita bisa memuat ulang dari server untuk konsistensi
      fetchPromotions(); 
      rethrow;
    }
  }
}

// 3. Provider utama yang akan digunakan oleh UI
final promoProvider = StateNotifierProvider<PromoNotifier, AsyncValue<List<Promotion>>>((ref) {
  return PromoNotifier(ref.watch(promoServiceProvider));
});
