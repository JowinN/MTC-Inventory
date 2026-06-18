import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'qr_downloader_stub.dart'
    if (dart.library.html) 'qr_downloader_web.dart'
    if (dart.library.io) 'qr_downloader_mobile.dart';

/// Generates a QR code image for [id] and saves it to accessible storage.
/// Returns the full file path where the image was saved.
Future<String> saveAndDownloadQr(String id) async {
  final painter = QrPainter(
    data: id,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    color: const Color(0xFF000000),
    emptyColor: const Color(0xFFFFFFFF),
    gapless: true,
  );

  const double qrSize = 512.0;
  const double margin = 64.0; // Clean 64px white border on all sides
  const double totalSize = qrSize + (margin * 2); // 640.0

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Draw white background
  final backgroundPaint = Paint()..color = const Color(0xFFFFFFFF);
  canvas.drawRect(const Rect.fromLTWH(0, 0, totalSize, totalSize), backgroundPaint);

  // Center the QR code inside the white background
  canvas.translate(margin, margin);
  
  // Paint the QR code
  painter.paint(canvas, const Size(qrSize, qrSize));

  final picture = recorder.endRecording();
  final img = await picture.toImage(totalSize.toInt(), totalSize.toInt());
  final picData = await img.toByteData(format: ui.ImageByteFormat.png);

  if (picData == null) {
    throw Exception('QR image generation returned null — try again.');
  }

  final bytes = picData.buffer.asUint8List();
  final savedPath = await downloadQrCode(id, bytes);
  return savedPath;
}
