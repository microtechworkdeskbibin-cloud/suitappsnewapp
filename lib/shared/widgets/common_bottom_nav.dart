import 'package:flutter/material.dart';
import 'package:suitapps/shared/extensions/responsive.dart'; // âœ… adjust path to your Responsive file

// import 'package:suitapps/shared/widgets/expandable_fab.dart';
class CommonBottomNav extends StatelessWidget {
  const CommonBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.activeColor,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    // âœ… Responsive sizing
    final double navH = Responsive.scale(context, 72.0);
    final double marginH = Responsive.pad(context, 18.0);
    final double padH = Responsive.pad(context, 10.0);
    final double radius = Responsive.radius(context, 40.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: Responsive.pad(context, 0.0)),
        child: Container(
          height: navH,
          margin: EdgeInsets.symmetric(horizontal: marginH),
          padding: EdgeInsets.symmetric(horizontal: padH),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: Responsive.scale(context, 26.0),
                offset: Offset(0, Responsive.scale(context, 10.0)),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                selected: index == 0,
                onTap: () => onChanged(0),
                activeColor: activeColor,
              ),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                selected: index == 1,
                onTap: () => onChanged(1),
                activeColor: activeColor,
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                selected: index == 2,
                onTap: () => onChanged(2),
                activeColor: activeColor,
              ),
              _NavItem(
                icon: Icons.description_rounded,
                selected: index == 3,
                onTap: () => onChanged(3),
                activeColor: activeColor,
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                selected: index == 4,
                onTap: () => onChanged(4),
                activeColor: activeColor,
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    // âœ… Responsive sizing
    final double selectedSize = Responsive.scale(context, 54.0);
    final double normalSize = Responsive.scale(context, 46.0);
    final double iconSize = Responsive.scale(context, 28.0);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: selected ? selectedSize : normalSize,
        height: selected ? selectedSize : normalSize,
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: selected ? Colors.white : activeColor,
        ),
      ),
    );
  }
}
