import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String? address;
  final String? whatsapp;
  final Timestamp createdAt;

  Customer({
    required this.id,
    required this.name,
    this.address,
    this.whatsapp,
    required this.createdAt,
  });

  // Untuk membaca data dari Firestore
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] as String?,
      whatsapp: data['whatsapp'] as String?,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Untuk menulis data ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'whatsapp': whatsapp,
      'createdAt': createdAt,
    };
  }
}
