
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart'; 
import 'screens/auth/auth_screen.dart';
import 'screens/main_tab_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);

  // 1. Bungkus aplikasi dengan ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

// 2. Ubah menjadi ConsumerWidget
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Pindahkan tema ke sini jika perlu, atau biarkan seperti adanya.
    const primaryColor = Color(0xFF5DADE2);
    final theme = ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFF2C3E50),
          displayColor: const Color(0xFF2C3E50),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: primaryColor),
          titleTextStyle: GoogleFonts.inter(
            color: const Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ));

    // 4. Pantau status autentikasi menggunakan ref.watch
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Manafidh Store',
      theme: theme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const MainTabController(); // Pengguna login
          }
          return const AuthScreen(); // Pengguna tidak login
        },
        loading: () => const Center(child: CircularProgressIndicator()), // Tampilan loading
        error: (error, stack) => Center(child: Text('Terjadi error: $error')), // Tampilan error
      ),
    );
  }
}
