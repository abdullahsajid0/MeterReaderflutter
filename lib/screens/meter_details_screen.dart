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
import '../widgets/app_toast.dart';
import '../services/pitc_bill_client.dart';

/// Converted to StatefulWidget to hold the chart toggle state.
class MeterDetailsScreen extends StatefulWidget {
  final String meterId;

  const MeterDetailsScreen({super.key, required this.meterId});

  @override
  State<MeterDetailsScreen> createState() => _MeterDetailsScreenState();
}

class _MeterDetailsScreenState extends State<MeterDetailsScreen> {
  bool _showAreaChart = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WattWiseStore>(
      builder: (context, store, child) {
        final meter = store.meters.firstWhere((m) => m.id == widget.meterId,
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
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') {
                    _confirmDeleteMeter(context, store, meter);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, color: AppTheme.danger, size: 18),
                        SizedBox(width: 10),
                        Text('Delete Meter',
                            style: TextStyle(
                                color: AppTheme.danger, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverviewCard(context, meter, used, cycle),
              const SizedBox(height: 16),
              _buildDailyTargetCard(meter, used, cycle),
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
                _buildSwitchableChart(context, stats),
                const SizedBox(height: 24),
                const Text('Reading History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._buildReadingTiles(context, readings),
                const SizedBox(height: 24),
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

  // ─── Daily Target / Average Card ──────────────────────────────────────
  Widget _buildDailyTargetCard(Meter m, int used, Cycle cycle) {
    final daysElapsed = cycle.daysElapsed;
    final remainingDays = cycle.daysRemaining;

    String title;
    String value;
    String subtitle;
    IconData icon;
    Color accentColor;

    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      int remaining = m.monthlyLimit! - used;
      if (remaining < 0) remaining = 0;
      int targetPerDay = remainingDays > 0 ? (remaining / remainingDays).round() : 0;
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = 'Daily Target';
      value = '~$targetPerDay units/day';
      subtitle = 'You are currently averaging ~$avgPerDay units/day · $remaining units remaining in $remainingDays days';
      icon = LucideIcons.target;
      accentColor = remaining > 0 ? AppTheme.success : AppTheme.danger;
    } else {
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = 'Daily Average';
      value = '~$avgPerDay units/day';
      subtitle = '$used units consumed over $daysElapsed days this cycle';
      icon = LucideIcons.activity;
      accentColor = AppTheme.accent;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Switchable Bar / Area Chart ──────────────────────────────────────
  Widget _buildSwitchableChart(BuildContext context, AnalyticsResult stats) {
    if (stats.months.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAreaChart ? 'Area Chart' : 'Bar Chart',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chartToggleButton(
                        icon: LucideIcons.barChart2,
                        isActive: !_showAreaChart,
                        onTap: () => setState(() => _showAreaChart = false),
                      ),
                      _chartToggleButton(
                        icon: LucideIcons.lineChart,
                        isActive: _showAreaChart,
                        onTap: () => setState(() => _showAreaChart = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAreaChart
                    ? _buildAreaChart(stats)
                    : _buildBarChart(stats),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.white : AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildBarChart(AnalyticsResult stats) {
    return BarChart(
      key: const ValueKey('bar'),
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (stats.highest?.value ?? 100) * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= stats.months.length) {
                  return const SizedBox();
                }
                final monthStr = stats.months[value.toInt()].key;
                final label = monthStr.split('-')[1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(label,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    );
  }

  Widget _buildAreaChart(AnalyticsResult stats) {
    return LineChart(
      key: const ValueKey('area'),
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= stats.months.length) {
                  return const SizedBox();
                }
                final monthStr = stats.months[value.toInt()].key;
                final label = monthStr.split('-')[1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(label,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: stats.months.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.3),
                  AppTheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reading History Tiles (with delta from previous scan) ────────────
  List<Widget> _buildReadingTiles(BuildContext context, List<Reading> readings) {
    final tiles = <Widget>[];
    // readings are sorted newest-first
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final scannedDate = DateTime.tryParse(r.scannedAt);
      final dateStr = scannedDate != null
          ? DateFormat('d MMM · h:mm a').format(scannedDate.toLocal())
          : r.billingMonth;

      // Calculate delta from the *next older* reading (i+1 is older)
      String deltaText = '';
      if (i < readings.length - 1) {
        final older = readings[i + 1];
        final delta = r.currentReading - older.currentReading;
        deltaText = delta >= 0 ? '+$delta units since last scan' : '$delta units';
      } else {
        deltaText = 'First scan this cycle';
      }

      tiles.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.activity, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reading: ${r.currentReading}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${r.unitsConsumed} units',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(deltaText,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ),
                          Text(dateStr,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return tiles;
  }

  // ─── Overview Card ────────────────────────────────────────────────────
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

  // ─── Schedule Editing ─────────────────────────────────────────────────
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
    AppToast.show(
      context,
      message: 'Next reading set for ${DateFormat('d MMM yyyy').format(selected)}',
      type: ToastType.success,
    );
  }

  // ─── Bill Fetching ────────────────────────────────────────────────────
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
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update reading schedule?'),
          content: Text(
              'The official bill was read on ${DateFormat('d MMM yyyy').format(DateTime.parse(bill.readingDate))}. Use this date for future cycles?'),
          actions: [
            TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('Keep current')),
            ElevatedButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Update schedule')),
          ],
        ),
      );
      if (updateSchedule == true) store.applyBillSchedule(bill);
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Official bill saved successfully!',
          type: ToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppToast.show(
          context,
          message: 'Bill lookup: $error',
          type: ToastType.warning,
        );
      }
    }
  }

  // ─── Delete Confirmation ──────────────────────────────────────────────
  void _confirmDeleteMeter(
      BuildContext context, WattWiseStore store, Meter meter) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Meter?'),
        content: Text(
            'Are you sure you want to delete "${meter.nickname}"? All associated readings and bill records will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              store.deleteMeter(meter.id);
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
