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
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(orderId: order.id),
          ),
        );
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
                    '#${order.id.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: formatter.getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatter.getStatusText(order.status),
                      style: TextStyle(
                        color: formatter.getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.customer,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.date.toDate()),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.products.length} item',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    currencyFormatter.format(double.tryParse(order.total) ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
