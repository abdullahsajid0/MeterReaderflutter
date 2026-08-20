import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/wattwise_types.dart';
import '../services/wattwise_billing.dart';

const String _metersKey = "wattwise.meters.v2";
const String _readingsKey = "wattwise.readings.v2";
const String _billsKey = "wattwise.bills.v2";
const String _dismissKey = "wattwise.dismissed.v2";

const String _providerKey = "wattwise.provider.v2";
const String _remindersKey = "wattwise.reminders.v2";
const String _tariffKey = "wattwise.tariff.v2";

class WattWiseStore extends ChangeNotifier {
  List<Meter> meters = [];
  List<Reading> readings = [];
  List<BillInfo> bills = [];
  List<String> dismissed = [];

  String defaultCompany = 'LESCO';
  bool remindersEnabled = true;
  bool protectedTariff = false;

  bool _hydrated = false;
  final Uuid _uuid = const Uuid();

  WattWiseStore() {
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();

    final metersJson = prefs.getStringList(_metersKey) ?? [];
    meters = metersJson.map((e) => Meter.fromJson(jsonDecode(e))).toList();

    final readingsJson = prefs.getStringList(_readingsKey) ?? [];
    readings =
        readingsJson.map((e) => Reading.fromJson(jsonDecode(e))).toList();

    final billsJson = prefs.getStringList(_billsKey) ?? [];
    bills = billsJson.map((e) => BillInfo.fromJson(jsonDecode(e))).toList();

    dismissed = prefs.getStringList(_dismissKey) ?? [];

    defaultCompany = prefs.getString(_providerKey) ?? 'LESCO';
    remindersEnabled = prefs.getBool(_remindersKey) ?? true;
    protectedTariff = prefs.getBool(_tariffKey) ?? false;

    _hydrated = true;
    notifyListeners();
  }

