import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/receipt_settings.dart';

/// Form pengaturan identitas toko & catatan footer untuk struk.
///
/// Setelah disimpan, sebuah pratinjau (preview) struk ditampilkan di bawah
/// form memakai contoh transaksi, sehingga pengguna langsung melihat hasilnya.
class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _footerNoteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  /// Terisi setelah menyimpan → memicu tampilnya preview.
  ReceiptSettings? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ReceiptSettings.load();
    if (!mounted) return;
    setState(() {
      _storeNameController.text = s.storeName;
      _storeAddressController.text = s.storeAddress;
      _storePhoneController.text = s.storePhone;
      _footerNoteController.text = s.footerNote;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _footerNoteController.dispose();
    super.dispose();
  }

  ReceiptSettings _currentInput() => ReceiptSettings(
        storeName: _storeNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        storePhone: _storePhoneController.text.trim(),
        footerNote: _footerNoteController.text.trim(),
      );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = _currentInput();

    if (settings.storeName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nama toko tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _saving = true);
    await settings.save();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _preview = settings;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Pengaturan struk disimpan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Struk')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Identitas Toko',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _storeNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _storeAddressController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Toko',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _storePhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    prefixText: 'Telp: ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footerNoteController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Footer',
                    hintText: 'Contoh: Barang yang sudah dibeli tidak dapat dikembalikan.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan & Lihat Preview'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_preview != null) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text('Preview Struk',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(child: _ReceiptPreview(settings: _preview!)),
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}

/// Pratinjau struk memakai contoh transaksi, meniru tampilan pada
/// print_page_screen.dart agar hasil cetak nyata mudah dibayangkan.
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.settings});

  final ReceiptSettings settings;

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    const textStyle = TextStyle(fontFamily: 'monospace', color: Colors.black);
    const boldTextStyle = TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: Colors.black);

    // Contoh item transaksi (hanya untuk pratinjau).
    const sampleItems = [
      {'name': 'Contoh Produk A', 'qty': 2, 'price': 25000.0},
      {'name': 'Contoh Produk B', 'qty': 1, 'price': 30000.0},
    ];
    final subtotal = sampleItems.fold<double>(
        0.0, (sum, e) => sum + (e['qty'] as int) * (e['price'] as double));

    Widget line(String left, String right, {bool bold = false}) {
      final style = bold ? boldTextStyle : textStyle;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: style),
          Text(right, style: style),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Center(
                child: Text(
                    settings.storeName.isEmpty
                        ? '(Nama Toko)'
                        : settings.storeName,
                    style: boldTextStyle.copyWith(fontSize: 18),
                    textAlign: TextAlign.center)),
            if (settings.storeAddress.isNotEmpty)
              Center(
                  child: Text(settings.storeAddress,
                      style: textStyle, textAlign: TextAlign.center)),
            if (settings.storePhone.isNotEmpty)
              Center(
                  child: Text('Telp: ${settings.storePhone}',
                      style: textStyle, textAlign: TextAlign.center)),
            const Divider(color: Colors.black),

            // --- Info transaksi (contoh) ---
            const Text('No: PREVIEW1', style: textStyle),
            Text(
                'Tanggal: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}',
                style: textStyle),
            const Text('Kasir: Kasir', style: textStyle),
            const Divider(color: Colors.black),

            // --- Item (contoh) ---
            for (final item in sampleItems) ...[
              Text(item['name'] as String, style: textStyle),
              line(
                '  ${item['qty']} x ${currency.format(item['price'])}',
                currency.format((item['qty'] as int) * (item['price'] as double)),
              ),
              const SizedBox(height: 4),
            ],
            const Divider(color: Colors.black),

            // --- Total ---
            line('Subtotal', currency.format(subtotal)),
            line('Total Diskon', currency.format(0)),
            const SizedBox(height: 4),
            line('Total', currency.format(subtotal), bold: true),
            const Divider(color: Colors.black),

            // --- Footer ---
            const Center(child: Text('Terima Kasih!', style: textStyle)),
            if (settings.footerNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                  child: Text(settings.footerNote,
                      style: textStyle, textAlign: TextAlign.center)),
            ],
          ],
        ),
      ),
    );
  }
}
