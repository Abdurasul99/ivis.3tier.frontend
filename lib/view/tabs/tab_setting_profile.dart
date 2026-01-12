import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:ivis/view/dialogs/photo_edit_dialog.dart';
import 'package:get/get.dart';

import '../../model/user_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text_read_only.dart';
import '../components/input_edit_text_setting.dart';
import '../dialogs/noti_dialog.dart';
import '../dialogs/password_change_dialog.dart';
import '../pages/login_page.dart';

class TabSettingProfile extends StatefulWidget {
  const TabSettingProfile({super.key});

  @override
  State<TabSettingProfile> createState() => _TabSettingProfileState();
}

class _TabSettingProfileState extends State<TabSettingProfile> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final FocusNode _phoneNumberFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    LoginUser? loginUser = Get.find<UserController>().loginUser;
    _phoneNumberController.text = loginUser?.phoneNumber ?? "";
  }

  @override
  void dispose() {
    super.dispose();

    _phoneNumberController.dispose();
    _phoneNumberFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingProfile();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 546,
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: GetBuilder<UserController>(
            init: UserController(),
            builder: (controller) {
              LoginUser? loginUser = controller.loginUser;

              if (loginUser == null) {
                return Container();
              }

              String imageUrl = loginUser.imageUrl ?? "";

              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 96,
                        alignment: Alignment.centerLeft,
                        child: imageUrl.isEmpty
                            ? Container(
                                width: 96,
                                height: 96,
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  "assets/images/icons_profile.svg",
                                  width: 96,
                                ),
                              )
                            : Container(
                                width: 96,
                                height: 96,
                                alignment: Alignment.center,
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.white,
                                  backgroundImage: ExtendedNetworkImageProvider(
                                    imageUrl,
                                    cache: true,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: () async {
                            await showDialog(
                              context: Get.context!,
                              builder: (BuildContext context) {
                                return const PhotoEditDialog();
                              },
                              barrierDismissible: false,
                            );
                          },
                          child: Container(
                            width: 35,
                            height: 35,
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/images/icons_small_edit.svg',
                              width: 35,
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  InputEditTextReadOnly(
                    title: "이름",
                    value: loginUser.name,
                  ),
                  const SizedBox(height: 22),
                  InputEditTextReadOnly(
                    title: "메일",
                    value: loginUser.email,
                  ),
                  const SizedBox(height: 22),
                  InputEditTextReadOnly(
                    title: "멤버등급",
                    value: (loginUser.role == "admin") ? "관리자" : "일반",
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: InputEditTextSetting(
                          controller: _phoneNumberController,
                          focusNode: _phoneNumberFocusNode,
                          title: "핸드폰",
                          hintText: "핸드폰 번호를 입력해주세요.",
                          onChanged: (String value) {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 28),
                            GradientButton(
                              buttonText: "연락처 변경",
                              onTap: () async {
                                if (_phoneNumberController.text.isEmpty) {
                                  Utils.showSnackBar("핸드폰 번호를 입력해주세요.", isError: true);
                                  return;
                                }

                                Map<String, dynamic> params = {};
                                params['id'] = Get.find<UserController>().loginUser!.id;
                                params["phoneNumber"] = _phoneNumberController.text;

                                bool isSuccess = await Get.find<UserController>().reqChangePhoneNumber(params);

                                if (isSuccess) {
                                  await showDialog(
                                    context: Get.context!,
                                    builder: (BuildContext context) {
                                      return const NotiDialog(
                                        message: "개인 정보가 변경되었습니다.",
                                        addMessage: "연락처 정보가 변경되었습니다.",
                                      );
                                    },
                                    barrierDismissible: false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 54),
                  GradientButton(
                    buttonText: "비밀번호 변경",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () async {
                      final result = await showDialog(
                        context: Get.context!,
                        builder: (BuildContext context) {
                          return PasswordChangeDialog();
                        },
                        barrierDismissible: false,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    buttonText: "로그아웃",
                    onTap: () async {
                      await Get.find<UserController>().logout();
                      Get.offAllNamed(LoginPage.routeName);
                    },
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(child: Container()),
      ],
    );
  }
}
