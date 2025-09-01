import 'package:flutter/material.dart';

import '../../constants/constants.dart';

class CustomMenuItem extends StatelessWidget {
  const CustomMenuItem({
    super.key,
    this.icon,
    this.menuText = "",
    required this.onPressMenu,
    required this.onHover,
    this.isParentMenu = false,
    this.subMenuList,
    this.isOpened = false,
    this.isSelected = false,
    this.isOnHover = false,
  });

  final IconData? icon;
  final String menuText;
  final GestureTapCallback onPressMenu;
  final ValueChanged<bool> onHover;
  final bool isParentMenu;
  final List<CustomMenuItem>? subMenuList;
  final bool isOpened;
  final bool isSelected;
  final bool isOnHover;

  @override
  Widget build(BuildContext context) {
    return buildTabletMenu();
  }

  Widget buildTabletMenu() {
    return InkWell(
      onTap: () {
        onPressMenu();
      },
      onHover: (value) {
        onHover(value);
      },
      child: Container(
        width: 74,
        height: 70,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            (icon == null)
                ? Container()
                : Icon(
                    icon,
                    size: 28,
                    color: isSelected
                        ? Colors.white
                        : isOnHover
                            ? kHoverColor
                            : Colors.grey,
                  ),
            const SizedBox(height: 8),
            Text(
              menuText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : isOnHover
                        ? kHoverColor
                        : Colors.grey,
                decoration:
                    isOnHover ? TextDecoration.underline : TextDecoration.none,
                decorationColor: isOnHover ? Colors.white : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDesktopMenu() {
    return Column(
      children: [
        InkWell(
          onTap: onPressMenu,
          onHover: onHover,
          child: Container(
            height: 50,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 50,
                  alignment: Alignment.center,
                  child: (icon == null)
                      ? Container()
                      : Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : isOnHover
                                  ? kHoverColor
                                  : Colors.grey,
                        ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 50,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    menuText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isOnHover
                              ? kHoverColor
                              : Colors.grey,
                      decoration: isOnHover
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor:
                          isOnHover ? Colors.white : Colors.transparent,
                      height: 1.6,
                    ),
                  ),
                ),
                Icon(
                  (isParentMenu && !isOpened)
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 20,
                  color: (isParentMenu &&
                          subMenuList != null &&
                          subMenuList!.isNotEmpty)
                      ? Colors.white
                      : Colors.transparent,
                )
              ],
            ),
          ),
        ),
        if (isParentMenu &&
            isOpened &&
            subMenuList != null &&
            subMenuList!.isNotEmpty)
          ListView.builder(
            padding: const EdgeInsets.all(0),
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: subMenuList!.length,
            itemBuilder: (BuildContext context, int index) {
              return CustomMenuItem(
                menuText: subMenuList![index].menuText,
                icon: subMenuList![index].icon,
                onPressMenu: subMenuList![index].onPressMenu,
                onHover: subMenuList![index].onHover,
                isParentMenu: false,
                subMenuList: null,
                isSelected: subMenuList![index].isSelected,
              );
            },
          ),
      ],
    );
  }
}
