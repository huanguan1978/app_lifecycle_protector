# App Lifecycle Protector

`app_lifecycle_protector` is a framework for coordinating Flutter application
lifecycle events and periodic tasks. It also provides two reusable features
built on that framework: screen protection and network probing.

## What the framework provides

### Keep lifecycle logic in one place

Refreshing data when the app resumes, hiding sensitive content when it moves
to the background, and periodically checking session state are often spread
across widgets and services. Extend `AppLifecycleEvent` and override the
callbacks you need to bring that logic together in one event handler, rather
than registering lifecycle observers, managing timers, and checking
foreground/background state separately for each feature.

### Schedule periodic work while the app can run

`AppLifecycleScheduler` calls `onPeriodic()` at the configured interval. The
timer is not stopped just because the app's UI is hidden. When a user switches
to another app, the original app is in the background, but its process
typically remains present. While that process is running and Dart code can
execute, periodic callbacks can handle foreground or background work.

The operating system may suspend the app, in which case Dart execution pauses
and timer callbacks are delayed. If the process is terminated, its timers and
callbacks stop. The framework can handle work while the app is able to execute
code; it cannot prevent the operating system from suspending or terminating
the app.

## Quick start

Use `AppLifecycleEvent` to define your app's event handling logic.
`AppLifecycleScheduler` receives Flutter lifecycle notifications and calls
`onPeriodic()` at the configured interval:

```dart
class MyAppEvents extends AppLifecycleEvent {
  @override
  void onResume() {
    // Refresh data when the app resumes.
  }

  @override
  void onPeriodic() {
    if (isInForeground) {
      // Foreground work.
    } else {
      // Background work.
    }
  }
}

void initializeLifecycle() {
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: MyAppEvents(),
  );
}
```

Call `initializeLifecycle()` after the Flutter binding has been initialized,
for example before `runApp()` or from the root widget's `initState()`. The
first `onPeriodic()` callback runs after one `interval` has elapsed.

## Two reusable features

To protect sensitive screens when the app is backgrounded or the user is
idle, use `ScreenSecure` to manage masking and lock state, then
`ScreenProtector` to display the corresponding UI. Your app supplies the
authentication flow, such as an existing passcode or biometric flow. See the
[screen protection guide](screen_secure.md).

To check whether a server endpoint is reachable, use `NetworkProber` to send
an HTTP probe and listen for its result. It does not poll on its own; the
caller chooses when to probe. Use `RouteSentry` when probing should be limited
to selected routes. See the [network probing guide](network_prober.md).

These features can be combined with the lifecycle framework or used
independently as needed. You can also implement session-expiration checks,
business heartbeats, and other logic in your own event handler.

## Run and explore the example

Run the Flutter app in the `example/` directory to try the lifecycle
framework, screen protection, and network probing:

```shell
cd example
flutter run
```

The example source is organized into framework demonstrations, feature
implementations, and UI. You can read and copy the source into your own
project, then adapt it to your needs and explore how each feature works. For
the example walkthrough, source guide, and platform-specific network
configuration notes, see [`example/example.md`](../../example/example.md).

## Dependencies and further use

This package depends on the Flutter SDK and `logging`; it does not depend on
platform plugins or a particular state-management solution. In addition to
`onResume()`, `AppLifecycleEvent` provides callbacks for events such as show,
hide, pause, and exit. These callbacks represent different notifications and
should not be treated as interchangeable.

`AppLifecycleScheduler` is a global singleton, and `initialize()` creates it
only once. To release it, call
`AppLifecycleScheduler.instance.dispose()`. Configure idle timeouts with
`aliveDuration`; call `updateAliveStatus()` at app startup and in response to
user interaction, then use `isAlive()` to check activity. Before an active
time has been recorded, `isAlive()` returns `false`.

## AI coding agent skills

This package includes skills for the lifecycle framework, screen protection,
and network probing. After adding the package dependency and running
`flutter pub get`, run this command from the root of your Flutter project to
install the skills for GitHub Copilot in VS Code:

```shell
dart run skills@ get -p app_lifecycle_protector --agent copilot
```

The skills CLI installs them into `.github/skills/`, VS Code Copilot's
project-level skills directory. Copilot is not auto-detected by the CLI, so
specify `--agent copilot`. Adding the package dependency or running `pub get`
does not install the skills automatically.

The `-p app_lifecycle_protector` option limits discovery to this package, but
the command still prompts you to select skills. To install all three skills
from this package, select all three in the prompt (for example, press
`Ctrl+A`, then `Enter`). Avoid `--all` if you only want this package's skills:
it installs all available skills from all dependencies and configured sources.

Open the project in VS Code and start a new Copilot Chat session. The skills
should be available from the `/` menu. You can invoke one directly, or Copilot
may select it based on the request; automatic selection is not guaranteed.

The CLI also supports these common agents:

| Agent | Option | Project skills directory |
| --- | --- | --- |
| Antigravity | `--agent antigravity` | `.agents/skills/` |
| Claude Code | `--agent claude` | `.claude/skills/` |
| Cline | `--agent cline` | `.cline/skills/` |
| OpenAI Codex | `--agent codex` | `.agents/skills/` |
| Cursor | `--agent cursor` | `.cursor/skills/` |
| GitHub Copilot | `--agent copilot` | `.github/skills/` |
| OpenCode | `--agent opencode` | `.opencode/skills/` |
| Generic Agent Skills client | `--agent generic` | `.agents/skills/` |

For another agent, replace `copilot` in the command with its option value.
See the [`skills` CLI documentation](https://pub.dev/packages/skills) for the
current list and details.

## Support the project

If you find this package useful, consider supporting the project:

- Star the repository on GitHub or like the package on pub.dev.
- Support the developer through [GitHub Sponsors](https://github.com/sponsors/huanguan1978)
  or [Buy Me a Coffee](https://buymeacoffee.com/huanguan1978).
- For support in mainland China, visit
  [Ifdian](https://ifdian.net/a/huanguan1978).

Thank you for your support!

## License

MIT License.
