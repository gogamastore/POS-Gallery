import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/printing_service.dart';
import 'usb_printer_list_screen.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrintingService _printingService = getPrintingService();
  StreamSubscription<List<dynamic>>? _scanSubscription;
  List<dynamic> _devices = [];
  bool _isScanning = false;
  String? _defaultPrinterAddress;
  String? _defaultPrinterName;
  int _paperSize = 80;
  String _connectionType = 'bluetooth';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadSettings().then((_) => _startScan());
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    if (!kIsWeb) {
      _printingService.stopScan();
    }
    super.dispose();
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

  void _startScan() {
    if (kIsWeb || !mounted) return;

    _scanSubscription?.cancel();

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    if (_connectionType == 'bluetooth') {
      _printingService.startScan(isBle: false); // For classic bluetooth
      _scanSubscription = _printingService.scanResults.listen((devices) {
        if (!mounted) return;
        setState(() {
          _devices = devices;
          _isScanning = false; // scan finishes when it finds devices
        });
      }, onError: (e) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
      });
    } else {
      // For USB, we handle scanning in a separate screen
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _setDefaultPrinter(dynamic device) async {
    if (kIsWeb) return;

    final String address = device.address ?? '';
    final String name = device.name ?? 'Unknown';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_printer_address', address);
    await prefs.setString('default_printer_name', name);

    if (!mounted) return;

    setState(() {
      _defaultPrinterAddress = address;
      _defaultPrinterName = name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ditetapkan sebagai printer utama.')),
    );
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
      _devices = []; // Clear device list when changing type
    });

    if (type == 'bluetooth') {
      _startScan();
    }

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
            if (_connectionType == 'usb')
              ListTile(
                title: const Text('Pilih & Pasangkan Printer USB'),
                subtitle: Text(_defaultPrinterName != null
                    ? 'Terpilih: $_defaultPrinterName'
                    : 'Ketuk untuk memilih'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (!mounted) return;
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
        actions: [
          if (_connectionType == 'bluetooth')
            _isScanning
                ? const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Ionicons.refresh_outline),
                    onPressed: _startScan,
                    tooltip: 'Scan Ulang',
                  ),
        ],
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
          const Divider(),
          if (_connectionType == 'bluetooth')
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Perangkat Bluetooth Ter-pairing',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          if (_connectionType == 'bluetooth')
            ..._devices.map((device) {
              final name = device.name ?? 'Unknown';
              final address = device.address ?? 'No Address';
              final isDefault = address == _defaultPrinterAddress;

              return ListTile(
                leading: Icon(
                    isDefault ? Ionicons.print : Ionicons.print_outline),
                title: Text(name),
                subtitle: Text(address),
                onTap: () => _setDefaultPrinter(device),
                selected: isDefault,
                selectedTileColor:
                    Theme.of(context).primaryColor.withAlpha(25),
              );
            }),
        ],
      ),
    );
  }
}
