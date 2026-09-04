import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// Bundled variable typeface every interface surface speaks in.
///
/// Declared in `pubspec.yaml` from `assets/fonts/Outfit-Variable.ttf`, which is
/// licensed under the SIL Open Font License. The file carries a `wght` axis
/// whose default instance is the thinnest weight, so every style built here
/// also pins the axis through `fontVariations`.
const interfaceFontFamily = 'Outfit';

/// Bundled family used wherever [interfaceFontFamily] has no glyphs.
///
/// Outfit is Latin-only, so Arabic chrome is set in the Naskh face the offline
/// export already bundles rather than in a face that would render nothing.
const arabicInterfaceFontFamily = 'NotoNaskhArabic';

/// Interface family for [language].
///
/// This is the single place the Arabic fallback is decided, and it follows the
/// same script rule story prose already uses for the easy-reading font.
String interfaceFontFamilyFor(AppLanguage language) {
  return language.usesLatinScript
      ? interfaceFontFamily
      : arabicInterfaceFontFamily;
}

/// Iam - hero visual system shared by every target platform.
///
/// This is the single source of the redesign palette and of the small text
/// styles that repeat across screens. No feature names a colour or a caption
/// metric of its own; `test/app/app_theme_test.dart` scans `lib/features` and
/// `lib/shared` and fails when one does.
///
/// Two long-standing ambiguities are settled here, and the tokens below are
/// named so that the answers stay visible:
///
/// **Quiet ink: [frost] or [mutedDeep]?** The surface underneath decides.
/// [mutedDeep] is the quiet ink on the app's own dark chrome — a tile, a card,
/// a row — where it reads as deliberately recessive. [frost] is the quiet ink
/// printed *on artwork*, where [mutedDeep] would sink into whatever the PC
/// happened to draw. The two meta styles differ in nothing else: [caption] and
/// [coverCaption] are the same size and carry only that one difference.
///
/// **[candle] as the accent, or the bedtime palette?** They never compete.
/// [candle] is the *default* accent: the primary a family is lit by until a
/// child saves a colour, plus the fixed warm emphasis the design prints
/// regardless of who is reading (the favourite heart, the drafts notice, the
/// new-story tile). Once a child has saved a colour, that colour is the accent
/// and [candle] speaks only in those fixed warm places. The `bedtime` tokens
/// are not an accent at all: they are a whole page palette the reader swaps in
/// for the duration of bedtime mode — [bedtimeProse] for the prose,
/// [bedtimeSurface] for the page, [bedtimeWash] over the illustration — and
/// they replace, rather than tint, what they cover. The one place the two meet
/// is the narration highlight, which uses [candle] while bedtime is on because
/// a cold accent would fight warm prose.
abstract final class AppTheme {
  /// Deep background the whole application sits on.
  static const night = Color(0xFF0A0D18);

  /// Raised tile surface used by cards, dialogs, and grouped content.
  static const tile = Color(0xFF151A2E);

  /// Recessed surface used by fields, icon buttons, and navigation chrome.
  static const sunken = Color(0xFF141930);

  /// Warm candle used for primary emphasis and the default hero accent.
  ///
  /// The accent only until a child saves a colour of their own; after that it
  /// stays exactly where the design prints warmth for everybody — the
  /// favourite heart, the parent drafts notice, the new-story tile, and the
  /// narration highlight while bedtime mode is on.
  static const candle = Color(goldenProfileThemeColorValue);

  /// Lighter candle used for warm inline emphasis such as link-style actions.
  static const candleLight = Color(0xFFFFC469);

  /// Ink printed on candle-colored surfaces.
  static const onCandle = Color(0xFF2A1900);

  /// Primary text color on every dark surface.
  static const light = Color(0xFFF2EFEA);

  /// Bright secondary tone for icons and small chrome labels.
  ///
  /// Also the quiet ink for meta text printed *on artwork*, where [mutedDeep]
  /// would disappear into the picture. See [coverCaption].
  static const frost = Color(0xFFC6CBDC);

  /// Secondary text color for supporting sentences.
  static const muted = Color(0xFF9AA1B8);

  /// Quietest text color, used for captions and inactive labels.
  ///
  /// The quiet ink on the app's own chrome — tiles, cards and rows. Meta text
  /// over a cover uses [frost] instead. See [caption].
  static const mutedDeep = Color(0xFF6E7793);

  /// Hairline border separating tiles from the background.
  static const hairline = Color(0xFF262D45);

  /// Hairline in a warm tint, reserved for parent-facing notices.
  static const hairlineWarm = Color(0xFF3A3320);

  /// Deeper orange used in gradients and focused states.
  static const orange = Color(0xFFFF7426);

  /// Pink accent applied after selecting a girl profile.
  static const girlPink = Color(roseProfileThemeColorValue);

