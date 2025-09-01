// lib/view/widgets/device_status_widget_mobile.dart
//

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/model/robot_model.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/robot_controller.dart';

class DeviceStatusWidgetMobile extends StatelessWidget {
  const DeviceStatusWidgetMobile({super.key});

  static const double _horizontalPadding = 14.0;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RobotController>(
      init: RobotController(),
      builder: (RobotController controller) {
        int active = 0, charging = 0, error = 0;

        /* ───── classify robots ───── */
        for (final RobotStatus s in controller.robotStatusList) {
          final String desc = (s.description ?? '').toLowerCase();
          bool onStation = false;

          if (controller.isDeletedRobot(s.id!)) {
            continue;
          }

          if (desc == 'untact') {
            onStation = _isUntactOnStation(s);
            if (s.robotStatus == 4) {
              error++;
            } else if (onStation) {
              charging++;
            } else {
              active++;
            }
          } else {
            onStation = _isDefaultOnStation(s);
            if (s.robotStatus == RobotState.error) {
              error++;
            } else if (onStation) {
              charging++;
            } else {
              active++;
            }
          }
        }

        /* ───── states ───── */
        if (controller.isLoading) {
          return const Center(
            child: CupertinoActivityIndicator(radius: 20, color: Colors.grey),
          );
        }
        if (active + charging + error == 0) {
          return const Center(
            child: Text(
              '운행 정보가 없습니다 😑',
              style: TextStyle(fontSize: 15, color: kHintColor),
            ),
          );
        }

        /* ───── UI ───── */
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: 8.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '기기 운행 현황',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'pretendard',
                  color: Color(0xFF666565),
                ),
              ),
              const SizedBox(height: 8.0),
              _statusCard(
                color: const Color(0xFF005FB8),
                title: '운행중',
                subtitle: '현재 정상',
                count: active,
              ),
              const SizedBox(height: 10.0),
              _statusCard(
                color: const Color(0xFFFFAE00),
                title: '충전중',
                subtitle: '현재 충전',
                count: charging,
              ),
              const SizedBox(height: 10.0),
              _statusCard(
                color: const Color(0xFFC42B1C),
                title: '고장',
                subtitle: '현재 고장',
                count: error,
              ),
            ],
          ),
        );
      },
    );
  }

  /* ────────── helpers ────────── */

  bool _isUntactOnStation(RobotStatus s) =>
      (s.latitude == kStation0Latitude && s.longitude == kStation0Longitude) ||
      (s.latitude == kStation1Latitude && s.longitude == kStation1Longitude) ||
      (s.latitude == kStation2Latitude && s.longitude == kStation2Longitude) ||
      (s.latitude == kStation3Latitude && s.longitude == kStation3Longitude) ||
      (s.latitude == kStation4Latitude && s.longitude == kStation4Longitude);

  bool _isDefaultOnStation(RobotStatus s) => (s.posX == kPosReturn['X']) && (s.posY == kPosReturn['Y']);

  Widget _statusCard({
    required Color color,
    required String title,
    required String subtitle,
    required int count,
  }) {
    final String countStr = Utils.numberWithComma(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            countStr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
