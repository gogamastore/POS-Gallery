// lib/screens/main_tab_controller.dart (revisi)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'products/products_screen.dart';
import 'purchases/purchases_screen.dart'; // Import PurchasesScreen
import 'profile/profile_screen.dart'; // Import ProfileScreen
import 'pos/pos_screen.dart';
import 'orders/marketplace_orders_screen.dart';

class MainTabController extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainTabController({super.key, this.initialIndex = 0});

  @override
  MainTabControllerState createState() => MainTabControllerState();
}

class MainTabControllerState extends ConsumerState<MainTabController> {
  late int _selectedIndex;

  static final List<Widget> _widgetOptions = <Widget>[
    const PosScreen(), // Penjualan (kasir POS)
    const MarketplaceOrdersScreen(), // Pesanan (marketplace: biteship + midtrans)
    const ProductsScreen(),
    const PurchasesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

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
            icon: Icon(Icons.shopping_cart),
            label: 'Penjualan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Pesanan',
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
