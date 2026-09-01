import 'dart:ui';
import 'package:flutter/material.dart';

class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    this.onCustomerTap,
    this.onOrderTap,
    this.onInvoiceTap,
    this.onProductTap,
  });

  final VoidCallback? onCustomerTap;
  final VoidCallback? onOrderTap;
  final VoidCallback? onInvoiceTap;
  final VoidCallback? onProductTap;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with TickerProviderStateMixin {
  bool isOpen = false;

  late AnimationController _backdropController;
  late AnimationController _fabController;
  late List<AnimationController> _itemControllers;

  late Animation<double> _backdropAnimation;
  late Animation<double> _fabRotation;
  late Animation<double> _fabScale;

  static const _itemCount = 4;

  final _items = const [
    _FabItem(
      label: 'Add Customer',
      icon: Icons.person_add_rounded,
      color: Color.fromARGB(255, 35, 0, 196),
    ),
    _FabItem(
      label: 'Order',
      icon: Icons.shopping_bag_rounded,
      color: Color.fromARGB(255, 35, 0, 196),
    ),
    _FabItem(
      label: 'Invoice',
      icon: Icons.receipt_long_rounded,
      color: Color.fromARGB(255, 35, 0, 196),
    ),
    _FabItem(
      label: 'Product',
      icon: Icons.inventory_2_rounded,
      color: Color.fromARGB(255, 35, 0, 196),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _itemControllers = List.generate(
      _itemCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      ),
    );

    _backdropAnimation = CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeOut,
    );

    _fabRotation = Tween<double>(begin: 0, end: 0.375).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOutBack),
    );

    _fabScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _fabController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openMenu() async {
  setState(() => isOpen = true);

  _backdropController.forward();
  _fabController.forward();

  for (int i = 0; i < _itemControllers.length; i++) {
    _itemControllers[i].forward();
  }
}

  Future<void> _closeMenu() async {
  _fabController.reverse();
  _backdropController.reverse();

  for (final controller in _itemControllers) {
    controller.reverse();
  }

  await Future.wait([
    _fabController.reverse(),
    _backdropController.reverse(),
  ]);

  if (mounted) {
    setState(() => isOpen = false);
  }
}

  void toggleMenu() {
    if (isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _handleItemTap(VoidCallback? callback) async {
    await _closeMenu();
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop blur overlay
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: FadeTransition(
                opacity: _backdropAnimation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(color: Colors.black.withValues(alpha: 0.08)),
                ),
              ),
            ),
          ),

        // Menu items + FAB column
        Positioned(
          bottom: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Items (reversed so first item is closest to FAB)
              ...List.generate(_items.length, (i) {
                final item = _items[i];
                final ctrl = _itemControllers[i];

                final slideAnim =
                    Tween<Offset>(
                      begin: const Offset(0.3, 0.15),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: ctrl,
                        curve: const _SpringCurve(),
                      ),
                    );

                final fadeAnim = CurvedAnimation(
                  parent: ctrl,
                  curve: const Interval(0, 0.6, curve: Curves.easeOut),
                );

                final scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
                  CurvedAnimation(parent: ctrl, curve: const _SpringCurve()),
                );

                return FadeTransition(
                  opacity: fadeAnim,
                  child: SlideTransition(
                    position: slideAnim,
                    child: ScaleTransition(
                      scale: scaleAnim,
                      alignment: Alignment.centerRight,
                      child: _MenuChip(
                        item: item,
                        onTap: () => _handleItemTap(
                          [
                            widget.onCustomerTap,
                            widget.onOrderTap,
                            widget.onInvoiceTap,
                            widget.onProductTap,
                          ][i],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // FAB button
              ScaleTransition(
                scale: _fabScale,
                child: GestureDetector(
                  onTap: toggleMenu,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 35, 0, 196),
                      borderRadius: BorderRadius.circular(isOpen ? 20 : 18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                          blurRadius: isOpen ? 24 : 16,
                          spreadRadius: isOpen ? 2 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: RotationTransition(
                      turns: _fabRotation,
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Menu chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MenuChip extends StatefulWidget {
  const _MenuChip({required this.item, required this.onTap});

  final _FabItem item;
  final VoidCallback onTap;

  @override
  State<_MenuChip> createState() => _MenuChipState();
}

class _MenuChipState extends State<_MenuChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 180, // same width for all buttons
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: widget.item.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[850],
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Data model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FabItem {
  const _FabItem({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}


class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transform(double t) {
    return Curves.easeOutBack.transform(t);
  }
}
