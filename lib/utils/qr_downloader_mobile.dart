import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Saves [bytes] as QR_[id].png to internal storage/MTC Inventory.
/// Falls back to app documents if external is unavailable or restricted.
/// Returns the full file path.
Future<String> downloadQrCode(String id, Uint8List bytes) async {
  if (Platform.isAndroid) {
    // 1. Request storage permission
    PermissionStatus storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }

    bool isGranted = storageStatus.isGranted;

    // If storage status is still not granted (or on Android 11+ where storage request is a no-op/denied),
    // request manageExternalStorage.
    if (!isGranted) {
      PermissionStatus manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
      isGranted = manageStatus.isGranted;
    }

    if (isGranted) {
      final customDir = Directory('/storage/emulated/0/MTC Inventory');
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        final file = File('${customDir.path}/QR_$id.png');
        await file.writeAsBytes(bytes);
        return file.path;
      } catch (e) {
        print("Failed to save to /storage/emulated/0/MTC Inventory: $e");
        // Fallback to other public directories if root fails
        final fallbackPaths = [
          '/storage/emulated/0/Download/MTC Inventory',
          '/storage/emulated/0/Pictures/MTC Inventory',
        ];
        for (final path in fallbackPaths) {
          try {
            final fallbackDir = Directory(path);
            if (!await fallbackDir.exists()) {
              await fallbackDir.create(recursive: true);
            }
            final file = File('${fallbackDir.path}/QR_$id.png');
            await file.writeAsBytes(bytes);
            return file.path;
          } catch (err) {
            print("Failed to save to fallback path $path: $err");
          }
        }
        throw Exception("Failed to save to external storage: $e");
      }
    } else {
      throw Exception('Storage permission is required to save the QR code to "MTC Inventory".');
    }
  }

  // Fallback option to app sandbox directory for non-Android platforms (if compile-time target differs)
  Directory? dir;
  try {
    dir = await getExternalStorageDirectory();
  } catch (_) {
    dir = null;
  }

  // Fallback to app documents if external unavailable
  dir ??= await getApplicationDocumentsDirectory();

  final fileName = 'QR_$id.png';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
