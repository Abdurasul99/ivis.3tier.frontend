import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/graph_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';

class MovingDistanceWidget extends StatefulWidget {
  const MovingDistanceWidget({super.key});

  @override
  State<MovingDistanceWidget> createState() => _MovingDistanceWidgetState();
}

class _MovingDistanceWidgetState extends State<MovingDistanceWidget> {
  @override
  void initState() {
    super.initState();

    Get.find<GraphController>().makeTotalValues();
  }

  Future<void> refresh() async {
    await Get.find<GraphController>().makeTotalValues();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '전체 로봇의 누적 주행거리',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF666565),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GetBuilder<GraphController>(
              init: GraphController(),
              builder: (controller) {
                List<Robot> robots = Get.find<RobotController>().unDeletedRobots;

                if (controller.totalDistance.isEmpty) {
                  refresh();
                }

                if (controller.isLoadingTotal) {
                  return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
                }

                Map<int, double> totalDistance = controller.totalDistance;

                if (robots.isEmpty || totalDistance.isEmpty) {
                  return const Center(
                    child: Text(
                      '주행 정보가 없습니다 😑',
                      style: TextStyle(
                        fontSize: 18,
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: (robots.length / 2).ceil(),
                  itemBuilder: (BuildContext context, int index) {
                    return Row(
                      children: [
                        Expanded(
                          child: buildRobotItem(robots[index * 2], totalDistance[robots[index * 2].id] ?? 0.0),
                        ),
                        if (index * 2 + 1 < robots.length)
                          Expanded(
                            child:
                                buildRobotItem(robots[index * 2 + 1], totalDistance[robots[index * 2 + 1].id] ?? 0.0),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRobotItem(Robot robot, double distance) {
    String distanceStr = "";

    if (robot.typeDescription!.toLowerCase() == "untact") {
      distance = ((distance / 10000) * 100).round() / 100;

      distanceStr = "${Utils.doubleWithComma(distance)}km";
    } else {
      distance = (distance * 100).round() / 100;
      distanceStr = "${Utils.doubleWithComma(distance)}m";
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFDBDBDB), width: 1.0),
              image: DecorationImage(
                image: ExtendedNetworkImageProvider(
                  robot.imageUrl ?? robot.typeImageUrl ?? "",
                  cache: true,
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "${robot.typeDescription}_${robot.name}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: kGrayFontColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                distanceStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: kBlackFontColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
