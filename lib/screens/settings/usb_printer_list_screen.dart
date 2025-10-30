import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../services/printing_service.dart';
import '../../services/device_utils.dart';

class UsbPrinterListScreen extends StatefulWidget {
  const UsbPrinterListScreen({super.key});

  @override
  State<UsbPrinterListScreen> createState() => _UsbPrinterListScreenState();
}

class _UsbPrinterListScreenState extends State<UsbPrinterListScreen> {
  final PrintingService _printingService = getPrintingService();
  bool _loading = true;
  List<dynamic> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadUsbDevices();
  }

  Future<void> _loadUsbDevices() async {
    setState(() {
      _loading = true;
      _devices = [];
    });
    final devices = await _printingService.scanUsbDevices();
    if (kDebugMode) print('scanUsbDevices returned ${devices.length} entries');
    try {
      if (kDebugMode) {
        for (var e in devices) print('discovered entry: $e');
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<bool> _pairDevice(dynamic device) async {
    try {
      final result = await _printingService.pairUsbDevice(device);
      final snack =
          result ? 'Berhasil pairing printer USB' : 'Gagal pairing printer USB';
      if (!mounted) return result;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(snack)));
      if (result) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pairing printer USB: $e')));
      return false;
    }
  }

  String _displayName(dynamic d) => getDeviceName(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Printer USB')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? const Center(child: Text('Tidak ada printer USB terdeteksi'))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final entry = _devices[index];
                    // entry expected to be {'device': device, 'online': bool}
                    final device = (entry is Map && entry.containsKey('device'))
                        ? entry['device']
                        : entry;
                    final online = (entry is Map && entry.containsKey('online'))
                        ? entry['online'] == true
                        : false;
                    return ListTile(
                      leading: Icon(Ionicons.print_outline,
                          color: online ? Colors.green : null),
                      title: Text(_displayName(device)),
                      subtitle: Text([
                        getDeviceAddress(device),
                        if (online) 'Online'
                      ].where((s) => s.isNotEmpty).join(' • ')),
                      onTap: () async {
                        // Allow interaction for both online and offline devices
                        if (!mounted) return;
                        if (online) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Jadikan Printer Default?'),
                              content: Text(
                                  'Set ${_displayName(device)} sebagai printer utama?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Batal')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Ya')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final prefs = await SharedPreferences.getInstance();
                            final addr = getDeviceAddress(device);
                            final name = _displayName(device);
                            await prefs.setString(
                                'default_printer_address', addr);
                            await prefs.setString('default_printer_name', name);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('$name diset sebagai printer utama')));
                            Navigator.of(context).pop(device);
                          }
                        } else {
                          // offer to pair then set as default
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Pasangkan Printer USB'),
                              content: Text(
                                  'Printer ${_displayName(device)} tidak terhubung. Coba pasangkan sekarang?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Batal')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Pasangkan')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final success = await _pairDevice(device);
                            if (success) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final addr = getDeviceAddress(device);
                              final name = _displayName(device);
                              await prefs.setString(
                                  'default_printer_address', addr);
                              await prefs.setString(
                                  'default_printer_name', name);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '$name diset sebagai printer utama')));
                              Navigator.of(context).pop(device);
                            }
                          }
                        }
                      },
                    );
                  },
                ),
    );
  }
}
