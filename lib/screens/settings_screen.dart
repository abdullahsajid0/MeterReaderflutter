import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _providers = [
    'LESCO',
    'MEPCO',
    'FESCO',
    'IESCO',
    'PESCO',
    'GEPCO',
    'HESCO',
    'SEPCO',
    'QESCO',
    'TESCO',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('General Preferences'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.building2, color: AppTheme.accent),
                      ),
                      title: const Text('Default Provider',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Primary electricity company for new meters'),
                      trailing: DropdownButton<String>(
                        value: store.defaultCompany,
                        underline: const SizedBox(),
                        items: _providers
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            store.setDefaultCompany(val);
                            AppToast.show(
                              context,
                              message: 'Default provider updated to $val',
                              type: ToastType.success,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Notifications & Reminders'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.bell, color: AppTheme.success),
                      ),
                      title: const Text('Reading Reminders',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Native device alerts before billing cycle ends'),
                      value: store.remindersEnabled,
                      onChanged: (val) {
                        store.setRemindersEnabled(val);
                        AppToast.show(
                          context,
                          message: val
                              ? 'Reading reminders enabled'
                              : 'Reading reminders disabled',
                          type: val ? ToastType.success : ToastType.info,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Tariff & Billing'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.shieldCheck, color: AppTheme.warning),
                      ),
                      title: const Text('Protected Consumer Tariff',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Apply subsidized rates for under 200 units'),
                      value: store.protectedTariff,
                      onChanged: (val) {
                        store.setProtectedTariff(val);
                        AppToast.show(
                          context,
                          message: val
                              ? 'Protected tariff mode enabled'
                              : 'Protected tariff mode disabled',
                          type: ToastType.info,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Data & Storage'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.refreshCw, color: AppTheme.accent),
                      ),
                      title: const Text('Restore Hidden Alerts',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Clear list of dismissed notifications'),
                      onTap: () {
                        store.dismissed.clear();
                        AppToast.show(
                          context,
                          message: 'All hidden notifications restored',
                          type: ToastType.success,
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.trash2, color: AppTheme.danger),
                      ),
                      title: const Text('Reset Reading History',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Clear saved meter scans and history'),
                      onTap: () => _confirmResetHistory(context, store),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.zap, size: 28, color: AppTheme.accent),
                    const SizedBox(height: 8),
                    Text(
                      'WattWise v1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Smart Electricity Meter & Billing Assistant',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _confirmResetHistory(BuildContext context, WattWiseStore store) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Reading History?'),
        content: const Text(
            'Are you sure you want to clear all meter reading records? Your meters will remain intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              store.readings.clear();
              Navigator.of(dialogContext).pop();
              AppToast.show(
                context,
                message: 'Meter reading history cleared',
                type: ToastType.warning,
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
