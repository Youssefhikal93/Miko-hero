import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/export/story_pdf_layout.dart';
import 'package:miko_hero/core/export/story_pdf_symbols.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _brandName = 'Iam - hero';
const _bodyLatinAsset = 'assets/fonts/NotoSans-Regular.ttf';
const _bodyArabicAsset = 'assets/fonts/NotoNaskhArabic-Regular.ttf';
const _displayLatinAsset = 'assets/fonts/Baloo2-Variable.ttf';
const _displayArabicAsset = 'assets/fonts/Amiri-Bold.ttf';

/// Framed size of the optional cover portrait.
const _coverPhotoSize = 128.0;

/// Corner radius of every framed picture and panel in the book.
const _corner = 20.0;

/// Printed size of the child's kingdom symbol on the dedication page.
const _symbolSize = 30.0;

/// Share of a story page an illustration may occupy.
///
/// Roughly the top two thirds: enough that the picture leads the page the way
/// a picture book's does, while leaving the prose panel below it whole.
const _illustrationHeightShare = 0.62;

/// Tallest a cover picture prints, with and without the optional portrait.
const _coverPictureHeight = 400.0;
const _coverPictureHeightWithPhoto = 300.0;

/// Builds printable storybooks locally without uploading family content.
class StoryPdfService {
  /// Creates a PDF builder using Flutter's bundled asset loader.
  StoryPdfService({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  /// Renders one approved story as an A4 picture book.
  ///
  /// The finished document is a cover, a dedication page, one sheet per story
  /// page, and a back cover. Everything is rendered on device from bundled
  /// fonts and the pictures this device already holds; nothing is uploaded and
  /// no network font is fetched.
  ///
  /// The book's own words — the dedication, the page badges, the closing
  /// lines — are printed in the **story's** language rather than the parent's
  /// interface language, because the book belongs to the child who reads it.
  ///
  /// [coverPhotoBase64] places the child's reference photo on the cover only,
  /// and only when the parent asked for it at export time. Unreadable bytes
  /// fall back to the photo-free cover instead of failing the export. Inner
  /// pages never contain the photo.
  ///
  /// [illustrationBytesById] carries the page images this device already
  /// downloaded, keyed by the master-library illustration identity each bridge
  /// page names in its provenance. A page is illustrated exactly when its
  /// identity is present and its bytes decode; anything else — a demo story
  /// with no identities at all, a picture this device never fetched, or bytes
  /// that no decoder recognizes — prints as a text-focused page instead of
  /// leaving a hole. Illustrations are story content, so unlike the photo they
  /// need no per-export permission.
  ///
  /// [kingdomSymbol] is the child's chosen favourite badge, drawn on the
  /// dedication page. It is a decoration choice rather than private
  /// information; absent simply means no badge is drawn.
  Future<Uint8List> build(
    StoryBook story, {
    String? coverPhotoBase64,
    Map<String, Uint8List> illustrationBytesById = const <String, Uint8List>{},
    KingdomSymbol? kingdomSymbol,
  }) async {
    final language = story.content.request.presentation.language;
    final fonts = await _loadFonts(language);
    final text = await AppLocalizations.delegate.load(language.locale);
    final book = _Book(
      story: story,
      fonts: fonts,
      text: text,
      layout: StoryPdfLayout(language),
      palette: StoryPdfPalette.forStyle(
        story.content.request.presentation.style,
      ),
      kingdomSymbol: kingdomSymbol,
    );
    final illustrations = <int, pw.MemoryImage>{
      for (final page in story.content.pages)
        page.number: ?_illustration(page, illustrationBytesById),
    };

    final document = _document(book);
    _addCover(document, book, _coverPhoto(coverPhotoBase64), illustrations);
    _addDedication(document, book);
    for (final page in story.content.pages) {
      _addStoryPage(document, book, page, illustrations[page.number]);
    }
    _addBackCover(document, book);
    return document.save();
  }

  /// Decodes the optional cover photo, treating invalid bytes as absent.
  pw.MemoryImage? _coverPhoto(String? coverPhotoBase64) {
    final encodedPhoto = coverPhotoBase64;
    if (encodedPhoto == null || encodedPhoto.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(encodedPhoto));
    } on Exception {
      return null;
    }
  }

  /// Decodes one page's downloaded picture, treating bad bytes as absent.
  ///
  /// Mirrors the cover photo's failure semantics: a picture that cannot be
  /// decoded, or that reports no usable pixel size, costs the family one
  /// text-focused page rather than the whole export.
  pw.MemoryImage? _illustration(
    StoryPage page,
    Map<String, Uint8List> illustrationBytesById,
  ) {
    if (illustrationBytesById.isEmpty) return null;
    final provenance = BridgeStoryProvenance.fromSceneDescription(
      page.sceneDescription,
    );
    if (provenance == null) return null;
    final bytes = illustrationBytesById[provenance.illustrationId];
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final illustration = pw.MemoryImage(bytes);
      final width = illustration.width ?? 0;
      final height = illustration.height ?? 0;
      return width > 0 && height > 0 ? illustration : null;
    } on Exception {
      return null;
    }
  }

