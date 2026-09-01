import 'package:flutter/material.dart';

class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.align = Alignment.centerLeft,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class EllipsizeText extends StatelessWidget {
  const EllipsizeText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
