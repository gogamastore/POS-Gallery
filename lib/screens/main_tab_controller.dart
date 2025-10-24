// lib/screens/main_tab_controller.dart (revisi)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard/dashboard_screen.dart';
import 'products/products_screen.dart';
import 'purchases/purchases_screen.dart'; // Import PurchasesScreen
import 'profile/profile_screen.dart'; // Import ProfileScreen
import 'pos/pos_screen.dart';

class MainTabController extends ConsumerStatefulWidget {
  const MainTabController({super.key});

  @override
  MainTabControllerState createState() => MainTabControllerState();
}

class MainTabControllerState extends ConsumerState<MainTabController> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardScreen(),
    const PosScreen(), // Ganti placeholder dengan PosScreen
    const ProductsScreen(),
    const PurchasesScreen(), // Ganti placeholder dengan PurchasesScreen
    const ProfileScreen(), // Ganti placeholder dengan ProfileScreen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Penjualan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Pembelian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF5DADE2),
        unselectedItemColor: const Color(0xFF7F8C8D),
        onTap: _onItemTapped,
      ),
    );
  }
}