  /// Soft pink used for girl-profile gradients and secondary controls.
  static const girlRose = Color(0xFFFF91C5);

  /// Cyan accent applied after selecting a boy profile.
  static const boyCyan = Color(cyanProfileThemeColorValue);

  /// Purple palette offered as a one-tap My Kingdom choice.
  static const purple = Color(0xFF9C6BFF);

  /// Green palette offered as a one-tap My Kingdom choice.
  static const green = Color(0xFF43D19E);

  /// Blue used for boy-profile gradients and secondary controls.
  static const boyBlue = Color(0xFF3987FF);

  /// Warm, dimmed prose color used by the reader's bedtime mode.
  ///
  /// Deliberately softer than white while staying well above the contrast a
  /// child needs to keep reading in a dark room.
  static const bedtimeProse = Color(0xFFE9CFA4);

  /// Warm page surface behind bedtime prose.
  static const bedtimeSurface = Color(0xFF1B1409);

  /// Dimming and warming wash drawn over bedtime illustrations.
  static const bedtimeWash = LinearGradient(
    colors: <Color>[Color(0xB3140A02), Color(0x8CFF9A3C)],
  );

  /// Violet the redesign closes its cover placeholders on.
  ///
  /// Deliberately not [purple]: that token names a kingdom palette a parent can
  /// pick for a child, so borrowing it would make an unrelated decoration
  /// choice and a story's artwork move together. Read by
  /// `StoryArtwork.placeholderColors` for the colorful-3D style, and by nothing
  /// else.
  static const violet = Color(0xFF8A31CB);

  /// Ink printed directly on cover artwork.
  ///
  /// "Cover" is any story picture a caption sits on: a shelf tile, the review
  /// cover, or a reader page's placeholder. Pure white, because the artwork
  /// underneath is a photograph-like render rather than a known surface.
  static const onCover = Color(0xFFFFFFFF);

  /// Softer on-cover ink for decorative glyphs rather than words.
  static const onCoverMuted = Color(0xCCFFFFFF);

  /// Translucent disc a placeholder face sits in on top of artwork.
  static const onCoverVeil = Color(0x3DFFFFFF);

