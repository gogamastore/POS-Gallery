# Catatan Sesi — 2 Oktober 2026

Ringkasan pekerjaan pada sesi ini. Fokus utama: **menghubungkan metode
pembayaran di halaman Proses Penjualan POS ke Midtrans**, memakai Cloud
Functions yang sama dengan aplikasi marketplace pembeli
(`D:\gogamaapp_marketplace`).

> **Status akhir: kode selesai dan lolos analyzer, tetapi BELUM di-deploy dan
> BELUM diuji di perangkat.** Lihat bagian 6 untuk langkah yang wajib
> dilakukan sebelum fitur ini aktif.

---

## 1. Temuan awal

- **Satu Firebase project untuk dua aplikasi.** POS dan marketplace sama-sama
  memakai project `gallerypos` dan koleksi `orders` yang sama (dibedakan oleh
  field `source: 'pos'` / `'marketplace'`). Artinya function yang live hanya
  satu set dan dipakai bersama.
- **Function lama tidak bisa dipakai POS apa adanya:**
  - `createMidtransTransaction` hanya mengizinkan pemanggil dengan
    `customerId == user login`. Di POS yang memanggil adalah kasir, jadi
    selalu `permission-denied`.
  - Webhook menyetel status `Processing` saat lunas (alur marketplace) dan
    tidak mengurangi stok. Penjualan POS seharusnya `success` + potong stok.
  - Sweeper menulis `Cancelled` (huruf besar), sedangkan POS memakai huruf
    kecil (query dashboard bersifat case-sensitive).
- **Salinan functions di POS ketinggalan.** `functions/src/midtrans.ts` di POS
  belum punya baris voucher & biaya admin seperti versi marketplace. File
  disamakan dulu dengan versi marketplace sebelum ditambah dukungan POS.
- **`cloud_functions` 6.3.2 tidak punya implementasi Windows.** Panggilan
  `httpsCallable` via plugin akan gagal di aplikasi POS Windows.
- **`firebase.json` di POS awalnya tidak punya konfigurasi `functions`.**
  Sudah ditambahkan (disalin dari marketplace), jadi sekarang deploy bisa
  dilakukan dari folder POS maupun marketplace.

---

## 2. Perubahan Cloud Functions (`functions/src/midtrans.ts`)

Semua tambahan hanya berlaku bila `order.source === "pos"`. Alur marketplace
tidak berubah.

| Function | Perubahan |
|----------|-----------|
| `createMidtransTransaction` | Untuk order POS: pemanggil harus ber-role `admin`/`kasir` (koleksi `user`), status order harus `pending`, `customer_details` diambil dari data pelanggan (bukan data kasir), tanpa callback deep link `gogama://`, batas bayar **30 menit**, dan baris `ROUNDING` bila pembulatan harga membuat jumlah item ≠ total. |
| `handleMidtransNotification` | Membaca dokumen order lebih dulu. Order tidak ada → balas 200 (sebelumnya 500, membuat Midtrans mengirim ulang terus). Order POS → diteruskan ke `applyPosNotification`. |
| `applyPosNotification` (baru) | Menuntaskan order POS di dalam Firestore transaction (lihat tabel di bagian 3). Pengurangan stok hanya sekali (dijaga oleh `stockUpdated`); produk `temp_` dan produk yang sudah dihapus dilewati. |
| `checkExpiredOrders` | Order POS yang kedaluwarsa diberi status `cancelled` (huruf kecil). |

Dua perbedaan kecil yang juga berlaku untuk marketplace: satu baca Firestore
tambahan per notifikasi, dan balasan 200 untuk order yang tidak ada.

---

## 3. Alur pembayaran Midtrans di POS

1. Kasir memilih **"Midtrans (QRIS / VA / E-Wallet)"** lalu menekan
   **Konfirmasi**.
2. Pesanan dibuat dengan status `pending`; stok belum dikurangi.
3. Halaman pembayaran Snap terbuka — di dalam aplikasi pada Android
   (`LaunchMode.inAppWebView`, ditutup otomatis), di browser pada Windows/web.
4. Layar **Pembayaran Midtrans** memantau dokumen `orders/{id}` secara
   real-time. Status lunas hanya ditentukan oleh webhook di server.
5. Lunas → keranjang dikosongkan, langsung ke halaman struk. Gagal/kedaluwarsa
   /dibatalkan → kembali ke Proses Penjualan dengan keranjang utuh.

| Kejadian | `status` | `paymentStatus` | Stok |
|----------|----------|-----------------|------|
| Dibuat kasir | `pending` | `pending_payment` | belum dikurangi |
| Lunas (webhook) | `success` | `paid` | dikurangi sekali |
| Gagal / expire (webhook atau sweeper) | `cancelled` | `failed` | — |
| Dibatalkan kasir | `cancelled` | `cancelled` | — |

Kasus tepi yang sudah ditangani:
- Token Midtrans gagal dibuat → pesanan `pending` langsung dibatalkan.
- Notifikasi berulang / tidak berurutan → diabaikan bila order sudah bukan
  `pending` (kecuali notifikasi lunas, yang bersifat idempoten).
- Pembeli tetap membayar setelah kasir membatalkan → tetap dicatat `success`
  (uang sudah masuk) dan ditulis peringatan di log function.

