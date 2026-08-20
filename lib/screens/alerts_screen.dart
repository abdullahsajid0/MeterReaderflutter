import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../models/wattwise_types.dart';
import '../widgets/app_toast.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WattWiseStore>(
      builder: (context, store, child) {
        final alerts = store.buildAlerts();

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
            actions: [
              if (alerts.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () {
                    store.dismissAllAlerts(alerts.map((a) => a.key).toList());
                    AppToast.show(
                      context,
                      message: 'All notifications cleared',
                      type: ToastType.info,
                    );
                  },
                ),
            ],
          ),
          body: alerts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.checkCheck, size: 44, color: AppTheme.success),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No notifications',
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return _buildNotificationCard(context, alert, store);
                  },
                ),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, Alert alert, WattWiseStore store) {
    Color accentColor;
    IconData icon;
    Color iconBg;

    switch (alert.tone) {
      case 'danger':
        accentColor = AppTheme.danger;
        icon = LucideIcons.alertTriangle;
        iconBg = AppTheme.dangerLight;
        break;
      case 'warn':
        accentColor = AppTheme.warning;
        icon = LucideIcons.alertCircle;
        iconBg = AppTheme.warningLight;
        break;
      case 'good':
        accentColor = AppTheme.success;
        icon = LucideIcons.checkCircle2;
        iconBg = AppTheme.successLight;
        break;
      case 'info':
      default:
        accentColor = AppTheme.accent;
        icon = LucideIcons.info;
        iconBg = AppTheme.accentLight;
        break;
    }

    return Dismissible(
      key: Key(alert.key),
      direction: DismissDirection.horizontal, // Swipe left-to-right or right-to-left
      onDismissed: (_) {
        store.dismissAlert(alert.key);
        AppToast.show(
          context,
          message: 'Notification dismissed',
          type: ToastType.info,
        );
      },
      // Left-to-right swipe background
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.dangerLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: const Icon(LucideIcons.trash2, color: AppTheme.danger, size: 20),
      ),
      // Right-to-left swipe background
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.dangerLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
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
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
                  color: iconBg,
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
