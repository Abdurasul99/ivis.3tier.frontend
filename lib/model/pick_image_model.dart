import 'dart:typed_data';

enum PickImageFileType { networkFile, imageBytes }

class PickImageFile {
  PickImageFileType fileType; // 0 : Network Image File, 1: bytes
  String? filePath;
  Uint8List? imageBytes;

  PickImageFile({required this.fileType, this.filePath, this.imageBytes});

  @override
  String toString() {
    return 'PickImageFile{fileType: $fileType, filePath: $filePath, imageBytes: $imageBytes}';
  }
}
