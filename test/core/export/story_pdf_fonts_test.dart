import 'package:bidi/bidi.dart' as bidi;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:pdf/pdf.dart';

/// Proves the bundled display faces really cover the text an export prints.
///
/// Rendering a valid PDF is not enough: a missing glyph produces a valid file
/// with a blank where a letter should be, which is exactly the failure that
/// shipped fonts hide. So the fonts are opened and their character maps are
/// asked directly, for every string the book actually sets in a display face.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const displayLatin = 'assets/fonts/Baloo2-Variable.ttf';
  const displayArabic = 'assets/fonts/Amiri-Bold.ttf';
  const bodyLatin = 'assets/fonts/NotoSans-Regular.ttf';
  const bodyArabic = 'assets/fonts/NotoNaskhArabic-Regular.ttf';

  /// Every kind of string the export sets in the display face, per language.
  ///
  /// Titles, the dedication line, the page badge, the closing line, the app
  /// mark, and the moral heading — with the awkward characters of each
  /// language deliberately present.
  const displayStrings = <AppLanguage, List<String>>{
    AppLanguage.english: <String>[
      'Iam - hero',
      'Miko and the Kind Dragon',
      'This book belongs to Miko',
      'Page 3 of 6',
      'The heart of this story',
      'The End',
      'for Miko',
    ],
    AppLanguage.swedish: <String>[
      'Iam - hero',
      'Miko och den vänliga draken över ängen',
      'Den här boken tillhör Åsa-Märta Öberg',
      'Sida 3 av 6',
      'Berättelsens hjärta',
      'Slut',
      'till Åsa',
    ],
    AppLanguage.somali: <String>[
      'Iam - hero',
      'Miko iyo masduulaagii naxariista leh',
      'Buuggan waxaa iska leh Nuur',
      'Bogga 3 ee 6',
      'Wadnaha sheekadan',
      'Dhammaad',
      'loogu talagalay Nuur',
    ],
    AppLanguage.arabic: <String>[
      'ميكو والتنين اللطيف',
      'هذا الكتاب يخص ميكو',
      'صفحة ٣ من ٦',
      'صفحة 3 من 6',
      'قلب هذه القصة',
      'النهاية',
      'إلى ميكو',
      'الذي يشارك النور يكبر نوره، وفي البيت فرح.',
    ],
  };

  /// Loads one bundled font and returns its parsed character map.
  Future<Set<int>> coveredRunes(String asset) async {
    final data = await rootBundle.load(asset);
    return TtfParser(data).charToGlyphIndexMap.keys.toSet();
  }

  /// Shapes [input] exactly the way the `pdf` package does before drawing.
  ///
  /// A copy of `bidi_utils.logicalToVisual`, which the `pdf` package keeps
  /// private: Arabic letters become Presentation Forms-B code points, and it is
  /// those code points the font is looked up by.
  String visualOrder(String input) {
    final buffer = StringBuffer();
    for (final paragraph in bidi.BidiString.fromLogical(input).paragraphs) {
      final endsWithNewLine = paragraph.separator == 10;
      final endIndex = paragraph.bidiText.length - (endsWithNewLine ? 1 : 0);
      final visual = String.fromCharCodes(paragraph.bidiText, 0, endIndex);
      buffer.write(visual.split(' ').reversed.join(' '));
      if (endsWithNewLine) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Code points of [strings] that none of [fonts] can draw.
  Set<int> uncovered(List<String> strings, List<Set<int>> fonts) {
    final missing = <int>{};
    for (final string in strings) {
      for (final rune in visualOrder(string).runes) {
        if (rune == 0x20 || rune == 0x0A) continue;
        if (fonts.any((font) => font.contains(rune))) continue;
        missing.add(rune);
      }
    }
    return missing;
  }

  /// Renders the uncovered set as readable `U+XXXX` names for a failure.
  String describe(Set<int> runes) {
    return runes
        .map((rune) => 'U+${rune.toRadixString(16).toUpperCase()}')
        .join(' ');
  }

  test(
    'the Latin display face covers every string it is asked to set',
    () async {
      final display = await coveredRunes(displayLatin);
      for (final language in <AppLanguage>[
        AppLanguage.english,
        AppLanguage.swedish,
        AppLanguage.somali,
      ]) {
        final missing = uncovered(displayStrings[language]!, <Set<int>>[
          display,
        ]);
        expect(
          missing,
          isEmpty,
          reason:
              'Baloo 2 cannot draw ${describe(missing)} for ${language.code}; '
              'the export would print blanks',
        );
      }
    },
  );

  test('the Latin display face covers Swedish å, ä and ö', () async {
    final display = await coveredRunes(displayLatin);

    for (final letter in 'åäöÅÄÖ'.runes) {
      expect(
        display,
        contains(letter),
        reason: 'missing U+${letter.toRadixString(16).toUpperCase()}',
      );
    }
  });

  test('the Arabic display face covers every shaped Arabic string', () async {
    final display = await coveredRunes(displayArabic);

    final missing = uncovered(displayStrings[AppLanguage.arabic]!, <Set<int>>[
      display,
    ]);

    expect(
      missing,
      isEmpty,
      reason:
          'Amiri Bold cannot draw ${describe(missing)}; Arabic titles would '
          'print blanks or fall back to the body face',
    );
  });

  test('the body faces still cover the prose of all four languages', () async {
    final latin = await coveredRunes(bodyLatin);
    final arabic = await coveredRunes(bodyArabic);
    final fonts = <Set<int>>[latin, arabic];

    const prose = <String>[
      'Miko found a kind and curious dragon.',
      'Miko följde stjärnorna över den gröna ängen — åter och åter.',
      'Miko wuxuu saaxiibbadii la wadaagay xiddigaha.',
      'وجد ميكو تنيناً لطيفاً وساعد أصدقاءه بشجاعة.',
      'الذي يشارك النور يكبر نوره، وفي البيت فرح.',
    ];

    expect(uncovered(prose, fonts), isEmpty);
  });

  test('every bundled font parses as a usable TrueType file', () async {
    for (final asset in <String>[
      displayLatin,
      displayArabic,
      bodyLatin,
      bodyArabic,
    ]) {
      final data = await rootBundle.load(asset);
      final parser = TtfParser(data);

      expect(parser.unitsPerEm, greaterThan(0), reason: asset);
      expect(parser.charToGlyphIndexMap, isNotEmpty, reason: asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
      expect(
        Uint8List.sublistView(data.buffer.asUint8List(), 0, 4),
        isNotEmpty,
        reason: asset,
      );
    }
  });
}
