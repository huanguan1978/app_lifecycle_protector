import 'package:flutter_test/flutter_test.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

void main() {
  group('NetworkProber', () {
    test('initial status is connected and isConnected is true', () {
      final prober = NetworkProber();
      expect(prober.status, NetworkStatus.connected);
      expect(prober.isConnected, isTrue);
      expect(prober.isDisconnected, isFalse);
      prober.dispose();
    });

    test('exposes isConnected and statusNotifier reactive updates', () {
      final prober = NetworkProber();

      expect(prober.isConnected, isTrue);
      prober.statusNotifier.value = NetworkStatus.disconnected;
      expect(prober.isDisconnected, isTrue);
      expect(prober.isConnected, isFalse);

      prober.dispose();
    });
  });
}
