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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildSectionHeader('Preferences'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.building2, color: AppTheme.accent, size: 20),
                    ),
                    title: const Text(
                      'Default Provider',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Primary utility for new meters',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: store.defaultCompany,
                        borderRadius: BorderRadius.circular(12),
                        items: _providers
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
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
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Notifications'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.bell, color: AppTheme.success, size: 20),
                    ),
                    title: const Text(
                      'Reading Reminders',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Alerts before billing cycle ends',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    value: store.remindersEnabled,
                    activeColor: AppTheme.accent,
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
              const SizedBox(height: 24),
              _buildSectionHeader('Billing & Tariff'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.shieldCheck, color: AppTheme.warning, size: 20),
                    ),
                    title: const Text(
                      'Protected Consumer Tariff',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Apply subsidized tier rates under 200 units',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    value: store.protectedTariff,
                    activeColor: AppTheme.accent,
                    onChanged: (val) {
                      store.setProtectedTariff(val);
                      AppToast.show(
                        context,
                        message: val
                            ? 'Protected tariff enabled'
                            : 'Protected tariff disabled',
                        type: ToastType.info,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Data Management'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.refreshCw, color: AppTheme.accent, size: 20),
                    ),
                    title: const Text(
                      'Restore Hidden Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Un-dismiss all active cycle notifications',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textMuted),
                    onTap: () {
                      store.dismissed.clear();
                      AppToast.show(
                        context,
                        message: 'All notifications restored',
                        type: ToastType.success,
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.trash2, color: AppTheme.danger, size: 20),
                    ),
                    title: const Text(
                      'Clear Reading History',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.danger,
                      ),
                    ),
                    subtitle: const Text(
                      'Delete recorded scans while keeping meters',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textMuted),
                    onTap: () => _confirmResetHistory(context, store),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.zap, size: 20, color: Color(0xFFFBBF24)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'WattWise v1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Electricity meter & billing tracker',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupedCard({required List<Widget> children}) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  void _confirmResetHistory(BuildContext context, WattWiseStore store) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Reading History?'),
        content: const Text(
          'All recorded meter scans will be deleted. Your meters and billing parameters will remain intact.',
        ),
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
                message: 'Reading history cleared',
                type: ToastType.warning,
              );
            },
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }
}
