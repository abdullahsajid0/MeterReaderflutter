import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  String nickname = '';
  String company = 'LESCO';
  String referenceNumber = '';
  int readingDay = 10;
  int? limit;

  final companies = [
    'LESCO',
    'IESCO',
    'GEPCO',
    'FESCO',
    'MEPCO',
    'PESCO',
    'HESCO',
    'SEPCO',
    'QESCO',
    'TESCO'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meter'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.mounted) {
              context.pop();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormCard(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Meter Nickname',
                      hintText: 'e.g. Home, Ground Floor, Office',
                      prefixIcon: Icon(LucideIcons.home, size: 18, color: AppTheme.textSecondary),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a nickname' : null,
                    onSaved: (v) => nickname = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Electricity Provider',
                      prefixIcon: Icon(LucideIcons.building2, size: 18, color: AppTheme.textSecondary),
                    ),
                    initialValue: company,
                    borderRadius: BorderRadius.circular(14),
                    items: companies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => company = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Reference Number',
                      hintText: '14-digit consumer number from bill',
                      prefixIcon: Icon(LucideIcons.hash, size: 18, color: AppTheme.textSecondary),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Reference number is required';
                      final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                      if (digitsOnly.length < 10) return 'Must contain at least 10 digits';
                      return null;
                    },
                    onSaved: (v) => referenceNumber = v!.trim(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFormCard(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Billing Reading Day',
                      hintText: 'Day of month (1 – 28)',
                      helperText: 'Date your meter reader usually visits each month',
                      prefixIcon: Icon(LucideIcons.calendar, size: 18, color: AppTheme.textSecondary),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: '10',
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 28) {
                        return 'Enter a day between 1 and 28';
                      }
                      return null;
                    },
                    onSaved: (v) => readingDay = int.parse(v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Monthly Unit Target (Optional)',
                      hintText: 'e.g. 200 or 300 units',
                      helperText: 'Helps calculate daily pacing and budget alerts',
                      prefixIcon: Icon(LucideIcons.target, size: 18, color: AppTheme.textSecondary),
                    ),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => limit = int.tryParse(v?.trim() ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    context.read<WattWiseStore>().addMeter(
                          nickname: nickname,
                          company: company,
                          referenceNumber: referenceNumber,
                          readingDay: readingDay,
                          monthlyLimit: limit,
                        );
                    context.pop();
                  }
                },
                child: const Text('Save Meter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
