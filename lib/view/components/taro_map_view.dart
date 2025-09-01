import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../viewmodel/controller/robot_controller.dart';

class TaroMapView extends StatefulWidget {
  const TaroMapView({
    super.key,
    this.selectedTaroSerial,
    this.initialScale,
  });

  final String? selectedTaroSerial;
  final double? initialScale;

  @override
  State<TaroMapView> createState() => _TaroMapViewState();
}

class _TaroMapViewState extends State<TaroMapView> with TickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final String _backgroundImagePath = 'assets/images/img_taro_map_flexdesian.png';

  final double _imageOriginalWidth = 745.0;
  final double _imageOriginalHeight = 400.0;

  // For centering animation
  late AnimationController _mapCenteringAnimationController;
  Animation<Matrix4>? _mapMatrixAnimation;

  // For robot movement animation
  final Map<String, AnimationController> _robotAnimControllers = {};
  final Map<String, Animation<Offset>> _robotPositionAnimations = {};
  final Map<String, Offset> _robotTargetPositions = {};
  Timer? _animationUpdateDebounceTimer;

  // Store layout dimensions
  double _viewerWidth = 0;
  double _viewerHeight = 0;
  double _drawnImageWidth = 0;
  double _drawnImageHeight = 0;
  double _offsetX = 0;
  double _offsetY = 0;
  double _initialFitScale = 1.0;
  bool _initialViewSetupDone = false;
  static const double _markerIconSize = 24.0;

  @override
  void initState() {
    super.initState();

    _mapCenteringAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (_mapMatrixAnimation != null) {
          _transformationController.value = _mapMatrixAnimation!.value;
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupInitialView();
    });
  }

  void _setupInitialView() {
    // Guard to run only once and if conditions are met
    if (_initialViewSetupDone ||
        widget.initialScale == null ||
        _viewerWidth == 0 ||
        _viewerHeight == 0 ||
        _initialFitScale == 0.0) {
      return;
    }

    _mapCenteringAnimationController.stop();

    double targetScaleProvided = widget.initialScale!;
    Offset targetPointOnOriginalImage;

    final robotController = Get.isRegistered<RobotController>() ? Get.find<RobotController>() : null;
    final selectedTaroStatus = (widget.selectedTaroSerial != null && robotController != null)
        ? robotController.robotStatusList.firstWhereOrNull((status) => status.serial == widget.selectedTaroSerial)
        : null;

    if (selectedTaroStatus != null && selectedTaroStatus.posX != null && selectedTaroStatus.posY != null) {
      final List<double> imageCoords = calcPOS(selectedTaroStatus.posX!, selectedTaroStatus.posY!);
      targetPointOnOriginalImage = Offset(imageCoords[0], imageCoords[1]);
    } else {
      targetPointOnOriginalImage = Offset(_imageOriginalWidth / 2, _imageOriginalHeight / 2);
    }

    final double pxOnFittedContent = _offsetX + targetPointOnOriginalImage.dx * _initialFitScale;
    final double pyOnFittedContent = _offsetY + targetPointOnOriginalImage.dy * _initialFitScale;

    double s_iv = targetScaleProvided / _initialFitScale;
    s_iv = s_iv.clamp(0.1, 4.0);

    Matrix4 initialMatrix = Matrix4.identity()
      ..translate(_viewerWidth / 2, _viewerHeight / 2)
      ..scale(s_iv)
      ..translate(-pxOnFittedContent, -pyOnFittedContent);

    _transformationController.value = initialMatrix;
    _initialViewSetupDone = true;
  }

  @override
  void didUpdateWidget(covariant TaroMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTaroSerial != null && widget.selectedTaroSerial != oldWidget.selectedTaroSerial) {
      _centerOnSelectedTaro(widget.selectedTaroSerial!, isNewSelection: true);
    }
  }

  void _initOrUpdateRobotAnimation(String serial, Offset beginPosition, Offset newTargetPosition) {
    AnimationController? controller = _robotAnimControllers[serial];

    if (controller == null) {
      controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );
      _robotAnimControllers[serial] = controller;
    } else {
      controller.duration = const Duration(milliseconds: 1000);
    }

    final animation = Tween<Offset>(
      begin: beginPosition,
      end: newTargetPosition,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    _robotPositionAnimations[serial] = animation;

    controller.forward(from: 0.0);
  }

  void _centerOnSelectedTaro(String taroSerial, {bool isNewSelection = false}) {
    if (widget.selectedTaroSerial == null) return;

    final double currentInteractiveScale = _transformationController.value.getMaxScaleOnAxis();
    if (!isNewSelection && currentInteractiveScale <= _initialFitScale * 1.05) {
      return;
    }

    final robotController = Get.find<RobotController>();
    final selectedTaroStatus =
        robotController.robotStatusList.firstWhereOrNull((status) => status.serial == taroSerial);

    if (selectedTaroStatus != null && selectedTaroStatus.posX != null && selectedTaroStatus.posY != null) {
      final List<double> imageCoords = calcPOS(selectedTaroStatus.posX!, selectedTaroStatus.posY!);
      final double targetXOnImage = imageCoords[0];
      final double targetYOnImage = imageCoords[1];

      final double targetXInDrawnImage = (targetXOnImage / _imageOriginalWidth) * _drawnImageWidth + _offsetX;
      final double targetYInDrawnImage = (targetYOnImage / _imageOriginalHeight) * _drawnImageHeight + _offsetY;

      final Matrix4 currentMatrix = _transformationController.value.clone();
      final double currentScale = currentMatrix.getMaxScaleOnAxis();

      double targetScale = currentScale;

      Matrix4 targetMatrix = Matrix4.identity()
        ..translate(_viewerWidth / 2, _viewerHeight / 2)
        ..scale(targetScale)
        ..translate(-targetXInDrawnImage, -targetYInDrawnImage);

      final Offset currentCenterViewer =
          MatrixUtils.transformPoint(currentMatrix, Offset(targetXInDrawnImage, targetYInDrawnImage));
      final double distanceToCenter = (Offset(_viewerWidth / 2, _viewerHeight / 2) - currentCenterViewer).distance;

      final Offset transformedTarget =
          MatrixUtils.transformPoint(currentMatrix, Offset(targetXInDrawnImage, targetYInDrawnImage));
      bool isOffScreen = transformedTarget.dx < 0 ||
          transformedTarget.dx > _viewerWidth ||
          transformedTarget.dy < 0 ||
          transformedTarget.dy > _viewerHeight;

      if (isNewSelection || distanceToCenter > 50 || isOffScreen) {
        _mapMatrixAnimation = Matrix4Tween(
          begin: currentMatrix,
          end: targetMatrix,
        ).animate(CurvedAnimation(parent: _mapCenteringAnimationController, curve: Curves.easeInOut));
        _mapCenteringAnimationController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _mapCenteringAnimationController.dispose();
    _robotAnimControllers.forEach((_, controller) => controller.dispose());
    _animationUpdateDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewerWidth = constraints.maxWidth;
        _viewerHeight = constraints.maxHeight;

        if (_viewerWidth <= 0 || _viewerHeight <= 0) {
          _initialFitScale = 1.0;
        } else {
          _initialFitScale = min(_viewerWidth / _imageOriginalWidth, _viewerHeight / _imageOriginalHeight);
        }

        _drawnImageWidth = _imageOriginalWidth * _initialFitScale;
        _drawnImageHeight = _imageOriginalHeight * _initialFitScale;
        _offsetX = (_viewerWidth - _drawnImageWidth) / 2;
        _offsetY = (_viewerHeight - _drawnImageHeight) / 2;

        final List<MarkerInfo> markerInfos = kTaroMakers.map((markerData) {
          final List<double> imageCoords = calcPOS(markerData['X'] as double, markerData['Y'] as double);

          return MarkerInfo(
            x: imageCoords[0],
            y: imageCoords[1],
            title: markerData['title'] as String,
            originalX: imageCoords[0],
            originalY: imageCoords[1],
          );
        }).toList();

        return GetBuilder<RobotController>(
          init: RobotController(),
          builder: (controller) {
            final List<String> currentRobotSerials = [];
            final List<MarkerInfo> taroInfos = [];

            MarkerInfo? selectedTaro;

            for (int i = 0; i < controller.robotStatusList.length; i++) {
              RobotStatus status = controller.robotStatusList[i];

              if (Get.find<RobotController>().isDeletedRobot(status.id!)) {
                continue;
              }

              if (status.serial != null && status.serial!.contains("controller")) {
                continue;
              }

              if (status.objectTypeId != 2) {
                continue;
              }

              currentRobotSerials.add(status.serial!);
              final List<double> imageCoords = calcPOS(status.posX!, status.posY!);
              final newPos = Offset(imageCoords[0], imageCoords[1]);

              if (_robotTargetPositions[status.serial!] == null || _robotTargetPositions[status.serial!] != newPos) {
                Offset animationBeginPos;
                final animController = _robotAnimControllers[status.serial!];
                final currentAnimation = _robotPositionAnimations[status.serial!];

                if (animController != null && animController.isAnimating && currentAnimation != null) {
                  animationBeginPos = currentAnimation.value;
                } else {
                  animationBeginPos = _robotTargetPositions[status.serial!] ?? newPos;
                }

                _initOrUpdateRobotAnimation(status.serial!, animationBeginPos, newPos);
                _robotTargetPositions[status.serial!] = newPos;
              }

              if (status.serial == widget.selectedTaroSerial) {
                _centerOnSelectedTaro(widget.selectedTaroSerial!);
                selectedTaro = MarkerInfo(
                  x: imageCoords[0],
                  y: imageCoords[1],
                  title: "${status.serial}",
                  originalX: imageCoords[0],
                  originalY: imageCoords[1],
                );
              } else {
                taroInfos.add(MarkerInfo(
                  x: imageCoords[0],
                  y: imageCoords[1],
                  title: "${status.serial}",
                  originalX: imageCoords[0],
                  originalY: imageCoords[1],
                ));
              }
            }

            if (selectedTaro != null) {
              taroInfos.add(selectedTaro);
            }

            final removedSerials =
                _robotAnimControllers.keys.where((serial) => !currentRobotSerials.contains(serial)).toList();
            for (var serial in removedSerials) {
              _robotAnimControllers[serial]?.dispose();
              _robotAnimControllers.remove(serial);
              _robotPositionAnimations.remove(serial);
              _robotTargetPositions.remove(serial);
            }

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.1,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: _viewerWidth,
                    height: _viewerHeight,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          left: _offsetX,
                          top: _offsetY,
                          width: _drawnImageWidth,
                          height: _drawnImageHeight,
                          child: Image.asset(
                            _backgroundImagePath,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onInteractionEnd: (details) {
                    debugPrint(_transformationController.value.toString());
                  },
                ),
                ValueListenableBuilder<Matrix4>(
                  valueListenable: _transformationController,
                  builder: (context, matrix, child) {
                    return Stack(
                      children: [
                        ...markerInfos.map((markerInfo) {
                          final double initialX =
                              (markerInfo.originalX / _imageOriginalWidth) * _drawnImageWidth + _offsetX;
                          final double initialY =
                              (markerInfo.originalY / _imageOriginalHeight) * _drawnImageHeight + _offsetY;

                          final Offset transformedOffset = MatrixUtils.transformPoint(
                            matrix,
                            Offset(initialX, initialY),
                          );

                          final double finalX = transformedOffset.dx - _markerIconSize / 2;
                          final double finalY = transformedOffset.dy - _markerIconSize + 20;

                          return Positioned(
                            left: finalX,
                            top: finalY,
                            child: SizedBox(
                              width: _markerIconSize,
                              height: _markerIconSize,
                              child: Tooltip(
                                message: markerInfo.title,
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                textStyle: const TextStyle(
                                  fontFamily: 'light',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                child: markerInfo.title == "반환지점"
                                    ? SvgPicture.asset(
                                        'assets/images/icons_bolt.svg',
                                        color: const Color(0xFF407BFF),
                                        width: _markerIconSize,
                                        height: _markerIconSize,
                                      )
                                    : markerInfo.title.contains("시작지점")
                                        ? SvgPicture.asset(
                                            'assets/images/icons_rocket.svg',
                                            color: Colors.red,
                                            width: _markerIconSize,
                                            height: _markerIconSize,
                                          )
                                        : Icon(
                                            Icons.location_on,
                                            color: Colors.grey,
                                            size: _markerIconSize,
                                          ),
                              ),
                            ),
                          );
                        }),
                        ...taroInfos.map((taroInfo) {
                          final animation = _robotPositionAnimations[taroInfo.title];
                          final controller = _robotAnimControllers[taroInfo.title];

                          Widget taroWidget;
                          if (animation != null && controller != null) {
                            taroWidget = AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                final animatedX =
                                    (animation.value.dx / _imageOriginalWidth) * _drawnImageWidth + _offsetX;
                                final animatedY =
                                    (animation.value.dy / _imageOriginalHeight) * _drawnImageHeight + _offsetY;

                                final Offset transformedOffset = MatrixUtils.transformPoint(
                                  matrix, // current transformation matrix from InteractiveViewer
                                  Offset(animatedX, animatedY),
                                );

                                final double finalX = transformedOffset.dx - _markerIconSize / 2;
                                final double finalY = transformedOffset.dy - _markerIconSize + 20;

                                return Positioned(
                                  left: finalX,
                                  top: finalY,
                                  child: child!,
                                );
                              },
                              child: Tooltip(
                                message: "Taro_Robot${taroInfo.title}",
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                textStyle: const TextStyle(
                                  fontFamily: 'light',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                child: buildTaro(taroInfo),
                              ),
                            );
                          } else {
                            final double initialX =
                                (taroInfo.originalX / _imageOriginalWidth) * _drawnImageWidth + _offsetX;
                            final double initialY =
                                (taroInfo.originalY / _imageOriginalHeight) * _drawnImageHeight + _offsetY;

                            final Offset transformedOffset = MatrixUtils.transformPoint(
                              matrix,
                              Offset(initialX, initialY),
                            );

                            final double finalX = transformedOffset.dx - _markerIconSize / 2;
                            final double finalY = transformedOffset.dy - _markerIconSize + 20;
                            taroWidget = Positioned(
                              left: finalX,
                              top: finalY,
                              child: Tooltip(
                                message: "Taro_Robot${taroInfo.title}",
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                textStyle: const TextStyle(
                                  fontFamily: 'light',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                child: buildTaro(taroInfo),
                              ),
                            );
                          }
                          return taroWidget;
                        }),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildTaro(MarkerInfo taro) {
    return Stack(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: (taro.title == widget.selectedTaroSerial) ? Colors.orange : Colors.grey, width: 1),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/images/icons_taro.svg',
            color: (taro.title == widget.selectedTaroSerial) ? Colors.orange : Colors.grey,
            width: 20,
            height: 20,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: (taro.title == widget.selectedTaroSerial) ? Colors.orange : Colors.grey,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          width: 10,
          height: 10,
          alignment: Alignment.center,
          child: Text(
            taro.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'light',
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  List<double> calcPOS(double a, double b) {
    double c, d;
    double tempA = a;
    double tempB = -b;

    double offsetXWorld = 14.0;
    double offsetYWorld = 19.0;

    double scaleFactor = 8.908950149038706;

    c = (tempA + offsetXWorld) * scaleFactor;
    d = (tempB + offsetYWorld) * scaleFactor;

    return [c, d];
  }
}

class MarkerInfo {
  final double x;
  final double y;
  final String title;
  final double originalX;
  final double originalY;
  // Add a field for the robot's current heading if available and needed for icon rotation
  // final double? heading;

  MarkerInfo({
    required this.x,
    required this.y,
    required this.title,
    required this.originalX,
    required this.originalY,
    // this.heading,
  });
}
