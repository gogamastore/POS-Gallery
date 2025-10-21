// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// Provider untuk instance AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// StreamProvider untuk memantau perubahan state autentikasi pengguna
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});