import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes(
    String filename, Uint8List bytes, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)]));
}

Future<void> openPdfInNewTab(Uint8List bytes) async {
  await Printing.sharePdf(bytes: bytes);
}
