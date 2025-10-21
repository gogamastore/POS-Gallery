import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id; // Document ID from Firestore
  final String name;
  final String email;
  final String role; // 'admin' atau 'kasir'
  final String position; // 'Admin', 'Kasir', 'Owner'
  final String photoURL;

  Staff({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.position,
    this.photoURL = '',
  });

  // Factory constructor untuk membuat instance Staff dari dokumen Firestore
  factory Staff.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Staff(
      id: doc.id,
      name: data['name'] ?? 'Tanpa Nama',
      email: data['email'] ?? 'Tanpa Email',
      role: data['role'] ?? 'kasir', 
      position: data['position'] ?? 'Kasir', // Menambahkan position
      photoURL: data['photoURL'] ?? '',
    );
  }
}
