import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../services/wattwise_billing.dart';
import '../models/wattwise_types.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

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
            Text('Consumption Visual Trend',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildConsumptionGraph(context, meters, store),
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

  Widget _buildConsumptionGraph(BuildContext context, List<Meter> meters, WattWiseStore store) {
    // Generate data per meter for graph
    final List<MapEntry<String, int>> data = [];
    int maxVal = 10;
    for (var m in meters) {
      final used = store.unitsThisCycle(m);
      data.add(MapEntry(m.nickname, used));
      if (used > maxVal) maxVal = used;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Cycle Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(LucideIcons.barChart2, size: 18, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((e) {
                  final double pct = (e.value / maxVal).clamp(0.08, 1.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 32,
                        height: 90 * pct,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentGradient],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.key.length > 8 ? '${e.key.substring(0, 7)}…' : e.key,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
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
