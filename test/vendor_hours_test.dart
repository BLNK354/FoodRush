import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/models/user.dart';

Vendor stall({bool isOpen = true, Map<String, dynamic>? hours}) =>
    Vendor.fromMap('v1', {
      'ownerId': 'o1',
      'name': 'Test Stall',
      'isOpen': isOpen,
      'hours': ?hours,
    });

// 2026-10-12 is a Monday.
DateTime mon(int h, [int m = 0]) => DateTime(2026, 10, 12, h, m);

void main() {
  final weekdays = {
    for (var d = 1; d <= 5; d++) '$d': {'open': '07:00', 'close': '17:00'},
  };

  group('isOpenAt', () {
    test('no schedule: the manual switch alone decides', () {
      expect(stall().isOpenAt(mon(3)), isTrue);
      expect(stall(isOpen: false).isOpenAt(mon(12)), isFalse);
    });

    test('schedule: open only inside the day window', () {
      final v = stall(hours: weekdays);
      expect(v.isOpenAt(mon(6, 59)), isFalse);
      expect(v.isOpenAt(mon(7)), isTrue);
      expect(v.isOpenAt(mon(16, 59)), isTrue);
      expect(v.isOpenAt(mon(17)), isFalse, reason: 'close time is exclusive');
    });

    test('schedule: closed on days not listed', () {
      final sat = DateTime(2026, 10, 17, 12);
      expect(stall(hours: weekdays).isOpenAt(sat), isFalse);
    });

    test('switched off overrides the schedule', () {
      expect(stall(isOpen: false, hours: weekdays).isOpenAt(mon(12)), isFalse);
    });
  });

  group('hoursLabel', () {
    final v = stall(hours: weekdays);

    test('open: says when it closes', () {
      expect(v.hoursLabel(mon(12)), 'Closes 5:00 PM');
    });

    test('before opening: opens later today', () {
      expect(v.hoursLabel(mon(6)), 'Opens 7:00 AM');
    });

    test('after closing: opens tomorrow', () {
      expect(v.hoursLabel(mon(18)), 'Opens tomorrow 7:00 AM');
    });

    test('Friday evening: skips the weekend', () {
      expect(v.hoursLabel(DateTime(2026, 10, 16, 18)), 'Opens Mon 7:00 AM');
    });

    test('manually closed or no schedule: no promise', () {
      expect(stall(isOpen: false, hours: weekdays).hoursLabel(mon(12)), isNull);
      expect(stall().hoursLabel(mon(12)), isNull);
    });
  });

  group('parsing', () {
    test('invalid day entries are ignored', () {
      final v = stall(hours: {
        '1': {'open': '17:00', 'close': '07:00'}, // close before open
        '2': {'open': 'x', 'close': '10:00'},
        '9': {'open': '07:00', 'close': '10:00'}, // no such weekday
        '3': {'open': '08:30', 'close': '12:00'},
      });
      expect(v.hours.keys, [3]);
      expect(v.hours[3]!.toMap(), {'open': '08:30', 'close': '12:00'});
    });

    test('defaults for older stall docs', () {
      final v = stall();
      expect(v.prepMinutes, Vendor.kDefaultPrepMinutes);
      expect(v.rating, isNull);
      expect(v.hasSchedule, isFalse);
    });
  });
}
