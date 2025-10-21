import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

// Provider untuk mengambil dan mengurutkan semua data customer (users)
final customerListProvider = FutureProvider<List<AppUser>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('user').get();

  // Ubah setiap dokumen menjadi objek AppUser
  final users = snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();

  // Urutkan daftar user berdasarkan nama (A-Z), case-insensitive
  users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return users;
});
