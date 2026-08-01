import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../services/wattwise_billing.dart';
import '../models/wattwise_types.dart';
import '../widgets/billing_cycle_card.dart';
import '../services/pitc_bill_client.dart';

class MeterDetailsScreen extends StatelessWidget {
  final String meterId;

  const MeterDetailsScreen({super.key, required this.meterId});

  @override
  Widget build(BuildContext context) {
    return Consumer<WattWiseStore>(
      builder: (context, store, child) {
        final meter = store.meters.firstWhere((m) => m.id == meterId,
            orElse: () => throw Exception('Meter not found'));
        final readings = store.readingsForMeter(meter.id);
        final cycle = cycleFor(meter);
        final used = store.unitsThisCycle(meter);
        final stats = analytics(readings);

        return Scaffold(
          appBar: AppBar(
            title: Text(meter.nickname),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.camera),
                onPressed: () => context.push('/meters/${meter.id}/scan'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverviewCard(context, meter, used, cycle),
              const SizedBox(height: 16),
              BillingCycleCard(
                meter: meter,
                cycle: cycle,
                bill: store.billFor(meter.id),
                onEditSchedule: () =>
                    _editSchedule(context, store, meter, cycle),
                onFetchBill: () => _fetchBill(context, store, meter),
              ),
              const SizedBox(height: 24),
              if (readings.isNotEmpty) ...[
                const Text('Analytics',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildAnalyticsChart(context, stats),
                const SizedBox(height: 24),
                const Text('History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...readings.map((r) => _buildReadingTile(context, r)),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No readings recorded yet.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSchedule(BuildContext context, WattWiseStore store,
      Meter meter, Cycle cycle) async {
    final initialDate = meter.nextReadingDateOverride == null
        ? cycle.end
        : DateTime.tryParse(meter.nextReadingDateOverride!) ?? cycle.end;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Choose the next meter reading date',
    );
    if (selected == null || !context.mounted) return;
    store.setReadingSchedule(meter.id, overrideDate: toISODate(selected));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Next reading set for ${DateFormat('d MMM yyyy').format(selected)}')),
    );
  }

  Future<void> _fetchBill(
      BuildContext context, WattWiseStore store, Meter meter) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Fetching official bill...'),
          ],
        ),
      ),
    );
    try {
      final bill = await fetchPitcBill(
        meter.referenceNumber,
        meter.company,
        meterId: meter.id,
      );
      if (context.mounted) Navigator.of(context).pop();
      store.saveBill(bill);
      if (!context.mounted) return;
      final updateSchedule = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update reading schedule?'),
          content: Text(
              'The official bill was read on ${DateFormat('d MMM yyyy').format(DateTime.parse(bill.readingDate))}. Use this date for future cycles?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update schedule')),
          ],
        ),
      );
      if (updateSchedule == true) store.applyBillSchedule(bill);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Official bill saved')));
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bill lookup failed: $error')));
      }
    }
  }

  Widget _buildOverviewCard(
      BuildContext context, Meter m, int used, Cycle cycle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Cycle Usage',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('$used units',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(formatCycle(cycle),
                      style: const TextStyle(
                          color: AppTheme.accent, fontWeight: FontWeight.w600)),
                )
              ],
            ),
            if (m.monthlyLimit != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (used / m.monthlyLimit!).clamp(0.0, 1.0),
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                    used >= m.monthlyLimit!
                        ? AppTheme.danger
                        : AppTheme.success),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text('${m.monthlyLimit! - used} units remaining until limit',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsChart(BuildContext context, AnalyticsResult stats) {
    if (stats.months.isEmpty) return const SizedBox();

    return SizedBox(
      height: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (stats.highest?.value ?? 100) * 1.2,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < 0 ||
                          value.toInt() >= stats.months.length)
                        return const SizedBox();
                      final monthStr =
                          stats.months[value.toInt()].key; // YYYY-MM
                      final label = monthStr
                          .split('-')[1]; // Just month number for brevity
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary)),
                      );
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: stats.months.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.value.toDouble(),
                      color: AppTheme.accent,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    )
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadingTile(BuildContext context, Reading r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.background,
          child: Icon(LucideIcons.activity, color: AppTheme.primary),
        ),
        title: Text('${r.unitsConsumed} units'),
        subtitle: Text('Reading: ${r.currentReading}'),
        trailing: Text(r.billingMonth,
            style: const TextStyle(color: AppTheme.textSecondary)),
      ),
    );
  }
}
