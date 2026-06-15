# App Lifecycle Protector Example App

This directory contains a comprehensive example of the `app_lifecycle_protector` package. It demonstrates a complete security workflow, including lifecycle monitoring, privacy masking, and idle timeout protection.

## 🚀 How to Run

1.  Ensure you have Flutter installed.
2.  Navigate to this directory: `cd example`
3.  Run the app: `flutter run`

## 🛠️ What's Inside?

### 1. Advanced Interaction Tracking
The app uses three methods to ensure it knows when the user is active:
*   **Touch Events**: A root-level `Listener` captures taps and scrolls.
*   **Hardware Keyboard**: `HardwareKeyboard.instance.addHandler` captures physical key presses.
*   **Soft Keyboard**: The `TextField` in the demo manually calls `updateAliveStatus()` in its `onChanged` callback.

### 2. Mock Services
To ensure this example runs "out of the box" without requiring native permissions (like Biometrics or Camera), we use **Mock Classes**:
*   `MockBiometricValidator`: Simulates a successful biometric scan.
*   In a real app, replace this with the [local_auth](https://pub.dev/packages/local_auth) package.

### 3. Lifecycle Logging
A real-time log viewer at the bottom of the screen shows when events like `onPeriodic` (inspection), `onPause` (backgrounding), and `onResume` (foregrounding) occur.

## ⚙️ Demo Configurations

*   **Inspection Interval**: 5 Seconds (High frequency for observing `onPeriodic`).
*   **Idle Timeout**: 60 Seconds (The app will automatically lock if no interaction is detected for 1 minute).
*   **Passphrase**: The default secret key for the fallback lock screen is `123456`.

## 📖 Deep Dive
To fully understand the design philosophy and security patterns used here, please refer to the localized implementation guide:
- [Implementation Guide (English)](../doc/en/EXAMPLE.md)
- [Implementation Guide (Chinese)](../doc/zh/EXAMPLE.md)

## 💡 Integration Tips

1.  **Production Duration**: For production apps, an `aliveDuration` of 3-5 minutes is usually recommended for banking apps, while 10-15 minutes might be better for general utility apps.
2.  **Native Hardening**: Always pair the Privacy Mask feature with the [no_screenshot](https://pub.dev/packages/no_screenshot) package to prevent manual screenshots when the app is active.
