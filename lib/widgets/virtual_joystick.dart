import 'package:flutter/material.dart';

/// VirtualJoystick — absolute-position tracking, spring return
///
/// Design principles:
///  • Knob tracks absolute finger Y from the joystick centre at ALL times.
///    No delta accumulation = no drift. Knob is always exactly under finger.
///  • Outputs a normalised value: -1.0 (full up) to +1.0 (full down).
///    Caller sees positive = push down, negative = push up.
///  • Spring return on release.
class VirtualJoystick extends StatefulWidget {
  final double size;
  final Color  color;
  final void Function(double) onMove;    // -1..+1, called every update
  final VoidCallback           onRelease;

  const VirtualJoystick({
    super.key,
    this.size = 80,
    this.color = Colors.red,
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {

  double _norm   = 0.0;   // normalised -1..1
  bool   _active = false;

  late AnimationController _spring;
  late Animation<double>   _springAnim;

  // Layout constants derived from widget.size
  double get _h          => widget.size * 2.2;   // total container height
  double get _centreY    => _h / 2;
  double get _maxTravel  => widget.size * 0.70;  // px from centre the knob can travel
  double get _knobR      => widget.size * 0.24;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  // ── Gesture handlers ──────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    _spring.stop();
    _setFromLocal(d.localPosition.dy);
    setState(() => _active = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _setFromLocal(d.localPosition.dy);
  }

  void _onPanEnd(DragEndDetails? _) {
    widget.onRelease();
    _springAnim = Tween<double>(begin: _norm, end: 0.0)
        .animate(CurvedAnimation(parent: _spring, curve: Curves.elasticOut))
      ..addListener(_onSpringTick);
    setState(() => _active = false);
    _spring.forward(from: 0);
  }

  void _onSpringTick() {
    setState(() => _norm = _springAnim.value);
    // Notify continuously during spring so bar returns smoothly
    widget.onMove(_norm);
  }

  /// Convert raw local Y position to normalised knob value and notify.
  void _setFromLocal(double localY) {
    final offset = localY - _centreY;
    final clamped = offset.clamp(-_maxTravel, _maxTravel);
    final norm    = clamped / _maxTravel;
    setState(() => _norm = norm);
    widget.onMove(_norm);  // positive = pushed down, negative = pushed up
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final knobTop = _centreY + (_norm * _maxTravel) - _knobR;

    return GestureDetector(
      // Use onPan (not onVerticalDrag) so it captures immediately without
      // competing with scroll recognisers.
      onPanStart:  _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd:    _onPanEnd,
      onPanCancel: () => _onPanEnd(null),
      child: SizedBox(
        width:  widget.size,
        height: _h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [

            // Track
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(widget.size / 2),
                  border: Border.all(
                    color: widget.color.withOpacity(_active ? 0.75 : 0.35),
                    width: _active ? 2.5 : 2.0,
                  ),
                  boxShadow: _active ? [
                    BoxShadow(
                      color:        widget.color.withOpacity(0.25),
                      blurRadius:   24,
                      spreadRadius: 4,
                    ),
                  ] : [],
                ),
              ),
            ),

            // Centre notch
            Positioned(
              top:   _centreY - 1.5,
              left:  widget.size * 0.20,
              right: widget.size * 0.20,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color:        widget.color.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Rail line
            Positioned(
              left:   widget.size / 2 - 1.5,
              top:    _centreY - _maxTravel,
              height: _maxTravel * 2,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color:        widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Knob — position is absolute, tracks finger exactly
            Positioned(
              top:  knobTop,
              left: widget.size / 2 - _knobR,
              child: Container(
                width:  _knobR * 2,
                height: _knobR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(_active ? 1.0 : 0.7),
                      widget.color.withOpacity(_active ? 0.7 : 0.4),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: _active ? [
                    BoxShadow(
                      color:        widget.color.withOpacity(0.6),
                      blurRadius:   18,
                      spreadRadius: 3,
                    ),
                  ] : [],
                ),
                child: Center(
                  child: Container(
                    width:  _knobR * 0.35,
                    height: _knobR * 0.35,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),

            // Label
            Positioned(
              bottom: 6,
              left: 0, right: 0,
              child: Center(
                child: Text(
                  widget.color == Colors.red ? 'L' : 'R',
                  style: TextStyle(
                    color:      widget.color.withOpacity(0.55),
                    fontSize:   12,
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
