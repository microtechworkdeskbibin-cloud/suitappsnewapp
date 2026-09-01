import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:suitapps/shared/extensions/responsive.dart'; // âœ… adjust path

class SalesOrdersChart extends StatefulWidget {
  const SalesOrdersChart({super.key});

  @override
  State<SalesOrdersChart> createState() => _SalesOrdersChartState();
}

class _SalesOrdersChartState extends State<SalesOrdersChart> {
  static const _salesColor = Color(0xFF4B4CF6);
  static const _ordersColor = Color(0xFF22C7A6);

  // base sizes (we will scale using Responsive)
  static const double _baseCardHPad = 16;
  static const double _baseCardVPadTop = 14;
  static const double _baseCardVPadBottom = 14;

  static const double _baseLeftAxisReserved = 34;
  static const double _baseRightPlotPad = 8;

  static const double _baseTooltipW = 160;
  static const double _baseTooltipMargin = 6;

  int? _selectedX;
  bool _isTouching = false;

  final _labels = const [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
  ];

  final _sales = const <FlSpot>[
    FlSpot(0, 95),
    FlSpot(1, 95),
    FlSpot(2, 120),
    FlSpot(3, 210),
    FlSpot(4, 300),
    FlSpot(5, 280),
    FlSpot(6, 310),
    FlSpot(7, 200),
  ];

  final _orders = const <FlSpot>[
    FlSpot(0, 160),
    FlSpot(1, 150),
    FlSpot(2, 140),
    FlSpot(3, 170),
    FlSpot(4, 150),
    FlSpot(5, 210),
    FlSpot(6, 155),
    FlSpot(7, 150),
  ];

  int _indexFromDx(
    double dx,
    double totalWidth,
    double leftAxisReserved,
    double rightPlotPad,
  ) {
    final plotWidth = (totalWidth - leftAxisReserved - rightPlotPad).clamp(
      1.0,
      double.infinity,
    );
    final local = (dx - leftAxisReserved).clamp(0.0, plotWidth);
    final t = local / plotWidth;
    return (t * (_labels.length - 1)).round().clamp(0, _labels.length - 1);
  }

  double _xPixelForIndex(
    int idx,
    double totalWidth,
    double leftAxisReserved,
    double rightPlotPad,
  ) {
    final plotWidth = (totalWidth - leftAxisReserved - rightPlotPad).clamp(
      1.0,
      double.infinity,
    );
    final t = idx / (_labels.length - 1);
    return leftAxisReserved + (t * plotWidth);
  }

  int _valueAt(List<FlSpot> series, int idx) {
    for (final s in series) {
      if (s.x.toInt() == idx) return s.y.toInt();
    }
    return 0;
  }

  void _updateSelection(
    Offset localPos,
    double width,
    double leftAxisReserved,
    double rightPlotPad,
  ) {
    final idx = _indexFromDx(
      localPos.dx,
      width,
      leftAxisReserved,
      rightPlotPad,
    );
    setState(() {
      _selectedX = idx;
      _isTouching = true;
    });
  }

