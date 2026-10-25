
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cash_drawer_shift.dart';
import '../models/user_model.dart';

// Mengambil data kasir dari koleksi 'user' dengan role 'admin'
final cashiersProvider = FutureProvider<List<UserModel>>((ref) async {
  final firestore = FirebaseFirestore.instance;
  try {
    final querySnapshot = await firestore
        .collection('user') // BENAR: koleksi 'user'
        .where('role', isEqualTo: 'admin') // BENAR: role 'admin'
        .get();

    final List<UserModel> cashiers = [];
    for (var doc in querySnapshot.docs) {
      try {
        Map<String, dynamic> data = doc.data();
        cashiers.add(UserModel.fromJson(data).copyWith(uid: doc.id));
      } catch (e, s) {
        developer.log(
          'Gagal mem-parsing dokumen user: ${doc.id}',
          error: e,
          stackTrace: s,
          level: 1000, 
        );
      }
    }
    return cashiers;
  } on FirebaseException catch (e, s) {
      developer.log('Firebase error getting cashiers', error: e, stackTrace: s, level: 1000);
      return [];
  } catch (e, s) {
    developer.log('Unexpected error getting cashiers', error: e, stackTrace: s, level: 1000);
    return [];
  }
});


class ShiftState {
  final CashDrawerShift? activeShift;
  final bool isLoading;

  const ShiftState({this.activeShift, this.isLoading = false});

  bool get isShiftActive => activeShift != null;

