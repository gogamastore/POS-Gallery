
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseItem {
  final String id;
  final String category;
  final double amount;
  final String description;
  final DateTime date;

  ExpenseItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory ExpenseItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExpenseItem(
      id: doc.id,
      category: data['category'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