  void _endTouch() {
    setState(() {
      _isTouching = false;
      _selectedX = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // âœ… Responsive sizes
    final double cardHPad = Responsive.pad(context, _baseCardHPad);
    final double cardVTop = Responsive.pad(context, _baseCardVPadTop);
    final double cardVBottom = Responsive.pad(context, _baseCardVPadBottom);

    final double cardRadius = Responsive.radius(context, 22.0);
    final double shadowBlur = Responsive.scale(context, 18.0);
    final double shadowY = Responsive.scale(context, 10.0);

    final double chartH = Responsive.scale(context, 220.0);

    final double leftAxisReserved = Responsive.scale(
      context,
      _baseLeftAxisReserved,
    );
    final double rightPlotPad = Responsive.pad(context, _baseRightPlotPad);

    final double tooltipW = Responsive.scale(context, _baseTooltipW);
    final double tooltipMargin = Responsive.pad(context, _baseTooltipMargin);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(cardHPad, cardVTop, cardHPad, cardVBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowY),
          ),
        ],
      ),
      child: Column(
        children: [
          const _Header(),
          SizedBox(height: Responsive.pad(context, 12.0)),

          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final idx = (_isTouching && _selectedX != null)
                  ? _selectedX
                  : null;

              double? tooltipLeft;
              if (idx != null) {
                final x = _xPixelForIndex(
                  idx,
                  w,
                  leftAxisReserved,
                  rightPlotPad,
                );
                tooltipLeft = (x - (tooltipW / 2)).clamp(
                  tooltipMargin,
                  w - tooltipW - tooltipMargin,
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _updateSelection(
                  d.localPosition,
                  w,
                  leftAxisReserved,
                  rightPlotPad,
                ),
                onTapUp: (_) => _endTouch(),
                onTapCancel: _endTouch,
                onPanDown: (d) => _updateSelection(
                  d.localPosition,
                  w,
                  leftAxisReserved,
                  rightPlotPad,
                ),
                onPanUpdate: (d) => _updateSelection(
                  d.localPosition,
                  w,
                  leftAxisReserved,
                  rightPlotPad,
                ),
                onPanEnd: (_) => _endTouch(),
                onPanCancel: _endTouch,
                child: SizedBox(
                  height: chartH,
                  child: Stack(
                    children: [
                      LineChart(_chartData(leftAxisReserved: leftAxisReserved)),

                      if (idx != null && tooltipLeft != null)
                        _TooltipBubble(
                          left: tooltipLeft,
                          top: Responsive.pad(context, 18.0),
                          month: _labels[idx],
                          year: "2026",
                          sales: _valueAt(_sales, idx),
                          orders: _valueAt(_orders, idx),
                          width: tooltipW,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  LineChartData _chartData({required double leftAxisReserved}) {
    final show = _isTouching && _selectedX != null;

    final double axisFont = Responsive.font(context, 11.0);

    return LineChartData(
      minX: 0,
      maxX: 7,
      minY: 0,
      maxY: 400,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 100,
        getDrawingHorizontalLine: (v) => FlLine(
          color: Colors.black.withValues(alpha: 0.12),
          strokeWidth: 1,
          dashArray: [3, 6],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 100,
            reservedSize: leftAxisReserved,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: axisFont,
                  color: Colors.black.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= _labels.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(top: Responsive.pad(context, 10.0)),
                child: Text(
                  _labels[idx],
                  style: TextStyle(
                    fontSize: axisFont,
                    color: Colors.black.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(
        verticalLines: (!show)
            ? []
            : [
                VerticalLine(
                  x: _selectedX!.toDouble(),
                  color: _salesColor.withValues(alpha: 0.12),
                  strokeWidth: Responsive.scale(context, 40.0),
                ),
              ],
      ),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: _sales,
          isCurved: true,
          curveSmoothness: 0.35,
          color: _salesColor,
          barWidth: Responsive.scale(context, 3.0),
          dotData: FlDotData(
            show: show,
            checkToShowDot: (spot, _) => spot.x.toInt() == _selectedX,
          ),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: _orders,
          isCurved: true,
          curveSmoothness: 0.35,
          color: _ordersColor,
          barWidth: Responsive.scale(context, 3.0),
          dotData: FlDotData(
            show: show,
            checkToShowDot: (spot, _) => spot.x.toInt() == _selectedX,
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------ */
/* HEADER                                                       */
/* ------------------------------------------------------------ */

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final double titleSize = Responsive.font(context, 16.0);
    final double legendGap = Responsive.pad(context, 16.0);

    return Row(
      children: [
        Text(
          "Sales vs Orders",
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        const _LegendDot(color: Color(0xFF4B4CF6), label: "Sales"),
        SizedBox(width: legendGap),
        const _LegendDot(color: Color(0xFF22C7A6), label: "Orders"),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double dot = Responsive.scale(context, 8.0);
    final double gap = Responsive.pad(context, 6.0);
    final double fontSize = Responsive.font(context, 12.0);

    return Row(
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------ */
/* TOOLTIP BUBBLE                                               */
/* ------------------------------------------------------------ */

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({
    required this.left,
    required this.top,
    required this.month,
    required this.year,
    required this.sales,
    required this.orders,
    required this.width,
  });

  final double left;
  final double top;
  final double width;
  final String month;
  final String year;
  final int sales;
  final int orders;

  @override
  Widget build(BuildContext context) {
    final double radius = Responsive.radius(context, 16.0);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.pad(context, 12.0),
          vertical: Responsive.pad(context, 10.0),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.font(context, 12.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$month, $year",
                style: TextStyle(
                  fontSize: Responsive.font(context, 12.0),
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: Responsive.pad(context, 10.0)),
              Row(
                children: [
                  const _Dot(color: Color(0xFF4B4CF6)),
                  SizedBox(width: Responsive.pad(context, 8.0)),
                  Expanded(
                    child: Text(
                      "Sales",
                      style: TextStyle(
                        fontSize: Responsive.font(context, 12.0),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    "$sales",
                    style: TextStyle(
                      fontSize: Responsive.font(context, 12.0),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.pad(context, 8.0)),
              Row(
                children: [
                  const _Dot(color: Color(0xFF22C7A6)),
                  SizedBox(width: Responsive.pad(context, 8.0)),
                  Expanded(
                    child: Text(
                      "Orders",
                      style: TextStyle(
                        fontSize: Responsive.font(context, 12.0),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    "$orders",
                    style: TextStyle(
                      fontSize: Responsive.font(context, 12.0),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double dot = Responsive.scale(context, 8.0);
    return Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
