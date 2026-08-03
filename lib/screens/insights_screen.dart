import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../services/wattwise_billing.dart';
import '../models/wattwise_types.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _showAreaChart = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WattWiseStore>(
      builder: (context, store, child) {
        final meters = store.meters;
        if (meters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.barChart2, size: 64, color: AppTheme.border),
                const SizedBox(height: 16),
                Text('No Data Available', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Add meters to see insights and analytics.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        int totalUnitsThisCycle = 0;
        int totalLimitThisCycle = 0;
        int overLimitCount = 0;
        int totalRemainingUnits = 0;
        int minRemainingDays = 30;

        for (var m in meters) {
          final used = store.unitsThisCycle(m);
          final cycle = cycleFor(m);
          totalUnitsThisCycle += used;
          if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
            totalLimitThisCycle += m.monthlyLimit!;
            final rem = (m.monthlyLimit! - used).clamp(0, m.monthlyLimit!);
            totalRemainingUnits += rem;
            if (used > m.monthlyLimit!) {
              overLimitCount++;
            }
          }
          if (cycle.daysRemaining < minRemainingDays) {
            minRemainingDays = cycle.daysRemaining;
          }
        }

        int householdTargetPerDay = minRemainingDays > 0 && totalRemainingUnits > 0
            ? (totalRemainingUnits / minRemainingDays).round()
            : 0;

        final stats = analytics(store.readings);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Summary Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatCard(
              context,
              title: 'Total Units Consumed',
              value: '$totalUnitsThisCycle',
              subtitle: totalLimitThisCycle > 0
                  ? 'Limit: $totalLimitThisCycle units total'
                  : 'Across all meters this cycle',
              icon: LucideIcons.zap,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            if (totalLimitThisCycle > 0) ...[
              _buildDailyPacingSummaryCard(
                targetPerDay: householdTargetPerDay,
                remainingUnits: totalRemainingUnits,
                daysLeft: minRemainingDays,
              ),
              const SizedBox(height: 12),
            ],
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Active Meters',
                      value: '${meters.length}',
                      subtitle: 'Monitored',
                      icon: LucideIcons.home,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Over Limit',
                      value: '$overLimitCount',
                      subtitle: overLimitCount > 0 ? 'Action required' : 'Normal',
                      icon: LucideIcons.alertTriangle,
                      color: overLimitCount > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Consumption Visual Trend',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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
            _buildSwitchableConsumptionGraph(context, meters, store, stats),
            const SizedBox(height: 24),
            Text('Meter Breakdown & Targets',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...meters.map((m) => _buildMeterInsightCard(context, m, store)),
          ],
        );
      },
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
          color: isActive ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: isActive ? Colors.white : AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildDailyPacingSummaryCard({
    required int targetPerDay,
    required int remainingUnits,
    required int daysLeft,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.target, color: AppTheme.success, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recommended Daily Target',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('~$targetPerDay units/day',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success)),
                  const SizedBox(height: 2),
                  Text('Pacing for $remainingUnits remaining units across ~$daysLeft days',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchableConsumptionGraph(
      BuildContext context, List<Meter> meters, WattWiseStore store, AnalyticsResult stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAreaChart ? 'Historical Usage Area Trend' : 'Current Cycle Breakdown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Icon(_showAreaChart ? LucideIcons.lineChart : LucideIcons.barChart2,
                    size: 18, color: AppTheme.accent),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAreaChart
                    ? _buildFlAreaChart(stats)
                    : _buildFlBarChart(meters, store),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlBarChart(List<Meter> meters, WattWiseStore store) {
    final entries = meters.map((m) => MapEntry(m.nickname, store.unitsThisCycle(m).toDouble())).toList();
    final double maxY = entries.map((e) => e.value).fold(10.0, (prev, element) => element > prev ? element : prev) * 1.2;

    return BarChart(
      key: const ValueKey('insights_bar'),
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                final name = entries[idx].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(name.length > 7 ? '${name.substring(0, 6)}…' : name,
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
        barGroups: entries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: AppTheme.accent,
                width: 20,
                borderRadius: BorderRadius.circular(6),
              )
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlAreaChart(AnalyticsResult stats) {
    if (stats.months.isEmpty) {
      return const Center(child: Text('No historical readings yet for area graph.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return LineChart(
      key: const ValueKey('insights_area'),
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= stats.months.length) return const SizedBox();
                final monthStr = stats.months[idx].key;
                final label = monthStr.split('-')[1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
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
                  AppTheme.primary.withOpacity(0.35),
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

  Widget _buildMeterInsightCard(BuildContext context, Meter m, WattWiseStore store) {
    final used = store.unitsThisCycle(m);
    final cycle = cycleFor(m);
    
    final daysElapsed = cycle.daysElapsed;
    final remainingDays = cycle.daysRemaining;

    String pacingText;
    Color pacingColor = AppTheme.accent;

    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      int remaining = (m.monthlyLimit! - used).clamp(0, m.monthlyLimit!);
      int targetPerDay = remainingDays > 0 ? (remaining / remainingDays).round() : 0;
      pacingText = 'Target: ~$targetPerDay units/day';
      if (used >= m.monthlyLimit!) {
        pacingColor = AppTheme.danger;
      } else {
        pacingColor = AppTheme.success;
      }
    } else {
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;
      pacingText = 'Avg: ~$avgPerDay units/day';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.gauge, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${cycle.daysRemaining} days remaining in cycle',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$used units',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accent)),
                    if (m.monthlyLimit != null)
                      Text('Limit: ${m.monthlyLimit}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pacingColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(m.monthlyLimit != null ? LucideIcons.target : LucideIcons.activity,
                      size: 14, color: pacingColor),
                  const SizedBox(width: 6),
                  Text(pacingText,
                      style: TextStyle(fontSize: 12, color: pacingColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
