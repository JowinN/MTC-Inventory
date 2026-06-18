# MTC Inventory

MTC Inventory is a modern, elegant, and cross-platform inventory management application built with Flutter. It streamlines the process of tracking assets, managing stock levels, and organizing logistics efficiently.

## Features

- **Secure Authentication:** Integrated with Firebase Auth and Google Sign-In for seamless and secure user access.
- **Real-time Database:** Utilizes Cloud Firestore for real-time syncing of inventory data across all devices.
- **QR Code & Barcode Scanning:** Built-in mobile scanner to quickly scan and look up items on the fly.
- **QR Code Generation:** Generate QR codes for assets to easily label and track physical inventory.
- **Local Notifications:** Get timely alerts and reminders for stock thresholds or important updates.
- **Sleek UI:** Modern, clean, and intuitive user interface designed for productivity.

## Technology Stack

- **Framework:** [Flutter](https://flutter.dev/)
- **Backend/Database:** [Firebase Firestore](https://firebase.google.com/docs/firestore)
- **Authentication:** Firebase Authentication & [Google Sign-In](https://pub.dev/packages/google_sign_in)
- **Scanning:** [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- **Notifications:** [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Permissions:** [permission_handler](https://pub.dev/packages/permission_handler)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.12.2)
- Android Studio / Xcode for running emulators
- A Firebase project configured for Android/iOS

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd mtc_inventory
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Add your `google-services.json` to the `android/app/` directory.
   - (For iOS) Add your `GoogleService-Info.plist` to the `ios/Runner/` directory.
   - Ensure your SHA-1 and SHA-256 fingerprints are registered in your Firebase console.

4. **Run the App:**
   ```bash
   flutter run
   ```

## Building for Release

To build a release APK for Android:

```bash
flutter build apk --release
```

*Note: If you run into OutOfMemory (OOM) issues during the Gradle R8 shrinking phase on constrained machines, you can bypass the shrinking step by running:*
```bash
flutter build apk --no-shrink
```

## License
This project is licensed under the MIT License.
