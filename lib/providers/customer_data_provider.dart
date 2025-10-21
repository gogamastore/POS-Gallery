import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider yang membuat Map<userId, userName> dari koleksi 'user'.
// Dibuat terpisah agar tidak mengganggu provider pengguna yang sudah ada.
final customerMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('user').get();
  
  final customersMap = <String, String>{};
  for (final doc in snapshot.docs) {
    final data = doc.data();
    // Pastikan field 'name' ada dan tidak null sebelum ditambahkan
    if (data.containsKey('name') && data['name'] != null) {
       customersMap[doc.id] = data['name'] as String;
    }
  }
  return customersMap;
});
