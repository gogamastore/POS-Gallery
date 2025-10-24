// lib/screens/auth/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            _emailController.text,
            _passwordController.text,
          );
      // Navigasi ditangani di widget utama (main.dart)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Login Gagal: Email atau password tidak valid')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: Center( // 1. Menambahkan Center untuk memposisikan konten di tengah
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), // Sedikit padding ekstra
          child: ConstrainedBox( // 2. Membatasi lebar maksimum
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center, // Pusatkan secara vertikal juga
              children: [
                // Logo Section
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/gallery-makassar.firebasestorage.app/o/GM%20logo.png?alt=media&token=35855c49-17b5-4a6d-9887-45134c7ad829',
                    width: 100,
                    height: 100,
                  ),
                ),

                // Welcome Section
                const Text(
                  'Selamat Datang',
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5276), // Warna lebih gelap
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masuk ke akun Anda untuk melanjutkan',
                  style: TextStyle(
                    fontSize: 16, 
                    color: Color(0xFF566573), // Warna abu-abu yang lebih lembut
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Email Input
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'email@contoh.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)), // Sudut lebih bulat
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),

                // Password Input
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)), // Sudut lebih bulat
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB), // Warna biru yang lebih cerah
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)), // Sudut lebih bulat
                    elevation: 5, // Tambah sedikit bayangan
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('Masuk',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
