import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../models/wattwise_types.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.mounted) {
              context.pop();
            }
          },
        ),
      ),
      body: Consumer<WattWiseStore>(
        builder: (context, store, child) {
          final alerts = store.buildAlerts();

          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.checkCheck, size: 44, color: AppTheme.success),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No active alerts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All monitored meters are operating within normal billing limits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
            );
          }

          final dangerAlerts = alerts.where((a) => a.tone == 'danger').toList();
          final warnAlerts = alerts.where((a) => a.tone == 'warn').toList();
          final goodAlerts = alerts.where((a) => a.tone == 'good').toList();
          final infoAlerts = alerts.where((a) => a.tone == 'info').toList();
          final grouped = [...dangerAlerts, ...warnAlerts, ...goodAlerts, ...infoAlerts];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildSummaryHeader(context, alerts),
              const SizedBox(height: 16),
              ...grouped.map((a) => _buildAlertCard(context, a, store)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, List<Alert> alerts) {
    final dangerCount = alerts.where((a) => a.tone == 'danger').length;
    final warnCount = alerts.where((a) => a.tone == 'warn').length;
    final totalCount = alerts.length;

    Color headerColor = AppTheme.primary;
    if (dangerCount > 0) {
      headerColor = AppTheme.danger;
    } else if (warnCount > 0) {
      headerColor = AppTheme.warning;
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
              color: headerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.bell, color: headerColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCount Alert${totalCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (dangerCount > 0) ...[
                      _buildMiniPill('$dangerCount critical', AppTheme.danger, AppTheme.dangerLight),
                      const SizedBox(width: 6),
                    ],
                    if (warnCount > 0) ...[
                      _buildMiniPill('$warnCount warning', AppTheme.warning, AppTheme.warningLight),
                      const SizedBox(width: 6),
                    ],
                    if (dangerCount == 0 && warnCount == 0) ...[
                      _buildMiniPill('Status update', AppTheme.accent, AppTheme.accentLight),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert, WattWiseStore store) {
    Color accentColor;
    IconData icon;
    Color bgColor;

    switch (alert.tone) {
      case 'danger':
        accentColor = AppTheme.danger;
        icon = LucideIcons.alertTriangle;
        bgColor = AppTheme.dangerLight;
        break;
      case 'warn':
        accentColor = AppTheme.warning;
        icon = LucideIcons.alertCircle;
        bgColor = AppTheme.warningLight;
        break;
      case 'good':
        accentColor = AppTheme.success;
        icon = LucideIcons.checkCircle2;
        bgColor = AppTheme.successLight;
        break;
      case 'info':
      default:
        accentColor = AppTheme.accent;
        icon = LucideIcons.info;
        bgColor = AppTheme.accentLight;
        break;
    }

    return Dismissible(
      key: Key(alert.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => store.dismissAlert(alert.key),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.dangerLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: const Icon(LucideIcons.trash2, color: AppTheme.danger, size: 20),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            alert.meterName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM · h:mm a').format(DateTime.now()),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => store.dismissAlert(alert.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.check, size: 13, color: AppTheme.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}
