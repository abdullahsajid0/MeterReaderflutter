import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
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
                  const Icon(LucideIcons.bellOff, size: 64, color: AppTheme.border),
                  const SizedBox(height: 16),
                  Text('All caught up', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('No new alerts at this time.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _buildAlertCard(context, alerts[index], store);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert, WattWiseStore store) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (alert.tone) {
      case 'danger':
        bgColor = AppTheme.danger.withOpacity(0.1);
        iconColor = AppTheme.danger;
        icon = LucideIcons.alertTriangle;
        break;
      case 'warn':
        bgColor = AppTheme.warning.withOpacity(0.1);
        iconColor = AppTheme.warning;
        icon = LucideIcons.alertCircle;
        break;
      case 'good':
        bgColor = AppTheme.success.withOpacity(0.1);
        iconColor = AppTheme.success;
        icon = LucideIcons.checkCircle;
        break;
      case 'info':
      default:
        bgColor = AppTheme.accent.withOpacity(0.1);
        iconColor = AppTheme.accent;
        icon = LucideIcons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(alert.body,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(LucideIcons.x, size: 20, color: AppTheme.textSecondary),
            onPressed: () => store.dismissAlert(alert.key),
          )
        ],
      ),
    );
  }
}
