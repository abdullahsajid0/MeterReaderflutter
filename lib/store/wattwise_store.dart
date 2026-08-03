import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/wattwise_types.dart';
import '../services/wattwise_billing.dart';

const String METERS_KEY = "wattwise.meters.v2";
const String READINGS_KEY = "wattwise.readings.v2";
const String BILLS_KEY = "wattwise.bills.v2";
const String DISMISS_KEY = "wattwise.dismissed.v2";

const String PROVIDER_KEY = "wattwise.provider.v2";
const String REMINDERS_KEY = "wattwise.reminders.v2";
const String TARIFF_KEY = "wattwise.tariff.v2";

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

    final metersJson = prefs.getStringList(METERS_KEY) ?? [];
    meters = metersJson.map((e) => Meter.fromJson(jsonDecode(e))).toList();

    final readingsJson = prefs.getStringList(READINGS_KEY) ?? [];
    readings =
        readingsJson.map((e) => Reading.fromJson(jsonDecode(e))).toList();

    final billsJson = prefs.getStringList(BILLS_KEY) ?? [];
    bills = billsJson.map((e) => BillInfo.fromJson(jsonDecode(e))).toList();

    dismissed = prefs.getStringList(DISMISS_KEY) ?? [];

    defaultCompany = prefs.getString(PROVIDER_KEY) ?? 'LESCO';
    remindersEnabled = prefs.getBool(REMINDERS_KEY) ?? true;
    protectedTariff = prefs.getBool(TARIFF_KEY) ?? false;

    _hydrated = true;
    notifyListeners();
  }

  Future<void> _persistMeters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        METERS_KEY, meters.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistReadings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        READINGS_KEY, readings.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistBills() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        BILLS_KEY, bills.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> _persistDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(DISMISS_KEY, dismissed);
    notifyListeners();
  }

  Future<void> setDefaultCompany(String company) async {
    defaultCompany = company;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PROVIDER_KEY, company);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    remindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(REMINDERS_KEY, enabled);
    notifyListeners();
  }

  Future<void> setProtectedTariff(bool protected) async {
    protectedTariff = protected;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TARIFF_KEY, protected);
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

    // Reset readings for this meter's current billing cycle
    // since the official bill has arrived
    readings = readings.where((r) =>
        !(r.meterId == bill.meterId && r.billingMonth == bill.billingMonth)).toList();
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

  // Selectors
  List<Reading> readingsForMeter(String meterId) {
    var filtered = readings.where((r) => r.meterId == meterId).toList();
    filtered.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return filtered;
  }

  Reading? currentCycleReading(Meter meter) {
    final cycle = cycleFor(meter);
    var filtered = readingsForMeter(meter.id);
    try {
      return filtered.firstWhere((r) => r.cycleEnd == cycle.endISO);
    } catch (_) {
      return null;
    }
  }

  Reading? latestReading(String meterId) {
    var filtered = readingsForMeter(meterId);
    return filtered.isNotEmpty ? filtered.first : null;
  }

  int unitsThisCycle(Meter meter) {
    return currentCycleReading(meter)?.unitsConsumed ?? 0;
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
      final cycle = cycleFor(m, today);
      final cur = currentCycleReading(m);
      final used = cur?.unitsConsumed ?? 0;
      final daysToRead = daysBetween(today, cycle.end);

      if (cur == null) {
        out.add(Alert(
            key: 'scan:${m.id}:${cycle.endISO}',
            meterId: m.id,
            meterName: m.nickname,
            tone: 'info',
            title: 'No reading this cycle',
            body:
                'Record a reading for ${m.nickname} — the cycle ends ${DateFormat('d MMM').format(cycle.end)}.'));
      }

      if (daysToRead <= 3 && daysToRead >= 0) {
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
