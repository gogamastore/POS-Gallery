import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.ean13], // Hanya memindai format EAN-13
    detectionSpeed: DetectionSpeed.normal,
  );

  // Flag untuk mencegah pemrosesan ganda
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Barcode EAN-13'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              // Jika sudah memproses, jangan lakukan apa-apa
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? sku = barcodes.first.rawValue;
                if (sku != null) {
                  // Set flag untuk menandakan pemrosesan dimulai
                  setState(() {
                    _isProcessing = true;
                  });
                  
                  // Pastikan widget masih terpasang sebelum navigasi
                  if (mounted) {
                    // Kembali dan kirim hasil SKU
                    Navigator.of(context).pop(sku);
                  }
                }
              }
            },
          ),
          // Overlay atau penanda area pindai
          Center(
            child: Container(
              width: 300,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withAlpha(180), width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
