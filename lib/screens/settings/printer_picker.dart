import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/printing_service.dart';

/// Menampilkan dialog pemindaian langsung dan mengembalikan printer terpilih.
///
/// [usb] true → pindai printer USB (khusus Windows). false → pindai Bluetooth.
Future<PrinterDevice?> showPrinterPicker(
  BuildContext context, {
  required bool usb,
}) {
  return showDialog<PrinterDevice>(
    context: context,
    builder: (_) => _PrinterPickerDialog(usb: usb),
  );
}

class _PrinterPickerDialog extends StatefulWidget {
  const _PrinterPickerDialog({required this.usb});
  final bool usb;

  @override
  State<_PrinterPickerDialog> createState() => _PrinterPickerDialogState();
}

class _PrinterPickerDialogState extends State<_PrinterPickerDialog> {
  final PrintingService _service = getPrintingService();
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // Izin Bluetooth hanya relevan & tersedia di Android.
      if (!widget.usb &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }
      await _service.startDiscovery(
        bluetooth: !widget.usb,
        usb: widget.usb,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _close([PrinterDevice? device]) async {
    await _service.stopDiscovery();
    if (mounted) Navigator.of(context).pop(device);
  }

  @override
  void dispose() {
    _service.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wantUsb = widget.usb;
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(wantUsb ? 'Pilih Printer USB' : 'Pilih Printer Bluetooth'),
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal memindai:\n$_error',
                    textAlign: TextAlign.center),
              )
            : StreamBuilder<List<PrinterDevice>>(
                stream: _service.devicesStream,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? const <PrinterDevice>[];
                  final want = wantUsb
                      ? PrinterConnection.usb
                      : PrinterConnection.bluetooth;
                  final devices =
                      all.where((d) => d.connection == want).toList();

                  if (devices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            wantUsb
                                ? 'Mencari printer USB...\nPastikan printer terpasang di Windows.'
                                : 'Mencari printer Bluetooth...\nPastikan printer menyala & Bluetooth aktif.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final d = devices[index];
                      return ListTile(
                        leading: Icon(
                          wantUsb ? Ionicons.hardware_chip_outline : Ionicons.bluetooth,
                          color: d.isConnected ? Colors.green : null,
                        ),
                        title: Text(d.name),
                        subtitle: Text([
                          d.address,
                          if (d.isConnected) 'Terhubung',
                        ].where((s) => s.isNotEmpty).join(' • ')),
                        onTap: () => _close(d),
                      );
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
