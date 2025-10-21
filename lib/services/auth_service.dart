import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> createCustomer({
    required String email,
    required String password,
    required String name,
    required String whatsapp,
    required String address,
    required String role,
  }) async {
    // --- SOLUSI AGAR ADMIN TIDAK LOGOUT ---
    // 1. Buat instance aplikasi Firebase sementara yang terisolasi
    final appName = 'temp_user_creation_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options, // Gunakan konfigurasi yang sama
    );

    try {
      // 2. Buat pengguna menggunakan instance auth dari aplikasi sementara
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? newUser = userCredential.user;

      if (newUser == null) {
        throw Exception('Gagal membuat pengguna, tidak ada data pengguna yang dikembalikan.');
      }

      // 3. Simpan detail user ke Firestore (tetap menggunakan instance utama)
      await _firestore.collection('user').doc(newUser.uid).set({
        'name': name,
        'email': email,
        'whatsapp': whatsapp,
        'address': address,
        'role': role,
        'createdAt': Timestamp.now(),
        'photoURL': '', 
      });

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'Alamat email ini sudah terdaftar. Silakan gunakan email lain.';
      } else if (e.code == 'weak-password') {
        throw 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      } else {
        throw 'Terjadi kesalahan saat pendaftaran. Silakan coba lagi.';
      }
    } catch (e) {
      rethrow;
    } finally {
      // 4. Hapus aplikasi sementara setelah selesai untuk membersihkan memori
      await tempApp.delete();
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _firebaseAuth.currentUser;

    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Pengguna tidak ditemukan atau tidak memiliki email. Silakan login ulang.',
      );
    }

    final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);

    try {
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Password lama yang Anda masukkan salah.',
        );
      }
      rethrow;
    }
  }
}