  /// Loads the body pair plus the one display face this language needs.
  ///
  /// Loads sequentially: concurrent [AssetBundle.load] calls combined with
  /// `Future.wait` resolve to an empty list under the Flutter test binding.
  Future<_StoryPdfFonts> _loadFonts(AppLanguage language) async {
    final bodyLatin = await _assetBundle.load(_bodyLatinAsset);
    final bodyArabic = await _assetBundle.load(_bodyArabicAsset);
    final isArabic = language == AppLanguage.arabic;
    final display = await _assetBundle.load(
      isArabic ? _displayArabicAsset : _displayLatinAsset,
    );
    return _StoryPdfFonts(
      bodyLatin: pw.Font.ttf(bodyLatin),
      bodyArabic: pw.Font.ttf(bodyArabic),
      display: pw.Font.ttf(display),
      isArabic: isArabic,
    );
  }

  /// Creates document metadata and a font theme appropriate for the story.
  pw.Document _document(_Book book) {
    return pw.Document(
      title: book.story.content.title,
      author: _brandName,
      creator: _brandName,
      theme: pw.ThemeData.withFont(
        base: book.fonts.body,
        bold: book.fonts.body,
        fontFallback: <pw.Font>[book.fonts.bodyFallback, book.fonts.display],
      ),
    );
  }

