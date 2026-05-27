import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final Color color;
  final Function(double dy) onMove;
  final VoidCallback onRelease;

  const VirtualJoystick({
    super.key,
    this.size = 100,
    this.color = Colors.red,
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _currentPos = Offset.zero;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _pressed = true;
          _currentPos = Offset(0, details.localPosition.dy - widget.size / 2);
          _clampPosition();
        });
        _notify();
      },
      onPanUpdate: (details) {
        setState(() {
          _currentPos = Offset(0, _currentPos.dy + details.delta.dy);
          _clampPosition();
        });
        _notify();
      },
      onPanEnd: (_) {
        setState(() {
          _pressed = false;
          _currentPos = Offset.zero;
        });
        widget.onRelease();
      },
      onPanCancel: () {
        setState(() {
          _pressed = false;
          _currentPos = Offset.zero;
        });
        widget.onRelease();
      },
      child: Container(
        width: widget.size,
        height: widget.size * 1.8,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(widget.size / 2),
          border: Border.all(
            color: widget.color.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Guide line
            Positioned(
              top: widget.size * 0.3,
              bottom: widget.size * 0.3,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Center marker
            Positioned(
              child: Container(
                width: widget.size * 0.6,
                height: 2,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Knob
            AnimatedPositioned(
              duration: _pressed 
                  ? const Duration(milliseconds: 16) 
                  : const Duration(milliseconds: 200),
              curve: Curves.elasticOut,
              top: (_pressed 
                  ? (widget.size * 0.9 + _currentPos.dy - widget.size * 0.22)
                  : (widget.size * 0.9 - widget.size * 0.22)),
              child: Container(
                width: widget.size * 0.45,
                height: widget.size * 0.45,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(_pressed ? 0.9 : 0.6),
                      widget.color.withOpacity(_pressed ? 0.7 : 0.4),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _pressed
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ]
                      : [],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: widget.size * 0.15,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            // Label
            Positioned(
              bottom: 8,
              child: Text(
                widget.color == Colors.red ? 'L' : 'R',
                style: TextStyle(
                  color: widget.color.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clampPosition() {
    final maxDy = widget.size * 0.5;
    _currentPos = Offset(
      0,
      _currentPos.dy.clamp(-maxDy, maxDy),
    );
  }

  void _notify() {
    final maxDy = widget.size * 0.5;
    final normalized = -_currentPos.dy / maxDy; // -1 to 1, inverted so up is positive
    widget.onMove(normalized);
  }
}
