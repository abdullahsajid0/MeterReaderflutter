import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../services/wattwise_billing.dart';

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
        int overLimitCount = 0;

        for (var m in meters) {
          final used = store.unitsThisCycle(m);
          totalUnitsThisCycle += used;
          if (m.monthlyLimit != null && used > m.monthlyLimit!) {
            overLimitCount++;
          }
        }

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
              subtitle: 'Across all meters this cycle',
              icon: LucideIcons.zap,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Active Meters',
                    value: '${meters.length}',
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
                    icon: LucideIcons.alertTriangle,
                    color: overLimitCount > 0 ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Meter Breakdown',
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
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
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
                    ?.copyWith(color: AppTheme.textPrimary)),
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

  Widget _buildMeterInsightCard(BuildContext context, dynamic m, WattWiseStore store) {
    final used = store.unitsThisCycle(m);
    final cycle = cycleFor(m);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.gauge, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${cycle.daysRemaining} days remaining in cycle', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$used units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (m.monthlyLimit != null)
                  Text('Limit: ${m.monthlyLimit}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