  /// The page theme every sheet of the book shares.
  pw.PageTheme _pageTheme(_Book book, {required pw.EdgeInsets margin}) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
      textDirection: book.layout.textDirection,
      buildBackground: (_) => pw.Container(color: book.palette.wash),
    );
  }

  /// Adds the cover: the story's own first picture, its title, and the hero.
  ///
  /// The bridge does not mark one illustration as the cover, so the first
  /// drawn page is the cover picture — which is also the opening scene, and
  /// therefore the right one.
  void _addCover(
    pw.Document document,
    _Book book,
    pw.MemoryImage? coverPhoto,
    Map<int, pw.MemoryImage> illustrations,
  ) {
    final cover = illustrations.isEmpty
        ? null
        : illustrations[book.story.content.pages.first.number] ??
              illustrations.values.first;
    document.addPage(
      pw.Page(
        pageTheme: _pageTheme(
          book,
          margin: const pw.EdgeInsets.fromLTRB(46, 42, 46, 38),
        ),
        build: (_) => _cover(book, cover, coverPhoto),
      ),
    );
  }

  /// Composes the cover, including the portrait only when it was supplied.
  pw.Widget _cover(
    _Book book,
    pw.MemoryImage? cover,
    pw.MemoryImage? coverPhoto,
  ) {
    final pictureHeight = coverPhoto == null
        ? _coverPictureHeight
        : _coverPictureHeightWithPhoto;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        _brandMark(book),
        pw.SizedBox(height: 24),
        if (cover != null)
          _framedPicture(book, cover, height: pictureHeight)
        else
          _coverOrnament(book, height: pictureHeight),
        pw.SizedBox(height: 30),
        pw.Text(
          book.story.content.title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: book.fonts.display,
            fontFallback: book.fonts.fallbacks,
            fontSize: 32,
            color: book.palette.ink,
            lineSpacing: 3,
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          book.text.pdfForHero(book.story.content.request.heroName),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 15, color: book.palette.accent),
        ),
        if (coverPhoto != null) ...<pw.Widget>[
          pw.SizedBox(height: 22),
          pw.Container(
            width: _coverPhotoSize,
            height: _coverPhotoSize,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(_corner),
              border: pw.Border.all(color: book.palette.accent, width: 3),
              image: pw.DecorationImage(image: coverPhoto),
            ),
          ),
        ],
      ],
    );
  }

  /// Adds the dedication page that names the book's owner.
  void _addDedication(pw.Document document, _Book book) {
    document.addPage(
      pw.Page(
        pageTheme: _pageTheme(
          book,
          margin: const pw.EdgeInsets.fromLTRB(58, 90, 58, 70),
        ),
        build: (_) => pw.Center(child: _dedication(book)),
      ),
    );
  }

  /// Composes the dedication card: badge, owner, moral, and creation date.
  pw.Widget _dedication(_Book book) {
    final symbol = book.kingdomSymbol;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 40),
      decoration: pw.BoxDecoration(
        color: book.palette.panel,
        borderRadius: pw.BorderRadius.circular(_corner + 6),
        border: pw.Border.all(color: book.palette.soft, width: 1),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          if (symbol != null) ...<pw.Widget>[
            pw.CustomPaint(
              size: const PdfPoint(_symbolSize, _symbolSize),
              painter: (canvas, size) => paintKingdomSymbol(
                canvas,
                size,
                symbol,
                color: book.palette.accent,
                background: book.palette.panel,
              ),
            ),
            pw.SizedBox(height: 22),
          ],
          pw.Text(
            book.text.pdfBelongsTo(book.story.content.request.heroName),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: book.fonts.display,
              fontFallback: book.fonts.fallbacks,
              fontSize: 22,
              color: book.palette.ink,
              lineSpacing: 3,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: 70,
            height: 3,
            decoration: pw.BoxDecoration(
              color: book.palette.accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            book.story.content.request.moral,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 13,
              color: book.palette.accent,
              lineSpacing: 5,
            ),
          ),
          pw.SizedBox(height: 26),
          pw.Text(
            book.text.pdfMadeOn(book.createdOn),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, color: book.palette.ink),
          ),
        ],
      ),
    );
  }

  /// Adds one story page: picture above, prose in a soft panel below.
  ///
  /// Still a [pw.MultiPage], so prose longer than one sheet continues rather
  /// than being clipped — a demo story's pages can be much longer than the two
  /// to four sentences the local model is asked for.
  void _addStoryPage(
    pw.Document document,
    _Book book,
    StoryPage page,
    pw.MemoryImage? illustration,
  ) {
    document.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(
          book,
          margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
        ),
        header: (_) => _pageBadge(book, page),
        footer: (context) => _footer(book, context),
        build: (_) => <pw.Widget>[
          if (illustration != null) ...<pw.Widget>[
            _framedPicture(
              book,
              illustration,
              height: _storyPictureHeight(illustration),
            ),
            pw.SizedBox(height: 22),
          ],
          _prosePanel(book, page, illustrated: illustration != null),
        ],
      ),
    );
  }

  /// Height one page picture prints at, capped to leave the prose its panel.
  double _storyPictureHeight(pw.MemoryImage illustration) {
    final width = PdfPageFormat.a4.width - 80;
    final pixelWidth = (illustration.width ?? 1).toDouble();
    final pixelHeight = (illustration.height ?? 1).toDouble();
    final natural = width * pixelHeight / pixelWidth;
    final cap = (PdfPageFormat.a4.height - 88) * _illustrationHeightShare;
    return math.min(natural, cap);
  }

  /// The page-number badge, in the corner reading starts from.
  pw.Widget _pageBadge(_Book book, StoryPage page) {
    return pw.Container(
      alignment: book.layout.badgeAlignment,
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: pw.BoxDecoration(
          color: book.palette.accent,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Text(
          book.text.pdfPageBadge(page.number, book.story.content.pages.length),
          style: pw.TextStyle(
            font: book.fonts.display,
            fontFallback: book.fonts.fallbacks,
            fontSize: 11,
            color: book.palette.onAccent,
          ),
        ),
      ),
    );
  }

  /// The prose panel: generous line spacing on a soft rounded surface.
  ///
  /// The short accent bar above the prose and the roomier inner edge both sit
  /// on the side reading starts from, so an Arabic panel is the mirror image of
  /// an English one rather than the same panel with mirrored text in it.
  ///
  /// A page with no picture is not a page with a hole: it gets the story's
  /// title above the prose, so the sheet still reads as a designed page of a
  /// book rather than as a paragraph adrift on A4.
  pw.Widget _prosePanel(
    _Book book,
    StoryPage page, {
    required bool illustrated,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: book.layout.prosePanelInsets,
      decoration: pw.BoxDecoration(
        color: book.palette.panel,
        borderRadius: pw.BorderRadius.circular(_corner),
        border: pw.Border.all(color: book.palette.soft, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          if (!illustrated) ...<pw.Widget>[
            pw.Container(
              alignment: book.layout.accentBarAlignment,
              child: pw.Text(
                book.story.content.title,
                style: pw.TextStyle(
                  font: book.fonts.display,
                  fontFallback: book.fonts.fallbacks,
                  fontSize: 19,
                  color: book.palette.ink,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Container(
            alignment: book.layout.accentBarAlignment,
            child: pw.Container(
              width: 48,
              height: 3,
              decoration: pw.BoxDecoration(
                color: book.palette.accent,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            page.text,
            textAlign: pw.TextAlign.start,
            style: pw.TextStyle(
              fontSize: 15.5,
              lineSpacing: 8,
              color: book.palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// Adds the closing sheet: the lesson, the app mark, and nothing private.
  void _addBackCover(pw.Document document, _Book book) {
    document.addPage(
      pw.Page(
        pageTheme: _pageTheme(
          book,
          margin: const pw.EdgeInsets.fromLTRB(58, 96, 58, 60),
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            pw.Text(
              book.text.pdfTheEnd,
              style: pw.TextStyle(
                font: book.fonts.display,
                fontFallback: book.fonts.fallbacks,
                fontSize: 30,
                color: book.palette.ink,
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 32,
              ),
              decoration: pw.BoxDecoration(
                color: book.palette.panel,
                borderRadius: pw.BorderRadius.circular(_corner + 6),
                border: pw.Border.all(color: book.palette.soft, width: 1),
              ),
              child: pw.Column(
                children: <pw.Widget>[
                  pw.Text(
                    book.text.pdfMoralHeading,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: book.fonts.display,
                      fontFallback: book.fonts.fallbacks,
                      fontSize: 15,
                      color: book.palette.accent,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    book.story.content.request.moral,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 14,
                      lineSpacing: 6,
                      color: book.palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 46),
            _brandMark(book),
          ],
        ),
      ),
    );
  }

  /// One picture in a rounded frame with a quiet border.
  pw.Widget _framedPicture(
    _Book book,
    pw.MemoryImage picture, {
    required double height,
  }) {
    return pw.Container(
      width: double.infinity,
      height: height,
      decoration: pw.BoxDecoration(
        color: book.palette.panel,
        borderRadius: pw.BorderRadius.circular(_corner),
        border: pw.Border.all(color: book.palette.soft, width: 1.5),
        image: pw.DecorationImage(image: picture),
      ),
    );
  }

  /// A quiet drawn panel standing in for a cover picture the family has none of.
  pw.Widget _coverOrnament(_Book book, {required double height}) {
    return pw.Container(
      width: double.infinity,
      height: height,
      decoration: pw.BoxDecoration(
        color: book.palette.panel,
        borderRadius: pw.BorderRadius.circular(_corner),
        border: pw.Border.all(color: book.palette.soft, width: 1.5),
      ),
      child: pw.Center(
        child: pw.CustomPaint(
          size: const PdfPoint(120, 120),
          painter: (canvas, size) => paintKingdomSymbol(
            canvas,
            size,
            book.kingdomSymbol ?? KingdomSymbol.sparkles,
            color: book.palette.soft,
            background: book.palette.panel,
          ),
        ),
      ),
    );
  }

  /// The small app mark, printed without any child information.
  pw.Widget _brandMark(_Book book) {
    return pw.Text(
      _brandName,
      style: pw.TextStyle(
        font: book.fonts.display,
        fontFallback: book.fonts.fallbacks,
        fontSize: 12,
        color: book.palette.accent,
      ),
    );
  }

  /// Marks generated sheets without adding child profile information.
  pw.Widget _footer(_Book book, pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 14),
      child: pw.Text(
        '$_brandName  •  ${context.pageNumber}',
        style: pw.TextStyle(fontSize: 9, color: book.palette.accent),
      ),
    );
  }
}

/// Everything one render of one book needs, resolved once.
class _Book {
  _Book({
    required this.story,
    required this.fonts,
    required this.text,
    required this.layout,
    required this.palette,
    required this.kingdomSymbol,
  });

  final StoryBook story;
  final _StoryPdfFonts fonts;
  final AppLocalizations text;
  final StoryPdfLayout layout;
  final StoryPdfPalette palette;
  final KingdomSymbol? kingdomSymbol;

  /// The story's creation day, written the way the story's language writes it.
  ///
  /// The month-name tables are loaded here rather than relied on: a PDF can be
  /// exported without any Flutter localization delegate having run, and `intl`
  /// throws instead of guessing. A language `intl` has no calendar for — Somali
  /// on some versions — falls back to English month names rather than to no
  /// date at all.
  String get createdOn {
    _ensureDateFormatting();
    final code = layout.language.code;
    return DateFormat.yMMMMd(
      DateFormat.localeExists(code) ? code : 'en',
    ).format(story.createdAt.toLocal());
  }
}

/// Whether `intl`'s per-locale calendar data has already been loaded.
bool _dateFormattingLoaded = false;

/// Loads `intl`'s calendar data once per process.
void _ensureDateFormatting() {
  if (_dateFormattingLoaded) return;
  initializeDateFormatting();
  _dateFormattingLoaded = true;
}

/// Fonts loaded once for a single local PDF build operation.
class _StoryPdfFonts {
  const _StoryPdfFonts({
    required this.bodyLatin,
    required this.bodyArabic,
    required this.display,
    required this.isArabic,
  });

  final pw.Font bodyLatin;
  final pw.Font bodyArabic;
  final pw.Font display;
  final bool isArabic;

  /// Body face of the story's own script.
  pw.Font get body => isArabic ? bodyArabic : bodyLatin;

  /// Body face of the other script, kept as a fallback.
  pw.Font get bodyFallback => isArabic ? bodyLatin : bodyArabic;

  /// Fallbacks for display text, so a title never prints a blank box.
  List<pw.Font> get fallbacks => <pw.Font>[body, bodyFallback];
}
