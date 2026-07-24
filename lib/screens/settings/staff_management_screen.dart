import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/staff_model.dart';
import '../../services/staff_service.dart';
import 'staff_form_screen.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  void _openStaffForm(BuildContext context, WidgetRef ref, {Staff? staff}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffFormScreen(staff: staff),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsyncValue = ref.watch(staffStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Staff'),
      ),
      body: staffAsyncValue.when(
        data: (staffList) {
          if (staffList.isEmpty) {
            return const Center(child: Text('Belum ada staff. Silakan tambahkan.'));
          }
          return ListView.separated(
            itemCount: staffList.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              // Menentukan warna chip berdasarkan posisi
              Color chipColor = staff.position == 'Owner' ? Colors.orange : (staff.position == 'Admin' ? Colors.red : Colors.green);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(40),
                  backgroundImage: staff.photoURL.isNotEmpty ? NetworkImage(staff.photoURL) : null,
                  child: staff.photoURL.isEmpty
                      ? Text(
                          staff.name.isNotEmpty ? staff.name.substring(0, 1) : 'S',
                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(staff.email),
                trailing: Chip(
                  label: Text(
                    staff.position,
                    // PERBAIKAN: Menggunakan chipColor secara langsung
                    style: TextStyle(color: chipColor, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: chipColor.withAlpha(30),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onTap: () => _openStaffForm(context, ref, staff: staff), 
              );
            },
          );
        },
        error: (error, stackTrace) => Center(
          child: Text('Terjadi kesalahan: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openStaffForm(context, ref), 
        icon: const Icon(Icons.add),
        label: const Text('Tambah Staff'),
      ),
    );
  }
}
