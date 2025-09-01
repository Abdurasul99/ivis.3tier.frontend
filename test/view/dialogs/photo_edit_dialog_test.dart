// test/view/dialogs/photo_edit_dialog_test.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Import the stub so pickAsBytes & ImagePickerWeb.getImageAsBytes are in scope:
import 'package:fms/utils/stubs/image_picker_web_stub.dart';

import 'package:fms/view/dialogs/photo_edit_dialog.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/viewmodel/controller/upload_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/model/user_model.dart';
import 'package:fms/model/upload_model.dart';
import 'package:fms/model/pick_image_model.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A 1×1 transparent PNG, base64-encoded.
const String _kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

/// Decode it once for reuse.
final Uint8List _kTinyPngBytes = base64.decode(_kTinyPngBase64);

/// Fake picker that always returns our tiny PNG bytes.
class FakeImagePicker {
  static Future<Uint8List?> pickAsBytes({
    int? maxWidth,
    int? maxHeight,
    int? quality,
    bool? allowMultiple,
  }) async {
    debugPrint('[FakeImagePicker] pickAsBytes called');
    return _kTinyPngBytes;
  }
}

/// Fake UploadController that returns whatever uploads you seed.
class FakeUploadController extends UploadController {
  List<UploadModel> _seededUploads = [];

  void seedUploads(List<UploadModel> uploads) {
    debugPrint('[FakeUploadController] seedUploads: $uploads');
    _seededUploads = uploads;
  }

  @override
  Future<List<UploadModel>> reqUploadImage(List<PickImageFile> files) async {
    debugPrint('[FakeUploadController] reqUploadImage(files=$files)');
    return _seededUploads;
  }
}

/// Fake UserController that holds a fake LoginUser and captures update params.
class FakeUserController extends UserController {
  LoginUser? _currentUser;
  Map<String, dynamic>? lastUpdateParameters;

  void seedLoginUser(int userId, String imageUrl) {
    _currentUser = LoginUser(
      id: userId,
      email: 'abdurasul@ivis.ai',
      accessToken: '',
      imageUrl: imageUrl,
    );
    debugPrint('[FakeUserController] seedLoginUser: id=$userId, url=$imageUrl');
  }

  @override
  LoginUser? get loginUser {
    debugPrint('[FakeUserController] loginUser getter → $_currentUser');
    return _currentUser;
  }

  @override
  Future<bool> reqUpdateProfileImage(Map<String, dynamic> params) async {
    lastUpdateParameters = params;
    debugPrint('[FakeUserController] reqUpdateProfileImage(params=$params)');
    return true;
  }
}

void main() {
  late FakeUploadController fakeUploadController;
  late FakeUserController fakeUserController;
  final GlobalKey<ScaffoldMessengerState> scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  setUp(() {
    debugPrint('--- setUp called ---');
    Get.reset();
    fakeUploadController = FakeUploadController();
    fakeUserController = FakeUserController();
    Get.put<UploadController>(fakeUploadController);
    Get.put<UserController>(fakeUserController);
    ImagePickerWeb.getImageAsBytes = FakeImagePicker.pickAsBytes;
  });

  Widget buildTestApp(Widget dialogWidget) {
    return GetMaterialApp(
      scaffoldMessengerKey: scaffoldKey,
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return Center(
            child: ElevatedButton(
              key: const Key('openDialogButton'),
              onPressed: () {
                debugPrint('[TestApp] openDialogButton tapped');
                showDialog(context: ctx, builder: (_) => dialogWidget);
              },
              child: const Text('OPEN DIALOG'),
            ),
          );
        }),
      ),
    );
  }

  testWidgets('initial URL image shows then delete resets to SVG', (WidgetTester tester) async {
    debugPrint('=== Test: initial URL image shows then delete resets to SVG ===');
    fakeUserController.seedLoginUser(
      42,
      'data:image/png;base64,$_kTinyPngBase64',
    );

    debugPrint('[Test] Pumping widget');
    await tester.pumpWidget(buildTestApp(const PhotoEditDialog()));

    debugPrint('[Test] Tapping openDialogButton');
    await tester.tap(find.byKey(const Key('openDialogButton')));
    debugPrint('[Test] Waiting 300ms for dialog animation');
    await tester.pump(const Duration(milliseconds: 300));

    final int extendedImageCount = find.byType(ExtendedImage).evaluate().length;
    debugPrint('[Test] Found ExtendedImage count: $extendedImageCount');
    expect(find.byType(ExtendedImage), findsNWidgets(2));

    debugPrint('[Test] Tapping 사진 삭제');
    await tester.tap(find.widgetWithText(GradientButton, '사진 삭제'));
    debugPrint('[Test] Waiting 300ms after delete');
    await tester.pump(const Duration(milliseconds: 300));

    final bool svgFound = find.byType(SvgPicture).evaluate().isNotEmpty;
    debugPrint('[Test] SVG placeholder present? $svgFound');
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('pick/upload/save calls controllers and closes dialog', (WidgetTester tester) async {
    debugPrint('=== Test: pick/upload/save calls controllers and closes dialog ===');
    fakeUserController.seedLoginUser(100, '');
    fakeUploadController.seedUploads([
      UploadModel(location: 'data:image/png;base64,$_kTinyPngBase64'),
    ]);

    debugPrint('[Test] Pumping widget');
    await tester.pumpWidget(buildTestApp(const PhotoEditDialog()));

    debugPrint('[Test] Tapping openDialogButton');
    await tester.tap(find.byKey(const Key('openDialogButton')));
    debugPrint('[Test] Waiting 300ms for dialog animation');
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('[Test] Verifying initial button text is 사진 추가');
    expect(find.widgetWithText(GradientButton, '사진 추가'), findsOneWidget);

    debugPrint('[Test] Tapping 사진 추가');
    await tester.tap(find.widgetWithText(GradientButton, '사진 추가'));
    debugPrint('[Test] Waiting 300ms after pick');
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('[Test] Verifying button text changed to 사진 변경');
    expect(find.widgetWithText(GradientButton, '사진 변경'), findsOneWidget);

    debugPrint('[Test] Tapping 저장');
    await tester.tap(find.widgetWithText(GradientButton, '저장'));
    debugPrint('[Test] pumpAndSettle to close dialog');
    await tester.pumpAndSettle();

    final bool dialogOpen = find.byType(PhotoEditDialog).evaluate().isNotEmpty;
    debugPrint('[Test] Dialog still open? $dialogOpen');
    expect(find.byType(PhotoEditDialog), findsNothing);

    final Map<String, dynamic> params = fakeUserController.lastUpdateParameters!;
    debugPrint('[Test] Captured params: $params');
    expect(params['id'], equals(100));
    expect(params['imageUrl'], equals('data:image/png;base64,$_kTinyPngBase64'));
  });
}
