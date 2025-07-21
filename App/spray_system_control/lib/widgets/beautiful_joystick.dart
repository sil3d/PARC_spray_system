import 'package:flutter/material.dart';
// import 'dart:math'; // <<< SUPPRESSION DE L'IMPORT INUTILISÉ

typedef JoystickCallback = void Function(double x, double y);

class BeautifulJoystick extends StatefulWidget {
  final double size;
  final JoystickCallback listener;
  final Color baseColor;
  final Color stickColor;
  final bool isEnabled;

  const BeautifulJoystick({
    super.key,
    this.size = 150.0,
    required this.listener,
    this.baseColor = const Color(0xFFE0E0E0),
    this.stickColor = const Color(0xFF616161),
    this.isEnabled = true,
  });

  @override
  State<BeautifulJoystick> createState() => _BeautifulJoystickState();
}

class _BeautifulJoystickState extends State<BeautifulJoystick> {
  Offset _stickOffset = Offset.zero;

  double get _maxRadius => widget.size / 2 - _stickSize / 2;
  double get _stickSize => widget.size / 2;

  void _handleDragStart(DragStartDetails details) {
    if (!widget.isEnabled) return;
    _updateStickPosition(details.localPosition);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled) return;
    _updateStickPosition(details.localPosition);

    final double normalizedX = (_stickOffset.dx / _maxRadius).clamp(-1.0, 1.0);
    final double normalizedY = (_stickOffset.dy / _maxRadius).clamp(-1.0, 1.0);
    widget.listener(normalizedX, -normalizedY);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.isEnabled) return;

    setState(() {
      _stickOffset = Offset.zero;
    });

    widget.listener(0.0, 0.0);
  }

  void _updateStickPosition(Offset localPosition) {
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    final Offset vector = localPosition - center;

    final double distance = vector.distance;
    if (distance > _maxRadius) {
      setState(() {
        _stickOffset = Offset.fromDirection(vector.direction, _maxRadius);
      });
    } else {
      setState(() {
        _stickOffset = vector;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handleDragStart,
      onPanUpdate: _handleDragUpdate,
      onPanEnd: _handleDragEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isEnabled ? widget.baseColor : Colors.grey.shade400,
          gradient: RadialGradient(
            colors: [
              _lighten(widget.baseColor, 0.2),
              widget.baseColor,
              _darken(widget.baseColor, 0.2),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(102), // <<< CORRECTION
              offset: const Offset(4, 4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withAlpha(179), // <<< CORRECTION
              offset: const Offset(-4, -4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              _stickOffset.dx,
              _stickOffset.dy,
              0,
            ),
            child: Container(
              width: _stickSize,
              height: _stickSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isEnabled
                    ? widget.stickColor
                    : Colors.grey.shade600,
                gradient: RadialGradient(
                  colors: [
                    _lighten(widget.stickColor),
                    widget.stickColor,
                    _darken(widget.stickColor),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(128), // <<< CORRECTION
                    blurRadius: 5,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return hslLight.toColor();
  }

  Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
