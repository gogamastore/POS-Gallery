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
    setState(() { _isLoading = true; });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      // Navigasi ditangani di widget utama (main.dart)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Gagal: Email atau password tidak valid')),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo Section
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/orderflow-r7jsk.firebasestorage.app/o/go%20logo.png?alt=media&token=cd0ae460-6836-4418-a44d-5c26fed509ec',
                      width: 100,
                      height: 100,
                    ),
                  
                  ],
                ),
              ),

              // Welcome Section
              const Text(
                'Selamat Datang',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, // Ini adalah cara yang benar
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan email dan password untuk masuk ke akun Anda.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center, // Ini juga
              ),
              const SizedBox(height: 32),

              // Email Input
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'email@contoh.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  fillColor: Colors.white,
                  filled: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              // Password Input
              const SizedBox(height: 20),
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  fillColor: Colors.white,
                  filled: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5DADE2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
