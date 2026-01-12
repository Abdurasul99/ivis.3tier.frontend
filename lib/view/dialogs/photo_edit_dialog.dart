import 'dart:typed_data';
import 'dart:ui';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/pick_image_model.dart';
import '../../model/upload_model.dart';
import '../../model/user_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/upload_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/gradient_button.dart';

class PhotoEditDialog extends StatefulWidget {
  const PhotoEditDialog({super.key});

  @override
  State<PhotoEditDialog> createState() => _PhotoEditDialogState();
}

class _PhotoEditDialogState extends State<PhotoEditDialog> {
  String _imageUrl = "";
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    final LoginUser? loginUser = Get.find<UserController>().loginUser;
    _imageUrl = loginUser?.imageUrl ?? "";
  }

  @override
  Widget build(BuildContext context) {
    const double dialogWidth = 430;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 35),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 0),
              blurRadius: 5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              alignment: Alignment.centerLeft,
              child: const Text(
                "사진 변경",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Container(
              alignment: Alignment.center,
              child: (_imageBytes != null)
                  ? buildProfileByBytes(_imageBytes!)
                  : (_imageUrl.isNotEmpty)
                      ? buildProfileByUrl(_imageUrl)
                      : buildProfileDefault(),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GradientButton(
                buttonText: (_imageUrl.isEmpty && _imageBytes == null) ? "사진 추가" : "사진 변경",
                onTap: () async {
                  // Cross-platform picker (Web/iOS/Android/Desktop)
                  try {
                    final picker = ImagePicker();
                    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
                    if (file == null) return;

                    final Uint8List bytes = await file.readAsBytes(); // Works on Web too
                    _imageBytes = bytes;
                    _imageUrl = "";
                    if (mounted) setState(() {});
                  } catch (e) {
                    debugPrint("pickImage error: $e");
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GradientButton(
                buttonText: "사진 삭제",
                onTap: () {
                  _imageUrl = "";
                  _imageBytes = null;
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: GradientButton(
                    buttonText: "저장",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () async {
                      // If user picked local bytes, upload first
                      if (_imageUrl.isEmpty && (_imageBytes != null && _imageBytes!.isNotEmpty)) {
                        final PickImageFile selImageFile = PickImageFile(
                          fileType: PickImageFileType.imageBytes,
                          imageBytes: _imageBytes,
                        );

                        final List<UploadModel> upload =
                            await Get.find<UploadController>().reqUploadImage([selImageFile]);

                        if (upload.isEmpty) {
                          Utils.showSnackBar("이미지 업로드에 실패했습니다.", isError: true);
                          return;
                        }

                        _imageUrl = upload.first.location ?? "";
                        if (_imageUrl.isEmpty) {
                          Utils.showSnackBar("이미지 업로드에 실패했습니다.", isError: true);
                          return;
                        }
                      }

                      final Map<String, dynamic> params = {
                        'id': Get.find<UserController>().loginUser!.id,
                        'imageUrl': _imageUrl,
                      };

                      final bool result = await Get.find<UserController>().reqUpdateProfileImage(params);

                      Get.back();
                      if (result) {
                        Utils.showSnackBar("프로필 이미지가 변경되었습니다.");
                      }

                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GradientButton(
                    buttonText: "취소",
                    onTap: () {
                      Get.back();
                    },
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfileDefault() {
    return SvgPicture.asset("assets/images/icons_profile_ex.svg", width: 160, height: 160);
  }

  Widget buildProfileByUrl(String url) {
    return Container(
      width: 160,
      height: 160,
      alignment: Alignment.center,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ExtendedImage.network(
                url,
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.black.withOpacity(0.3),
            ),
            child: ClipOval(
              child: Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                child: ExtendedImage.network(
                  url,
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.white, width: 1.0),
              borderRadius: const BorderRadius.all(Radius.circular(160.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileByBytes(Uint8List bytes) {
    return Container(
      width: 160,
      height: 160,
      alignment: Alignment.center,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: Image.memory(
                bytes,
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.black.withOpacity(0.3),
            ),
            child: ClipOval(
              child: Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                child: Image.memory(
                  bytes,
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.white, width: 1.0),
              borderRadius: const BorderRadius.all(Radius.circular(160.0)),
            ),
          ),
        ],
      ),
    );
  }
}
