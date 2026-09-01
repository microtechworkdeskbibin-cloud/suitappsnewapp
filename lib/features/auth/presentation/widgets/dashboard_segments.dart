import 'package:flutter/material.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/shared/extensions/responsive.dart'; // âœ… adjust path

class DashboardSegments extends StatelessWidget {
  const DashboardSegments({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // âœ… Responsive spacing + sizing
    final double gap = Responsive.pad(context, 4.0);
    final double vPad = Responsive.pad(context, 10.0);
    final double radius = Responsive.radius(context, 999.0);
    final double fontSize = Responsive.font(context, 10.5);

    return Row(
      children: [
        _SegBtn(
          "Order History",
          selectedIndex == 0,
          () => onChanged(0),
          gap: gap,
          vPad: vPad,
          radius: radius,
          fontSize: fontSize,
        ),
        _SegBtn(
          "Sales History",
          selectedIndex == 1,
          () => onChanged(1),
          gap: gap,
          vPad: vPad,
          radius: radius,
          fontSize: fontSize,
        ),
        _SegBtn(
          "Payment Collection",
          selectedIndex == 2,
          () => onChanged(2),
          gap: gap,
          vPad: vPad,
          radius: radius,
          fontSize: fontSize,
        ),
        _SegBtn(
          "Invoice History",
          selectedIndex == 3,
          () => onChanged(3),
          gap: gap,
          vPad: vPad,
          radius: radius,
          fontSize: fontSize,
        ),
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn(
    this.text,
    this.selected,
    this.onTap, {
    required this.gap,
    required this.vPad,
    required this.radius,
    required this.fontSize,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  final double gap;
  final double vPad;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gap),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: vPad),
            decoration: BoxDecoration(
              color: selected ? DashboardConstants.brandBlue : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected
                    ? DashboardConstants.brandBlue
                    : const Color(0xFFE6E8F0),
                width: Responsive.scale(context, 1.0),
              ),
            ),
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : DashboardConstants.brandBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
