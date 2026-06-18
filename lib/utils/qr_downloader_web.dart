// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> downloadQrCode(String id, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'QR_$id.png')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'QR_$id.png'; // Web downloads to default Downloads folder
}
