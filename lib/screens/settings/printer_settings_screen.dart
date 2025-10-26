import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/printing_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrintingService _printingService = PrintingService();
  StreamSubscription<List<dynamic>>? _scanSubscription;
  List<dynamic> _devices = [];
  bool _isScanning = false;
  String? _defaultPrinterAddress;
  String? _defaultPrinterName;
  int _paperSize = 80; // default, can be 58 or 80

  @override
  void initState() {
    super.initState();
    _loadDefaultPrinter();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _printingService.stopScan();
    super.dispose();
  }

  Future<void> _loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultPrinterAddress = prefs.getString('default_printer_address');
      _defaultPrinterName = prefs.getString('default_printer_name');
      _paperSize = prefs.getInt('printer_paper_size') ?? 80;
    });
  }

  void _startScan() {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    _printingService.startScan();
    _scanSubscription = _printingService.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    });
  }

  Future<void> _setDefaultPrinter(dynamic device) async {
    final prefs = await SharedPreferences.getInstance();

    // device object shape may vary; try common fields
    final address = device?.address ?? device?.id ?? device?.deviceId ?? device?.id?.toString();
    final name = device?.name ?? device?.localName ?? device?.deviceName ?? 'Unknown Device';

    if (address == null) return;

    await prefs.setString('default_printer_address', address.toString());
    await prefs.setString('default_printer_name', name.toString());

    if (!mounted) return;

    setState(() {
      _defaultPrinterAddress = address.toString();
      _defaultPrinterName = name.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ditetapkan sebagai printer utama.')),
    );
  }

  Future<void> _setDefaultPrinterAndDiscover(dynamic device) async {
    if (!mounted) return;

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Menghubungkan dan menyimpan UUID...')],
          ),
        ),
      ),
    );

    bool saved = false;
    try {
      saved = await _printingService.discoverAndSaveWriteCharacteristic(device);
    } catch (e) {
      saved = false;
    }

    // Always set default printer even if UUID discovery failed
    await _setDefaultPrinter(device);

    Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;

    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UUID printer berhasil disimpan.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat menemukan UUID writable. Simpan manual jika perlu.')),
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

  void _onDeviceTap(dynamic device) {
    // show options: set default or set default + discover UUID
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final name = device?.name ?? device?.localName ?? device?.deviceName ?? 'Unknown Device';
        final address = device?.address ?? device?.id ?? device?.deviceId ?? 'No Address';
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Ionicons.star),
                title: Text('Set sebagai printer utama'),
                subtitle: Text('$name — $address'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setDefaultPrinter(device);
                },
              ),
              ListTile(
                leading: const Icon(Ionicons.save_outline),
                title: const Text('Set dan simpan UUID (direkomendasikan)'),
                subtitle: const Text('Temukan characteristic writable dan simpan secara otomatis'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setDefaultPrinterAndDiscover(device);
                },
              ),
              ListTile(
                leading: const Icon(Ionicons.close),
                title: const Text('Batal'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Ionicons.refresh_outline),
              onPressed: _startScan,
              tooltip: 'Scan Ulang',
            ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Printer Default'),
            subtitle: Text(_defaultPrinterName ?? _defaultPrinterAddress ?? 'Belum dipilih'),
            trailing: _defaultPrinterAddress != null ? const Icon(Ionicons.star, color: Colors.amber) : null,
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
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];

                // attempt to extract displayable name and address from dynamic device
                final name = device?.name ?? device?.localName ?? device?.deviceName ?? 'Unknown Device';
                final address = device?.address ?? device?.id ?? device?.deviceId ?? 'No Address';

                final bool isDefault = address == _defaultPrinterAddress;

                return ListTile(
                  leading: Icon(isDefault ? Ionicons.print : Ionicons.print_outline),
                  title: Text(name.toString()),
                  subtitle: Text(address.toString()),
                  trailing: isDefault ? const Icon(Ionicons.star, color: Colors.amber) : null,
                  onTap: () => _onDeviceTap(device),
                  selected: isDefault,
                  selectedTileColor: Theme.of(context).primaryColor.withAlpha(25),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
