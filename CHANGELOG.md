## 0.0.5

* Added `NetworkProber` for reusable network reachability checks with status notifications, request reuse, retries, and fallback endpoints.
* Added `RouteSentry` to monitor configured routes and activate route-aware network checks.

## 0.0.4

* Enhanced `onPeriodic` scheduler to run continuously across the active lifecycle (foreground & background) until suspended or terminated.
* Added `isInForeground` and `isInBackground` state-awareness getters to `AppLifecycleEvent` and `AppLifecycleScheduler`.

## 0.0.3

* Refactored `onExitRequested()` in `AppLifecycleEvent` as an abstract shutdown hook for cleanup before exit.

## 0.0.2

* doc, add Real-world Implementation.

## 0.0.1

* initial release.