**Windows:** `MidtransService` memanggil endpoint callable langsung lewat HTTPS
(`https://asia-southeast1-<project>.cloudfunctions.net/<nama>`) dengan ID token
Firebase Auth. Android/web tetap memakai plugin `cloud_functions`.

---

## Daftar file

### File BARU

| File | Keterangan |
|------|-----------|
| `lib/services/midtrans_service.dart` | Wrapper `createMidtransTransaction`, termasuk jalur HTTPS untuk Windows dan `MidtransException`. |
| `lib/screens/pos/midtrans_payment_screen.dart` | Layar tunggu pembayaran: buka ulang halaman Snap, batalkan transaksi, pantau status real-time. |

### File yang DIUBAH

| File | Perubahan |
|------|-----------|
| `firebase.json` | Tambah konfigurasi `functions` (dari marketplace). App ID Android di bagian `flutter` dikembalikan ke milik POS (`da1f41…`, `store.gallerymakassar.app`) dan entri iOS milik marketplace dihapus. |
| `functions/src/midtrans.ts` | Disamakan dengan versi marketplace + dukungan POS (bagian 2). |
| `functions/lib/midtrans.js`, `.js.map` | Hasil build ulang (`npm run build`). |
| `functions/lib/biteship.js`, `.js.map` | Ikut ter-build ulang karena `src/biteship.ts` sudah disinkronkan dari marketplace sebelum sesi ini. |
| `lib/services/pos_service.dart` | Tambah `createPendingMidtransOrder` & `cancelPendingMidtransOrder`. Penyusunan dokumen pesanan digabung ke helper `_buildOrder` (perilaku dua method lama tidak berubah). |
| `lib/screens/pos/process_pos_screen.dart` | Opsi radio "Midtrans (QRIS / VA / E-Wallet)" dan method `_processMidtransPayment`. |

### Tidak diubah
- Aplikasi marketplace (Flutter) di `D:\gogamaapp_marketplace`.
- Metode Cash / Bank Transfer / QRIS manual dan alur draf **Simpan**.
- `pubspec.yaml` / `pubspec.lock` — tidak ada dependency baru.

---

## Verifikasi

- `tsc` dan `npm run build` di `functions/`: **berhasil**.
- `flutter analyze` pada file yang diubah: **0 error**. Ada 3 info
  `use_build_context_synchronously` dari kode lama di `_processTransaction`.
- **Belum dilakukan:** deploy, uji di Android/Windows, uji sandbox Midtrans.

---

## Langkah WAJIB sebelum fitur aktif

1. Deploy dari `D:\POS-Gallery`. Dry-run sudah berhasil. Bila muncul error
   `User code failed to load ... Timeout after 10000`, perpanjang batas waktu
   pemuatan kode (dalam detik):
   ```powershell
   $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
   firebase deploy --only functions:createMidtransTransaction,functions:handleMidtransNotification,functions:checkExpiredOrders
   ```
2. Salin function ke folder marketplace agar deploy berikutnya dari sana tidak
   mengembalikan versi lama:
   ```powershell
   Copy-Item D:\POS-Gallery\functions\src\midtrans.ts D:\gogamaapp_marketplace\functions\src\midtrans.ts
   ```
3. Uji di sandbox (`MIDTRANS_IS_PRODUCTION=true`):
   - Transaksi POS di Windows dan Android: lunas, kedaluwarsa, dibatalkan kasir.
   - **Satu transaksi marketplace** untuk memastikan tidak ada regresi
     (status harus tetap `paid` / `Processing`).
4. Bila ada masalah, rollback (versi lama masih ter-commit di git marketplace):
   ```
   cd D:\gogamaapp_marketplace
   git checkout functions/src/midtrans.ts
   firebase deploy --only functions:createMidtransTransaction,functions:handleMidtransNotification,functions:checkExpiredOrders
   ```

> Penting: kedua folder functions harus selalu identik. Deploy dari salinan
> yang ketinggalan akan menghapus fitur yang ada di salinan lain.

---

## Catatan lanjutan (opsional)

- **Runtime Node.js 20 akan dihentikan 30 Oktober 2026.** Setelah tanggal itu
  functions tidak bisa di-deploy lagi sebelum `runtime`/`engines` dinaikkan
  (mis. Node 22) di kedua folder functions. CLI juga memperingatkan
  `firebase-functions` versi lama.

- **Biteship di Windows:** tombol kirim di halaman Pesanan memakai plugin
  `cloud_functions`, jadi kemungkinan juga gagal di Windows. Bisa diperbaiki
  dengan pola HTTPS yang sama seperti `MidtransService._callOverHttp`.
- **Pesanan `pending` belum punya tab sendiri** di halaman Pesanan POS
  (Proses / Berhasil / Dibatalkan). Statusnya sementara (maks. 30 menit), tetapi
  tab "Menunggu Bayar" bisa ditambahkan bila diperlukan.
- **Pembatalan oleh kasir hanya di Firestore.** Transaksi di sisi Midtrans
  tidak ikut dibatalkan lewat API. Bila pembeli tetap membayar, pesanan tercatat
  `success` dan perlu refund manual.
- **Sweeper berjalan tiap jam.** Pesanan POS yang pembelinya belum memilih
  metode bayar bisa bertahan hingga ±1,5 jam sebelum otomatis dibatalkan.
- **Git "dubious ownership":** perintah git di repo ini menolak jalan karena
  beda pemilik folder. Atasi sekali dengan:
  `git config --global --add safe.directory D:/POS-Gallery`
