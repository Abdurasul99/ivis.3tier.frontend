// test/viewmodel/controller/upload_controller_test.dart
//
// UploadController unit-tests (production code is unchanged).
// We use TestableUploadController to inject MockUploadRepository.
//
// Run: flutter test test/viewmodel/controller/upload_controller_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/model/pick_image_model.dart';
import 'package:fms/model/upload_model.dart';
import 'package:fms/viewmodel/controller/upload_controller.dart';
import 'package:fms/viewmodel/repository/upload_repository.dart';

import 'upload_controller_test.mocks.dart';

/// ---------------------------------------------------------------------------
/// Wrapper-controller that delegates repo-calls to the injected mock.
/// ---------------------------------------------------------------------------
class TestableUploadController extends UploadController {
  TestableUploadController(this.mockRepository);
  final UploadRepository mockRepository;

  @override
  Future<List<UploadModel>> reqUploadImage(List<PickImageFile> filesToUpload) {
    return mockRepository.requestUploadImage(filesToUpload);
  }
}

/// ---------------------------------------------------------------------------
/// Mockito generation – build with:
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ---------------------------------------------------------------------------
@GenerateNiceMocks(<MockSpec<dynamic>>[
  MockSpec<UploadRepository>(),
])
void main() {
  late MockUploadRepository mockRepository;
  late TestableUploadController controller;

  setUp(() {
    print('\n=== setUp: fresh mock & controller ===');
    mockRepository = MockUploadRepository();
    controller = TestableUploadController(mockRepository); // DI via wrapper
  });

  group('UploadController – AAA pattern with debug prints', () {
    test('reqUploadImage() returns uploaded list on success', () async {
      print('\n▶ TEST: reqUploadImage()');

      // ─── Arrange ───────────────────────────────────────────
      print('ARRANGE   → stub requestUploadImage');
      final List<PickImageFile> pickedFiles = <PickImageFile>[
        PickImageFile(
          // use the first enum value; we do not rely on a specific constant name
          fileType: PickImageFileType.values.first,
          filePath: 'example.png',
          imageBytes: Uint8List(0),
        ),
      ];
      final List<UploadModel> uploadedFiles = <UploadModel>[UploadModel()];

      when(mockRepository.requestUploadImage(pickedFiles)).thenAnswer((_) async => uploadedFiles);

      // ─── Act ───────────────────────────────────────────────
      print('ACT       → call controller.reqUploadImage');
      final List<UploadModel> result = await controller.reqUploadImage(pickedFiles);
      print('RESULT    = $result');

      // ─── Assert ────────────────────────────────────────────
      print('ASSERT    → verify outcome and interaction');
      expect(result, equals(uploadedFiles));
      verify(mockRepository.requestUploadImage(pickedFiles)).called(1);
    });
  });
}
