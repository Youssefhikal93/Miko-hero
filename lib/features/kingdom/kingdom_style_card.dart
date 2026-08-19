import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Per-child castle, photo frame, backdrop, and favourite symbol controls.
class KingdomStyleCard extends ConsumerWidget {
  /// Creates decoration controls for the active My Kingdom profile.
  const KingdomStyleCard({required this.profile, super.key});

  /// Active child whose kingdom decoration is edited and saved.
  final ChildProfile profile;

  @override
  /// Saves every choice immediately, the way the color palette already does.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final theme = profile.kingdomTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.kingdomStyleTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(text.kingdomStyleBody(profile.name)),
            const SizedBox(height: 18),
            _choices<CastleStyle>(
              context: context,
              label: text.kingdomCastle,
              values: CastleStyle.values,
              selected: theme.castle,
              keyPrefix: 'castle',
              labelOf: (value) => _castleLabel(text, value),
              onSelected: (value) =>
                  _save(context, ref, theme.withCastle(value)),
            ),
            const SizedBox(height: 18),
            _choices<AvatarFrameStyle>(
              context: context,
              label: text.kingdomAvatarFrame,
              values: AvatarFrameStyle.values,
              selected: theme.frame,
              keyPrefix: 'frame',
              labelOf: (value) => _frameLabel(text, value),
              onSelected: (value) =>
                  _save(context, ref, theme.withFrame(value)),
            ),
            const SizedBox(height: 18),
            _choices<KingdomBackdrop>(
              context: context,
              label: text.kingdomBackdrop,
              values: KingdomBackdrop.values,
              selected: theme.backdrop,
              keyPrefix: 'backdrop',
              labelOf: (value) => _backdropLabel(text, value),
              onSelected: (value) =>
                  _save(context, ref, theme.withBackdrop(value)),
            ),
            const SizedBox(height: 18),
            _symbolChoices(context, ref, text, theme),
          ],
        ),
      ),
    );
  }

  /// Builds one labelled row of mutually exclusive decoration choices.
  Widget _choices<T extends Enum>({
    required BuildContext context,
    required String label,
    required List<T> values,
    required T selected,
    required String keyPrefix,
    required String Function(T value) labelOf,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map((value) {
                return ChoiceChip(
                  key: ValueKey<String>('$keyPrefix-${value.name}'),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                  label: Text(labelOf(value)),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  /// Builds the bounded set of kid-friendly symbols as icon-only choices.
  Widget _symbolChoices(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations text,
    KingdomTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text.kingdomSymbol,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: KingdomSymbol.values
              .map((symbol) {
                return ChoiceChip(
                  key: ValueKey<String>('symbol-${symbol.name}'),
                  selected: theme.symbol == symbol,
                  onSelected: (_) =>
                      _save(context, ref, theme.withSymbol(symbol)),
                  avatar: Icon(kingdomSymbolIcon(symbol), size: 20),
                  tooltip: _symbolLabel(text, symbol),
                  label: Text(_symbolLabel(text, symbol)),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  /// Persists one decoration change and confirms it like the other cards.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    KingdomTheme theme,
  ) async {
    final text = AppLocalizations.of(context);
    try {
      await ref
          .read(profileControllerProvider)
          .setKingdomTheme(profile.id, theme);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(text.kingdomStyleSaved(profile.name))),
        );
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}

/// Localizes one castle silhouette while keeping its stable storage name.
String _castleLabel(AppLocalizations text, CastleStyle style) {
  return switch (style) {
    CastleStyle.classicTowers => text.castleClassicTowers,
    CastleStyle.roundDomes => text.castleRoundDomes,
    CastleStyle.crystalSpires => text.castleCrystalSpires,
    CastleStyle.forestTreehouse => text.castleForestTreehouse,
  };
}

/// Localizes one photo frame while keeping its stable storage name.
String _frameLabel(AppLocalizations text, AvatarFrameStyle frame) {
  return switch (frame) {
    AvatarFrameStyle.none => text.avatarFrameNone,
    AvatarFrameStyle.stars => text.avatarFrameStars,
    AvatarFrameStyle.hearts => text.avatarFrameHearts,
    AvatarFrameStyle.laurel => text.avatarFrameLaurel,
  };
}

/// Localizes one backdrop flavor while keeping its stable storage name.
String _backdropLabel(AppLocalizations text, KingdomBackdrop backdrop) {
  return switch (backdrop) {
    KingdomBackdrop.nightSky => text.backdropNightSky,
    KingdomBackdrop.meadow => text.backdropMeadow,
    KingdomBackdrop.ocean => text.backdropOcean,
    KingdomBackdrop.sunset => text.backdropSunset,
  };
}

/// Localizes one favourite symbol while keeping its stable storage name.
String _symbolLabel(AppLocalizations text, KingdomSymbol symbol) {
  return switch (symbol) {
    KingdomSymbol.star => text.symbolStar,
    KingdomSymbol.rocket => text.symbolRocket,
    KingdomSymbol.crown => text.symbolCrown,
    KingdomSymbol.butterfly => text.symbolButterfly,
    KingdomSymbol.dragon => text.symbolDragon,
    KingdomSymbol.flower => text.symbolFlower,
    KingdomSymbol.football => text.symbolFootball,
    KingdomSymbol.music => text.symbolMusic,
    KingdomSymbol.book => text.symbolBook,
    KingdomSymbol.paw => text.symbolPaw,
    KingdomSymbol.rainbow => text.symbolRainbow,
    KingdomSymbol.sparkles => text.symbolSparkles,
  };
}
