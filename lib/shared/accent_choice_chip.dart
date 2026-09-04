import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';

/// How much of an accent is left behind a chip that is selected.
///
/// The same fraction `AppTheme` tints the theme's own selected chip with, kept
/// here as well because this is the one place a chip carrying somebody else's
/// accent has to mix it for itself.
const double _selectedAccentAlpha = 0.18;

/// A choice chip that can be lit by one child's accent instead of the theme's.
///
/// Every chip in the app already agrees on what "selected" looks like — the
/// accent at [_selectedAccentAlpha] behind the label, the accent as the ring
/// around it — because `AppTheme` says so once. The shelf is the exception:
/// its child chips and filter chips belong to the child they name rather than
/// to whoever is reading, so each one has to say which accent it is lit by.
/// That is the whole of [accent]: leave it out and the chip is the theme's,
/// pass a colour and the chip is that child's, and either way the selected
/// tint and the ring are the same two decisions.
///
/// No checkmark, in either case. The ring and the tint already say which chip
/// is chosen, and a chip that swaps its [avatar] for a checkmark loses the
/// hero face or the symbol that made it recognisable. A chip row that does
/// want the checkmark — the kingdom's decorations, the reading sizes, the
/// palette swatches — is a plain `ChoiceChip` on the theme and stays one.
class AccentChoiceChip extends StatelessWidget {
  /// Creates one chip in [accent], or in the theme's accent when it is absent.
  const AccentChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.accent,
    this.avatar,
    super.key,
  });

  /// What the chip says. A widget rather than a string because the shelf's
  /// child chips print a kingdom symbol beside the hero name and the creation
  /// form writes each language in its own script.
  final Widget label;

  /// Whether this chip is the chosen one of its row.
  final bool selected;

  /// Chooses this chip. Null disables it, exactly as `ChoiceChip` reads it.
  final VoidCallback? onSelected;

  /// Colour this chip is lit by, or null to be lit by the active accent.
  final Color? accent;

  /// Optional face, glyph or swatch drawn before the label.
  final Widget? avatar;

  @override
  /// Rings and tints the chip in [accent], or leaves both to the chip theme.
  Widget build(BuildContext context) {
    final accent = this.accent;
    final onSelected = this.onSelected;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected == null ? null : (_) => onSelected(),
      selectedColor: accent?.withValues(alpha: _selectedAccentAlpha),
      side: accent == null
          ? null
          : BorderSide(color: selected ? accent : AppTheme.hairline),
      avatar: avatar,
      label: label,
    );
  }
}
