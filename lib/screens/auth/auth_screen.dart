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

  // Foto promo login (Firebase Storage) — dipakai sebagai panel kiri (desktop)
  // & background penuh (mobile).
  static const _promoImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/gallerypos.firebasestorage.app/o/latar%20app.png?alt=media&token=efd771c3-da73-4082-bc3d-b05bee235b43';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Layar lebar (desktop/tablet landscape): dua panel — kiri foto
          // promo, kanan form. Layar sempit (mobile): foto jadi background
          // penuh dengan kartu form di atasnya.
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(child: _promoImage()),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: _buildForm(),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _promoImage(),
              Container(color: Colors.black.withValues(alpha: 0.4)),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildForm(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _promoImage() {
    return Image.network(
      _promoImageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFE91E8C),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        color: const Color(0xFFE91E8C),
        alignment: Alignment.center,
        child: const Icon(Icons.storefront, color: Colors.white70, size: 64),
      ),
    );
  }

  Widget _buildForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo Section
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Image.network(
              'https://firebasestorage.googleapis.com/v0/b/gallerypos.firebasestorage.app/o/Manafidh%20Logo.png?alt=media&token=4472e2c9-c319-4222-85e8-708dbf36e7be',
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
              color: Color(0xFF1A5276),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Masuk ke akun Anda untuk melanjutkan',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF566573),
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
                  borderRadius: BorderRadius.circular(12)),
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
                  borderRadius: BorderRadius.circular(12)),
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
              backgroundColor: const Color(0xFF3498DB),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 5,
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
    );
  }
}
