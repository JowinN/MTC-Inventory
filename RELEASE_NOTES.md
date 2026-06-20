# MTC Inventory - Release Notes

## Version 1.1.0

### 🚀 New Features & Enhancements:
- **Bulk Item Handling:** You can now manage bulk assets! Added support to track `quantity` per item. Scanning identical assets increments an audit counter (e.g., `Scan: 5/14`), streamlining your bulk audits.
- **Partial Service Dispatches:** When sending bulk items to service, you can now specify exactly how many items are being sent. The app dynamically tracks partial service statuses (e.g., `5 / 14 in Service`).
- **External Event Check-out System:** A dedicated new module for external events! Check out specific quantities of equipment for events without marking them as "In Service". The system safely prevents over-checking-out and features a clean UI to track active events and instantly check off returned items.


## Version 1.0.2

### 🐛 Bug Fixes & Improvements:
- **Storage Permissions Fix:** Resolved an issue where QR code saving would fail silently by correctly prompting users for storage/photo permissions (including support for Android 13+ devices).
- **Cleaner Error UI:** Replaced the developer-focused Google Sign-In error fallback page with a sleek, user-friendly error dialog.

## Version 1.0.1

### ✨ Aesthetic Updates:
- **New App Icon:** Replaced the generic geometric icon with a custom-designed, elegant church-inspired logo reflecting the MTC branding.
- **Visual Polish:** Updated the app launcher resources for a seamless brand experience across Android.

## Version 1.0.0 (Initial Release)

Welcome to the very first release of **MTC Inventory**! We are thrilled to launch this modern, elegant solution for your inventory management needs.

### 🚀 Key Features in this Release:

- **Seamless Authentication:** Quickly and securely sign in using your Google account via Firebase Auth.
- **Real-Time Database Sync:** All your inventory data is securely stored and synced in real-time across your devices using Cloud Firestore.
- **Integrated QR/Barcode Scanner:** Easily look up or track items on the fly using the built-in mobile scanner.
- **QR Code Generation:** Generate new QR codes to label and organize your physical assets efficiently.
- **Smart Notifications:** Stay informed with local notifications directly on your device.
- **Sleek & Modern UI:** A beautiful, responsive, and intuitive interface designed to boost your productivity.
- **Custom Branding:** Features a brand new elegant geometric app icon tailored for professional inventory tracking.

### 🛠 Technical Improvements:
- Fully optimized Android package namespace (`com.church.inventory.church_inventory`).
- Enabled core library desugaring for broad Android device compatibility.
- Fully configured Firebase pipeline and Google Services mapping.

---
*Thank you for using MTC Inventory! Stay tuned for future updates and feature enhancements.*
