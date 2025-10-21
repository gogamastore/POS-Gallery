import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../models/order_product.dart';
import '../../providers/order_provider.dart';
import '../../utils/formatter.dart';
import '../../utils/pdf_invoice_exporter.dart';
import './edit_order_screen.dart';
import './pos_validation_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailsProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          orderAsync.when(
            data: (order) {
              if (order == null) return const SizedBox.shrink();

              final showEditButton =
                  order.status != 'delivered' && order.status != 'cancelled';
              final showDownloadButton = [
                'processing',
                'shipped',
                'delivered'
              ].contains(order.status);

              return Row(
                children: [
                  if (showDownloadButton)
                    IconButton(
                      icon: const Icon(Ionicons.download_outline),
                      tooltip: 'Download Faktur',
                      onPressed: () async {
                        final pdfExporter = PdfInvoiceExporter();
                        final pdfBytes =
                            await pdfExporter.generateInvoice(order);
                        await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async => pdfBytes,
                            name: 'faktur_pesanan_${order.id}.pdf');
                      },
                    ),
                  if (showEditButton)
                    IconButton(
                      icon: const Icon(Ionicons.create_outline),
                      tooltip: 'Edit Pesanan',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditOrderScreen(order: order),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Gagal memuat: $err')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pesanan tidak ditemukan.'));
          }
          return _buildOrderDetailsView(context, ref, order);
        },
      ),
    );
  }

  Widget _buildOrderDetailsView(
      BuildContext context, WidgetRef ref, Order order) {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildInfoCard(order),
        const SizedBox(height: 12),
        _buildCustomerCard(order),
        const SizedBox(height: 12),
        _buildProductsCard(context, order),
        const SizedBox(height: 12),
        _buildPaymentInfoCard(context, order),
        const SizedBox(height: 12),
        _buildShippingInfoCard(order),
        const SizedBox(height: 20),
        _buildValidateButton(context, order),
        const SizedBox(height: 12),
        _buildCancelButton(context, ref, order),
      ],
    );
  }

  Widget _buildValidateButton(BuildContext context, Order order) {
    if (order.status == 'pending') {
      return ElevatedButton.icon(
        icon: const Icon(Ionicons.scan_outline, color: Colors.white),
        label: const Text('Validasi Pesanan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PosValidationScreen(order: order),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoCard(Order order) {
    return _buildCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No. Pesanan ${order.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMMM yyyy, HH:mm', 'id_ID')
                        .format(order.date.toDate()),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    getStatusColor(order.status).withAlpha(33), Colors.white),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                getStatusText(order.status),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(order.status),
                    fontSize: 12),
              ),
            ),
          ],
        ),
        if (order.kasir != null && order.kasir!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                Icon(Ionicons.person_circle_outline,
                    color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Text('Kasir: ',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Expanded(
                  child: Text(
                    order.kasir!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerCard(Order order) {
    return _buildCard(
      children: [
        const Text('Detail Pelanggan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        _buildCustomerDetailRow(Ionicons.person_outline, order.customer),
        if (order.customerPhone.isNotEmpty)
          _buildCustomerDetailRow(Ionicons.logo_whatsapp, order.customerPhone),
        _buildCustomerDetailRow(
            Ionicons.location_outline, order.customerAddress,
            isLast: true),
      ],
    );
  }

  Widget _buildCustomerDetailRow(IconData icon, String text,
      {bool isLast = false}) {
    if (text.isEmpty || text == '-') return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildProductsCard(BuildContext context, Order order) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final sortedProducts = List<OrderProduct>.from(order.products);
    sortedProducts
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final subtotal =
        sortedProducts.fold(0.0, (sum, p) => sum + (p.price * p.quantity));

    return _buildCard(
      children: [
        const Text('Produk Dipesan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        ...sortedProducts.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: CachedNetworkImage(
                  imageUrl: p.imageUrl ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[200],
                    child:
                        const Icon(Ionicons.image_outline, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[200],
                    child: const Icon(Ionicons.alert_circle_outline,
                        color: Colors.red),
                  ),
                ),
              ),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.sku != null && p.sku!.isNotEmpty)
                    Text('SKU: ${p.sku}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  Text('${p.quantity} x ${formatter.format(p.price)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              trailing: Text(formatter.format(p.price * p.quantity),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        const Divider(height: 20),
        _buildSummaryRow('Subtotal', subtotal),
        const SizedBox(height: 8),
        _buildSummaryRow('Ongkos Kirim', order.shippingFee ?? 0),
        const SizedBox(height: 12),
        _buildSummaryRow('Total', double.tryParse(order.total) ?? 0.0,
            isTotal: true),
      ],
    );
  }

  Widget _buildPaymentInfoCard(BuildContext context, Order order) {
    return _buildCard(
      children: [
        const Text('Informasi Pembayaran',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Status',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    getPaymentStatusColor(order.paymentStatus).withAlpha(38),
                    Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getPaymentStatusText(order.paymentStatus),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: getPaymentStatusColor(order.paymentStatus)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Metode',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                order.paymentMethod,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (order.paymentProofUrl != null && order.paymentProofUrl!.isNotEmpty)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Ionicons.receipt_outline, size: 18),
              label: const Text('Lihat Bukti Pembayaran'),
              onPressed: () async {
                final Uri url = Uri.parse(order.paymentProofUrl!);
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal membuka URL.')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                backgroundColor: Color.alphaBlend(
                    Theme.of(context).primaryColor.withAlpha(25), Colors.white),
                elevation: 0,
              ),
            ),
          )
        else
          const Center(
            child: Text('Bukti pembayaran belum diunggah.',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildShippingInfoCard(Order order) {
    return _buildCard(
      children: [
        const Text('Info Pengiriman',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        Row(
          children: [
            Icon(Ionicons.cube_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(order.shippingMethod,
                    style: const TextStyle(fontSize: 15))),
          ],
        )
      ],
    );
  }

  Widget _buildSummaryRow(String title, num value, {bool isTotal = false}) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: isTotal ? 18 : 15,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(formatter.format(value),
            style: TextStyle(
                fontSize: isTotal ? 20 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == 'pending' || order.status == 'processing') {
      return ElevatedButton.icon(
        icon: const Icon(Ionicons.close_circle_outline, color: Colors.white),
        label: const Text('Batalkan Pesanan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final bool? confirmed = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Konfirmasi Pembatalan'),
              content: const Text(
                  'Apakah Anda yakin ingin membatalkan pesanan ini?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Tidak'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ya, Batalkan',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              await ref
                  .read(orderServiceProvider)
                  .updateOrderStatus(order.id, 'cancelled');
              ref.invalidate(orderProvider);
              ref.invalidate(orderDetailsProvider(order.id));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Pesanan berhasil dibatalkan.'),
                      backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Gagal membatalkan pesanan: $e'),
                      backgroundColor: Colors.red),
                );
              }
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.alphaBlend(
                Colors.black.withAlpha(12), Colors.transparent),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
