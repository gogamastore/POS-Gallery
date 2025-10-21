import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// A custom card widget for displaying a specific metric (e.g., stock suggestion).
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.iconColor = Colors.blue, // Default color
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(unit, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// A custom card for displaying analysis sections (like summary or reasoning).
class _AnalysisDetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;

  const _AnalysisDetailCard({required this.title, required this.icon, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }
}

// The main widget that combines all parts of the AI suggestion result.
class AiSuggestionResultCard extends StatelessWidget {
  final Map<String, dynamic> suggestionData;

  const AiSuggestionResultCard({super.key, required this.suggestionData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Safely extract data with default fallbacks
    final suggestion = suggestionData['suggestion'] as Map<String, dynamic>? ?? {};
    final analysis = suggestionData['analysis'] as Map<String, dynamic>? ?? {};
    final reasoning = suggestionData['reasoning'] as String? ?? 'No reasoning provided.';

    final nextPeriodStock = suggestion['nextPeriodStock']?.toString() ?? 'N/A';
    final safetyStock = suggestion['safetyStock']?.toString() ?? 'N/A';

    final totalSold = analysis['totalSold']?.toString() ?? 'N/A';
    final salesTrend = analysis['salesTrend'] as String? ?? 'N/A';
    final peakDays = analysis['peakDays'] as List? ?? [];
    final peakDaysString = peakDays.join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Hasil Analisis & Rekomendasi',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'AI telah memberikan saran jumlah stok dan alasan di baliknya.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          
          // Metric cards for suggestions
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Saran Stok Bulan Depan',
                  value: nextPeriodStock,
                  unit: 'unit',
                  icon: LucideIcons.packageCheck,
                  iconColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  title: 'Stok Pengaman',
                  value: safetyStock,
                  unit: 'unit',
                  icon: LucideIcons.alertTriangle, // <-- NAMA IKON DIPERBAIKI
                  iconColor: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Analysis summary card
          _AnalysisDetailCard(
            title: 'Ringkasan Analisis',
            icon: LucideIcons.barChartBig,
            content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: TextSpan(style: theme.textTheme.bodyLarge, children: [const TextSpan(text: 'Total Terjual: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '$totalSold unit')])),
                  const SizedBox(height: 8),
                  RichText(text: TextSpan(style: theme.textTheme.bodyLarge, children: [const TextSpan(text: 'Tren Penjualan: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: salesTrend)])),
                  const SizedBox(height: 8),
                  RichText(text: TextSpan(style: theme.textTheme.bodyLarge, children: [const TextSpan(text: 'Periode Puncak: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: peakDaysString)])),
                ]
            ),
          ),
          const SizedBox(height: 24),

          // AI reasoning card
          _AnalysisDetailCard(
            title: 'Alasan AI',
            icon: LucideIcons.bot,
            content: Text(
              reasoning,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
