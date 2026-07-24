import 'package:cloud_functions/cloud_functions.dart';

/// Wrapper untuk Cloud Functions Biteship (region asia-southeast1), sama
/// dengan yang dipakai halaman web dashboard pesanan.
///
/// Fungsi `createBiteshipOrder` di server membuat order kurir, menulis field
/// biteship (resi/tracking) ke dokumen `orders`, DAN menyetel `status:'shipped'`
/// secara otomatis — jadi klien cukup memanggilnya.
class BiteshipService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  /// Membuat order kurir untuk pesanan. Mengembalikan info resi/tracking.
  /// Melempar [FirebaseFunctionsException] bila gagal (mis. tarif/kurir belum
  /// diset) — penelepon menampilkan pesan `e.message`.
  Future<BiteshipResult> createOrder(String orderId) async {
    final callable = _functions.httpsCallable('createBiteshipOrder');
    final res = await callable.call<Map<String, dynamic>>({'orderId': orderId});
    final data = res.data;
    return BiteshipResult(
      success: data['success'] == true,
      biteshipOrderId: data['biteshipOrderId'] as String?,
      courierTrackingId: data['courierTrackingId'] as String?,
      waybillId: data['waybillId'] as String?,
      trackingUrl: data['trackingUrl'] as String?,
      status: data['status'] as String?,
    );
  }

  /// Melacak status pengiriman terkini.
  Future<Map<String, dynamic>> track(String orderId) async {
    final callable = _functions.httpsCallable('trackBiteshipOrder');
    final res = await callable.call<Map<String, dynamic>>({'orderId': orderId});
    return Map<String, dynamic>.from(res.data);
  }
}

class BiteshipResult {
  final bool success;
  final String? biteshipOrderId;
  final String? courierTrackingId;
  final String? waybillId;
  final String? trackingUrl;
  final String? status;

  const BiteshipResult({
    required this.success,
    this.biteshipOrderId,
    this.courierTrackingId,
    this.waybillId,
    this.trackingUrl,
    this.status,
  });
}
