import 'package:flutter/material.dart';
import 'package:suitapps/shared/extensions/responsive.dart'; // âœ… adjust path

class TimelineItemData {
  final String title;
  final String time;
  final bool showProfile;
  final String? name;
  final String? email;

  const TimelineItemData({
    required this.title,
    required this.time,
    this.showProfile = false,
    this.name,
    this.email,
  });
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.items});

  final List<TimelineItemData> items;

  @override
  Widget build(BuildContext context) {
    final double gap = Responsive.pad(context, 10.0);

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isLast = i == items.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : gap),
          child: _TimelineItem(
            title: item.title,
            time: item.time,
            showProfile: item.showProfile,
            name: item.name,
            email: item.email,
            drawLine: !isLast,
          ),
        );
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.time,
    required this.drawLine,
    this.showProfile = false,
    this.name,
    this.email,
  });

  final String title;
  final String time;
  final bool drawLine;
  final bool showProfile;
  final String? name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    // âœ… Responsive values
    final double dotSize = Responsive.scale(context, 10.0);
    final double lineW = Responsive.scale(context, 2.0);
    final double lineH = Responsive.scale(context, showProfile ? 54.0 : 26.0);

    final double cardRadius = Responsive.radius(context, 14.0);
    final double cardPad = Responsive.pad(context, 12.0);

    final double titleFont = Responsive.font(context, 12.5);
    final double timeFont = Responsive.font(context, 10.5);
    final double nameFont = Responsive.font(context, 11.5);
    final double emailFont = Responsive.font(context, 10.5);

    final double avatarR = Responsive.scale(context, 14.0);
    final double avatarIcon = Responsive.scale(context, 18.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: Color(0xFF17B26A),
                shape: BoxShape.circle,
              ),
            ),
            if (drawLine)
              Container(
                width: lineW,
                height: lineH,
                color: const Color(0xFFE3E6EF),
              ),
          ],
        ),

        SizedBox(width: Responsive.pad(context, 10.0)),

        Expanded(
          child: Container(
            padding: EdgeInsets.all(cardPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: const Color(0xFFEDEFF6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFont,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: Responsive.pad(context, 4.0)),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: timeFont,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),

                if (showProfile) ...[
                  SizedBox(height: Responsive.pad(context, 10.0)),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: avatarR,
                        backgroundColor: const Color(0xFFEAF0FF),
                        child: Icon(
                          Icons.person_rounded,
                          color: const Color(0xFF2300C4),
                          size: avatarIcon,
                        ),
                      ),
                      SizedBox(width: Responsive.pad(context, 10.0)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name ?? "",
                              style: TextStyle(
                                fontSize: nameFont,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: Responsive.pad(context, 2.0)),
                            Row(
                              children: [
                                Icon(
                                  Icons.mail_outline_rounded,
                                  size: Responsive.scale(context, 14.0),
                                  color: Colors.black45,
                                ),
                                SizedBox(width: Responsive.pad(context, 6.0)),
                                Expanded(
                                  child: Text(
                                    email ?? "",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: emailFont,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
