// Enum untuk merepresentasikan tipe pergerakan stok
enum StockMovementType {
  sale,          // Penjualan dari koleksi 'orders'
  purchase,      // Pembelian dari koleksi 'purchase_transactions'
  adjustmentIn,  // Penyesuaian manual (masuk)
  adjustmentOut, // Penyesuaian manual (keluar)
  cancellation,  // Pesanan dibatalkan (stok masuk kembali)
}

class StockMovement {
  final DateTime date;
  final String description;
  final int change; // Perubahan kuantitas (+ untuk masuk, - untuk keluar)
  final StockMovementType type;
  final String referenceId; // ID dokumen sumber (orderId, transactionId, etc.)
  final String? source; // Kanal pesanan: 'pos' | 'marketplace' | null (non-pesanan)

  // Properti ini akan dihitung setelah semua data diurutkan
  int stockBefore;
  int stockAfter;

  StockMovement({
    required this.date,
    required this.description,
    required this.change,
    required this.type,
    required this.referenceId,
    this.source,
    this.stockBefore = 0,
    this.stockAfter = 0,
  });

  /// true untuk pergerakan yang berasal dari pesanan (bisa dibuka detailnya).
  bool get isOrder =>
      type == StockMovementType.sale || type == StockMovementType.cancellation;

  /// Label sumber: POS = "Toko Offline", marketplace = "Toko Online".
  /// null bila bukan dari pesanan (pembelian/penyesuaian).
  String? get sourceLabel {
    switch (source) {
      case 'pos':
        return 'Toko Offline';
      case 'marketplace':
        return 'Toko Online';
      default:
        return null;
    }
  }

  // Helper untuk mendapatkan label tipe yang lebih ramah pengguna
  String get typeLabel {
    switch (type) {
      case StockMovementType.sale:
        return 'Penjualan';
      case StockMovementType.purchase:
        return 'Pembelian';
      case StockMovementType.adjustmentIn:
        return 'Penyesuaian Masuk';
      case StockMovementType.adjustmentOut:
        return 'Penyesuaian Keluar';
      case StockMovementType.cancellation:
        return 'Pembatalan';
    }
  }
}
