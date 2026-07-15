
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

    final salesSnapshot = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startTime)
        .where('createdAt', isLessThanOrEqualTo: now)
        .get();
    final totalSales = salesSnapshot.docs.fold(0.0, (total, doc) => total + (doc.data()['totalPrice'] as num));

    final expensesSnapshot = await _firestore
        .collection('operational_expenses')
        .where('date', isGreaterThanOrEqualTo: startTime)
        .where('date', isLessThanOrEqualTo: now)
        .get();
    final totalExpenses = expensesSnapshot.docs.fold(0.0, (total, doc) => total + (doc.data()['amount'] as num));

    return {
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'endingCash': shift.startingCash + totalSales - totalExpenses,
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
