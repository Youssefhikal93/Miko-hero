import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';

/// Constrains feature content while retaining comfortable phone padding.
class ScreenLayout extends StatelessWidget {
  /// Creates a scrollable screen with an optional narrower content width.
  const ScreenLayout({
    required this.child,
    this.maxWidth = 1160,
    this.backgroundGradient,
    super.key,
  });

  /// Feature content rendered inside the responsive constraint.
  final Widget child;

  /// Largest content width before centered gutters grow.
  final double maxWidth;

  /// Optional per-page backdrop replacing the shared ambient gradient.
  ///
  /// Used by My Kingdom for the active child's chosen flavor; every accepted
  /// gradient must stay dark enough for the shared light-on-dark text.
  final Gradient? backgroundGradient;

  @override
  /// Adds safe-area spacing and a subtle ambient background gradient.
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: backgroundGradient ?? _ambientGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Shared ambient wash used by every page without its own backdrop.
  static const _ambientGradient = RadialGradient(
    center: Alignment(0.8, -0.9),
    radius: 1.2,
    colors: <Color>[Color(0x222F2340), AppTheme.night],
  );
}

/// Reusable tile reserved for hero-level content.
class AccentPanel extends StatelessWidget {
  /// Creates a highlighted panel around the supplied content.
  const AccentPanel({required this.child, super.key});

  /// Content displayed on the tile surface.
  final Widget child;

  @override
  /// Renders a flat tile ringed by the active child's accent.
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

/// Consistent feature heading with optional supporting text.
class SectionHeading extends StatelessWidget {
  /// Creates a heading whose subtitle may be omitted when no context is needed.
  const SectionHeading({required this.title, this.subtitle, super.key});

  /// Main section label.
  final String title;

  /// Optional explanatory sentence.
  final String? subtitle;

  @override
  /// Renders title and subtitle using the current localized text direction.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
  }
}
