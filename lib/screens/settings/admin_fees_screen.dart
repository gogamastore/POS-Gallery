import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Pengaturan Biaya Admin & Biaya Layanan (dokumen `settings/admin_fees`)
/// yang muncul di rincian biaya checkout reseller.
class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  final _ref = FirebaseFirestore.instance.collection('settings').doc('admin_fees');

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  final _adminFee = TextEditingController();
  final _servicePercent = TextEditingController();
  final _serviceMax = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _adminFee.dispose();
    _servicePercent.dispose();
    _serviceMax.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _ref.get();
      final d = snap.data();
      if (d != null) {
        _enabled = d['enabled'] != false;
        final adminFee = (d['adminFee'] as num?)?.toInt() ?? 0;
        final pct = (d['serviceFeePercent'] as num?)?.toInt() ?? 0;
        final max = (d['serviceFeeMax'] as num?)?.toInt() ?? 0;
        _adminFee.text = adminFee > 0 ? '$adminFee' : '';
        _servicePercent.text = pct > 0 ? '$pct' : '';
        _serviceMax.text = max > 0 ? '$max' : '';
      }
    } catch (_) {
      _snack('Gagal memuat pengaturan biaya');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final pct = int.tryParse(_servicePercent.text.trim()) ?? 0;
    if (pct < 0 || pct > 100) {
      _snack('Persentase biaya layanan harus 0–100%');
      return;
    }
    setState(() => _saving = true);
    try {
      await _ref.set({
        'enabled': _enabled,
        'adminFee': int.tryParse(_adminFee.text.trim()) ?? 0,
        'serviceFeePercent': pct,
        'serviceFeeMax': int.tryParse(_serviceMax.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('Pengaturan biaya disimpan');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    // Contoh perhitungan biaya layanan (subtotal Rp 250.000, di luar ongkir).
    final pct = int.tryParse(_servicePercent.text.trim()) ?? 0;
    final max = int.tryParse(_serviceMax.text.trim()) ?? 0;
    const sampleSubtotal = 250000;
    final rawService = (sampleSubtotal * pct / 100).round();
    final sampleService = max > 0 ? (rawService > max ? max : rawService) : rawService;

    return Scaffold(
      appBar: AppBar(title: const Text('Biaya Admin')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Biaya tambahan yang muncul di rincian biaya checkout reseller.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan biaya admin & layanan'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminFee,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Biaya Admin (flat, Rp)',
                    hintText: 'Contoh: 2000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Nominal tetap yang ditambahkan ke setiap pesanan.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biaya Layanan (persen, dengan batas maksimal)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _servicePercent,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Persentase (%)',
                                hintText: '5',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _serviceMax,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Maks. (Rp)',
                                hintText: '7500',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('0 pada Maks = tanpa batas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Contoh: Subtotal ${_currency.format(sampleSubtotal)} · '
                          'layanan $pct%${max > 0 ? ' (maks ${_currency.format(max)})' : ''} '
                          '→ ditambahkan ${_currency.format(sampleService)}'
                          '${max > 0 && rawService > max ? ' (dari ${_currency.format(rawService)}, dibatasi)' : ''}.',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Simpan Pengaturan'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
    );
  }
}
