import 'package:flutter/material.dart';

/// A finite entrance that leaves content immediately visible under reduced motion.
class StoryEntrance extends StatelessWidget {
  /// Stagger is a fraction of the entrance timeline, not a delayed timer.
  const StoryEntrance({required this.child, this.stagger = 0, super.key});

  /// Content retains its state throughout the entrance.
  final Widget child;

  /// Start position in the shared 800 ms timeline.
  final double stagger;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Interval(stagger, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, progress, content) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - progress)),
          child: content,
        ),
      ),
    );
  }
}

/// Pointer and keyboard feedback without adding a second action or tab stop.
class StoryHover extends StatefulWidget {
  /// Wraps existing interactive content, preserving its callbacks.
  const StoryHover({required this.child, super.key});

  /// Existing controls remain responsible for taps and keyboard activation.
  final Widget child;

  @override
  State<StoryHover> createState() => _StoryHoverState();
}

class _StoryHoverState extends State<StoryHover> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0,
            !reducedMotion && _hovered ? -4 : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hovered || _focused
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