  Future<void> _persistMeters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _metersKey, meters.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistReadings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _readingsKey, readings.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistBills() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _billsKey, bills.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissKey, dismissed);
    notifyListeners();
  }

  Future<void> setDefaultCompany(String company) async {
    defaultCompany = company;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, company);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    remindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, enabled);
    notifyListeners();
  }

  Future<void> setProtectedTariff(bool protected) async {
    protectedTariff = protected;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tariffKey, protected);
    notifyListeners();
  }

  Meter addMeter({
    required String nickname,
    required String company,
    required String referenceNumber,
    String? consumerId,
    String? notes,
    int? monthlyLimit,
    String kind = 'home',
    int readingDay = 10,
  }) {
    final meter = Meter(
      id: _uuid.v4(),
      nickname: nickname,
      company: company,
      referenceNumber: referenceNumber,
      consumerId: consumerId,
      notes: notes,
      monthlyLimit: monthlyLimit,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kind: kind,
      readingDay: readingDay,
    );
    meters = [meter, ...meters];
    _persistMeters();
    return meter;
  }

  void updateMeter(String id, Meter patch) {
    meters = meters.map((m) => m.id == id ? patch : m).toList();
    _persistMeters();
  }

  void setReadingSchedule(String meterId,
      {String? overrideDate, int? readingDay}) {
    final meter = meters.firstWhere((m) => m.id == meterId);
    updateMeter(
      meterId,
      meter.copyWith(
        nextReadingDateOverride: overrideDate,
        clearNextReadingDateOverride: overrideDate == null,
        readingDay: readingDay,
      ),
    );
  }

  void deleteMeter(String id) {
    meters = meters.where((m) => m.id != id).toList();
    readings = readings.where((r) => r.meterId != id).toList();
    bills = bills.where((b) => b.meterId != id).toList();
    _persistMeters();
    _persistReadings();
    _persistBills();
  }

  Reading addReading({
    required String meterId,
    required int currentReading,
    required int previousReading,
    required String cycleStart,
    required String cycleEnd,
    required int unitsConsumed,
    String source = 'ocr',
    required String billingMonth,
  }) {
    final reading = Reading(
      id: _uuid.v4(),
      meterId: meterId,
      currentReading: currentReading,
      scannedAt: DateTime.now().toUtc().toIso8601String(),
      previousReading: previousReading,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      unitsConsumed: unitsConsumed,
      source: source,
      billingMonth: billingMonth,
    );

    readings = [
      reading,
      ...readings
    ];
    _persistReadings();

    meters = meters
        .map((m) => m.id == reading.meterId
            ? m.copyWith(lastScanAt: reading.scannedAt)
            : m)
        .toList();
    _persistMeters();

    return reading;
  }

  void deleteReading(String id) {
    readings = readings.where((r) => r.id != id).toList();
    _persistReadings();
  }

  void saveBill(BillInfo bill) {
    bills = [
      bill,
      ...bills.where((b) =>
          !(b.meterId == bill.meterId && b.billingMonth == bill.billingMonth))
    ];
    _persistBills();

    final billDate = DateTime.tryParse(bill.readingDate);

    // Settle readings:
    // - Remove readings scanned on or before the official reading date (they are now settled by official bill)
    // - Preserve any readings scanned AFTER the official reading date, transitioning them to the new cycle with the new baseline
    List<Reading> updatedReadings = [];
    for (var r in readings) {
      if (r.meterId != bill.meterId) {
        updatedReadings.add(r);
        continue;
      }
      final scanDate = DateTime.tryParse(r.scannedAt);
      if (billDate != null &&
          scanDate != null &&
          scanDate.isAfter(billDate.add(const Duration(hours: 18)))) {
        // This scan was taken after the meter reader visited, so it belongs to the new cycle
        final newUnits =
            (r.currentReading - bill.currentReading).clamp(0, 999999);
        updatedReadings.add(Reading(
          id: r.id,
          meterId: r.meterId,
          currentReading: r.currentReading,
          scannedAt: r.scannedAt,
          previousReading: bill.currentReading,
          cycleStart: bill.readingDate,
          cycleEnd: bill.nextReadingDate,
          unitsConsumed: newUnits,
          source: r.source,
          billingMonth: bill.nextReadingDate.isNotEmpty
              ? bill.nextReadingDate.substring(0, 7)
              : r.billingMonth,
        ));
      } else if (r.billingMonth != bill.billingMonth &&
          (billDate == null ||
              scanDate == null ||
              scanDate.isAfter(billDate))) {
        updatedReadings.add(r);
      }
    }
    readings = updatedReadings;
    _persistReadings();

    meters = meters
        .map((m) => m.id == bill.meterId
            ? m.copyWith(lastBillFetchAt: bill.fetchedAt)
            : m)
        .toList();
    _persistMeters();
  }

  void applyBillSchedule(BillInfo bill) {
    final readingDate = DateTime.tryParse(bill.readingDate);
    if (readingDate == null) return;
    final meter = meters.firstWhere((m) => m.id == bill.meterId);
    updateMeter(
      bill.meterId,
      meter.copyWith(
        readingDay: readingDate.day.clamp(1, 28).toInt(),
        clearNextReadingDateOverride: true,
      ),
    );
  }

  void dismissAlert(String key) {
    if (dismissed.contains(key)) return;
    dismissed = [key, ...dismissed].take(200).toList();
    _persistDismissed();
  }

  void dismissAllAlerts(List<String> keys) {
    final newDismissed = <String>{...dismissed, ...keys}.toList().take(200).toList();
    dismissed = newDismissed;
    _persistDismissed();
  }

  // Selectors
  List<Reading> readingsForMeter(String meterId) {
    var filtered = readings.where((r) => r.meterId == meterId).toList();
    filtered.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return filtered;
  }

  Cycle cycleForMeter(Meter meter, [DateTime? on]) {
    return cycleFor(meter, latestBill: billFor(meter.id), on: on);
  }

  Reading? currentCycleReading(Meter meter) {
    final cycle = cycleForMeter(meter);
    final bill = billFor(meter.id);
    final meterReadings = readingsForMeter(meter.id);
    if (meterReadings.isEmpty) return null;

    if (bill != null && bill.readingDate.isNotEmpty) {
      final billDate = DateTime.tryParse(bill.readingDate);
      if (billDate != null) {
        final valid = meterReadings.where((r) {
          final dt = DateTime.tryParse(r.scannedAt);
          return dt != null &&
              !dt.isBefore(billDate.subtract(const Duration(hours: 12)));
        }).toList();
        return valid.isNotEmpty ? valid.first : null;
      }
    }

    try {
      return meterReadings.firstWhere((r) {
        final dt = DateTime.tryParse(r.scannedAt);
        if (dt != null) {
          return !dt.isBefore(cycle.start.subtract(const Duration(hours: 12)));
        }
        return r.cycleEnd == cycle.endISO || r.billingMonth == cycle.billingMonth;
      });
    } catch (_) {
      return meterReadings.isNotEmpty ? meterReadings.first : null;
    }
  }

  Reading? latestReading(String meterId) {
    var filtered = readingsForMeter(meterId);
    return filtered.isNotEmpty ? filtered.first : null;
  }

  int unitsThisCycle(Meter meter) {
    final cur = currentCycleReading(meter);
    if (cur == null) return 0;
    final bill = billFor(meter.id);
    if (bill != null && bill.currentReading > 0) {
      return (cur.currentReading - bill.currentReading).clamp(0, 999999);
    }
    return cur.unitsConsumed;
  }

  BillInfo? billFor(String meterId) {
    var filtered = bills.where((b) => b.meterId == meterId).toList();
    filtered.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    return filtered.isNotEmpty ? filtered.first : null;
  }

  List<Alert> buildAlerts() {
    List<Alert> out = [];
    final today = DateTime.now();

    for (var m in meters) {
      final cycle = cycleForMeter(m, today);
      final cur = currentCycleReading(m);
      final used = unitsThisCycle(m);
      final daysToRead = daysBetween(today, cycle.end);

      if (cycle.isPendingOfficialBill) {
        out.add(Alert(
            key: 'pendingbill:${m.id}:${cycle.endISO}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'info',
            title: 'Official bill pending',
            body:
                '${m.company} read ${m.nickname} on ${DateFormat('d MMM').format(cycle.end)}. Fetch your new bill when released.'));
      } else if (cur == null) {
        out.add(Alert(
            key: 'scan:${m.id}:${cycle.endISO}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'info',
            title: 'No reading this cycle',
            body:
                'Record a reading for ${m.nickname} — the cycle ends ${DateFormat('d MMM').format(cycle.end)}.'));
      }

      if (!cycle.isPendingOfficialBill && daysToRead <= 3 && daysToRead >= 0) {
        out.add(Alert(
            key: 'readday:${m.id}:${cycle.endISO}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'info',
            title: daysToRead == 0
                ? 'Today is your meter reading day'
                : 'Meter reading in $daysToRead day${daysToRead == 1 ? '' : 's'}',
            body:
                '${m.company} is expected to read ${m.nickname} on ${DateFormat('d MMM').format(cycle.end)}.'));
      }

      if (m.monthlyLimit != null && m.monthlyLimit! > 0 && used > 0) {
        final remaining = m.monthlyLimit! - used;
        if (remaining <= 0) {
          out.add(Alert(
              key: 'over:${m.id}:${cycle.endISO}',
              meterId: m.id,
              meterName: m.nickname,
              tone: 'danger',
              title: 'Limit exceeded',
              body:
                  '${m.nickname} has used $used of ${m.monthlyLimit} units this cycle.'));
        } else if (remaining <= 20) {
          out.add(Alert(
              key: 'close:${m.id}:${cycle.endISO}',
              meterId: m.id,
              meterName: m.nickname,
              tone: 'warn',
              title: 'Only $remaining units left',
              body:
                  '${m.nickname} is close to its ${m.monthlyLimit}-unit target.'));
        } else if (used / m.monthlyLimit! >= 0.6) {
          out.add(Alert(
              key: 'approach:${m.id}:${cycle.endISO}',
              meterId: m.id,
              meterName: m.nickname,
              tone: 'warn',
              title: 'Approaching your limit',
              body:
                  '${((used / m.monthlyLimit!) * 100).round()}% of ${m.nickname}\'s target used with ${cycle.daysRemaining} days to go.'));
        }
      }

      final history = readingsForMeter(m.id);
      if (history.length >= 2 &&
          history[0].unitsConsumed > history[1].unitsConsumed * 1.25) {
        out.add(Alert(
            key: 'faster:${m.id}:${history[0].id}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'warn',
            title: 'Usage rising',
            body:
                '${m.nickname} used ${history[0].unitsConsumed} units vs ${history[1].unitsConsumed} last cycle.'));
      }

      final bill = billFor(m.id);
      if (bill != null && bill.status == 'available') {
        out.add(Alert(
            key: 'bill:${m.id}:${bill.billingMonth}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'good',
            title: 'A new bill is available',
            body:
                '${m.nickname} · ${bill.billingMonth}${bill.amountPkr != null ? ' · Rs ${bill.amountPkr}' : ''}.'));
      }
    }

    return out.where((a) => !dismissed.contains(a.key)).toList();
  }
}
