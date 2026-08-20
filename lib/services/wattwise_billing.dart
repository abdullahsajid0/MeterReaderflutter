import 'package:intl/intl.dart';
import '../models/wattwise_types.dart';

DateTime clampDay(int year, int monthIndex, int day) {
  final lastDay = DateTime(year, monthIndex + 2, 0).day;
  return DateTime(year, monthIndex + 1, day < lastDay ? day : lastDay);
}

String toISODate(DateTime d) {
  return DateFormat('yyyy-MM-dd').format(d);
}

DateTime parseISODate(String s) {
  return DateTime.parse(s);
}

int daysBetween(DateTime a, DateTime b) {
  final aDt = DateTime(a.year, a.month, a.day);
  final bDt = DateTime(b.year, b.month, b.day);
  return bDt.difference(aDt).inDays;
}

class Cycle {
  final DateTime start;
  final DateTime end;
  final String startISO;
  final String endISO;
  final String billingMonth;
  final int lengthDays;
  final int daysElapsed;
  final int daysRemaining;
  final int progressPct;
  final bool isPendingOfficialBill;

  Cycle({
    required this.start,
    required this.end,
    required this.startISO,
    required this.endISO,
    required this.billingMonth,
    required this.lengthDays,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.progressPct,
    this.isPendingOfficialBill = false,
  });
}

Cycle cycleFor(Meter meter, {BillInfo? latestBill, DateTime? on}) {
  on ??= DateTime.now();
  final day = (meter.readingDay < 1
      ? 1
      : (meter.readingDay > 28 ? 28 : meter.readingDay));

  DateTime start;
  DateTime end;
  String billingMonth;

  if (latestBill != null && latestBill.readingDate.isNotEmpty) {
    // Cycle starts from the latest official bill's reading date
    DateTime billReadingDate = parseISODate(latestBill.readingDate);
    start = billReadingDate;

    // Determine the expected next reading date
    DateTime? expectedEnd;
    if (latestBill.nextReadingDate.isNotEmpty) {
      try {
        final parsedNext = parseISODate(latestBill.nextReadingDate);
        if (parsedNext.isAfter(start)) {
          expectedEnd = parsedNext;
        }
      } catch (_) {}
    }

    if (expectedEnd == null) {
      int nextMonth = start.month + 1;
      int nextYear = start.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      expectedEnd = clampDayDart(nextYear, nextMonth, day);
    }

    end = expectedEnd;
    billingMonth = toISODate(end).substring(0, 7);
  } else {
    // No official bill available yet: fallback to monthly reading day schedule
    int currentMonth = on.month;
    int currentYear = on.year;

    end = clampDayDart(currentYear, currentMonth, day);
    DateTime prevEnd = clampDayDart(end.year, end.month - 1, day);
    start = prevEnd;
    billingMonth = toISODate(end).substring(0, 7);
  }

  // Next reading date override if configured
  final overrideText = meter.nextReadingDateOverride;
  if (overrideText != null && overrideText.isNotEmpty) {
    try {
      final override = parseISODate(overrideText);
      if (!override.isBefore(start) && daysBetween(start, override) < 60) {
        end = override;
        billingMonth = toISODate(end).substring(0, 7);
      }
    } catch (_) {}
  }

  int lengthDays = daysBetween(start, end);
  if (lengthDays < 1) lengthDays = 1;

  final isPendingOfficialBill = on.isAfter(end);
  int elapsed = daysBetween(start, on);
  if (elapsed < 0) elapsed = 0;

  int remaining = daysBetween(on, end);
  if (remaining < 0) remaining = 0;

  int progressPct = lengthDays > 0 ? ((elapsed / lengthDays) * 100).round() : 0;
  if (progressPct > 100) progressPct = 100;

  return Cycle(
    start: start,
    end: end,
    startISO: toISODate(start),
    endISO: toISODate(end),
    billingMonth: billingMonth,
    lengthDays: lengthDays,
    daysElapsed: elapsed,
    daysRemaining: remaining,
    progressPct: progressPct,
    isPendingOfficialBill: isPendingOfficialBill,
  );
}

