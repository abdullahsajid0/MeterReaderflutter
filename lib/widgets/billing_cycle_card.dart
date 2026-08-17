import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/wattwise_types.dart';
import '../services/wattwise_billing.dart';
import '../theme/app_theme.dart';

class BillingCycleCard extends StatelessWidget {
  final Meter meter;
  final Cycle cycle;
  final BillInfo? bill;
  final VoidCallback onEditSchedule;
  final VoidCallback onFetchBill;

  const BillingCycleCard({
    super.key,
    required this.meter,
    required this.cycle,
    required this.bill,
    required this.onEditSchedule,
    required this.onFetchBill,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final scheduleText = meter.nextReadingDateOverride == null
        ? 'Repeats around day ${meter.readingDay} of each cycle'
        : 'Active date override';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.calendarClock, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Billing Cycle',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: 'Edit reading schedule',
                icon: const Icon(LucideIcons.pencil, size: 16, color: AppTheme.textSecondary),
                onPressed: onEditSchedule,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${dateFormat.format(cycle.start)} – ${dateFormat.format(cycle.end)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scheduleText,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(label: 'Elapsed', value: '${cycle.daysElapsed} days'),
              _Metric(label: 'Remaining', value: '${cycle.daysRemaining} days'),
              _Metric(label: 'Next Reading', value: DateFormat('d MMM').format(cycle.end)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (cycle.progressPct / 100).clamp(0.0, 1.0),
              backgroundColor: AppTheme.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${cycle.progressPct}% elapsed this cycle',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onFetchBill,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(bill == null ? 'Fetch Official Bill' : 'Refresh Official Bill'),
            ),
          ),
          if (bill != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(LucideIcons.receipt, size: 15, color: AppTheme.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Official bill recorded: ${dateFormat.format(DateTime.parse(bill!.readingDate))}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BillMetric(label: 'Previous', value: bill!.previousReading.toString()),
                _BillMetric(label: 'Present', value: bill!.currentReading.toString()),
                _BillMetric(label: 'Units used', value: bill!.unitsBilled.toString()),
                if (bill!.amountPkr != null)
                  _BillMetric(label: 'Amount', value: 'Rs ${bill!.amountPkr}'),
                if (bill!.dueDate != null)
                  _BillMetric(
                    label: 'Due date',
                    value: DateFormat('d MMM').format(DateTime.parse(bill!.dueDate!)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BillMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 95),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
