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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.bellOff, size: 48, color: AppTheme.success),
                  ),
                  const SizedBox(height: 20),
                  Text('All caught up!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('No new alerts at this time.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          // Group alerts by tone for visual hierarchy
          final dangerAlerts = alerts.where((a) => a.tone == 'danger').toList();
          final warnAlerts = alerts.where((a) => a.tone == 'warn').toList();
          final goodAlerts = alerts.where((a) => a.tone == 'good').toList();
          final infoAlerts = alerts.where((a) => a.tone == 'info').toList();
          final grouped = [...dangerAlerts, ...warnAlerts, ...goodAlerts, ...infoAlerts];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary header
              _buildSummaryHeader(context, alerts),
              const SizedBox(height: 20),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dangerCount > 0
                      ? [AppTheme.danger, AppTheme.danger.withOpacity(0.7)]
                      : warnCount > 0
                          ? [AppTheme.warning, AppTheme.warning.withOpacity(0.7)]
                          : [AppTheme.accent, AppTheme.accent.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.bell, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalCount Active Alert${totalCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (dangerCount > 0) ...[
                        _buildMiniPill('$dangerCount critical', AppTheme.danger),
                        const SizedBox(width: 8),
                      ],
                      if (warnCount > 0) ...[
                        _buildMiniPill('$warnCount warning', AppTheme.warning),
                      ],
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

  Widget _buildMiniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
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
        bgColor = AppTheme.danger.withOpacity(0.06);
        break;
      case 'warn':
        accentColor = AppTheme.warning;
        icon = LucideIcons.alertCircle;
        bgColor = AppTheme.warning.withOpacity(0.06);
        break;
      case 'good':
        accentColor = AppTheme.success;
        icon = LucideIcons.checkCircle;
        bgColor = AppTheme.success.withOpacity(0.06);
        break;
      case 'info':
      default:
        accentColor = AppTheme.accent;
        icon = LucideIcons.info;
        bgColor = AppTheme.accent.withOpacity(0.06);
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
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: AppTheme.danger),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(alert.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.meterName,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(alert.body,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM · h:mm a').format(DateTime.now()),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => store.dismissAlert(alert.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.check, size: 14, color: AppTheme.textSecondary),
                                SizedBox(width: 4),
                                Text('Dismiss', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
