# Catatan Sesi — 25 Juli 2026

Ringkasan pekerjaan pada sesi ini. Fokus utama: **memperbaiki cetak struk lewat
Bluetooth di Android** dan **menambah tombol cetak pada detail pesanan
marketplace**.

---

## 1. Masalah utama: Cetak Bluetooth Android gagal (printer diam)

**Gejala:** Di Android, aplikasi berhasil "mengirim" cetak (muncul notifikasi
sukses di layar), tetapi printer tidak merespons / tidak keluar kertas. Koneksi
USB di Windows sudah normal dan tidak diubah.

**Akar masalah:** Paket `flutter_thermal_printer` untuk Android hanya memakai
**BLE (Bluetooth Low Energy / GATT)**. Mayoritas printer struk termal (termasuk
printer Blueprint yang dipakai) adalah perangkat **Bluetooth Classic (SPP /
RFCOMM)**, bukan BLE. Akibatnya koneksi BLE "berhasil" di level API tetapi data
ESC/POS tidak pernah sampai ke printer.

**Solusi:** Menambahkan transport **Bluetooth Classic** khusus untuk cabang
Android memakai paket `blue_thermal_printer`, sementara Windows (USB & BLE) tetap
memakai `flutter_thermal_printer`. Generator ESC/POS dan arsitektur layanan tidak
diubah.

### Bug lanjutan A — daftar printer loading terus di picker
Daftar bonded Android hanya di-emit **sekali**, sedangkan `StreamController`
broadcast tidak menyangga event. Pendengar yang telat subscribe kehilangan emisi
→ loading selamanya. Juga, emisi kosong dari `flutter_thermal_printer` menimpa
daftar bonded. Diperbaiki dengan cache + replay snapshot dan mengabaikan emisi
plugin BLE di Android.

### Bug lanjutan B — `getBondedDevices()` hang (TimeoutException)
Bug di dalam paket `blue_thermal_printer` v1.2.3: pada Android 12+,
`getBondedDevices()` menuntut izin `ACCESS_FINE_LOCATION`, lalu memanggil
`requestPermissions(..., 1)` — tetapi `onRequestPermissionsResult` **tidak
menangani request code `1`**, sehingga `pendingResult` tidak pernah di-complete
dan Future menggantung (timeout 8 detik).

**Solusi:** Paket di-**vendor** (disalin) ke dalam proyek dan di-patch:
`getBondedDevices()` kini hanya butuh `BLUETOOTH_CONNECT` (sesuai dokumentasi
Android — lokasi tidak diperlukan untuk perangkat yang sudah dipasangkan) dan
tidak pernah menggantung.

> **Status akhir: cetak Bluetooth Android BERHASIL.**

---

## 2. Tombol cetak pada detail pesanan marketplace

Menambahkan tombol **Cetak Struk** (ikon printer) di AppBar halaman detail
pesanan marketplace, yang membuka `print_page_screen.dart` agar struk pesanan
marketplace bisa dicetak seperti pesanan POS.

---

## Daftar file

### File yang DIUBAH

| File | Perubahan |
|------|-----------|
| `pubspec.yaml` | Tambah dependency `blue_thermal_printer: ^1.2.3`; tambah `dependency_overrides` mengarah ke salinan lokal `blue_thermal_printer_local`. |
| `lib/services/thermal_printer_real.dart` | Pisah transport per platform: Android+Bluetooth → `blue_thermal_printer` (Classic/SPP), Windows → `flutter_thermal_printer`. Tambah discovery bonded device, cetak via SPP, cache+replay snapshot stream, abaikan emisi plugin BLE di Android. |
| `lib/screens/settings/printer_picker.dart` | Minta izin `BLUETOOTH_CONNECT` + `BLUETOOTH_SCAN` (lokasi tidak lagi diperlukan); tampilkan pesan + tombol "Buka Pengaturan" bila izin ditolak, alih-alih loading tanpa henti. |
| `lib/screens/orders/marketplace_order_detail_screen.dart` | Tambah tombol Cetak di AppBar → membangun `Order` dari dokumen Firestore (parsing tanggal defensif) → buka `print_page_screen.dart`. Import `cloud_firestore` memakai `hide Order` untuk hindari bentrok nama. |
| `pubspec.lock` | Otomatis diperbarui oleh `flutter pub get`. |
| `windows/flutter/generated_plugin_registrant.*`, `generated_plugins.cmake` | Otomatis diperbarui oleh Flutter tooling. |

### Folder/paket yang DITAMBAHKAN

| Item | Keterangan |
|------|-----------|
| `blue_thermal_printer_local/` | Salinan (vendor) paket `blue_thermal_printer` v1.2.3 yang sudah **di-patch**. Perubahan native ada di `android/src/main/java/id/kakzaki/blue_thermal_printer/BlueThermalPrinterPlugin.java` (case `getBondedDevices`) dan constraint SDK di `pubspec.yaml` dilonggarkan ke `<4.0.0`. Dipakai lewat `dependency_overrides`. |
| `blue_print_pos/` | Hasil clone referensi dari GitHub untuk investigasi solusi. **Tidak dipakai** oleh aplikasi (hanya referensi konsep Bluetooth Classic). Boleh dihapus bila tidak diperlukan. |

### Tidak diubah
- Jalur cetak **USB di Windows** — tetap berfungsi seperti semula.
- Generator/penyusun struk **ESC/POS** (`buildReceiptBytes`).
- `AndroidManifest.xml` — izin Bluetooth sudah lengkap sejak awal.

---

## Cara build setelah perubahan ini

Karena ada perubahan **kode native** (Java yang di-patch) dan pergantian sumber
plugin, wajib rebuild penuh (bukan sekadar hot reload):

```
flutter clean
flutter pub get
flutter run   # atau: flutter build apk
```

## Catatan lanjutan (opsional)
- Struk pesanan marketplace saat ini menampilkan Subtotal, Total Diskon, dan
  Total — baris **Ongkir** belum ditampilkan terpisah. Bisa ditambahkan bila
  diperlukan.
- Folder `blue_print_pos/` bisa dihapus karena hanya referensi.
