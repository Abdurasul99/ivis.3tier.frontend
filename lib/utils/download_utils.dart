import 'dart:html' as html;
import 'dart:typed_data';

class DownloadUtils {
  static void downloadFile({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  }) {
    Future.delayed(const Duration(milliseconds: 100), () {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();

      Future.delayed(const Duration(milliseconds: 200), () {
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });
    });
  }

  static void downloadExcelFile({
    required Uint8List excelBytes,
    required String fileName,
  }) {
    downloadFile(
      bytes: excelBytes,
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
