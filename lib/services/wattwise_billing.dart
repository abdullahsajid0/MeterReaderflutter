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
  });
}

Cycle cycleFor(Meter meter, [DateTime? on]) {
  on ??= DateTime.now();
  final day = (meter.readingDay < 1
      ? 1
      : (meter.readingDay > 28 ? 28 : meter.readingDay));
  // dart months are 1..12, monthIndex in JS was 0..11
  // let's just use dart months
  int currentMonth = on.month;
  int currentYear = on.year;

  DateTime end = clampDayDart(currentYear, currentMonth, day);
  if (on.isAfter(end)) {
    end = clampDayDart(currentYear, currentMonth + 1, day);
  }
  DateTime prevEnd = clampDayDart(end.year, end.month - 1, day);
  DateTime start = prevEnd.add(const Duration(days: 1));

  final overrideText = meter.nextReadingDateOverride;
  if (overrideText != null && overrideText.isNotEmpty) {
    final override = parseISODate(overrideText);
    if (!override.isBefore(start) &&
        !override.isBefore(on) &&
        daysBetween(end, override) < 45) {
      end = override;
    }
  }

  int lengthDays = daysBetween(start, end) + 1;
  if (lengthDays < 1) lengthDays = 1;
  int elapsed = daysBetween(start, on) + 1;
  if (elapsed < 0) elapsed = 0;
  if (elapsed > lengthDays) elapsed = lengthDays;

  return Cycle(
    start: start,
    end: end,
    startISO: toISODate(start),
    endISO: toISODate(end),
    billingMonth: toISODate(end).substring(0, 7),
    lengthDays: lengthDays,
    daysElapsed: elapsed,
    daysRemaining: (lengthDays - elapsed) < 0 ? 0 : (lengthDays - elapsed),
    progressPct: ((elapsed / lengthDays) * 100).round(),
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
  int projected = (dailyAvg * cycle.lengthDays).round();
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
  final String label;
  final double units;
  final bool hasActualReading;

  DailyUsagePoint({
    required this.date,
    required this.label,
    required this.units,
    this.hasActualReading = false,
  });
}

List<DailyUsagePoint> computeDailyCycleUsage(List<Reading> readings, Cycle cycle) {
  if (readings.isEmpty) return [];

  // Sort readings oldest-to-newest
  final sorted = [...readings];
  sorted.sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

  Map<String, double> dayUnits = {};
  Set<String> actualReadingDates = {};

  for (var r in sorted) {
    final dt = DateTime.tryParse(r.scannedAt);
    if (dt != null) {
      actualReadingDates.add(toISODate(dt));
    }
  }

  if (sorted.length == 1) {
    final r = sorted.first;
    final scanDate = DateTime.tryParse(r.scannedAt) ?? cycle.start;
    final scanDateStr = toISODate(scanDate);
    dayUnits[scanDateStr] = r.unitsConsumed.toDouble();
  } else {
    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final prevDate = DateTime.tryParse(prev.scannedAt) ?? cycle.start;
      final currDate = DateTime.tryParse(curr.scannedAt) ?? cycle.end;
      final delta = (curr.currentReading - prev.currentReading).clamp(0, 999999);
      final days = daysBetween(prevDate, currDate);

      if (days <= 1) {
        final key = toISODate(currDate);
        dayUnits[key] = (dayUnits[key] ?? 0) + delta.toDouble();
      } else {
        final perDay = delta / days;
        for (int d = 1; d <= days; d++) {
          final dayDt = prevDate.add(Duration(days: d));
          final key = toISODate(dayDt);
          dayUnits[key] = (dayUnits[key] ?? 0) + perDay;
        }
      }
    }
  }

  final today = DateTime.now();
  final lastDate = today.isBefore(cycle.end) ? today : cycle.end;
  final totalDays = daysBetween(cycle.start, lastDate) + 1;

  List<DailyUsagePoint> points = [];
  for (int i = 0; i < totalDays && i < 35; i++) {
    final d = cycle.start.add(Duration(days: i));
    final key = toISODate(d);
    final val = dayUnits[key] ?? 0.0;
    points.add(DailyUsagePoint(
      date: d,
      label: DateFormat('d MMM').format(d),
      units: val,
      hasActualReading: actualReadingDates.contains(key),
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
