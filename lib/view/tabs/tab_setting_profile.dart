import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:ivis/view/dialogs/photo_edit_dialog.dart';

import '../../i18n/app_locale.dart';
import '../../model/user_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
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
    final LoginUser? loginUser = Get.find<UserController>().loginUser;
    _phoneNumberController.text = loginUser?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _phoneNumberFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingProfile();
    }

    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 546,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: GetBuilder<UserController>(
                init: Get.find<UserController>(),
                builder: (UserController controller) {
                  final LoginUser? loginUser = controller.loginUser;
                  if (loginUser == null) {
                    return const SizedBox.shrink();
                  }

                  final String imageUrl = loginUser.imageUrl ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 40),
                      Stack(
                        children: <Widget>[
                          SizedBox(
                            width: 110,
                            height: 96,
                            child: imageUrl.isEmpty
                                ? Center(
                                    child: SvgPicture.asset(
                                      'assets/images/icons_profile.svg',
                                      width: 96,
                                    ),
                                  )
                                : ClipOval(
                                    child: Image.network(
                                      Utils.proxyImageUrl(imageUrl),
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => SvgPicture.asset(
                                        'assets/images/icons_profile.svg',
                                        width: 96,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 2,
                            child: GestureDetector(
                              onTap: () async {
                                await showDialog<void>(
                                  context: Get.context!,
                                  builder: (_) => const PhotoEditDialog(),
                                  barrierDismissible: false,
                                );
                              },
                              child: SizedBox(
                                width: 35,
                                height: 35,
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
                        title: t('이름'),
                        value: loginUser.name,
                      ),
                      const SizedBox(height: 22),
                      InputEditTextReadOnly(
                        title: t('메일'),
                        value: loginUser.email,
                      ),
                      const SizedBox(height: 22),
                      InputEditTextReadOnly(
                        title: t('멤버등급'),
                        value: loginUser.role == 'admin' ? t('관리자') : t('일반'),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: InputEditTextSetting(
                              controller: _phoneNumberController,
                              focusNode: _phoneNumberFocusNode,
                              title: t('핸드폰'),
                              hintText: t('핸드폰 번호를 입력해주세요.'),
                              onChanged: (_) {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: 28),
                                GradientButton(
                                  buttonText: t('연락처 변경'),
                                  onTap: () async {
                                    if (_phoneNumberController.text.isEmpty) {
                                      Utils.showSnackBar(t('핸드폰 번호를 입력해주세요.'), isError: true);
                                      return;
                                    }

                                    final Map<String, dynamic> params = <String, dynamic>{
                                      'id': Get.find<UserController>().loginUser!.id,
                                      'phoneNumber': _phoneNumberController.text,
                                    };

                                    final bool isSuccess =
                                        await Get.find<UserController>().reqChangePhoneNumber(params);

                                    if (isSuccess) {
                                      await showDialog<void>(
                                        context: Get.context!,
                                        builder: (_) => NotiDialog(
                                          message: t('개인 정보가 변경되었습니다.'),
                                          addMessage: t('연락처 정보가 변경되었습니다.'),
                                        ),
                                        barrierDismissible: false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 54),
                      GradientButton(
                        buttonText: t('비밀번호 변경'),
                        buttonColor: const Color(0xFF005FB8),
                        onTap: () async {
                          await showDialog<void>(
                            context: Get.context!,
                            builder: (_) => const PasswordChangeDialog(),
                            barrierDismissible: false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        buttonText: t('로그아웃'),
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
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
