import 'package:flutter/material.dart';

/// The one shape a screen takes when it has nothing of its own to show.
///
/// An empty shelf, a search that matched no title, a review queue with no
/// drafts left, a device with no child profiles on it yet, and the two panels
/// that report a local read failure were all the same column drawn seven
/// slightly different ways: a glyph, a line naming the situation, sometimes a
/// sentence under it, sometimes one action out of it. They are this widget
/// now, so the icon size and the four gaps are decided once and a new empty
/// screen cannot invent an eighth spacing.
///
/// The card is part of the shape rather than the caller's job: an empty state
/// is always a bounded piece of content on the page, never loose text on the
/// background. A caller that needs the card centred in the viewport still
/// wraps it in a `Center` of its own, because that is a question about the
/// page and not about the state.
///
/// [body] and [action] are both optional and independently so — the shortest
/// empty state is a glyph and one line, and the review queue's is that line
/// plus a way out. [title] is the one line that is always there, so it is the
/// sentence a state with only one sentence carries.
class EmptyState extends StatelessWidget {
  /// Creates the shared empty state.
  const EmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    super.key,
  });

  /// Glyph naming what is missing, drawn from the shared icon vocabulary.
  final IconData icon;

  /// The one line every empty state carries, set in the title slot.
  final String title;

  /// Optional supporting sentence under [title].
  final String? body;

  /// Optional single way out of the state, such as "Create a first story".
  final Widget? action;

  @override
  /// Draws the glyph, the line, and whatever else this state was given.
  Widget build(BuildContext context) {
    final body = this.body;
    final action = this.action;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
            ],
            if (action != null) ...<Widget>[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }
}
