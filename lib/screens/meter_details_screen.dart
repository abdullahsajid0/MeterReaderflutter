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
                tooltip: 'Scan meter',
                onPressed: () => context.push('/meters/${meter.id}/scan'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        Text(
                          'Delete Meter',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildOverviewCard(context, meter, used, cycle),
              const SizedBox(height: 14),
              _buildDailyTargetCard(meter, used, cycle),
              const SizedBox(height: 14),
              BillingCycleCard(
                meter: meter,
                cycle: cycle,
                bill: store.billFor(meter.id),
                onEditSchedule: () => _editSchedule(context, store, meter, cycle),
                onFetchBill: () => _fetchBill(context, store, meter),
              ),
              const SizedBox(height: 24),
              if (readings.isNotEmpty) ...[
                _buildSectionHeader('Analytics'),
                const SizedBox(height: 10),
                _buildSwitchableChart(context, stats),
                const SizedBox(height: 24),
                _buildSectionHeader('Reading History'),
                const SizedBox(height: 10),
                ..._buildReadingTiles(context, readings),
                const SizedBox(height: 16),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, color: AppTheme.accent, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No readings recorded yet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan your meter to start tracking usage history.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
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
    Color bgColor;

    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      int remaining = (m.monthlyLimit! - used).clamp(0, m.monthlyLimit!);
      int targetPerDay = remainingDays > 0 ? (remaining / remainingDays).round() : 0;
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = 'Daily Target';
      value = '~$targetPerDay units/day';
      subtitle = 'Averaging ~$avgPerDay units/day · $remaining units left in $remainingDays days';
      icon = LucideIcons.target;
      accentColor = remaining > 0 ? AppTheme.success : AppTheme.danger;
      bgColor = remaining > 0 ? AppTheme.successLight : AppTheme.dangerLight;
    } else {
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = 'Daily Average';
      value = '~$avgPerDay units/day';
      subtitle = '$used units consumed over $daysElapsed days this cycle';
      icon = LucideIcons.activity;
      accentColor = AppTheme.accent;
      bgColor = AppTheme.accentLight;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Switchable Bar / Area Chart ──────────────────────────────────────
  Widget _buildSwitchableChart(BuildContext context, AnalyticsResult stats) {
    if (stats.months.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showAreaChart ? 'Monthly Trend' : 'Monthly Consumption',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showAreaChart
                  ? _buildAreaChart(stats)
                  : _buildBarChart(stats),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? AppTheme.accent : AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildBarChart(AnalyticsResult stats) {
    return BarChart(
      key: const ValueKey('bar'),
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (stats.highest?.value ?? 100) * 1.25,
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                width: 18,
                borderRadius: BorderRadius.circular(6),
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                  AppTheme.primary.withOpacity(0.2),
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
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final scannedDate = DateTime.tryParse(r.scannedAt);
      final dateStr = scannedDate != null
          ? DateFormat('d MMM · h:mm a').format(scannedDate.toLocal())
          : r.billingMonth;

      String deltaText = '';
      if (i < readings.length - 1) {
        final older = readings[i + 1];
        final delta = r.currentReading - older.currentReading;
        deltaText = delta >= 0 ? '+$delta units since previous scan' : '$delta units';
      } else {
        deltaText = 'Initial scan for this cycle';
      }

      tiles.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.activity, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reading: ${r.currentReading}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '${r.unitsConsumed} units',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            deltaText,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return tiles;
  }

  // ─── Overview Card ────────────────────────────────────────────────────
  Widget _buildOverviewCard(
      BuildContext context, Meter m, int used, Cycle cycle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Cycle Usage',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$used units',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  formatCycle(cycle),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),
          if (m.monthlyLimit != null && m.monthlyLimit! > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (used / m.monthlyLimit!).clamp(0.0, 1.0),
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  used >= m.monthlyLimit! ? AppTheme.danger : AppTheme.success,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(m.monthlyLimit! - used).clamp(0, m.monthlyLimit!)} units remaining until limit',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ]
        ],
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
      helpText: 'Choose next meter reading date',
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
              child: const Text('Keep current'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Update schedule'),
            ),
          ],
        ),
      );
      if (updateSchedule == true) store.applyBillSchedule(bill);
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Official bill saved.',
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
          'Delete "${meter.nickname}"? All associated readings and bill records will be removed.',
        ),
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
