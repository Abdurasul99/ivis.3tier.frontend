// lib/utils/stubs/image_picker_web_stub.dart

library image_picker_web_stub;

import 'dart:typed_data';

/// A free function that your dialog can call, pointing through to the class stub.
Future<Uint8List?> pickAsBytes({
  int? maxWidth,
  int? maxHeight,
  int? quality,
  bool? allowMultiple,
}) {
  return ImagePickerWeb.getImageAsBytes(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
    allowMultiple: allowMultiple,
  );
}

class ImagePickerWeb {
  /// Now a mutable static field, so tests can reassign it.
  static Future<Uint8List?> Function({
    int? maxWidth,
    int? maxHeight,
    int? quality,
    bool? allowMultiple,
  }) getImageAsBytes = ({
    int? maxWidth,
    int? maxHeight,
    int? quality,
    bool? allowMultiple,
  }) async {
    throw UnsupportedError('image_picker_web not supported in tests');
  };

  static Future<List<Uint8List>?> getMultiImagesAsBytes({
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    throw UnsupportedError('image_picker_web not supported in tests');
  }

  static Future<dynamic> getImage({int? maxWidth, int? maxHeight}) =>
      throw UnsupportedError('image_picker_web not supported in tests');

  static Future<List<dynamic>?> getMultiImages({int? maxWidth, int? maxHeight}) =>
      throw UnsupportedError('image_picker_web not supported in tests');
}
