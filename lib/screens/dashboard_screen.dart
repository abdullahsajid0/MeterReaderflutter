import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../models/wattwise_types.dart';
import '../services/wattwise_billing.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
                const Icon(LucideIcons.zap, size: 64, color: AppTheme.border),
                const SizedBox(height: 16),
                Text('No meters yet',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Add your first electricity meter to get started.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add Meter'),
                  onPressed: () => context.push('/meters/new'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Meters',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add'),
                  onPressed: () => context.push('/meters/new'),
                )
              ],
            ),
            const SizedBox(height: 8),
            ...meters.map((m) => _buildMeterCard(context, m, store)),
          ],
        );
      },
    );
  }

  Widget _buildMeterCard(BuildContext context, Meter m, WattWiseStore store) {
    final used = store.unitsThisCycle(m);
    final cycle = cycleFor(m);
    double pct = 0;
    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      pct = used / m.monthlyLimit!;
    }

    Color progressColor = AppTheme.success;
    if (pct >= 1.0) {
      progressColor = AppTheme.danger;
    } else if (pct >= 0.85) {
      progressColor = AppTheme.warning;
    } else if (pct >= 0.6) {
      progressColor = AppTheme.warning.withOpacity(0.8);
    }

    if (pct > 1.0) pct = 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/meters/${m.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.zap, size: 22, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.nickname,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m.company.toUpperCase(),
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accent.withOpacity(0.1),
                    ),
                    icon:
                        const Icon(LucideIcons.camera, color: AppTheme.accent, size: 20),
                    onPressed: () => context.push('/meters/${m.id}/scan'),
                  )
                ],
              ),
              const SizedBox(height: 20),
              if (m.monthlyLimit != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$used / ${m.monthlyLimit} units',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(
                            color: progressColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
              ] else ...[
                Text('$used units used this cycle',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatCycle(cycle),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  Text('${cycle.daysRemaining} days left',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: cycle.progressPct / 100,
                backgroundColor: AppTheme.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
