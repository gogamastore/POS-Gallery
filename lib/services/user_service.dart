import 'dart:typed_data'; // DIIMPOR: Untuk Uint8List, menggantikan dart:io
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserService {
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('user');

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<UserModel?> getUserData(String uid) {
    return _userCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        try {
          final data = snapshot.data() as Map<String, dynamic>;
          return UserModel.fromJson({'uid': snapshot.id, ...data});
        } catch (e) {
          print('Gagal mem-parsing user dengan ID: $uid, error: $e');
          return null;
        }
      } else {
        return null; 
      }
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _userCollection.doc(uid).update(data);
    } catch (e) {
      print('Gagal memperbarui user dengan ID: $uid, error: $e');
      rethrow;
    }
  }

  // DIPERBAIKI: Menerima Uint8List agar kompatibel dengan web
  Future<String> uploadProfilePicture(String uid, Uint8List imageData) async {
    try {
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child(uid)
          .child(fileName);

      // Menggunakan putData untuk Uint8List
      final uploadTask = await storageRef.putData(imageData);

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Gagal mengunggah gambar profil: $e');
      rethrow;
    }
  }
}
