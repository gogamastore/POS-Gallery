import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/order.dart';
import 'package:myapp/screens/orders/order_detail_screen.dart';
import 'package:myapp/utils/formatter.dart' as formatter;

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Mencegah navigasi jika ID null
        if (order.id != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              // PERBAIKAN 1: Memastikan order.id tidak null saat dikirim.
              builder: (context) => OrderDetailScreen(orderId: order.id!),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // PERBAIKAN 2: Menangani ID yang bisa null dengan aman.
                    '#${order.id?.substring(0, 8) ?? 'N/A'}...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      // PERBAIKAN 3: Menggunakan .withAlpha untuk menghindari deprecation warning.
                      color: formatter.getStatusColor(order.status).withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: formatter.getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Asumsi dari error, widget ini menampilkan nama pelanggan dan tanggal.
              _buildInfoRow(
                icon: Icons.person_outline,
                // PERBAIKAN 4: Mengakses nama pelanggan dari map `customerDetails`.
                text: order.customerDetails?['name'] ?? 'Nama Pelanggan Tidak Ada',
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('d MMMM yyyy, HH:mm').format(order.date.toDate()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    // PERBAIKAN 5: Memformat nilai total menjadi String.
                    formatter.formatCurrency(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk konsistensi
  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}
