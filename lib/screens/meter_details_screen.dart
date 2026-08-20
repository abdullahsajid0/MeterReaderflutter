import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import '../services/wattwise_billing.dart';
import '../models/wattwise_types.dart';
import '../widgets/billing_cycle_card.dart';
import '../widgets/app_toast.dart';
import '../services/pitc_bill_client.dart';

class MeterDetailsScreen extends StatefulWidget {
  final String meterId;

  const MeterDetailsScreen({super.key, required this.meterId});

  @override
  State<MeterDetailsScreen> createState() => _MeterDetailsScreenState();
}

enum ChartTimeframe { daily, monthly }

class _MeterDetailsScreenState extends State<MeterDetailsScreen> {
  ChartTimeframe _timeframe = ChartTimeframe.daily;
  double _zoomLevel = 1.0;
  DailyUsagePoint? _selectedDailyPoint;

  @override
  Widget build(BuildContext context) {
    return Consumer<WattWiseStore>(
      builder: (context, store, child) {
        final meterMatches = store.meters.where((m) => m.id == widget.meterId);
        if (meterMatches.isEmpty) {
          return const Scaffold(
            body: SizedBox.shrink(),
          );
        }
        final meter = meterMatches.first;
        final readings = store.readingsForMeter(meter.id);
        final cycle = store.cycleForMeter(meter);
        final used = store.unitsThisCycle(meter);
        final stats = analytics(readings);
        final dailyPoints = computeDailyCycleUsage(readings, cycle, latestBill: store.billFor(meter.id));

        // Filter readings for the current cycle (all readings taken since the last bill / cycle start)
        final bill = store.billFor(meter.id);
        final billDate = bill != null ? DateTime.tryParse(bill.readingDate) : null;
        final cycleReadings = readings.where((r) {
          final dt = DateTime.tryParse(r.scannedAt);
          if (dt != null) {
            if (billDate != null) {
              return !dt.isBefore(billDate.subtract(const Duration(hours: 12)));
            }
            return !dt.isBefore(cycle.start.subtract(const Duration(hours: 12)));
          }
          return r.billingMonth == cycle.billingMonth;
        }).toList();

        final isDaily = _timeframe == ChartTimeframe.daily;

        return Scaffold(
          appBar: AppBar(
            title: Text(meter.nickname),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.camera),
                tooltip: 'Scan meter',
                onPressed: () => context.push('/meters/${meter.id}/scan'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (val) {
                  if (val == 'delete') {
                    _confirmDeleteMeter(context, store, meter);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, color: AppTheme.danger, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Delete Meter',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildOverviewCard(context, meter, used, cycle),
              const SizedBox(height: 14),
              _buildDailyTargetCard(meter, used, cycle),
              const SizedBox(height: 14),
              BillingCycleCard(
                meter: meter,
                cycle: cycle,
                bill: store.billFor(meter.id),
                onEditSchedule: () => _editSchedule(context, store, meter, cycle),
                onFetchBill: () => _fetchBill(context, store, meter),
              ),
              const SizedBox(height: 24),
              if (readings.isNotEmpty) ...[
                _buildSectionHeader('Consumption Graph'),
                const SizedBox(height: 10),
                _buildAreaUsageCard(context, stats, dailyPoints),
                const SizedBox(height: 24),
                _buildSectionHeader(isDaily ? 'Current Cycle Readings' : 'Monthly History'),
                const SizedBox(height: 10),
                if (isDaily)
                  ..._buildCycleReadingTiles(context, cycleReadings)
                else
                  ..._buildMonthlyHistoryTiles(context, stats, readings),
                const SizedBox(height: 16),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, color: AppTheme.accent, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No readings recorded yet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan your meter to start tracking daily and monthly usage history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ─── Daily Target / Average Card ──────────────────────────────────────
  Widget _buildDailyTargetCard(Meter m, int used, Cycle cycle) {
    final daysElapsed = cycle.daysElapsed;
    final remainingDays = cycle.daysRemaining;

    String title;
    String value;
    String subtitle;
    IconData icon;
    Color accentColor;
    Color bgColor;

    if (m.monthlyLimit != null && m.monthlyLimit! > 0) {
      int remaining = (m.monthlyLimit! - used).clamp(0, m.monthlyLimit!);
      int targetPerDay = remainingDays > 0 ? (remaining / remainingDays).round() : 0;
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = cycle.isPendingOfficialBill ? 'Cycle Pacing' : 'Daily Target';
      value = cycle.isPendingOfficialBill ? '~$avgPerDay units/day' : '~$targetPerDay units/day';
      subtitle = cycle.isPendingOfficialBill
          ? '$used units used over $daysElapsed days · Limit was ${m.monthlyLimit} units'
          : 'Averaging ~$avgPerDay units/day · $remaining units left in $remainingDays days';
      icon = LucideIcons.target;
      accentColor = remaining > 0 ? AppTheme.success : AppTheme.danger;
      bgColor = remaining > 0 ? AppTheme.successLight : AppTheme.dangerLight;
    } else {
      int avgPerDay = daysElapsed > 0 ? (used / daysElapsed).round() : 0;

      title = 'Daily Average';
      value = '~$avgPerDay units/day';
      subtitle = '$used units consumed over $daysElapsed days this cycle';
      icon = LucideIcons.activity;
      accentColor = AppTheme.accent;
      bgColor = AppTheme.accentLight;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Area Usage Graph (Daily & Monthly with Sticky Y-Axis & Zoom) ────
  Widget _buildAreaUsageCard(
    BuildContext context,
    AnalyticsResult stats,
    List<DailyUsagePoint> dailyPoints,
  ) {
    final isDaily = _timeframe == ChartTimeframe.daily;

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
          // Timeframe Header Row
          Row(
            children: [
              Expanded(
                child: Text(
                  isDaily ? 'Daily Trend' : 'Monthly Trend',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Daily vs Monthly pill selector
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _timeframeTabButton(
                      title: 'Daily',
                      isActive: isDaily,
                      onTap: () => setState(() => _timeframe = ChartTimeframe.daily),
                    ),
                    _timeframeTabButton(
                      title: 'Monthly',
                      isActive: !isDaily,
                      onTap: () => setState(() => _timeframe = ChartTimeframe.monthly),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Subtitle + Zoom Controls (Clean, un-truncated layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isDaily ? '24h Daily Usage (Units)' : 'Monthly Overview (Units)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isDaily && dailyPoints.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _zoomButton(
                        label: '1x Fit',
                        isActive: _zoomLevel == 1.0,
                        onTap: () => setState(() => _zoomLevel = 1.0),
                      ),
                      _zoomButton(
                        label: '2.5x Detail',
                        isActive: _zoomLevel == 2.5,
                        onTap: () => setState(() => _zoomLevel = 2.5),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Selected Point Details Card (if tapped)
          if (_selectedDailyPoint != null && isDaily) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Text(
                    _selectedDailyPoint!.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· ${_selectedDailyPoint!.units} units',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.accent,
                    ),
                  ),
                  if (_selectedDailyPoint!.readingValue != null) ...[
                    const Spacer(),
                    Text(
                      'Reading: ${_selectedDailyPoint!.readingValue}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Sticky Y-Axis + Zoomable Area Graph
          SizedBox(
            height: 195,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isDaily
                  ? _buildZoomableDailyAreaChart(dailyPoints)
                  : _buildMonthlyAreaChart(stats),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeframeTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _zoomButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Sticky Y-Axis + Zoomable Daily Area Chart ────────────────────────
  Widget _buildZoomableDailyAreaChart(List<DailyUsagePoint> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text('No daily data available for this cycle', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    double maxVal = points.map((p) => p.units).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) maxVal = 10;
    final double yInterval = (maxVal / 3).clamp(1.0, 1000.0);
    final isZoomed = _zoomLevel > 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const double yAxisWidth = 28.0;
        final chartAvailableWidth = availableWidth - yAxisWidth - 6;
        final chartContentWidth = isZoomed
            ? math.max(chartAvailableWidth, points.length * 36.0 * (_zoomLevel / 2.0))
            : chartAvailableWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sticky Fixed Left Y-Axis (stays static on screen!)
            SizedBox(
              width: yAxisWidth,
              height: 165,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    maxVal >= 1000 ? '${(maxVal / 1000).toStringAsFixed(1)}k' : '${(maxVal * 1.25).round()}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    maxVal >= 1000 ? '${((maxVal * 2 / 3) / 1000).toStringAsFixed(1)}k' : '${(maxVal * 2 / 3).round()}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    maxVal >= 1000 ? '${((maxVal / 3) / 1000).toStringAsFixed(1)}k' : '${(maxVal / 3).round()}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    '0',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // 2. Horizontally Scrollable Chart Surface
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: isZoomed
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: chartContentWidth,
                  height: 195,
                  child: LineChart(
                    key: ValueKey('daily_area_zoom_$_zoomLevel'),
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: isZoomed,
                        verticalInterval: 1.0,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppTheme.border.withValues(alpha: 0.5),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: AppTheme.border.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: isZoomed ? 1.0 : (points.length / 5).clamp(1, 10).toDouble(),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= points.length) return const SizedBox();
                              final p = points[idx];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  isZoomed ? p.shortLabel : p.label,
                                  style: TextStyle(
                                    fontSize: isZoomed ? 11 : 10,
                                    color: p.hasActualReading ? AppTheme.accent : AppTheme.textSecondary,
                                    fontWeight: p.hasActualReading || isZoomed ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                            final spot = response.lineBarSpots!.first;
                            final idx = spot.x.toInt();
                            if (idx >= 0 && idx < points.length) {
                              setState(() {
                                _selectedDailyPoint = points[idx];
                              });
                            }
                          }
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              if (idx < 0 || idx >= points.length) return null;
                              final p = points[idx];
                              return LineTooltipItem(
                                '${p.label}\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${p.units} units',
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      minY: 0,
                      maxY: maxVal * 1.25,
                      lineBarsData: [
                        LineChartBarData(
                          spots: points.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.units);
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.accent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) {
                              final idx = spot.x.toInt();
                              if (isZoomed) return true;
                              return idx >= 0 && idx < points.length && points[idx].hasActualReading;
                            },
                            getDotPainter: (spot, percent, barData, index) {
                              final idx = spot.x.toInt();
                              final isActual = idx >= 0 && idx < points.length && points[idx].hasActualReading;
                              return FlDotCirclePainter(
                                radius: isActual ? 4.5 : 2.5,
                                color: isActual ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.7),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accent.withValues(alpha: 0.22),
                                AppTheme.accent.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Sticky Y-Axis + Monthly Area Chart ───────────────────────────────
  Widget _buildMonthlyAreaChart(AnalyticsResult stats) {
    if (stats.months.isEmpty) {
      return const Center(
        child: Text('No monthly history recorded yet', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    double maxVal = stats.months.map((m) => m.value).fold(0, (a, b) => a > b ? a : b).toDouble();
    if (maxVal <= 0) maxVal = 100;
    final double yInterval = (maxVal / 3).clamp(1.0, 1000.0);
    const double yAxisWidth = 28.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky Left Y-Axis
        SizedBox(
          width: yAxisWidth,
          height: 165,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                maxVal >= 1000 ? '${(maxVal / 1000).toStringAsFixed(1)}k' : '${(maxVal * 1.25).round()}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              Text(
                maxVal >= 1000 ? '${((maxVal * 2 / 3) / 1000).toStringAsFixed(1)}k' : '${(maxVal * 2 / 3).round()}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              Text(
                maxVal >= 1000 ? '${((maxVal / 3) / 1000).toStringAsFixed(1)}k' : '${(maxVal / 3).round()}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              const Text(
                '0',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: SizedBox(
            height: 195,
            child: LineChart(
              key: const ValueKey('monthly_area'),
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= stats.months.length) {
                          return const SizedBox();
                        }
                        final monthStr = stats.months[value.toInt()].key;
                        final label = monthStr.split('-')[1];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: true),
                minY: 0,
                maxY: maxVal * 1.25,
                lineBarsData: [
                  LineChartBarData(
                    spots: stats.months.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: AppTheme.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.2),
                          AppTheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Current Cycle Reading Tiles ──────────────────────────────────────
  List<Widget> _buildCycleReadingTiles(BuildContext context, List<Reading> cycleReadings) {
    if (cycleReadings.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Center(
            child: Text(
              'No readings recorded for this active cycle yet.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        )
      ];
    }

    final tiles = <Widget>[];
    for (int i = 0; i < cycleReadings.length; i++) {
      final r = cycleReadings[i];
      final scannedDate = DateTime.tryParse(r.scannedAt);
      final dateStr = scannedDate != null
          ? DateFormat('d MMM · h:mm a').format(scannedDate.toLocal())
          : r.billingMonth;

      String deltaText = '';
      if (i < cycleReadings.length - 1) {
        final older = cycleReadings[i + 1];
        final delta = r.currentReading - older.currentReading;
        deltaText = delta >= 0 ? '+$delta units since previous scan' : '$delta units';
      } else {
        deltaText = 'First scan this cycle';
      }

      tiles.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.activity, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reading: ${r.currentReading}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '${r.unitsConsumed} units',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            deltaText,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
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
    return tiles;
  }

  // ─── Monthly History Tiles ────────────────────────────────────────────
  List<Widget> _buildMonthlyHistoryTiles(
    BuildContext context,
    AnalyticsResult stats,
    List<Reading> allReadings,
  ) {
    if (stats.months.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Center(
            child: Text(
              'No monthly records available.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        )
      ];
    }

    final tiles = <Widget>[];
    for (final monthEntry in stats.months.reversed) {
      final monthKey = monthEntry.key;
      final totalUnits = monthEntry.value;

      final monthReadings = allReadings.where((r) => r.billingMonth == monthKey).toList();
      final scanCount = monthReadings.length;

      String monthName = monthKey;
      try {
        final parsed = DateFormat('yyyy-MM').parse(monthKey);
        monthName = DateFormat('MMMM yyyy').format(parsed);
      } catch (_) {}

      tiles.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.calendar, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          monthName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '$totalUnits units',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$scanCount scan${scanCount == 1 ? '' : 's'} recorded',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        if (stats.avg > 0)
                          Text(
                            totalUnits > stats.avg ? 'Above average' : 'Below average',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: totalUnits > stats.avg ? AppTheme.warning : AppTheme.success,
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
      );
    }
    return tiles;
  }

  // ─── Overview Card ────────────────────────────────────────────────────
  Widget _buildOverviewCard(
      BuildContext context, Meter m, int used, Cycle cycle) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Cycle Usage',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$used units',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  formatCycle(cycle),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),
          if (m.monthlyLimit != null && m.monthlyLimit! > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (used / m.monthlyLimit!).clamp(0.0, 1.0),
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  used >= m.monthlyLimit! ? AppTheme.danger : AppTheme.success,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(m.monthlyLimit! - used).clamp(0, m.monthlyLimit!)} units remaining until limit',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ]
        ],
      ),
    );
  }

  // ─── Schedule Editing ─────────────────────────────────────────────────
  Future<void> _editSchedule(BuildContext context, WattWiseStore store,
      Meter meter, Cycle cycle) async {
    final initialDate = meter.nextReadingDateOverride == null
        ? cycle.end
        : DateTime.tryParse(meter.nextReadingDateOverride!) ?? cycle.end;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Choose next meter reading date',
    );
    if (selected == null || !context.mounted) return;
    store.setReadingSchedule(meter.id, overrideDate: toISODate(selected));
    AppToast.show(
      context,
      message: 'Next reading set for ${DateFormat('d MMM yyyy').format(selected)}',
      type: ToastType.success,
    );
  }

  // ─── Bill Fetching ────────────────────────────────────────────────────
  Future<void> _fetchBill(
      BuildContext context, WattWiseStore store, Meter meter) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Fetching official bill...'),
          ],
        ),
      ),
    );
    try {
      final bill = await fetchPitcBill(
        meter.referenceNumber,
        meter.company,
        meterId: meter.id,
      );
      if (context.mounted) Navigator.of(context).pop();
      store.saveBill(bill);
      if (!context.mounted) return;
      final updateSchedule = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update reading schedule?'),
          content: Text(
              'The official bill was read on ${DateFormat('d MMM yyyy').format(DateTime.parse(bill.readingDate))}. Use this date for future cycles?'),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: const Text('Keep current'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Update schedule'),
            ),
          ],
        ),
      );
      if (updateSchedule == true) store.applyBillSchedule(bill);
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Official bill saved.',
          type: ToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppToast.show(
          context,
          message: 'Bill lookup: $error',
          type: ToastType.warning,
        );
      }
    }
  }

  // ─── Delete Confirmation ──────────────────────────────────────────────
  void _confirmDeleteMeter(
      BuildContext context, WattWiseStore store, Meter meter) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Meter?'),
        content: Text(
          'Delete "${meter.nickname}"? All associated readings and bill records will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.pop();
              }
              store.deleteMeter(meter.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
