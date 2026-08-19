import 'package:flutter/services.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _brandName = 'Iam - hero';
const _sansAsset = 'assets/fonts/NotoSans-Regular.ttf';
const _arabicAsset = 'assets/fonts/NotoNaskhArabic-Regular.ttf';

/// Builds printable storybooks locally without uploading family content.
class StoryPdfService {
  /// Creates a PDF builder using Flutter's bundled asset loader.
  StoryPdfService({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  /// Renders one approved story as a multilingual A4 PDF byte sequence.
  Future<Uint8List> build(StoryBook story) async {
    final fonts = await _loadFonts();
    final document = _document(story, fonts);
    _addCover(document, story, fonts);
    for (final page in story.content.pages) {
      _addStoryPage(document, story, page, fonts);
    }
    return document.save();
  }

  /// Loads both embedded font files needed by all supported story languages.
  ///
  /// Loads sequentially: concurrent [AssetBundle.load] calls combined with
  /// `Future.wait` resolve to an empty list under the Flutter test binding.
  Future<_StoryPdfFonts> _loadFonts() async {
    final sans = await _assetBundle.load(_sansAsset);
    final arabic = await _assetBundle.load(_arabicAsset);
    return _StoryPdfFonts(sans: pw.Font.ttf(sans), arabic: pw.Font.ttf(arabic));
  }

  /// Creates document metadata and a font theme appropriate for the story.
  pw.Document _document(StoryBook story, _StoryPdfFonts fonts) {
    return pw.Document(
      title: story.content.title,
      author: _brandName,
      creator: _brandName,
      theme: _theme(story.content.request.presentation.language, fonts),
    );
  }

  /// Selects the primary script font while retaining the other as fallback.
  pw.ThemeData _theme(AppLanguage language, _StoryPdfFonts fonts) {
    final isArabic = language == AppLanguage.arabic;
    final primary = isArabic ? fonts.arabic : fonts.sans;
    final fallback = isArabic ? fonts.sans : fonts.arabic;
    return pw.ThemeData.withFont(
      base: primary,
      bold: primary,
      fontFallback: <pw.Font>[fallback],
    );
  }

  /// Adds a clean cover that identifies the saved title and selected hero.
  void _addCover(pw.Document document, StoryBook story, _StoryPdfFonts fonts) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: _direction(story),
        build: (_) => _cover(story, fonts),
      ),
    );
  }

  /// Creates the cover composition without including the private child photo.
  pw.Widget _cover(StoryBook story, _StoryPdfFonts fonts) {
    return pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: <pw.Widget>[
          pw.Text(_brandName, style: pw.TextStyle(font: fonts.sans)),
          pw.SizedBox(height: 36),
          pw.Text(story.content.title, style: const pw.TextStyle(fontSize: 30)),
          pw.SizedBox(height: 18),
          pw.Text(story.content.request.heroName),
        ],
      ),
    );
  }

  /// Adds one semantic story page and lets long prose continue safely.
  void _addStoryPage(
    pw.Document document,
    StoryBook story,
    StoryPage page,
    _StoryPdfFonts fonts,
  ) {
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: _direction(story),
        header: (_) => _pageHeader(story, page),
        footer: (context) => _footer(context, fonts),
        build: (_) => <pw.Widget>[_pageText(page)],
      ),
    );
  }

  /// Shows story position without depending on the interface language.
  pw.Widget _pageHeader(StoryBook story, StoryPage page) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Text(story.content.title, style: const pw.TextStyle(fontSize: 16)),
        pw.Text('${page.number} / ${story.content.pages.length}'),
        pw.Divider(),
        pw.SizedBox(height: 18),
      ],
    );
  }

  /// Formats page prose with comfortable print line spacing.
  pw.Widget _pageText(StoryPage page) {
    return pw.Text(
      page.text,
      style: const pw.TextStyle(fontSize: 18, lineSpacing: 8),
      textAlign: pw.TextAlign.start,
    );
  }

  /// Marks generated sheets without adding child profile information.
  pw.Widget _footer(pw.Context context, _StoryPdfFonts fonts) {
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        '$_brandName  •  ${context.pageNumber}',
        style: pw.TextStyle(font: fonts.sans, fontSize: 9),
      ),
    );
  }

  /// Mirrors Arabic pages while leaving other supported languages left-to-right.
  pw.TextDirection _direction(StoryBook story) {
    return story.content.request.presentation.language == AppLanguage.arabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }
}

/// Font pair loaded once for a single local PDF build operation.
class _StoryPdfFonts {
  /// Groups Latin-script and Arabic-script fonts for theme selection.
  const _StoryPdfFonts({required this.sans, required this.arabic});

  final pw.Font sans;
  final pw.Font arabic;
}
