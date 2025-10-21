// Model untuk merepresentasikan satu baris data dalam laporan piutang.
class ReceivableData {
  final String orderId;
  final String customerName;
  final DateTime orderDate;
  final String orderStatus;
  final double totalReceivable; // Total piutang dalam format double

  ReceivableData({
    required this.orderId,
    required this.customerName,
    required this.orderDate,
    required this.orderStatus,
    required this.totalReceivable,
  });
}