  ShiftState copyWith({
    CashDrawerShift? activeShift,
    bool? isLoading,
    bool clearActiveShift = false,
  }) {
    return ShiftState(
      activeShift: clearActiveShift ? null : activeShift ?? this.activeShift,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cashdrawers';
  
  ShiftNotifier() : super(const ShiftState()) {
    fetchActiveShift();
  }

  Future<void> fetchActiveShift() async {
    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('startTime', isLessThan: Timestamp.fromDate(tomorrow))
          .where('endTime', isNull: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        state = state.copyWith(
            activeShift: CashDrawerShift.fromDocument(querySnapshot.docs.first));
      } else {
        state = state.copyWith(clearActiveShift: true);
      }
    } on FirebaseException catch (e, s) {
      if (e.code == 'failed-precondition') {
        developer.log(
          'PENTING: BUAT INDEKS FIRESTORE! Kueri gagal. Buka Firebase Console -> Firestore -> Indexes dan buat indeks komposit untuk koleksi `cashdrawers` dengan fields: `startTime` (Ascending) dan `endTime` (Ascending).',
          error: e,
          stackTrace: s,
          level: 1000,
        );
      } else {
        developer.log('Firebase error fetching active shift', error: e, stackTrace: s);
      }
      state = state.copyWith(clearActiveShift: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> startShift(
      String cashierId, String cashierName, double startingCash) async {
    state = state.copyWith(isLoading: true);
    try {
      final Map<String, dynamic> shiftData = {
        'cashierId': cashierId,
        'cashierName': cashierName,
        'startingCash': startingCash,
        'startTime': Timestamp.now(),
        'endTime': null,
      };

      final docRef = await _firestore.collection(_collection).add(shiftData);
      final newShift = CashDrawerShift.fromDocument(await docRef.get());
      state = state.copyWith(activeShift: newShift, isLoading: false);
      return true;
    } catch (e, s) {
      developer.log('Error starting shift', error: e, stackTrace: s);
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<Map<String, double>> calculateShiftSummary(CashDrawerShift shift) async {
    final now = Timestamp.now();
    final startTime = shift.startTime;

    // Laci kas hanya berisi UANG TUNAI, jadi "Modal Akhir" dihitung dari
    // penjualan POS TUNAI yang berhasil selama shift. Penjualan QRIS/Transfer
    // tidak menambah uang di laci (dimasukkan manual saat menutup shift).
    // Field total order = `total` (BUKAN `totalPrice`); dibaca null-safe agar
    // order tanpa nilai tidak menyebabkan crash cast.
    final salesSnapshot = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startTime)
        .where('createdAt', isLessThanOrEqualTo: now)
        .get();

    // Hanya transaksi milik kasir shift ini (cashierId) yang direkonsiliasi.
    final cashierId = shift.cashierId;

    double cashSales = 0.0;
    // Penjualan POS NON-TUNAI (QRIS/Transfer/Midtrans) milik kasir ini selama
    // shift — dipakai untuk mengisi otomatis kotak "QRIS / Transfer" saat
    // mengakhiri shift. Uang ini TIDAK masuk laci (tidak menambah endingCash).
    double nonCashSales = 0.0;
    for (final doc in salesSnapshot.docs) {
      final d = doc.data();
      final isPos = (d['source'] as String?) == 'pos';
      final status = (d['status'] as String? ?? '').toLowerCase();
      final method = (d['paymentMethod'] as String? ?? '').toLowerCase();
      final docCashier = d['cashierId'] as String?;
      if (isPos && status == 'success' && docCashier == cashierId) {
        final amt = (d['total'] as num?)?.toDouble() ?? 0.0;
        if (method == 'cash' || method == 'tunai') {
          cashSales += amt;
        } else {
          nonCashSales += amt;
        }
      }
    }

    // Pesanan MARKETPLACE "Ambil di Toko" yang DIVALIDASI (dibayar di meja
    // kasir) selama shift juga masuk laci — uangnya diterima di kasir. Memakai
    // `validatedAt` (waktu dibayar/divalidasi), BUKAN `createdAt`, karena
    // pesanan bisa dibuat jauh sebelum diambil. COD/tunai → Penjualan Tunai
    // (menambah Modal Akhir); QRIS/Midtrans/Transfer → QRIS/Transfer (tidak
    // menambah Modal Akhir). Dicocokkan ke kasir shift ini.
    final pickupSnapshot = await _firestore
        .collection('orders')
        .where('validatedAt', isGreaterThanOrEqualTo: startTime)
        .where('validatedAt', isLessThanOrEqualTo: now)
        .get();
    for (final doc in pickupSnapshot.docs) {
      final d = doc.data();
      if ((d['source'] as String?) != 'marketplace') continue;
      final ship = (d['shippingMethod'] as String? ?? '').trim().toLowerCase();
      if (ship != 'ambil di toko') continue;
      if ((d['cashierId'] as String?) != cashierId) continue;
      final status = (d['status'] as String? ?? '').toLowerCase();
      if (status != 'delivered' &&
          status != 'success' &&
          status != 'processing' &&
          status != 'shipped') {
        continue;
      }
      final method = (d['paymentMethod'] as String? ?? '').toLowerCase();
      final amt = (d['total'] as num?)?.toDouble() ?? 0.0;
      if (method == 'cash' || method == 'tunai' || method == 'cod') {
        cashSales += amt;
      } else {
        nonCashSales += amt;
      }
    }

    final expensesSnapshot = await _firestore
        .collection('operational_expenses')
        .where('date', isGreaterThanOrEqualTo: startTime)
        .where('date', isLessThanOrEqualTo: now)
        .get();
    double totalExpenses = 0.0;
    for (final doc in expensesSnapshot.docs) {
      final e = doc.data();
      if ((e['cashierId'] as String?) == cashierId) {
        totalExpenses += (e['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'totalSales': cashSales,
      'qrisOrTransfer': nonCashSales,
      'totalExpenses': totalExpenses,
      'endingCash': shift.startingCash + cashSales - totalExpenses,
    };
  }

  Future<bool> endShift(double countedCash, double qrisOrTransfer) async {
    if (state.activeShift == null) return false;
    state = state.copyWith(isLoading: true);

    try {
      final calculations = await calculateShiftSummary(state.activeShift!);
      await _firestore.collection(_collection).doc(state.activeShift!.id).update({
        'endTime': Timestamp.now(),
        'totalSales': calculations['totalSales'],
        'totalExpenses': calculations['totalExpenses'],
        'endingCash': calculations['endingCash'],
        'countedCash': countedCash,
        'qrisOrTransfer': qrisOrTransfer,
        'declaredIncome': countedCash + qrisOrTransfer,
      });

      state = state.copyWith(clearActiveShift: true, isLoading: false);
      return true;
    } catch (e, s) {
      developer.log('Error ending shift', error: e, stackTrace: s);
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier();
});
