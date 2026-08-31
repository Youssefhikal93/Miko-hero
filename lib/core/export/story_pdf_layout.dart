import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Reading direction and every measurement that depends on it.
///
/// Kept apart from the renderer and resolved eagerly rather than left to the
/// PDF package's directional geometry, so an Arabic book's mirroring can be
/// asserted in a test instead of only being visible in the finished file.
class StoryPdfLayout {
  /// Creates the layout of a book written in [language].
  const StoryPdfLayout(this.language);

  /// Language every page of the exported book is written in.
  final AppLanguage language;

  /// Whether the book reads right to left.
  bool get isRtl => language == AppLanguage.arabic;

  /// Text direction handed to every page of the document.
  pw.TextDirection get textDirection =>
      isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  /// Corner the page-number badge sits in: the side reading starts from.
  pw.Alignment get badgeAlignment =>
      isRtl ? pw.Alignment.topRight : pw.Alignment.topLeft;

  /// Side the short accent bar above a prose panel is anchored to.
  pw.Alignment get accentBarAlignment =>
      isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

  /// Padding inside a prose panel, roomier on the edge reading starts from.
  pw.EdgeInsets get prosePanelInsets =>
      pw.EdgeInsets.fromLTRB(isRtl ? 22 : 28, 20, isRtl ? 28 : 22, 24);
}

/// The colours one exported book is printed in.
///
/// Derived from the story's own illustration style, so a watercolor book and a
/// bright animated one do not come out of the printer in the same beige.
class StoryPdfPalette {
  /// Creates a palette from already chosen colours.
  const StoryPdfPalette({
    required this.wash,
    required this.panel,
    required this.accent,
    required this.ink,
    required this.soft,
    required this.onAccent,
  });

  /// Selects the palette matching [style].
  factory StoryPdfPalette.forStyle(IllustrationStyle style) {
    return switch (style) {
      IllustrationStyle.pictureBook => const StoryPdfPalette(
        wash: PdfColor.fromInt(0xFFFDF6EC),
        panel: PdfColor.fromInt(0xFFFFFCF5),
        accent: PdfColor.fromInt(0xFFC9741A),
        ink: PdfColor.fromInt(0xFF3B2E24),
        soft: PdfColor.fromInt(0xFFE7D6BC),
        onAccent: PdfColor.fromInt(0xFFFFFBF4),
      ),
      IllustrationStyle.watercolor => const StoryPdfPalette(
        wash: PdfColor.fromInt(0xFFF0F6FB),
        panel: PdfColor.fromInt(0xFFFBFDFF),
        accent: PdfColor.fromInt(0xFF2A6E93),
        ink: PdfColor.fromInt(0xFF1F3743),
        soft: PdfColor.fromInt(0xFFCADFEC),
        onAccent: PdfColor.fromInt(0xFFF6FBFF),
      ),
      IllustrationStyle.colorful3d => const StoryPdfPalette(
        wash: PdfColor.fromInt(0xFFF5F2FE),
        panel: PdfColor.fromInt(0xFFFDFCFF),
        accent: PdfColor.fromInt(0xFF61439B),
        ink: PdfColor.fromInt(0xFF2A2340),
        soft: PdfColor.fromInt(0xFFDBD1F2),
        onAccent: PdfColor.fromInt(0xFFFBF9FF),
      ),
    };
  }

  /// Faint tint filling a whole sheet.
  final PdfColor wash;

  /// Slightly lighter surface a prose panel or a card is drawn on.
  final PdfColor panel;

  /// Saturated colour of badges, rules and the accent edge.
  final PdfColor accent;

  /// Colour every readable line of text is printed in.
  final PdfColor ink;

  /// Quiet colour of thin borders and separators.
  final PdfColor soft;

  /// Colour of text printed on top of [accent].
  final PdfColor onAccent;
}
