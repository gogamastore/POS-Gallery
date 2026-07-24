import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/printing_service.dart';
import 'printer_picker.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrintingService _service = getPrintingService();

  PrinterDevice? _defaultPrinter;
  int _paperSize = 80;
  String _connectionType = 'bluetooth';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _service.loadDefaultPrinter();
    if (!mounted) return;
    setState(() {
      _defaultPrinter = saved;
      _paperSize = prefs.getInt('printer_paper_size') ?? 80;
      // Jika ada printer default, selaraskan tipe koneksi dengannya.
      _connectionType = saved != null
          ? (saved.connection == PrinterConnection.usb ? 'usb' : 'bluetooth')
          : (prefs.getString('printer_connection_type') ?? 'bluetooth');
    });
  }

  Future<void> _setDefaultPrinter(PrinterDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    await _service.saveDefaultPrinter(device);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_connection_type', _connectionType);
    if (!mounted) return;
    setState(() => _defaultPrinter = device);
    messenger.showSnackBar(
      SnackBar(content: Text('${device.name} ditetapkan sebagai printer utama.')),
    );
  }

  Future<void> _setPaperSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printer_paper_size', size);
    if (!mounted) return;
    setState(() => _paperSize = size);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ukuran kertas diatur ke ${size}mm')),
    );
  }

  Future<void> _setConnectionType(String? type) async {
    if (type == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_connection_type', type);
    if (!mounted) return;
    setState(() => _connectionType = type);
  }

  Future<void> _pickPrinter({required bool usb}) async {
    final selected = await showPrinterPicker(context, usb: usb);
    if (selected != null) await _setDefaultPrinter(selected);
  }

  Widget _buildConnectionCard() {
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
            // Opsi USB hanya di platform yang mendukungnya (Windows).
            if (_service.supportsUsb)
              ListTile(
                title: const Text('USB'),
                subtitle: const Text('Untuk PC tanpa Bluetooth'),
                leading: Radio<String>(
                  value: 'usb',
                  groupValue: _connectionType,
                  onChanged: _setConnectionType,
                ),
                onTap: () => _setConnectionType('usb'),
              ),
            const Divider(),
            if (_connectionType == 'bluetooth')
              ListTile(
                title: const Text('Pilih Printer Bluetooth'),
                subtitle: Text(_subtitleFor(PrinterConnection.bluetooth)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickPrinter(usb: false),
              ),
            if (_connectionType == 'usb' && _service.supportsUsb)
              ListTile(
                title: const Text('Pilih Printer USB'),
                subtitle: Text(_subtitleFor(PrinterConnection.usb)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickPrinter(usb: true),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(PrinterConnection type) {
    final d = _defaultPrinter;
    if (d != null && d.connection == type) return 'Terpilih: ${d.name}';
    return 'Ketuk untuk memilih';
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
      appBar: AppBar(title: const Text('Pengaturan Printer')),
      body: ListView(
        children: [
          _buildConnectionCard(),
          ListTile(
            title: const Text('Printer Default'),
            subtitle: Text(_defaultPrinter?.name ?? 'Belum dipilih'),
            trailing: _defaultPrinter != null
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
