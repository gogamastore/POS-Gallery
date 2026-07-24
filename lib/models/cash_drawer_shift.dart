
import 'package:cloud_firestore/cloud_firestore.dart';

class CashDrawerShift {
  final String id;
  final String cashierId;
  final String cashierName;
  final double startingCash;
  final Timestamp startTime;
  final Timestamp? endTime;
  final double? totalSales;
  final double? totalExpenses;
  final double? endingCash;
  final double? countedCash;
  final double? qrisOrTransfer;
  final double? declaredIncome;

  CashDrawerShift({
    this.id = '',
    required this.cashierId,
    required this.cashierName,
    required this.startingCash,
    required this.startTime,
    this.endTime,
    this.totalSales,
    this.totalExpenses,
    this.endingCash,
    this.countedCash,
    this.qrisOrTransfer,
    this.declaredIncome,
  });

  /// Konversi objek Shift menjadi Map untuk disimpan ke Firestore.
  Map<String, dynamic> toMap() {
    return {
      'cashierId': cashierId,
      'cashierName': cashierName,
      'startingCash': startingCash,
      'startTime': startTime,
      'endTime': endTime,
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'endingCash': endingCash,
      'countedCash': countedCash,
      'qrisOrTransfer': qrisOrTransfer,
      'declaredIncome': declaredIncome,
    };
  }

  /// Buat objek Shift dari Dokumen Firestore dengan aman.
  factory CashDrawerShift.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {}; // Menangani jika data null
    return CashDrawerShift(
      id: doc.id,
      cashierId: data['cashierId'] as String? ?? '', // Default ke string kosong
      cashierName: data['cashierName'] as String? ?? '',
      startingCash: (data['startingCash'] as num?)?.toDouble() ?? 0.0, // Default ke 0.0
      startTime: data['startTime'] as Timestamp? ?? Timestamp.now(), // Default ke waktu sekarang jika null
      endTime: data['endTime'] as Timestamp?,
      totalSales: (data['totalSales'] as num?)?.toDouble(),
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble(),
      endingCash: (data['endingCash'] as num?)?.toDouble(),
      countedCash: (data['countedCash'] as num?)?.toDouble(),
      qrisOrTransfer: (data['qrisOrTransfer'] as num?)?.toDouble(),
      declaredIncome: (data['declaredIncome'] as num?)?.toDouble(),
    );
  }
}