DateTime clampDayDart(int year, int month, int day) {
  int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day < lastDay ? day : lastDay);
}

String formatCycle(Cycle c) {
  return '${DateFormat('d MMM').format(c.start)} – ${DateFormat('d MMM').format(c.end)}';
}

class Projection {
  final int used;
  final double dailyAvg;
  final int projected;
  final double? recommendedDaily;
  final bool willExceed;

  Projection({
    required this.used,
    required this.dailyAvg,
    required this.projected,
    this.recommendedDaily,
    required this.willExceed,
  });
}

Projection project(int used, Cycle cycle, int? limit) {
  double dailyAvg = used / (cycle.daysElapsed > 0 ? cycle.daysElapsed : 1);
  int totalProjectedDays = cycle.daysElapsed > cycle.lengthDays
      ? cycle.daysElapsed
      : cycle.lengthDays;
  int projected = (dailyAvg * totalProjectedDays).round();
  double? recommendedDaily;
  if (limit != null && limit > 0) {
    recommendedDaily =
        (limit - used) / (cycle.daysRemaining > 0 ? cycle.daysRemaining : 1);
    recommendedDaily = (recommendedDaily * 10).roundToDouble() / 10;
    if (recommendedDaily < 0) recommendedDaily = 0;
  }

  return Projection(
    used: used,
    dailyAvg: (dailyAvg * 10).roundToDouble() / 10,
    projected: projected,
    recommendedDaily: recommendedDaily,
    willExceed: limit != null && limit > 0 && projected > limit,
  );
}

int estimateBill(int units, {bool protectedTariff = false}) {
  if (units <= 0) return 0;
  List<List<num>> slabs = protectedTariff
      ? [
          [100, 13.5],
          [200, 18.95],
          [9999999, 24.5], // using 9999999 instead of Infinity
        ]
      : [
          [100, 23.6],
          [200, 30.0],
          [300, 34.3],
          [400, 39.2],
          [500, 41.4],
          [600, 42.7],
          [700, 43.6],
          [9999999, 48.8],
        ];
  num rest = units;
  num prev = 0;
  num total = 0;
  for (var slab in slabs) {
    num upTo = slab[0];
    num rate = slab[1];
    num width =
        upTo == 9999999 ? rest : (rest < upTo - prev ? rest : upTo - prev);
    if (width < 0) width = 0;
    total += width * rate;
    rest -= width;
    prev = upTo == 9999999 ? prev : upTo;
    if (rest <= 0) break;
  }
  return (total * 1.22 + 200).round();
}

String pkr(num n) {
  final format =
      NumberFormat.currency(locale: 'en_PK', symbol: 'Rs ', decimalDigits: 0);
  return format.format(n);
}

class AnalyticsResult {
  final List<MapEntry<String, int>> months;
  final int total;
  final int avg;
  final MapEntry<String, int>? highest;
  final MapEntry<String, int>? lowest;
  final int growth;

  AnalyticsResult(this.months, this.total, this.avg, this.highest, this.lowest,
      this.growth);
}

class DailyUsagePoint {
  final DateTime date;
  final String label; // e.g. "15 Aug"
  final String shortLabel; // e.g. "15"
  final double units;
  final int? readingValue;
  final bool hasActualReading;

  DailyUsagePoint({
    required this.date,
    required this.label,
    required this.shortLabel,
    required this.units,
    this.readingValue,
    this.hasActualReading = false,
  });
}

