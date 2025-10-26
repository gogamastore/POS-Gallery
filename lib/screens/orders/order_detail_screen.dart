import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/printing_service.dart';
import '../../utils/formatter.dart';
import '../pos/process_pos_screen.dart';
import 'edit_order_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final PrintingService _printingService = PrintingService();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handlePrint(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('default_printer_address');
    final name = prefs.getString('default_printer_name');

    if (address != null && address.isNotEmpty && name != null) {
      // create a minimal device object expected by BLE lib (may vary per platform)
      final dynamic defaultDevice = {
        'name': name,
        'address': address,
      };
      await _connectAndPrint(defaultDevice, order);
    } else {
      if (!mounted) return;
      await _showPrintDialog(context, order);
    }
  }

  Future<void> _connectAndPrint(dynamic device, Order order) async {
    if (!mounted) return; // Guard before first async gap

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Menghubungkan & Mencetak...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Attempt to connect using the printing service (best-effort)
      await _printingService.connectToDevice(device);

      // Build ESC/POS bytes using service (reads paper size from prefs if set)
      final prefs = await SharedPreferences.getInstance();
      final paperSize = prefs.getInt('printer_paper_size') ?? 80;
      final bytes =
          await _printingService.buildReceiptBytes(order, paperSize: paperSize);

      // Try writing bytes to device using bluetooth_low_energy package.
      final wrote = await _tryWriteBytes(device, bytes);

      // Disconnect best-effort
      try {
        await _printingService.disconnect();
      } catch (_) {}

      Navigator.of(context, rootNavigator: true).pop();

      if (wrote) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dikirim ke printer.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Gagal mengirim struk ke printer. Pastikan UUID write benar.')),
        );
      }
    } catch (e, s) {
      developer.log('Error printing: $e', stackTrace: s);
      if (!mounted) return; // Guard in catch block
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saat mencetak: $e')),
      );
    }
  }

  /// Best-effort writer: tries several common write methods exposed by BLE
  /// libraries. Returns true if any attempt succeeds.
  Future<bool> _tryWriteBytes(dynamic device, Uint8List bytes) async {
    // first try using saved service/characteristic UUID via PrintingService
    try {
      final saved = await _printingService.writeUsingSavedUuid(device, bytes);
      if (saved) return true;
    } catch (_) {}

    // device-level methods
    try {
      await device.write(bytes);
      return true;
    } catch (_) {}

    try {
      await device.writeCharacteristic(bytes);
      return true;
    } catch (_) {}

    try {
      await device.writeBytes(bytes);
      return true;
    } catch (_) {}

    // discover services via device object and try characteristics
    try {
      dynamic services;
      try {
        services = await device.discoverServices?.call();
      } catch (_) {
        try {
          services = device.services ?? device.discoveredServices;
        } catch (_) {
          services = null;
        }
      }

      if (services != null) {
        for (var svc in services) {
          final characteristics = svc?.characteristics ?? svc?.chars ?? [];
          for (var ch in characteristics) {
            try {
              await ch.write(bytes);
              return true;
            } catch (_) {}
            try {
              await ch.writeWithoutResponse(bytes);
              return true;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> _showPrintDialog(BuildContext context, Order order) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return _BluetoothDeviceDialog(
          order: order,
          printingService: _printingService,
          onDeviceSelected: (device) async {
            Navigator.of(dialogContext).pop();
            await _connectAndPrint(device, order);
          },
        );
      },
    );
  }

  Future<void> _processOrder(
      BuildContext context, WidgetRef ref, Order order) async {
    ref.read(posCartProvider.notifier).clearCart();
    final productsAsyncValue = ref.read(allProductsProvider);
    final allProducts = productsAsyncValue.asData?.value;

    if (allProducts == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data produk. Coba lagi.')),
      );
      return;
    }

    for (var orderProduct in order.products) {
      try {
        final product =
            allProducts.firstWhere((p) => p.id == orderProduct['productId']);
        ref.read(posCartProvider.notifier).addItem(
              product,
              orderProduct['quantity'] as int,
              (orderProduct['price'] as num).toDouble(),
            );
      } catch (e, s) {
        developer.log(
            'Produk dengan ID ${orderProduct['productId']} tidak ditemukan lagi.',
            name: 'OrderDetail',
            error: e,
            stackTrace: s);
        continue;
      }
    }

    await ref.read(orderActionsProvider.notifier).deleteOrder(order.id!);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ProcessPosScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          orderAsync.when(
            data: (order) => order != null
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Ionicons.print_outline),
                        tooltip: 'Cetak Struk',
                        onPressed: () => _handlePrint(order),
                      ),
                      IconButton(
                        icon: const Icon(Ionicons.create_outline),
                        tooltip: 'Edit Pesanan',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditOrderScreen(order: order),
                            ),
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          )
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pesanan tidak ditemukan.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailsProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  context,
                  title: 'Informasi Pelanggan',
                  icon: Ionicons.person_circle_outline,
                  children: [
                    _buildDetailRow(
                        'Nama', order.customerDetails?['name'] ?? 'N/A'),
                    _buildDetailRow(
                        'Alamat', order.customerDetails?['address'] ?? 'N/A'),
                    _buildWhatsAppRow(
                        context, order.customerDetails?['whatsapp']),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Detail Pesanan',
                  icon: Ionicons.receipt_outline,
                  children: [
                    _buildDetailRow(
                        'ID Pesanan', order.id?.substring(0, 8) ?? 'N/A'),
                    _buildDetailRow(
                        'Tanggal',
                        DateFormat('d MMMM y, HH:mm', 'id_ID')
                            .format(order.date.toDate())),
                    _buildDetailRow('Status', order.status),
                    _buildDetailRow('Kasir', order.kasir),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Produk Dipesan',
                  icon: Ionicons.cube_outline,
                  children: [
                    for (var product in order.products)
                      _buildProductTile(product),
                  ],
                ),
                _buildSection(
                  context,
                  title: 'Ringkasan Pembayaran',
                  icon: Ionicons.card_outline,
                  children: [
                    _buildDetailRow('Metode Pembayaran', order.paymentMethod),
                    _buildDetailRow('Status Pembayaran', order.paymentStatus),
                    const Divider(height: 20),
                    _buildTotalRow(
                        'Subtotal', formatCurrency(order.subtotal.toDouble())),
                    _buildTotalRow(
                        'Total', formatCurrency(order.total.toDouble()),
                        isTotal: true),
                  ],
                ),
                if (order.status.toLowerCase() != 'cancelled' &&
                    order.status.toLowerCase() != 'success')
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      children: [
                        if (order.status.toLowerCase() == 'processing')
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Ionicons.play_circle_outline),
                              label: const Text('Proses'),
                              onPressed: () =>
                                  _processOrder(context, ref, order),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (order.status.toLowerCase() == 'processing')
                          const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Ionicons.close_circle_outline),
                            label: const Text('Batalkan'),
                            onPressed: () =>
                                _showCancelConfirmation(context, ref, order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Gagal memuat detail: $e')),
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 18 : 16,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 6 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  style.copyWith(color: isTotal ? null : Colors.grey.shade600)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> product) {
    final imageUrl = product['imageUrl'] as String?;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Ionicons.image_outline, size: 50),
              ),
            )
          : const Icon(Ionicons.cube_outline, size: 40),
      title: Text(product['name'] ?? 'Nama Produk Tidak Ada'),
      subtitle: Text(
          '${product['quantity']} x ${formatCurrency((product['price'] as num).toDouble())}'),
      trailing: Text(
        formatCurrency((product['quantity'] as int) *
            (product['price'] as num).toDouble()),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildWhatsAppRow(BuildContext context, String? whatsappNumber) {
    if (whatsappNumber == null || whatsappNumber.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('WhatsApp', style: TextStyle(color: Colors.grey.shade600)),
          TextButton.icon(
            icon: const Icon(Ionicons.logo_whatsapp, size: 18),
            label: Text(whatsappNumber),
            onPressed: () async {
              final url = Uri.parse('https://wa.me/$whatsappNumber');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          )
        ],
      ),
    );
  }

  void _showCancelConfirmation(
      BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text(
            'Apakah Anda yakin ingin membatalkan pesanan ini? Stok produk akan dikembalikan jika sebelumnya sudah dikurangi.'),
        actions: [
          TextButton(
            child: const Text('Tidak'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Ya, Batalkan'),
            onPressed: () {
              ref
                  .read(orderActionsProvider.notifier)
                  .updateOrderStatus(order.id!, 'Cancelled');
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _BluetoothDeviceDialog extends StatefulWidget {
  final Order order;
  final PrintingService printingService;
  final Function(dynamic) onDeviceSelected;

  const _BluetoothDeviceDialog(
      {required this.order,
      required this.printingService,
      required this.onDeviceSelected});

  @override
  State<_BluetoothDeviceDialog> createState() => _BluetoothDeviceDialogState();
}

class _BluetoothDeviceDialogState extends State<_BluetoothDeviceDialog> {
  StreamSubscription<List<dynamic>>? _scanSubscription;
  List<dynamic> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    widget.printingService.stopScan();
    super.dispose();
  }

  void _startScan() {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _devices = [];
    });
    widget.printingService.startScan();
    _scanSubscription = widget.printingService.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pilih Printer'),
          if (_isScanning)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
                icon: const Icon(Ionicons.refresh),
                onPressed: _startScan,
                tooltip: 'Scan Ulang')
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _devices.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _isScanning
                        ? 'Mencari printer...'
                        : 'Tidak ada printer ter-pairing. Pastikan Bluetooth menyala.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final name = device?.name ??
                      device?.localName ??
                      device?.deviceName ??
                      'Unknown Device';
                  final address = device?.address ??
                      device?.id ??
                      device?.deviceId ??
                      'No Address';
                  return ListTile(
                    leading: const Icon(Ionicons.print_outline),
                    title: Text(name.toString()),
                    subtitle: Text(address.toString()),
                    onTap: () => widget.onDeviceSelected(device),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
