import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? whatsapp;
  final String? role;
  final String? photoURL;
  final Timestamp createdAt;
  final String? shopName;
  final String? address; // Akan menangani kedua kasus

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.whatsapp,
    this.role,
    this.photoURL,
    required this.createdAt,
    this.shopName,
    this.address,
  });

  // Factory constructor cerdas untuk menangani struktur data yang berbeda
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Logika untuk mendapatkan alamat dari salah satu dari dua field
    String? finalAddress;
    if (data['address'] is String && (data['address'] as String).isNotEmpty) {
      finalAddress = data['address'] as String;
    } else if (data['addresses'] is Map) {
      // Jika 'addresses' adalah Map, coba ambil nilai dari kunci umum
      // atau ambil nilai pertama yang ditemukan. Ini bisa disesuaikan.
      final addressMap = data['addresses'] as Map<String, dynamic>;
      if (addressMap.containsKey('default')) {
        finalAddress = addressMap['default'].toString();
      } else if (addressMap.isNotEmpty) {
        finalAddress = addressMap.values.first.toString();
      }
    }
    
    return AppUser(
      id: doc.id,
      name: data['name'] ?? 'Tanpa Nama',
      email: data['email'] ?? 'Tidak ada email',
      whatsapp: data['whatsapp'] as String?,
      role: data['role'] as String?,
      photoURL: data['photoURL'] as String?,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      shopName: data['shopName'] as String?,
      address: finalAddress ?? 'Tidak ada alamat',
    );
  }
}
