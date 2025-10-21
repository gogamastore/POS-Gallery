import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

// Provider untuk instance UserService
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

// StreamProvider untuk mendapatkan data user secara real-time
final userDataProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userService = ref.watch(userServiceProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        // Jika user login, ambil data user dari Firestore
        return userService.getUserData(user.uid);
      } else {
        // Jika tidak ada user login, kembalikan stream dengan data null
        return Stream.value(null);
      }
    },
    loading: () => Stream.value(null), // Saat loading, tidak ada data user
    error: (_, __) => Stream.value(null), // Jika ada error, tidak ada data user
  );
});
