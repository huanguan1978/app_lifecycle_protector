import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

void main() {
  group('RouteSentry', () {
    test('initial value is false', () {
      final sentry = RouteSentry(monitoredRoutes: {'/home', '/chat'});
      expect(sentry.value, isFalse);
      expect(sentry.monitoredRoutes, {'/home', '/chat'});
      sentry.dispose();
    });

    test('updates value on didPush, didPop, didReplace', () {
      final sentry = RouteSentry(
        monitoredRoutes: {'/talking/gencontent', '/talking/chat'},
      );

      final route1 = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/home'),
      );
      final route2 = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/talking/gencontent'),
      );
      final route3 = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/about'),
      );

      // Push /home -> false
      sentry.didPush(route1, null);
      expect(sentry.value, isFalse);

      // Push /talking/gencontent -> true
      sentry.didPush(route2, route1);
      expect(sentry.value, isTrue);

      // Push /about -> false
      sentry.didPush(route3, route2);
      expect(sentry.value, isFalse);

      // Pop /about back to route2 -> true
      sentry.didPop(route3, route2);
      expect(sentry.value, isTrue);

      // Pop route2 back to route1 -> false
      sentry.didPop(route2, route1);
      expect(sentry.value, isFalse);

      sentry.dispose();
    });
  });
}
