import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattwise/models/wattwise_types.dart';
import 'package:wattwise/services/wattwise_billing.dart';
import 'package:wattwise/store/wattwise_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Billing Cycle & Delay Handling', () {
    final testMeter = Meter(
      id: 'meter-1',
      nickname: 'Home Meter',
      company: 'LESCO',
      referenceNumber: '12345678901234',
      createdAt: '2026-07-01T00:00:00Z',
      readingDay: 20,
    );

    final julyBill = BillInfo(
      meterId: 'meter-1',
      fetchedAt: '2026-07-25T10:00:00Z',
      referenceNumber: '12345678901234',
      company: 'LESCO',
      billingMonth: '2026-07',
      previousReading: 15000,
      currentReading: 15400,
      readingDate: '2026-07-20',
      nextReadingDate: '2026-08-20',
      unitsBilled: 400,
      amountPkr: 16000,
      status: 'available',
    );

    test(
        'Cycle does not prematurely jump to next month while waiting for official bill',
        () {
      // Suppose today is August 23 (3 days after the expected August 20 reading day), and the official bill is not out yet
      final today = DateTime.parse('2026-08-23T12:00:00Z');
      final cycle = cycleFor(testMeter, latestBill: julyBill, on: today);

      expect(cycle.startISO, equals('2026-07-20'));
      expect(cycle.endISO, equals('2026-08-20'));
      expect(cycle.billingMonth, equals('2026-08'));
      expect(cycle.isPendingOfficialBill, isTrue);
      expect(cycle.daysRemaining, equals(0));
      expect(cycle.daysElapsed, greaterThanOrEqualTo(31));
    });

    test(
        'Store maintains readings and units during 4-5 day bill publication delay',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = WattWiseStore();
      await Future.delayed(const Duration(milliseconds: 50));

      store.meters = [testMeter];
      store.bills = [julyBill];

      // User logged an interim reading on Aug 15: current reading 15750 (350 units consumed since July bill 15400)
      store.addReading(
        meterId: 'meter-1',
        currentReading: 15750,
        previousReading: 15400,
        cycleStart: '2026-07-20',
        cycleEnd: '2026-08-20',
        unitsConsumed: 350,
        billingMonth: '2026-08',
      );

      // On Aug 23 (past day 20, waiting for official bill):
      final cycleReading = store.currentCycleReading(testMeter);
      expect(cycleReading, isNotNull);
      expect(cycleReading!.currentReading, equals(15750));
      expect(store.unitsThisCycle(testMeter), equals(350));

      // Daily usage points span through current date
      final points = computeDailyCycleUsage(
        store.readingsForMeter(testMeter.id),
        store.cycleForMeter(testMeter),
        latestBill: julyBill,
      );
      expect(points.isNotEmpty, isTrue);
    });

    test(
        'Official bill arrival transitions cycle, cleans settled readings, and anchors new baseline',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = WattWiseStore();
      await Future.delayed(const Duration(milliseconds: 50));

      store.meters = [testMeter];
      store.bills = [julyBill];

      // Interim reading on Aug 15 (before bill reading date)
      final r1 = Reading(
        id: 'r-1',
        meterId: 'meter-1',
        currentReading: 15750,
        scannedAt: '2026-08-15T10:00:00Z',
        previousReading: 15400,
        cycleStart: '2026-07-20',
        cycleEnd: '2026-08-20',
        unitsConsumed: 350,
        source: 'ocr',
        billingMonth: '2026-08',
      );

      // Post-reading scan on Aug 23 (after meter reader visited on Aug 21, but before bill fetched on Aug 25)
      final r2 = Reading(
        id: 'r-2',
        meterId: 'meter-1',
        currentReading: 15870,
        scannedAt: '2026-08-23T14:00:00Z',
        previousReading: 15400,
        cycleStart: '2026-07-20',
        cycleEnd: '2026-08-20',
        unitsConsumed: 470,
        source: 'ocr',
        billingMonth: '2026-08',
      );

      store.readings = [r2, r1];

      // New August official bill arrives on Aug 25 with readingDate = 2026-08-21 and currentReading = 15850
      final augustBill = BillInfo(
        meterId: 'meter-1',
        fetchedAt: '2026-08-25T10:00:00Z',
        referenceNumber: '12345678901234',
        company: 'LESCO',
        billingMonth: '2026-08',
        previousReading: 15400,
        currentReading: 15850,
        readingDate: '2026-08-21',
        nextReadingDate: '2026-09-21',
        unitsBilled: 450,
        amountPkr: 18500,
        status: 'available',
      );

      store.saveBill(augustBill);
      store.applyBillSchedule(augustBill);

      // Verify meter reading day updated to 21 (actual reader day)
      final updatedMeter = store.meters.firstWhere((m) => m.id == testMeter.id);
      expect(updatedMeter.readingDay, equals(21));

      // Verify settled reading r1 was cleared, and post-reading scan r2 transitioned to new cycle with new baseline 15850
      final currentReadings = store.readingsForMeter(testMeter.id);
      expect(currentReadings.length, equals(1));
      expect(currentReadings.first.previousReading, equals(15850));
      expect(currentReadings.first.currentReading, equals(15870));
      expect(currentReadings.first.unitsConsumed,
          equals(20)); // 15870 - 15850 = 20 units

      // Verify new active cycle starts on 2026-08-21 and unitsThisCycle is 20
      final newCycle = store.cycleForMeter(updatedMeter);
      expect(newCycle.startISO, equals('2026-08-21'));
      expect(store.unitsThisCycle(updatedMeter), equals(20));
    });
  });
}
