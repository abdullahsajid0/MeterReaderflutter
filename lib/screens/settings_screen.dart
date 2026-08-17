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
                    activeThumbColor: AppTheme.accent,
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
              _buildSectionHeader('Data Management'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                children: [
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
              const SizedBox(height: 48),

              // Version Section (Prominently styled)
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.gauge, size: 24, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'WattWise',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Electricity meter & billing tracker',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
