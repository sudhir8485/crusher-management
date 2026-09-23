import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes(
    String filename, Uint8List bytes, String mimeType) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = filename;
  html.document.body!.children.add(anchor);
  anchor.click();
  Future.delayed(const Duration(milliseconds: 200), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
}

Future<void> openPdfInNewTab(Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(
      const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
}
