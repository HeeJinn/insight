import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/providers/admin_lock_provider.dart';

void main() {
  test('wrong PINs pause unlocking, longer each time', () {
    var now = DateTime(2026, 10, 13, 9);
    final container = ProviderContainer(
      overrides: [
        adminLockControllerProvider.overrideWith(
          (ref) => AdminLockController(ref, clock: () => now),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(adminPinProvider.notifier).state = '2468';
    final lock = container.read(adminLockControllerProvider);

    for (var i = 0; i < AdminLockController.freeAttempts; i++) {
      expect(lock.lockedUntil, isNull, reason: 'free attempt ${i + 1}');
      expect(lock.tryUnlock('0000'), isFalse);
    }
    expect(lock.lockedUntil, now.add(const Duration(seconds: 30)));
    expect(lock.tryUnlock('2468'), isFalse, reason: 'even the right PIN');

    now = now.add(const Duration(seconds: 31));
    expect(lock.tryUnlock('1111'), isFalse);
    expect(lock.lockedUntil, now.add(const Duration(seconds: 60)));

    now = now.add(const Duration(seconds: 61));
    expect(lock.tryUnlock('2468'), isTrue);
    expect(container.read(adminUnlockedProvider), isTrue);
    expect(lock.tryUnlock('0000'), isFalse);
    expect(lock.lockedUntil, isNull, reason: 'a success resets the count');
  });
}
