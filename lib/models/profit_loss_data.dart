class ProfitLossData {
  final double totalRevenue; // Total Pendapatan
  final double totalCOGS; // Total HPP (Cost of Goods Sold)
  final double grossProfit; // Laba Kotor
  final double totalOperationalExpenses; // Total Biaya Operasional
  final double netProfit; // Laba Bersih

  ProfitLossData({
    required this.totalRevenue,
    required this.totalCOGS,
    required this.grossProfit,
    required this.totalOperationalExpenses,
    required this.netProfit,
  });

  // Untuk kasus di mana tidak ada data
  factory ProfitLossData.empty() {
    return ProfitLossData(
      totalRevenue: 0.0,
      totalCOGS: 0.0,
      grossProfit: 0.0,
      totalOperationalExpenses: 0.0,
      netProfit: 0.0,
    );
  }
}
