import 'package:flutter/material.dart';

/// Badge status pesanan — label & warna mengikuti web (dashboard/orders).
class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  static const Map<String, (String, Color)> _map = {
    'pending': ('Menunggu', Colors.orange),
    'processing': ('Diproses', Colors.blue),
    'shipped': ('Dikirim', Colors.cyan),
    'dikirim': ('Dikirim', Colors.cyan),
    'delivered': ('Selesai', Colors.green),
    'selesai': ('Selesai', Colors.green),
    'cancelled': ('Dibatalkan', Colors.red),
    'dibatalkan': ('Dibatalkan', Colors.red),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _map[status.toLowerCase()] ?? (status, Colors.grey);
    return OrderPill(label: cfg.$1, color: cfg.$2);
  }
}

/// Badge status pembayaran — mengikuti web (termasuk status Midtrans).
class PaymentStatusBadge extends StatelessWidget {
  final String status;
  const PaymentStatusBadge({super.key, required this.status});

  static const Map<String, (String, Color)> _map = {
    'paid': ('Lunas', Colors.green),
    'settlement': ('Lunas', Colors.green),
    'pending_payment': ('Belum Bayar', Colors.orange),
    'cancelled': ('Dibatalkan', Colors.red),
    'failed': ('Kadaluarsa', Colors.red),
    'unpaid': ('Belum Lunas', Colors.amber),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _map[status.toLowerCase()] ?? (status, Colors.grey);
    return OrderPill(label: cfg.$1, color: cfg.$2);
  }
}

class OrderPill extends StatelessWidget {
  final String label;
  final Color color;
  const OrderPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
