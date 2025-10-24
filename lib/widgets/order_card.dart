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
        if (order.id != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
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
                    '#${order.id?.substring(0, 8) ?? 'N/A'}...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
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
              _buildInfoRow(
                icon: Icons.person_outline,
                // PERBAIKAN: Mengakses nama pelanggan dari 'customer'
                text: order.customer ?? 'Nama Pelanggan Tidak Ada',
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
                    // PERBAIKAN: Mengonversi num ke double
                    formatter.formatCurrency(order.total.toDouble()),
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
