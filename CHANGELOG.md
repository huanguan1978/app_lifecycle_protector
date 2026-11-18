## 0.0.8

* Added `UserInteractionListener` widget for automatic user activity tracking across touch, keyboard, and scroll events.
* Updated screen protection documentation to recommend `UserInteractionListener` for simplified idle-event handling.
* Simplified example app by consolidating scattered activity tracking into unified `UserInteractionListener` wrapper.
* Enhanced lifecycle and screen-protection skills with `UserInteractionListener` integration guidance.

## 0.0.7

* Added lightweight interval task management with relative-time scheduling, task controls, and explicit snapshots.
* Enhanced interval task callbacks to receive the registered task ID as a
  `String`; callbacks that do not need it can ignore the argument.
* Added `runTaskNow` to manually run an eligible task immediately, bypassing its
  interval check.
* Added `dispose()` to clean up and prevent task execution after disposal.

## 0.0.6

* Restructured the package documentation and refactored the example app.
* Added package skills for the lifecycle framework, screen protection, and network probing.

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
