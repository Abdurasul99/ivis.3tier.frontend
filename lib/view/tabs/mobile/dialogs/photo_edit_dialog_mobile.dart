import 'dart:typed_data';
import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:fms/utils/stubs/image_picker_web_stub.dart'
    if (dart.library.html) 'package:image_picker_web/image_picker_web.dart';
import '/model/pick_image_model.dart';
import '/model/upload_model.dart';
import '/model/user_model.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/upload_controller.dart';
import '/viewmodel/controller/user_controller.dart';
import '/view/components/gradient_button.dart';

class PhotoEditPageMobile extends StatefulWidget {
  const PhotoEditPageMobile({super.key});

  @override
  State<PhotoEditPageMobile> createState() => _PhotoEditPageMobileState();
}

class _PhotoEditPageMobileState extends State<PhotoEditPageMobile> {
  static const double _btnHeight = 40.0;

  String _imageUrl = '';
  String _originalUrl = '';
  Uint8List? _imageBytes;
  bool _markedDelete = false;

  @override
  void initState() {
    super.initState();
    final user = Get.find<UserController>().loginUser;
    _imageUrl = user?.imageUrl ?? '';
    _originalUrl = _imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          '사진 변경',
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 37, vertical: 24),
          child: Column(
            children: <Widget>[
              (_imageBytes != null)
                  ? _previewBytes(_imageBytes!)
                  : (_imageUrl.isNotEmpty)
                      ? _previewUrl(_imageUrl)
                      : _previewDefault(),
              const SizedBox(height: 32),
              _whiteBtn('사진 추가', _pickPhoto),
              const SizedBox(height: 12),
              _whiteBtn(
                '사진 삭제',
                (_imageBytes == null && _imageUrl.isEmpty) ? null : _deletePhoto,
              ),
              const SizedBox(height: 32),
              _blueBtn('저장', _save),
              const SizedBox(height: 12),
              _whiteBtn('취소', _cancel),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final bytes = await ImagePickerWeb.getImageAsBytes();
      if (bytes == null || bytes.isEmpty) return;
      _imageBytes = bytes;
      _markedDelete = false;
      setState(() {});
    } catch (_) {}
  }

  void _deletePhoto() {
    _imageBytes = null;
    _imageUrl = '';
    _markedDelete = true;
    setState(() {});
  }

  Future<void> _save() async {
    String nextUrl = _imageUrl;

    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      final PickImageFile sel = PickImageFile(
        fileType: PickImageFileType.imageBytes,
        imageBytes: _imageBytes,
      );
      final List<UploadModel> upload = await Get.find<UploadController>().reqUploadImage(<PickImageFile>[sel]);
      if (upload.isEmpty || (upload.first.location ?? '').isEmpty) {
        Utils.showSnackBar('이미지 업로드에 실패했습니다.', isError: true);
        return;
      }
      nextUrl = upload.first.location!;
    }

    if (_markedDelete && _imageBytes == null) {
      nextUrl = '';
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'id': Get.find<UserController>().loginUser!.id,
      'imageUrl': nextUrl,
    };

    final bool ok = await Get.find<UserController>().reqUpdateProfileImage(params);

    if (!ok) return;

    Navigator.pop(context, true);
    Utils.showSnackBar('프로필 이미지가 변경되었습니다.');
  }

  void _cancel() {
    _imageUrl = _originalUrl;
    _imageBytes = null;
    _markedDelete = false;
    Navigator.pop(context, false);
  }

  Widget _previewDefault() => SvgPicture.asset(
        'assets/images/icons_profile_ex.svg',
        width: 180,
        height: 180,
      );

  Widget _previewUrl(String url) => _previewWrapper(
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ExtendedImage.network(url, width: 180, height: 180),
        ),
        ExtendedImage.network(url, width: 180, height: 180),
      );

  Widget _previewBytes(Uint8List bytes) => _previewWrapper(
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
          child: Image.memory(bytes, width: 180, height: 180),
        ),
        Image.memory(bytes, width: 180, height: 180),
      );

  Widget _previewWrapper(Widget back, Widget front) => SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          children: <Widget>[
            ClipRRect(borderRadius: BorderRadius.circular(4), child: back),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.black26,
              ),
              child: ClipOval(child: front),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(180),
              ),
            ),
          ],
        ),
      );

  Widget _whiteBtn(String text, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: _btnHeight,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFFDDDDDD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: onTap,
          child: Text(text),
        ),
      );

  Widget _blueBtn(String text, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: _btnHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Material(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDDDDD)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SizedBox.expand(
                child: GradientButton(
                  buttonText: text,
                  buttonColor: const Color(0xFF005FB8),
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      );
}
