import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_model.dart';

final staffServiceProvider = Provider<StaffService>((ref) => StaffService());

// Provider untuk mendapatkan semua staff (admin dan kasir)
final staffStreamProvider = StreamProvider<List<Staff>>((ref) {
  final staffService = ref.watch(staffServiceProvider);
  return staffService.getStaffStream();
});

// BARU: Provider khusus untuk mendapatkan pengguna dengan role 'admin'
final adminUsersProvider = StreamProvider<List<Staff>>((ref) {
  final staffService = ref.watch(staffServiceProvider);
  return staffService.getAdminUsersStream();
});

class StaffService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection('user');

  Stream<List<Staff>> getStaffStream() {
    return _userCollection
        .where('role', whereIn: ['kasir', 'admin'])
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      } catch (e) {
        print('Error mapping staff stream: $e');
        return [];
      }
    });
  }

  // BARU: Fungsi untuk mengambil stream pengguna dengan role 'admin'
  Stream<List<Staff>> getAdminUsersStream() {
    return _userCollection
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      } catch (e) {
        print('Error mapping admin users stream: $e');
        return [];
      }
    });
  }

  Future<void> createStaff(String name, String email, String password, String position) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? newUser = userCredential.user;
    if (newUser == null) {
      throw Exception("Gagal membuat pengguna baru di Firebase Auth.");
    }

    String role = (position == 'Admin' || position == 'Owner') ? 'admin' : 'kasir';

    await _userCollection.doc(newUser.uid).set({
      'uid': newUser.uid,
      'name': name,
      'email': email,
      'position': position,
      'role': role,
      'photoURL': '',
      'phone': '',
      'whatsapp': '',
    });
  }

  Future<void> updateStaffRole(String uid, String newPosition) {
    String newRole = (newPosition == 'Admin' || newPosition == 'Owner') ? 'admin' : 'kasir';

    return _userCollection.doc(uid).update({
      'position': newPosition,
      'role': newRole,
    });
  }

  // DITAMBAHKAN: Fungsi untuk hanya memperbarui posisi
  Future<void> updateStaffPosition(String uid, String newPosition) {
    return _userCollection.doc(uid).update({
      'position': newPosition,
    });
  }

  Future<void> deleteStaff(String uid) async {
    await _userCollection.doc(uid).delete();
    print('User document for $uid deleted from Firestore.');
  }
}
