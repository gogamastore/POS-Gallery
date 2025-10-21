// lib/main.dart (Revisi)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart'; // Impor Google Fonts
import 'package:intl/date_symbol_data_local.dart'; // Impor untuk inisialisasi lokal
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_tab_controller.dart'; // Import MainTabController

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // PERBAIKAN: Inisialisasi data lokal untuk Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    const primaryColor = Color(0xFF5DADE2); // Definisikan warna primer

    final theme = ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          primary: primaryColor,
          secondary: primaryColor, // Atur warna aksen juga
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF8F9FA), // Latar belakang netral
        textTheme:
            GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFF2C3E50), // Warna teks utama
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

    return MaterialApp(
      title: 'Gallery Makassar',
      theme: theme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const MainTabController(); // Arahkan ke tab controller
          }
          return const AuthScreen();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(child: Text('Terjadi kesalahan')),
      ),
    );
  }
}
