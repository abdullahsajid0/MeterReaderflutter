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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.gauge, size: 44, color: AppTheme.accent),
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
                    'Add an electricity meter to track consumption, billing cycles, and targets.',
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meters (${meters.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/meters/new'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(LucideIcons.plus, size: 15, color: AppTheme.accent),
                          SizedBox(width: 4),
                          Text(
                            'Add Meter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...meters.map((m) => _TactileMeterCard(meter: m, store: store)),
          ],
        );
      },
    );
  }
}

/// Tactile Meter Card with Apple-style press-down response
class _TactileMeterCard extends StatefulWidget {
  final Meter meter;
  final WattWiseStore store;

  const _TactileMeterCard({
    required this.meter,
    required this.store,
  });

  @override
  State<_TactileMeterCard> createState() => _TactileMeterCardState();
}

class _TactileMeterCardState extends State<_TactileMeterCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.meter;
    final used = widget.store.unitsThisCycle(m);
    final cycle = cycleFor(m);

    final daysElapsed = cycle.daysElapsed;
    final remainingDays = cycle.daysRemaining;

    double pct = 0;
    String pacingLabel = "";

    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      pct = used / m.monthlyLimit!;
      int remainingUnits = (m.monthlyLimit! - used).clamp(0, m.monthlyLimit!);
      int targetPerDay = remainingDays > 0 ? (remainingUnits / remainingDays).round() : 0;
      pacingLabel = 'Target: ~$targetPerDay units/day · $remainingUnits remaining';
    } else {
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;
      pacingLabel = 'Averaging ~$avgPerDay units/day over $daysElapsed days';
    }

    Color progressColor = AppTheme.success;
    if (pct >= 1.0) {
      progressColor = AppTheme.danger;
    } else if (pct >= 0.85) {
      progressColor = AppTheme.warning;
    } else if (pct >= 0.6) {
      progressColor = const Color(0xFFEAB308);
    }

    final clampedPct = pct.clamp(0.0, 1.0);

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onHighlightChanged: (pressed) {
              setState(() {
                _isPressed = pressed;
              });
            },
            onTap: () => context.push('/meters/${m.id}'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Avatar + Nickname & Meta + Scan action
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(LucideIcons.gauge, size: 20, color: AppTheme.accent),
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
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    m.company.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.referenceNumber,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accentLight,
                          foregroundColor: AppTheme.accent,
                          padding: const EdgeInsets.all(10),
                        ),
                        icon: const Icon(LucideIcons.camera, size: 18),
                        tooltip: 'Scan meter',
                        onPressed: () => context.push('/meters/${m.id}/scan'),
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Units Consumption Headline
                  if (m.monthlyLimit != null && m.monthlyLimit! > 0) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$used',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${m.monthlyLimit} units',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: TextStyle(
                            color: progressColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: clampedPct,
                        backgroundColor: AppTheme.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 6,
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$used',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'units this cycle',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Pacing Label Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m.monthlyLimit != null ? LucideIcons.target : LucideIcons.activity,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pacingLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cycle timeline info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCycle(cycle),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${cycle.daysRemaining} days left',
                        style: TextStyle(
                          fontSize: 12,
                          color: cycle.daysRemaining <= 3 ? AppTheme.danger : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (cycle.progressPct / 100).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
