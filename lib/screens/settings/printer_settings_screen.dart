import 'dart:async';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/printing_service.dart';
import 'usb_printer_list_screen.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  String? _defaultPrinterAddress;
  String? _defaultPrinterName;
  int _paperSize = 80;
  String _connectionType = 'bluetooth';

  // Use a future to manage permission state
  late Future<bool> _permissionsFuture;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadSettings();
      _permissionsFuture = _requestPermissions(); // Assign future on init
    }
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Location is often required for Bluetooth scanning
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Beberapa izin ditolak. Fungsionalitas Bluetooth mungkin terbatas.')),
      );
    }
    return allGranted;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _defaultPrinterAddress = prefs.getString('default_printer_address');
      _defaultPrinterName = prefs.getString('default_printer_name');
      _paperSize = prefs.getInt('printer_paper_size') ?? 80;
      _connectionType =
          prefs.getString('printer_connection_type') ?? 'bluetooth';
    });
  }

  Future<void> _setDefaultPrinter(dynamic device) async {
    if (kIsWeb) return;

    final String address = device.address ?? '';
    final String name = device.name ?? 'Unknown';

    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
              Text('Menyimpan printer...'),
            ],
          ),
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_printer_address', address);
      await prefs.setString('default_printer_name', name);
      await prefs.setString('printer_connection_type', _connectionType);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _defaultPrinterAddress = address;
        _defaultPrinterName = name;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('$name ditetapkan sebagai printer utama.')),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan printer: $e')),
      );
    }
  }

  Future<void> _setPaperSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printer_paper_size', size);
    if (!mounted) return;
    setState(() {
      _paperSize = size;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ukuran kertas diatur ke ${size}mm')),
    );
  }

  Future<void> _setConnectionType(String? type) async {
    if (type == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_connection_type', type);
    if (!mounted) return;
    setState(() {
      _connectionType = type;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tipe koneksi diatur ke ${type.toUpperCase()}')),
    );
  }

  Widget _buildConnectionTypeSelector() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text('Tipe Koneksi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('Bluetooth'),
              leading: Radio<String>(
                value: 'bluetooth',
                groupValue: _connectionType,
                onChanged: _setConnectionType,
              ),
              onTap: () => _setConnectionType('bluetooth'),
            ),
            ListTile(
              title: const Text('USB'),
              leading: Radio<String>(
                value: 'usb',
                groupValue: _connectionType,
                onChanged: _setConnectionType,
              ),
              onTap: () => _setConnectionType('usb'),
            ),
            // Use FutureBuilder to ensure permissions are checked before showing the dialog
            FutureBuilder<bool>(
                future: _permissionsFuture,
                builder: (context, snapshot) {
                  final permissionsGranted = snapshot.data ?? false;

                  if (_connectionType == 'bluetooth') {
                    return ListTile(
                      title: const Text('Pilih Printer Bluetooth'),
                      subtitle: Text(_defaultPrinterName != null &&
                              _connectionType == 'bluetooth'
                          ? 'Terpilih: $_defaultPrinterName'
                          : 'Ketuk untuk memilih'),
                      trailing: const Icon(Icons.chevron_right),
                      // Only enable if permissions are granted
                      enabled: permissionsGranted,
                      onTap: permissionsGranted
                          ? () async {
                              final selectedDevice =
                                  await showDialog<BluetoothDevice>(
                                context: context,
                                builder: (context) => _BluetoothDeviceDialog(),
                              );
                              if (selectedDevice != null) {
                                await _setDefaultPrinter(selectedDevice);
                              }
                            }
                          : null,
                    );
                  }
                  return const SizedBox.shrink(); // Hide if not bluetooth
                }),
            if (_connectionType == 'usb')
              ListTile(
                title: const Text('Pilih & Pasangkan Printer USB'),
                subtitle: Text(_defaultPrinterName != null && _connectionType == 'usb'
                    ? 'Terpilih: $_defaultPrinterName'
                    : 'Ketuk untuk memilih'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selectedDevice = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UsbPrinterListScreen(),
                    ),
                  );
                  if (selectedDevice != null) {
                    await _setDefaultPrinter(selectedDevice);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan Printer')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Pengaturan printer tidak tersedia di versi web.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer'),
      ),
      body: ListView(
        children: [
          _buildConnectionTypeSelector(),
          ListTile(
            title: const Text('Printer Default'),
            subtitle: Text(_defaultPrinterName ??
                _defaultPrinterAddress ??
                'Belum dipilih'),
            trailing: _defaultPrinterAddress != null
                ? const Icon(Ionicons.star, color: Colors.amber)
                : null,
          ),
          ListTile(
            title: const Text('Ukuran Kertas'),
            subtitle: Text('$_paperSize mm'),
            trailing: DropdownButton<int>(
              value: _paperSize,
              items: const [
                DropdownMenuItem(value: 58, child: Text('58 mm')),
                DropdownMenuItem(value: 80, child: Text('80 mm')),
              ],
              onChanged: (v) {
                if (v != null) _setPaperSize(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- REFACTORED BLUETOOTH DIALOG with FutureBuilder ---
class _BluetoothDeviceDialog extends StatefulWidget {
  @override
  State<_BluetoothDeviceDialog> createState() => _BluetoothDeviceDialogState();
}

class _BluetoothDeviceDialogState extends State<_BluetoothDeviceDialog> {
  final PrintingService _printingService = getPrintingService();
  late Future<List<dynamic>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    setState(() {
      _devicesFuture = _printingService.getBondedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pilih Printer Bluetooth'),
          IconButton(
            icon: const Icon(Ionicons.refresh),
            onPressed: _loadDevices,
            tooltip: 'Refresh Daftar',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<dynamic>>(
          future: _devicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tidak ada printer ter-pairing. Pastikan Bluetooth menyala dan printer sudah di-pairing di pengaturan HP Anda.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            } else {
              final devices = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index] as BluetoothDevice;
                  final name = device.name ?? 'Unknown Device';
                  final address = device.address ?? 'No Address';
                  return ListTile(
                    leading: const Icon(Ionicons.print_outline),
                    title: Text(name),
                    subtitle: Text(address),
                    onTap: () => Navigator.of(context).pop(device),
                  );
                },
              );
            }
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Batal'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
