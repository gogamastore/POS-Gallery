// Model printer yang netral & aman untuk web.
//
// PENTING: berkas ini TIDAK boleh meng-import `flutter_thermal_printer`
// (paket itu menarik `dart:io`, sehingga tak bisa dikompilasi untuk web).
// Lapisan transport asli (thermal_printer_real.dart) yang memetakan antara
// `Printer` milik paket dan `PrinterDevice` ini. UI cukup memakai model ini.

enum PrinterConnection { bluetooth, usb }

class PrinterDevice {
  const PrinterDevice({
    required this.name,
    required this.address,
    required this.connection,
    this.isConnected = false,
    this.vendorId,
    this.productId,
  });

  /// Nama tampil printer.
  final String name;

  /// Alamat unik. Untuk Bluetooth (BLE) ini deviceId; untuk USB di Windows
  /// ini nama printer yang terpasang di Windows (spooler).
  final String address;

  final PrinterConnection connection;
  final bool isConnected;

  /// Hanya terisi untuk USB.
  final String? vendorId;
  final String? productId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'connection': connection.name,
        'vendorId': vendorId,
        'productId': productId,
      };

  factory PrinterDevice.fromJson(Map<String, dynamic> json) => PrinterDevice(
        name: (json['name'] as String?) ?? 'Printer',
        address: (json['address'] as String?) ?? '',
        connection: (json['connection'] as String?) == 'usb'
            ? PrinterConnection.usb
            : PrinterConnection.bluetooth,
        isConnected: false,
        vendorId: json['vendorId'] as String?,
        productId: json['productId'] as String?,
      );

  // Identitas: satu printer dianggap sama bila tipe koneksi & alamatnya sama.
  @override
  bool operator ==(Object other) =>
      other is PrinterDevice &&
      other.connection == connection &&
      other.address == address;

  @override
  int get hashCode => Object.hash(connection, address);
}
