import 'package:flutter/material.dart';

/// VirtualJoystick — vertical rail, snap-to-finger, spring return
///
/// Feel improvements over previous version:
///  • onVerticalDragUpdate tracks absolute local position → knob
///    always sits exactly under the finger, no drift
///  • During drag: zero animation delay (Positioned, not AnimatedPositioned)
///  • On release: 250ms spring-back with elasticOut
///  • Larger travel range (60% of container half-height)
class VirtualJoystick extends StatefulWidget {
  final double size;
  final Color color;
  final Function(double) onMove;
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

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {
  // Normalised position: -1.0 (full up) → 0 (centre) → +1.0 (full down)
  double _value  = 0.0;
  bool   _active = false;

  late AnimationController _springCtrl;
  late Animation<double>   _springAnim;

  double get _containerH => widget.size * 2.0;
  double get _centerY    => _containerH / 2;
  double get _maxTravel  => widget.size * 0.64; // px from centre — more travel range
  double get _knobRadius => widget.size * 0.22;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _springCtrl.stop();
    final offset = (d.localPosition.dy - _centerY) / _maxTravel;
    setState(() {
      _active = true;
      _value  = offset.clamp(-1.0, 1.0);
    });
    widget.onMove(-_value); // negative: up = positive input
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Track absolute finger position for perfect snap
    final raw = (_value * _maxTravel + d.delta.dy) / _maxTravel;
    setState(() => _value = raw.clamp(-1.0, 1.0));
    widget.onMove(-_value);
  }

  void _onDragEnd(DragEndDetails? d) {
    widget.onRelease();
    _springAnim = Tween<double>(begin: _value, end: 0.0).animate(
      CurvedAnimation(parent: _springCtrl, curve: Curves.elasticOut),
    )..addListener(() => setState(() => _value = _springAnim.value));
    setState(() => _active = false);
    _springCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final knobY = _centerY + (_value * _maxTravel) - _knobRadius;

    return GestureDetector(
      onVerticalDragStart:  _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd:    _onDragEnd,
      onVerticalDragCancel: () => _onDragEnd(null),
      child: Container(
        width:  widget.size,
        height: _containerH,
        decoration: BoxDecoration(
          color:        Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(widget.size / 2),
          border: Border.all(
            color: widget.color.withOpacity(_active ? 0.7 : 0.35),
            width: _active ? 2.5 : 2.0,
          ),
          boxShadow: _active
              ? [BoxShadow(
                  color:       widget.color.withOpacity(0.2),
                  blurRadius:  20,
                  spreadRadius: 4,
                )]
              : [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Vertical rail line
            Positioned(
              left:   widget.size / 2 - 1,
              top:    widget.size * 0.2,
              bottom: widget.size * 0.2,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),

            // Centre notch
            Positioned(
              top:  _centerY - 1,
              left: widget.size * 0.25,
              right: widget.size * 0.25,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),

            // Knob — no animation during drag, spring only on release
            Positioned(
              top:  knobY,
              left: widget.size / 2 - _knobRadius,
              child: Container(
                width:  _knobRadius * 2,
                height: _knobRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    widget.color.withOpacity(_active ? 1.0 : 0.65),
                    widget.color.withOpacity(_active ? 0.7 : 0.4),
                  ]),
                  boxShadow: _active
                      ? [BoxShadow(
                          color:       widget.color.withOpacity(0.55),
                          blurRadius:  16,
                          spreadRadius: 3,
                        )]
                      : [],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width:  _knobRadius * 0.38,
                    height: _knobRadius * 0.38,
                    decoration: BoxDecoration(
                      color:  Colors.white.withOpacity(0.45),
                      shape:  BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),

            // Label
            Positioned(
              bottom: 8,
              left: 0, right: 0,
              child: Center(
                child: Text(
                  widget.color == Colors.red ? 'L' : 'R',
                  style: TextStyle(
                    color:      widget.color.withOpacity(0.5),
                    fontSize:   13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