  /// Bottom-weighted wash drawn between cover artwork and the text on it.
  ///
  /// Keeps a title readable over whatever the PC happened to draw. Painted by
  /// every story tile that prints words on its own cover.
  static const coverScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: <double>[0, 0.65],
    colors: <Color>[Color(0xD106080F), Color(0x1406080F)],
  );

  /// Darkening blend laid over a drawn cover before content is printed on it.
  static const coverShade = Color(0x73000000);

  /// Pill behind a badge that has to stay legible on any artwork.
  static const coverPill = Color(0x66000000);

  /// Ink for an action that cannot be undone, and for the check that blocks one.
  ///
  /// Used by the delete-everything control in Settings and by the required-photo
  /// message that stops a profile being saved without one. Recoverable form
  /// errors keep `ColorScheme.error`, which Material already derives.
  static const danger = Color(0xFFFF5252);

  /// Ink for a dependency that reports itself ready.
  static const ready = Color(0xFF69F0AE);

  /// Ink for a dependency that is reachable but not yet usable.
  static const attention = Color(0xFFFFAB40);

  /// Faint corner glow the shared page backdrop is lit from.
  ///
  /// `ScreenLayout` places it; the colour is a palette decision and lives here.
  static const ambientGlow = Color(0x222F2340);

  /// Neutral square a child's photo occupies before one has been chosen.
  static const mediaWell = Color(0xFF222635);

  /// Quiet meta line under a title on the app's own chrome.
  ///
  /// Merged onto the surrounding interface style, so it names only what makes
  /// it a caption. Used by every story tile, Home tile and shelf row.
  static const caption = TextStyle(fontSize: 13, color: mutedDeep);

  /// The same meta line, printed on cover artwork instead of on a tile.
  static const coverCaption = TextStyle(fontSize: 13, color: frost);

  /// Tracked capitals naming a strip of content, such as "ON THE SHELF".
  static const overline = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: mutedDeep,
  );

  /// The same capitals as an eyebrow inside a tile, in the tile's warm ink.
  static const overlineTile = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: candleLight,
  );

  /// Quiet label above a name, set in sentence case rather than capitals.
  ///
  /// Less tracked and lighter than [overline] precisely because it is not
  /// capitalised. Used by Home's "Reading as" header.
  static const overlineSoft = TextStyle(
    fontSize: 11,
    letterSpacing: 1.1,
    color: mutedDeep,
  );

  /// Label of a badge that rides on artwork, such as the demo marker.
  static const badgeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
  );

  /// Two-letter language code inside its accent-tinted square.
  ///
  /// Carries no colour: the caller supplies the active accent it is drawn in.
  static const codeBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.7,
  );

  /// Overrides that turn a resolved `labelLarge` into a form section heading.
  ///
  /// Merged rather than used alone so the heading keeps the label slot's own
  /// metrics; only the tracking, weight and ink are decided here.
  static const sectionLabel = TextStyle(
    color: mutedDeep,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
  );

  /// Style a label needs when it is written in [language]'s own script.
  ///
  /// Null while [language] reads the Latin face the interface already speaks
  /// in, so a caller can hand the result straight to a widget's `style`. This
  /// is the only way a feature asks for an interface face: the helper behind it
  /// stays private to the theme's own decisions.
  static TextStyle? scriptStyleFor(AppLanguage language) {
    if (language.usesLatinScript) return null;
    return TextStyle(
      fontFamily: interfaceFontFamilyFor(language),
      fontVariations: const <FontVariation>[],
    );
  }

  /// Creates a dark Material theme from the active child's saved opaque color.
  ///
  /// [locale] selects the interface typeface only; every color still comes from
  /// the shared tokens and the active child's accent. A child who saved their
  /// own color keeps the ink Material derives for it; the candle carries the
  /// warm ink the design reference prints on it.
  static ThemeData dark(ChildProfile? profile, {Locale? locale}) {
    final language = AppLanguage.fromCode(locale?.languageCode);
    final accent = profile == null ? candle : Color(profile.themeColorValue);
    final secondary = _secondaryForPrimary(accent);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: tile,
        ).copyWith(
          primary: accent,
          onPrimary: accent == candle ? onCandle : null,
          secondary: secondary,
          surface: tile,
          onSurface: light,
          onSurfaceVariant: muted,
          surfaceContainerLowest: night,
          surfaceContainerLow: night,
          surfaceContainer: sunken,
          surfaceContainerHigh: tile,
          surfaceContainerHighest: tile,
          outline: hairline,
          outlineVariant: hairline,
        );
    final theme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: night,
      canvasColor: night,
      dividerColor: hairline,
      useMaterial3: true,
      textTheme: _textTheme(),
      appBarTheme: _appBarTheme(),
      dividerTheme: _dividerTheme(),
      cardTheme: _cardTheme(),
      chipTheme: _chipTheme(accent, language),
      inputDecorationTheme: _inputTheme(accent, language),
      dialogTheme: _dialogTheme(language),
      filledButtonTheme: _buttonTheme(accent, scheme.onPrimary, language),
      textButtonTheme: _textButtonTheme(language),
      outlinedButtonTheme: _outlinedButtonTheme(language),
      navigationBarTheme: _navigationBarTheme(accent, language),
      navigationRailTheme: _navigationRailTheme(accent, language),
      navigationDrawerTheme: _navigationDrawerTheme(accent, language),
    );
    return theme.copyWith(
      textTheme: _interfaceTextTheme(theme.textTheme, language),
      primaryTextTheme: _interfaceTextTheme(theme.primaryTextTheme, language),
    );
  }

  /// Resolves the primary accent for neutral, girl, and boy profile states.
  static Color primaryFor(ChildGender gender) {
    return switch (gender) {
      ChildGender.unspecified => candle,
      ChildGender.girl => girlPink,
      ChildGender.boy => boyCyan,
    };
  }

  /// Resolves the secondary gradient color paired with a profile accent.
  static Color secondaryFor(ChildGender gender) {
    return switch (gender) {
      ChildGender.unspecified => orange,
      ChildGender.girl => girlRose,
      ChildGender.boy => boyBlue,
    };
  }

  /// Produces a softer companion shade for arbitrary parent-selected colors.
  static Color _secondaryForPrimary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withSaturation((hsl.saturation * 0.78).clamp(0.35, 0.86))
        .withLightness((hsl.lightness + 0.16).clamp(0.48, 0.82))
        .toColor();
  }

  /// Puts one style in the interface face without touching its metrics.
  ///
  /// The Latin face is variable and defaults to its thinnest instance, so the
  /// requested weight is pinned on the `wght` axis as well as asked for.
  static TextStyle _interfaceStyle(TextStyle style, AppLanguage language) {
    final weight = style.fontWeight ?? FontWeight.w400;
    return style.copyWith(
      fontFamily: interfaceFontFamilyFor(language),
      fontVariations: language.usesLatinScript
          ? <FontVariation>[FontVariation('wght', weight.value.toDouble())]
          : null,
    );
  }

  /// Builds one interface style from scratch in the family [language] reads.
  static TextStyle _face(
    AppLanguage language, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return _interfaceStyle(
      TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
      language,
    );
  }

  /// Applies the interface face to every slot of a resolved text theme.
  static TextTheme _interfaceTextTheme(TextTheme base, AppLanguage language) {
    TextStyle? faced(TextStyle? style) {
      return style == null ? null : _interfaceStyle(style, language);
    }

    return TextTheme(
      displayLarge: faced(base.displayLarge),
      displayMedium: faced(base.displayMedium),
      displaySmall: faced(base.displaySmall),
      headlineLarge: faced(base.headlineLarge),
      headlineMedium: faced(base.headlineMedium),
      headlineSmall: faced(base.headlineSmall),
      titleLarge: faced(base.titleLarge),
      titleMedium: faced(base.titleMedium),
      titleSmall: faced(base.titleSmall),
      bodyLarge: faced(base.bodyLarge),
      bodyMedium: faced(base.bodyMedium),
      bodySmall: faced(base.bodySmall),
      labelLarge: faced(base.labelLarge),
      labelMedium: faced(base.labelMedium),
      labelSmall: faced(base.labelSmall),
    );
  }

  /// Defines a compact display scale that remains readable on small phones.
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 17, height: 1.55),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5),
    );
  }

  /// Lets the app bar sit on the background instead of on its own surface.
  static AppBarThemeData _appBarTheme() {
    return const AppBarThemeData(
      backgroundColor: night,
      foregroundColor: light,
      iconTheme: IconThemeData(color: frost),
      actionsIconTheme: IconThemeData(color: frost),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  /// Draws every separator as the shared hairline.
  static DividerThemeData _dividerTheme() {
    return const DividerThemeData(color: hairline);
  }

  /// Keeps cards visually consistent without hiding focus or content edges.
  static CardThemeData _cardTheme() {
    return CardThemeData(
      color: tile,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: hairline),
      ),
    );
  }

  /// Rings a chip with the active child's accent once it is selected.
  static ChipThemeData _chipTheme(Color accent, AppLanguage language) {
    return ChipThemeData(
      backgroundColor: sunken,
      selectedColor: accent.withValues(alpha: 0.18),
      checkmarkColor: accent,
      side: WidgetStateBorderSide.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? BorderSide(color: accent)
            : const BorderSide(color: hairline);
      }),
      labelStyle: _face(
        language,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: light,
      ),
      secondaryLabelStyle: _face(
        language,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: light,
      ),
    );
  }

  /// Gives forms a clear, high-contrast surface on all breakpoints.
  static InputDecorationTheme _inputTheme(Color accent, AppLanguage language) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: hairline),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: sunken,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: accent)),
      labelStyle: _face(language, color: muted),
      hintStyle: _face(language, color: mutedDeep),
    );
  }

  /// Gives modal surfaces the same tile treatment as the cards behind them.
  static DialogThemeData _dialogTheme(AppLanguage language) {
    return DialogThemeData(
      backgroundColor: tile,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: hairline),
      ),
      titleTextStyle: _face(
        language,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: light,
      ),
      contentTextStyle: _face(language, fontSize: 15, color: muted),
    );
  }

  /// Styles primary calls to action with the active child's saved accent.
  static FilledButtonThemeData _buttonTheme(
    Color primary,
    Color foreground,
    AppLanguage language,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: foreground,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        textStyle: _face(language, fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Sets link-style actions in warm candle rather than in the child's accent.
  static TextButtonThemeData _textButtonTheme(AppLanguage language) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: candleLight,
        textStyle: _face(language, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Outlines secondary actions with the shared hairline.
  static OutlinedButtonThemeData _outlinedButtonTheme(AppLanguage language) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: light,
        side: const BorderSide(color: hairline),
        textStyle: _face(language, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Highlights the current bottom destination without an opaque bar.
  static NavigationBarThemeData _navigationBarTheme(
    Color accent,
    AppLanguage language,
  ) {
    return NavigationBarThemeData(
      backgroundColor: sunken.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withValues(alpha: 0.18),
      height: 72,
      labelTextStyle: WidgetStateProperty.all(
        _face(language, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : mutedDeep,
        );
      }),
    );
  }

  /// Keeps the desktop rail on the same recessed chrome as the bottom bar.
  static NavigationRailThemeData _navigationRailTheme(
    Color accent,
    AppLanguage language,
  ) {
    return NavigationRailThemeData(
      backgroundColor: sunken,
      indicatorColor: accent.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: const IconThemeData(color: mutedDeep),
      selectedLabelTextStyle: _face(
        language,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: light,
      ),
      unselectedLabelTextStyle: _face(
        language,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
    );
  }

  /// Matches the mobile drawer to the rail it replaces on narrow screens.
  static NavigationDrawerThemeData _navigationDrawerTheme(
    Color accent,
    AppLanguage language,
  ) {
    return NavigationDrawerThemeData(
      backgroundColor: night,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return _face(
          language,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected) ? light : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : mutedDeep,
        );
      }),
    );
  }
}
