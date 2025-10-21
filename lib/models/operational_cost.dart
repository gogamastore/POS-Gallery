import 'package:cloud_firestore/cloud_firestore.dart';

class OperationalCost {
  final String? id;
  final String category;
  final double amount;
  final String description;
  final Timestamp date;

  OperationalCost({
    this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory OperationalCost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OperationalCost(
      id: doc.id,
      category: data['category'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      date: data['date'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'amount': amount,
      'description': description,
      'date': date,
    };
  }
}
