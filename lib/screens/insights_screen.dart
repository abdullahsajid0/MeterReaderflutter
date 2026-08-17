import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.trendingUp, size: 44, color: AppTheme.accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No meters added',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add meters to see consumption trends and daily target pacing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Add Meter'),
                    onPressed: () => context.push('/meters/new'),
                  ),
                ],
              ),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildSectionTitle(context, 'Overview'),
            const SizedBox(height: 10),
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
                    child: _buildMiniStatCard(
                      context,
                      title: 'Active Meters',
                      value: '${meters.length}',
                      subtitle: 'Tracked',
                      icon: LucideIcons.home,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStatCard(
                      context,
                      title: 'Over Target',
                      value: '$overLimitCount',
                      subtitle: overLimitCount > 0 ? 'Exceeded' : 'On track',
                      icon: overLimitCount > 0 ? LucideIcons.alertTriangle : LucideIcons.checkCircle2,
                      color: overLimitCount > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Usage by Meter'),
            const SizedBox(height: 10),
            _buildConsumptionGraph(context, meters, store),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Meter Breakdown'),
            const SizedBox(height: 10),
            ...meters.map((m) => _buildMeterInsightCard(context, m, store)),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
      ),
    );
  }

  Widget _buildDailyPacingSummaryCard({
    required int targetPerDay,
    required int remainingUnits,
    required int daysLeft,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.target, color: AppTheme.success, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Pacing Target',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '~$targetPerDay units/day',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$remainingUnits units remaining across $daysLeft days',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionGraph(BuildContext context, List<Meter> meters, WattWiseStore store) {
    final List<MapEntry<String, int>> data = [];
    int maxVal = 10;
    for (var m in meters) {
      final used = store.unitsThisCycle(m);
      data.add(MapEntry(m.nickname, used));
      if (used > maxVal) maxVal = used;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Cycle Usage',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              Icon(LucideIcons.trendingUp, size: 18, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 20),
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
                    Text(
                      '${e.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: 28,
                      height: 90 * pct,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, Color(0xFF60A5FA)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.key.length > 8 ? '${e.key.substring(0, 7)}…' : e.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
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
      pacingText = 'Average: ~$avgPerDay units/day';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.gauge, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${cycle.daysRemaining} days left in cycle',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$used units',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.accent,
                    ),
                  ),
                  if (m.monthlyLimit != null)
                    Text(
                      'Limit: ${m.monthlyLimit}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pacingColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.monthlyLimit != null ? LucideIcons.target : LucideIcons.activity,
                  size: 13,
                  color: pacingColor,
                ),
                const SizedBox(width: 6),
                Text(
                  pacingText,
                  style: TextStyle(
                    fontSize: 12,
                    color: pacingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