List<DailyUsagePoint> computeDailyCycleUsage(
  List<Reading> readings,
  Cycle cycle, {
  BillInfo? latestBill,
}) {
  if (readings.isEmpty && latestBill == null) return [];

  // Sort readings oldest-to-newest
  final sorted = [...readings];
  sorted.sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

  final baselineReading = latestBill?.currentReading;

  // 1. Group readings by 24-hour calendar day (yyyy-MM-dd)
  Map<String, List<Reading>> dayGroups = {};
  for (var r in sorted) {
    final dt = DateTime.tryParse(r.scannedAt);
    if (dt != null) {
      final dayKey = toISODate(dt);
      dayGroups.putIfAbsent(dayKey, () => []).add(r);
    }
  }

  // 2. Determine 24-hour daily consumption
  Map<String, double> dayUnits = {};
  Map<String, int> dayLatestReading = {};
  final dayKeys = dayGroups.keys.toList()..sort();

  if (dayKeys.length == 1) {
    final key = dayKeys.first;
    final dayReadings = dayGroups[key]!;
    final earliest = dayReadings.first;
    final latest = dayReadings.last;
    final base = baselineReading ?? earliest.previousReading;
    if (dayReadings.length > 1) {
      dayUnits[key] = (latest.currentReading - earliest.previousReading)
          .clamp(0, 999999)
          .toDouble();
    } else {
      dayUnits[key] =
          (latest.currentReading - base).clamp(0, 999999).toDouble();
    }
    dayLatestReading[key] = latest.currentReading;
  } else if (dayKeys.isNotEmpty) {
    for (int i = 0; i < dayKeys.length; i++) {
      final currKey = dayKeys[i];
      final currReadings = dayGroups[currKey]!;
      final latest = currReadings.last;
      dayLatestReading[currKey] = latest.currentReading;

      if (i == 0) {
        final earliest = currReadings.first;
        final base = baselineReading ?? earliest.previousReading;
        final totalDayDelta = (latest.currentReading - base).clamp(0, 999999);
        dayUnits[currKey] = totalDayDelta.toDouble();
      } else {
        final prevKey = dayKeys[i - 1];
        final prevLatest = dayGroups[prevKey]!.last;
        final prevDt = DateTime.parse(prevKey);
        final currDt = DateTime.parse(currKey);
        final days = daysBetween(prevDt, currDt);
        final delta = (latest.currentReading - prevLatest.currentReading)
            .clamp(0, 999999);

        if (days <= 1) {
          dayUnits[currKey] = (dayUnits[currKey] ?? 0) + delta.toDouble();
        } else {
          final perDay = delta / days;
          for (int d = 1; d <= days; d++) {
            final dayDt = prevDt.add(Duration(days: d));
            final k = toISODate(dayDt);
            dayUnits[k] = (dayUnits[k] ?? 0) + perDay;
          }
        }
      }
    }
  }

  final today = DateTime.now();
  // Include dates through today (even if waiting past expected cycle end for official bill)
  final lastDate = today.isAfter(cycle.end) ? today : cycle.end;
  final totalDays = daysBetween(cycle.start, lastDate) + 1;

  List<DailyUsagePoint> points = [];
  for (int i = 0; i < totalDays && i < 45; i++) {
    final d = cycle.start.add(Duration(days: i));
    final key = toISODate(d);
    final val = dayUnits[key] ?? 0.0;
    points.add(DailyUsagePoint(
      date: d,
      label: DateFormat('d MMM').format(d),
      shortLabel: '${d.day}',
      units: (val * 10).roundToDouble() / 10,
      readingValue: dayLatestReading[key],
      hasActualReading: dayGroups.containsKey(key),
    ));
  }

  return points;
}

AnalyticsResult analytics(List<Reading> readings) {
  Map<String, int> byMonth = {};
  for (var r in readings) {
    byMonth[r.billingMonth] = (byMonth[r.billingMonth] ?? 0) + r.unitsConsumed;
  }
  var months = byMonth.entries.toList();
  months.sort((a, b) => a.key.compareTo(b.key));
  var values = months.map((e) => e.value).toList();
  var total = values.fold(0, (a, b) => a + b);
  var avg = values.isNotEmpty ? (total / values.length).round() : 0;

  MapEntry<String, int>? highest;
  MapEntry<String, int>? lowest;
  for (var m in months) {
    if (highest == null || m.value > highest.value) highest = m;
    if (lowest == null || m.value < lowest.value) lowest = m;
  }

  int growth = 0;
  if (values.length >= 2 && values[values.length - 2] > 0) {
    growth = (((values.last - values[values.length - 2]) /
                values[values.length - 2]) *
            100)
        .round();
  }

  return AnalyticsResult(months, total, avg, highest, lowest, growth);
}
