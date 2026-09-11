import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class Voucher {
  final String id;
  final String code;
  final String description;
  final String discountType; // 'fixed' | 'percentage'
  final num discountValue;
  final num maxDiscount; // cap % (0 = tanpa batas)
  final num minPurchase;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dailyLimitPerUser; // 0 = tanpa batas

  Voucher({
    required this.id,
    required this.code,
    this.description = '',
    this.discountType = 'fixed',
    this.discountValue = 0,
    this.maxDiscount = 0,
    this.minPurchase = 0,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.dailyLimitPerUser = 1,
  });

  factory Voucher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Voucher(
      id: doc.id,
      code: (data['code'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      discountType: data['discountType'] == 'percentage' ? 'percentage' : 'fixed',
      discountValue: (data['discountValue'] as num?) ?? 0,
      maxDiscount: (data['maxDiscount'] as num?) ?? 0,
      minPurchase: (data['minPurchase'] as num?) ?? 0,
      isActive: data['isActive'] == true,
      startDate: toDate(data['startDate']),
      endDate: toDate(data['endDate']),
      dailyLimitPerUser: (data['dailyLimitPerUser'] as num?)?.toInt() ?? 0,
    );
  }
}

class VoucherManagementScreen extends StatefulWidget {
  const VoucherManagementScreen({super.key});

  @override
  State<VoucherManagementScreen> createState() => _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen> {
  bool _isLoading = true;
  List<Voucher> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vouchers')
          .orderBy('createdAt', descending: true)
          .get();
      final data = snap.docs.map((d) => Voucher.fromFirestore(d)).toList();
      if (mounted) setState(() => _vouchers = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memuat voucher: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForm({Voucher? voucher}) {
    showDialog(
      context: context,
      builder: (_) => _VoucherFormDialog(voucher: voucher, onSave: _fetch),
    );
  }

  Future<void> _delete(String id, String code) async {
    try {
      await FirebaseFirestore.instance.collection('vouchers').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Voucher "$code" dihapus')));
      }
      _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  void _confirmDelete(String id, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anda Yakin?'),
        content: Text('Hapus voucher "$code" secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id, code);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  String _discountLabel(Voucher v) => v.discountType == 'percentage'
      ? '${v.discountValue}%${v.maxDiscount > 0 ? ' (maks ${_currency.format(v.maxDiscount)})' : ''}'
      : _currency.format(v.discountValue);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher Diskon')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vouchers.isEmpty
              ? const Center(
                  child: Text('Belum ada voucher.',
                      style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _tile(_vouchers[i]),
                ),
    );
  }

  Widget _tile(Voucher v) {
    final df = DateFormat('d MMM yyyy', 'id_ID');
    final validity = (v.startDate != null || v.endDate != null)
        ? 'Berlaku ${v.startDate != null ? df.format(v.startDate!) : '—'} s/d ${v.endDate != null ? df.format(v.endDate!) : '—'}'
        : 'Tanpa batas waktu';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            v.discountType == 'percentage' ? Icons.percent : Icons.local_offer_outlined,
            color: Theme.of(context).primaryColor,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(v.code,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (v.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(v.isActive ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: v.isActive ? Colors.green[800] : Colors.grey[700])),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Potongan ${_discountLabel(v)}'
                  '${v.minPurchase > 0 ? ' · min. ${_currency.format(v.minPurchase)}' : ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                Text(
                  '$validity${v.dailyLimitPerUser > 0 ? ' · ${v.dailyLimitPerUser}×/user/hari' : ' · pakai tanpa batas'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (v.description.isNotEmpty)
                  Text(v.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'edit') _showForm(voucher: v);
              if (val == 'delete') _confirmDelete(v.id, v.code);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
              PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Hapus', style: TextStyle(color: Colors.red)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherFormDialog extends StatefulWidget {
  final Voucher? voucher;
  final VoidCallback onSave;
  const _VoucherFormDialog({this.voucher, required this.onSave});

  @override
  State<_VoucherFormDialog> createState() => _VoucherFormDialogState();
}

class _VoucherFormDialogState extends State<_VoucherFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _desc;
  late final TextEditingController _value;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minPurchase;
  late final TextEditingController _dailyLimit;
  String _type = 'fixed';
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    _code = TextEditingController(text: v?.code ?? '');
    _desc = TextEditingController(text: v?.description ?? '');
    _value = TextEditingController(text: v != null && v.discountValue > 0 ? '${v.discountValue}' : '');
    _maxDiscount = TextEditingController(text: v != null && v.maxDiscount > 0 ? '${v.maxDiscount}' : '');
    _minPurchase = TextEditingController(text: v != null && v.minPurchase > 0 ? '${v.minPurchase}' : '');
    _dailyLimit = TextEditingController(text: '${v?.dailyLimitPerUser ?? 1}');
    _type = v?.discountType ?? 'fixed';
    _isActive = v?.isActive ?? true;
    _startDate = v?.startDate;
    _endDate = v?.endDate;
  }

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _value.dispose();
    _maxDiscount.dispose();
    _minPurchase.dispose();
    _dailyLimit.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = (isStart ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = num.tryParse(_value.text.trim()) ?? 0;
    if (value <= 0) {
      _snack('Nilai diskon harus lebih dari 0');
      return;
    }
    if (_type == 'percentage' && value > 100) {
      _snack('Persentase maksimal 100%');
      return;
    }
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      _snack('Tanggal berakhir sebelum tanggal mulai');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'code': _code.text.trim().toUpperCase(),
        'description': _desc.text.trim(),
        'discountType': _type,
        'discountValue': value,
        'maxDiscount': num.tryParse(_maxDiscount.text.trim()) ?? 0,
        'minPurchase': num.tryParse(_minPurchase.text.trim()) ?? 0,
        'isActive': _isActive,
        'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'dailyLimitPerUser': int.tryParse(_dailyLimit.text.trim()) ?? 0,
      };
      final col = FirebaseFirestore.instance.collection('vouchers');
      if (widget.voucher == null) {
        await col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await col.doc(widget.voucher!.id).update(data);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
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
    final df = DateFormat('d MMM yyyy', 'id_ID');
    return AlertDialog(
      title: Text(widget.voucher == null ? 'Tambah Voucher' : 'Edit Voucher'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Kode Voucher', hintText: 'HEMAT10', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Kode wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fixed', label: Text('Nominal'), icon: Icon(Icons.money)),
                  ButtonSegment(value: 'percentage', label: Text('Persen'), icon: Icon(Icons.percent)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _value,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: _type == 'percentage' ? 'Persentase Diskon (%)' : 'Nominal Diskon (Rp)',
                    border: const OutlineInputBorder()),
              ),
              if (_type == 'percentage') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _maxDiscount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Maks. Potongan (Rp) — 0 = tanpa batas', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _minPurchase,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Min. Belanja (Rp) — 0 = tanpa syarat', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text(_startDate != null ? df.format(_startDate!) : 'Berlaku Dari'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text(_endDate != null ? df.format(_endDate!) : 'Sampai'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Kosongkan tanggal = tanpa batas waktu.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dailyLimit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Batas pakai per user / 24 jam — 0 = tanpa batas',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktifkan voucher'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
