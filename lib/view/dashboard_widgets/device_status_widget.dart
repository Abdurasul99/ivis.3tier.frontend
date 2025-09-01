import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/robot_controller.dart';

class DeviceStatusWidget extends StatelessWidget {
  const DeviceStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RobotController>(
      init: RobotController(),
      builder: (controller) {
        int activeRobotCount = 0;
        int chargeRobotCount = 0;
        int errorRobotCount = 0;

        for (int i = 0; i < controller.robotStatusList.length; i++) {
          RobotStatus status = controller.robotStatusList[i];

          bool isDeleted = Get.find<RobotController>().isDeletedRobot(status.id!);
          if (isDeleted) {
            continue;
          }

          if ((status.description ?? "").toLowerCase() == "untact") {
            bool isCharging = ((status.latitude == kStation0Latitude) && (status.longitude == kStation0Longitude)) ||
                ((status.latitude == kStation1Latitude) && (status.longitude == kStation1Longitude)) ||
                ((status.latitude == kStation2Latitude) && (status.longitude == kStation2Longitude)) ||
                ((status.latitude == kStation3Latitude) && (status.longitude == kStation3Longitude)) ||
                ((status.latitude == kStation4Latitude) && (status.longitude == kStation4Longitude));
            if (status.robotStatus == 4) {
              errorRobotCount++;
            } else if (isCharging) {
              chargeRobotCount++;
            } else {
              activeRobotCount++;
            }
          } else {
            bool isCharging = ((status.posX == kPosReturn["X"]) && (status.posY == kPosReturn["Y"]));
            if (status.robotStatus == RobotState.error) {
              errorRobotCount++;
            } else if (isCharging) {
              chargeRobotCount++;
            } else {
              activeRobotCount++;
            }
          }
        }

        if (controller.isLoading) {
          return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
        }

        if (activeRobotCount == 0 && chargeRobotCount == 0 && errorRobotCount == 0) {
          return const Center(
            child: Text(
              '운행 정보가 없습니다 😑',
              style: TextStyle(
                fontSize: 18,
                color: kHintColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기기 운행 현황',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontFamily: "pretendard",
                  color: Color(0xFF666565),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildBigCard(
                        color: const Color(0xFF005FB8),
                        title: '운행중',
                        subtitle: '현재 정상 운행 로봇',
                        count: activeRobotCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildSmallCard(
                              color: const Color(0xFFFFAE00),
                              title: '충전중',
                              subtitle: '현재 충전 로봇',
                              count: chargeRobotCount,
                              imagePath: "assets/images/icons_yellow_charge.svg",
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _buildSmallCard(
                              color: const Color(0xFFC42B1C),
                              title: '고장',
                              subtitle: '현재 고장 로봇',
                              count: errorRobotCount,
                              imagePath: "assets/images/icons_red_alert.svg",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBigCard({
    Color color = const Color(0xFF005FB8),
    String title = "",
    String subtitle = "",
    int count = 0,
  }) {
    String countStr = Utils.numberWithComma(count);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: SvgPicture.asset(
                "assets/images/icons_blue_arrow.svg",
                width: 60,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: "pretendard",
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: "pretendard",
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    countStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard({
    Color color = const Color(0xFFFFAE00),
    String title = "",
    String subtitle = "",
    int count = 0,
    imagePath = "assets/images/icons_yellow_charge.svg",
  }) {
    String countStr = Utils.numberWithComma(count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1.0),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                SvgPicture.asset(
                  imagePath,
                  width: 40,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  countStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "pretendard",
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    // const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "pretendard",
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
