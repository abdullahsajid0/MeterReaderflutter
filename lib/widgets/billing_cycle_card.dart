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
        ? 'Repeats around day ${meter.readingDay} each cycle'
        : 'One-time date override';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.calendarClock,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Billing cycle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(
                  tooltip: 'Edit reading schedule',
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: onEditSchedule,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${dateFormat.format(cycle.start)} – ${dateFormat.format(cycle.end)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(scheduleText,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(label: 'Elapsed', value: '${cycle.daysElapsed} days'),
                _Metric(
                    label: 'Remaining', value: '${cycle.daysRemaining} days'),
                _Metric(
                    label: 'Reading day',
                    value: DateFormat('d MMM').format(cycle.end)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: cycle.progressPct / 100,
                backgroundColor: AppTheme.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text('${cycle.progressPct}% through this cycle',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFetchBill,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: Text(bill == null
                    ? 'Fetch official bill'
                    : 'Refresh official bill'),
              ),
            ),
            if (bill != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(LucideIcons.receipt,
                      size: 16, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Official bill reading: ${dateFormat.format(DateTime.parse(bill!.readingDate))}',
                          style: const TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BillMetric(
                      label: 'Previous',
                      value: bill!.previousReading.toString()),
                  _BillMetric(
                      label: 'Present', value: bill!.currentReading.toString()),
                  _BillMetric(
                      label: 'Units used', value: bill!.unitsBilled.toString()),
                  if (bill!.amountPkr != null)
                    _BillMetric(
                        label: 'Bill amount', value: 'Rs ${bill!.amountPkr}'),
                  if (bill!.dueDate != null)
                    _BillMetric(
                        label: 'Due date',
                        value: DateFormat('d MMM')
                            .format(DateTime.parse(bill!.dueDate!))),
                ],
              ),
            ],
          ],
        ),
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
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
