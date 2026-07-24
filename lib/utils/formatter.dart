import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Fungsi-fungsi ini sekarang terpusat di sini untuk digunakan di seluruh aplikasi.

String formatCurrency(double amount, {String symbol = 'Rp '}) {
  final formatter = NumberFormat.currency(locale: 'id_ID', symbol: symbol, decimalDigits: 0);
  return formatter.format(amount);
}

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
      return const Color(0xFF27AE60); // Green
    case 'shipped':
      return const Color(0xFF3498DB); // Blue
    case 'processing':
      return const Color(0xFFF39C12); // Orange
    case 'pending':
      return const Color(0xFFE74C3C); // Red
    case 'cancelled':
      return const Color(0xFF95A5A6); // Grey
    default:
      return const Color(0xFF7F8C8D); // Default Grey
  }
}

String getStatusText(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
      return 'Selesai';
    case 'shipped':
      return 'Dikirim';
    case 'processing':
      return 'Perlu Dikirim';
    case 'pending':
      return 'Belum Proses';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      // Membuat huruf pertama menjadi kapital secara otomatis
      return status.isNotEmpty
          ? status[0].toUpperCase() + status.substring(1)
          : 'N/A';
  }
}

Color getPaymentStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'paid':
      return const Color(0xFF27AE60); // Green
    case 'unpaid':
      return const Color(0xFFE74C3C); // Red
    case 'partial':
      return const Color(0xFFF39C12); // Orange
    default:
      return const Color(0xFF7F8C8D); // Default Grey
  }
}

String getPaymentStatusText(String? status) {
  switch (status?.toLowerCase()) {
    case 'paid':
      return 'Lunas';
    case 'unpaid':
      return 'Belum Lunas';
    case 'partial':
      return 'Sebagian';
    default:
      return 'N/A';
  }
}
