import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/export/story_pdf_layout.dart';
import 'package:miko_hero/core/export/story_pdf_service.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:pdf/widgets.dart' as pw;

/// Exercises real bundled fonts and the real PDF renderer for each script.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final examples = <AppLanguage, String>{
    AppLanguage.english: 'Miko found a kind and curious dragon.',
    AppLanguage.swedish: 'Miko följde stjärnorna över den gröna ängen.',
    AppLanguage.somali: 'Miko wuxuu saaxiibbadii la wadaagay xiddigaha.',
    AppLanguage.arabic: 'وجد ميكو تنيناً لطيفاً وساعد أصدقاءه بشجاعة.',
  };

  for (final example in examples.entries) {
    test('builds a readable ${example.key.code} PDF offline', () async {
      final bytes = await StoryPdfService().build(
        _story(example.key, example.value),
      );

      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
      expect(_pageCount(bytes), greaterThanOrEqualTo(4));
    });
  }

  test(
    'a book is a cover, a dedication, its pages, and a back cover',
    () async {
      final story = _illustratedStory(AppLanguage.english);

      final bytes = await StoryPdfService().build(story);

      expect(
        _pageCount(bytes),
        story.content.pages.length + 3,
        reason: 'cover, dedication, one sheet per page, back cover',
      );
    },
  );

  test('the chosen cover photo is embedded in a valid PDF', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final withPhoto = await StoryPdfService().build(
      story,
      coverPhotoBase64: _transparentPixel,
    );
    final withoutPhoto = await StoryPdfService().build(story);

    expect(ascii.decode(withPhoto.take(4).toList()), '%PDF');
    expect(ascii.decode(withoutPhoto.take(4).toList()), '%PDF');
    expect(withPhoto.length, greaterThan(withoutPhoto.length));
    expect(
      _pageCount(withPhoto),
      _pageCount(withoutPhoto),
      reason: 'the photo joins the cover; it never adds a sheet',
    );
  });

  test('an unreadable photo falls back to the photo-free cover', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final broken = await StoryPdfService().build(
      story,
      coverPhotoBase64: 'not-base64-at-all',
    );
    final withoutPhoto = await StoryPdfService().build(story);

    expect(ascii.decode(broken.take(4).toList()), '%PDF');
    expect(broken.length, withoutPhoto.length);
  });

  for (final language in <AppLanguage>[
    AppLanguage.english,
    AppLanguage.arabic,
  ]) {
    test('drawn ${language.code} pages carry their picture', () async {
      final story = _illustratedStory(language);

      final illustrated = await StoryPdfService().build(
        story,
        illustrationBytesById: <String, Uint8List>{
          'illustration-1': base64Decode(_transparentPixel),
          'illustration-2': base64Decode(_transparentPixel),
        },
      );
      final textOnly = await StoryPdfService().build(story);

      expect(ascii.decode(illustrated.take(4).toList()), '%PDF');
      expect(illustrated.length, greaterThan(textOnly.length));
      expect(
        _pageCount(illustrated),
        _pageCount(textOnly),
        reason: 'pictures fill their own page, they never add sheets',
      );
    });
  }

  test('the first drawn page becomes the cover picture', () async {
    final story = _illustratedStory(AppLanguage.english);
    final pictures = <String, Uint8List>{
      'illustration-1': base64Decode(_transparentPixel),
      'illustration-2': base64Decode(_transparentPixel),
    };

    final withCover = await StoryPdfService().build(
      story,
      illustrationBytesById: pictures,
    );
    final withoutFirstPicture = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-2': pictures['illustration-2']!,
      },
    );

    expect(ascii.decode(withCover.take(4).toList()), '%PDF');
    expect(withCover.length, greaterThan(withoutFirstPicture.length));
  });

  test('a page whose picture is missing stays text-focused', () async {
    final story = _illustratedStory(AppLanguage.english);

    final partial = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
      },
    );
    final everyPage = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
        'illustration-2': base64Decode(_transparentPixel),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(ascii.decode(partial.take(4).toList()), '%PDF');
    expect(partial.length, greaterThan(textOnly.length));
    expect(partial.length, lessThan(everyPage.length));
    expect(_pageCount(partial), _pageCount(everyPage));
  });

  test('undecodable page bytes fall back to the text-focused page', () async {
    final story = _illustratedStory(AppLanguage.english);

    final broken = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': Uint8List.fromList(ascii.encode('not-an-image')),
        'illustration-2': Uint8List(0),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(ascii.decode(broken.take(4).toList()), '%PDF');
    expect(broken.length, textOnly.length);
  });

  test('a demo story ignores bytes it has no identity for', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final withBytes = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(withBytes.length, textOnly.length);
  });

  test('a story with no pictures at all still renders every sheet', () async {
    for (final language in AppLanguage.values) {
      final story = _story(language, examples[language]!);

      final bytes = await StoryPdfService().build(story);

      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(
        _pageCount(bytes),
        story.content.pages.length + 3,
        reason: '${language.code} lost a sheet without pictures',
      );
    }
  });

  test('pictures leave the cover photo choice untouched', () async {
    final story = _illustratedStory(AppLanguage.english);
    final pictures = <String, Uint8List>{
      'illustration-1': base64Decode(_transparentPixel),
      'illustration-2': base64Decode(_transparentPixel),
    };

    final withoutPhoto = await StoryPdfService().build(
      story,
      illustrationBytesById: pictures,
    );
    final withPhoto = await StoryPdfService().build(
      story,
      coverPhotoBase64: _transparentPixel,
      illustrationBytesById: pictures,
    );

    expect(withPhoto.length, greaterThan(withoutPhoto.length));
  });

  test('every kingdom symbol draws on the dedication page', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');
    final withoutSymbol = await StoryPdfService().build(story);

    for (final symbol in KingdomSymbol.values) {
      final bytes = await StoryPdfService().build(story, kingdomSymbol: symbol);

      expect(
        ascii.decode(bytes.take(4).toList()),
        '%PDF',
        reason: '${symbol.name} broke the export',
      );
      expect(
        bytes.length,
        greaterThan(withoutSymbol.length),
        reason: '${symbol.name} drew nothing',
      );
      expect(_pageCount(bytes), _pageCount(withoutSymbol));
    }
  });

  test('an Arabic dedication draws its badge too', () async {
    final story = _story(AppLanguage.arabic, examples[AppLanguage.arabic]!);

    final bytes = await StoryPdfService().build(
      story,
      kingdomSymbol: KingdomSymbol.crown,
    );

    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(_pageCount(bytes), story.content.pages.length + 3);
  });

  for (final style in IllustrationStyle.values) {
    test('a ${style.name} book renders in its own palette', () async {
      final story = _story(
        AppLanguage.english,
        'Miko waved at the moon.',
        style: style,
      );

      final bytes = await StoryPdfService().build(story);

      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(_pageCount(bytes), story.content.pages.length + 3);
    });
  }

  test('the three styles do not share one palette', () {
    final palettes = IllustrationStyle.values
        .map(StoryPdfPalette.forStyle)
        .toList();
    final washes = palettes.map((palette) => palette.wash.toHex()).toSet();
    final accents = palettes.map((palette) => palette.accent.toHex()).toSet();

    expect(washes, hasLength(IllustrationStyle.values.length));
    expect(accents, hasLength(IllustrationStyle.values.length));
  });

  group('right-to-left mirroring', () {
    test('Arabic reads right to left and the others do not', () {
      expect(const StoryPdfLayout(AppLanguage.arabic).isRtl, isTrue);
      expect(
        const StoryPdfLayout(AppLanguage.arabic).textDirection,
        pw.TextDirection.rtl,
      );
      for (final language in <AppLanguage>[
        AppLanguage.english,
        AppLanguage.swedish,
        AppLanguage.somali,
      ]) {
        expect(StoryPdfLayout(language).isRtl, isFalse, reason: language.code);
        expect(
          StoryPdfLayout(language).textDirection,
          pw.TextDirection.ltr,
          reason: language.code,
        );
      }
    });

    test('the page badge sits in the corner reading starts from', () {
      expect(
        const StoryPdfLayout(AppLanguage.arabic).badgeAlignment,
        pw.Alignment.topRight,
      );
      expect(
        const StoryPdfLayout(AppLanguage.english).badgeAlignment,
        pw.Alignment.topLeft,
      );
    });

    test('the accent bar anchors to the reading-start edge', () {
      expect(
        const StoryPdfLayout(AppLanguage.arabic).accentBarAlignment,
        pw.Alignment.centerRight,
      );
      expect(
        const StoryPdfLayout(AppLanguage.swedish).accentBarAlignment,
        pw.Alignment.centerLeft,
      );
    });

    test('the prose panel insets mirror rather than shift', () {
      const arabic = StoryPdfLayout(AppLanguage.arabic);
      const english = StoryPdfLayout(AppLanguage.english);

      expect(arabic.prosePanelInsets.right, english.prosePanelInsets.left);
      expect(arabic.prosePanelInsets.left, english.prosePanelInsets.right);
      expect(arabic.prosePanelInsets.top, english.prosePanelInsets.top);
      expect(arabic.prosePanelInsets.bottom, english.prosePanelInsets.bottom);
      expect(
        arabic.prosePanelInsets.right,
        greaterThan(arabic.prosePanelInsets.left),
        reason: 'Arabic reads from the right, so that edge is the roomy one',
      );
    });

    test('an Arabic book renders through the mirrored layout', () async {
      final arabic = await StoryPdfService().build(
        _illustratedStory(AppLanguage.arabic),
        illustrationBytesById: <String, Uint8List>{
          'illustration-1': base64Decode(_transparentPixel),
          'illustration-2': base64Decode(_transparentPixel),
        },
      );

      expect(ascii.decode(arabic.take(4).toList()), '%PDF');
      expect(_pageCount(arabic), 5);
    });
  });
}

/// Number of page objects in a rendered document.
///
/// Read out of the page tree's `/Count`, which the renderer writes uncompressed,
/// so the export's structure can be asserted without a PDF parser.
int _pageCount(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final counts = RegExp(
    r'/Type\s*/Pages[^>]*?/Count\s+(\d+)',
  ).allMatches(raw).map((match) => int.parse(match.group(1)!)).toList();
  if (counts.isNotEmpty) return counts.reduce((a, b) => a > b ? a : b);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(raw).length;
}

/// Obviously fake 1x1 transparent image standing in for a reference photo.
const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Creates one approved book with realistic multilingual generation metadata.
StoryBook _story(
  AppLanguage language,
  String pageText, {
  IllustrationStyle style = IllustrationStyle.pictureBook,
}) {
  return StoryBook(
    id: 'story-${language.code}',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: _title(language),
      request: _request(language, style: style),
      pages: <StoryPage>[
        StoryPage(number: 1, text: pageText, sceneDescription: 'A kind hero'),
      ],
    ),
  );
}

/// Creates one bridge-generated book whose pages name their drawn pictures.
///
/// Built through the real provenance encoding, so the export has to recover the
/// identities the same way the reader does.
StoryBook _illustratedStory(AppLanguage language) {
  return StoryBook(
    id: 'story-drawn-${language.code}',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: _title(language),
      request: _request(language),
      pages: <StoryPage>[
        StoryPage(
          number: 1,
          text: language == AppLanguage.arabic
              ? 'وجد ميكو تنيناً لطيفاً.'
              : 'Miko found a kind dragon.',
          sceneDescription: const BridgeStoryProvenance(
            scene: 'A kind hero greets a dragon',
            storyId: 'bridge-story-1',
            illustrationId: 'illustration-1',
          ).toSceneDescription(),
        ),
        StoryPage(
          number: 2,
          text: language == AppLanguage.arabic
              ? 'ساعد أصدقاءه بشجاعة.'
              : 'He helped his friends bravely.',
          sceneDescription: const BridgeStoryProvenance(
            scene: 'The hero helps his friends',
            storyId: 'bridge-story-1',
            illustrationId: 'illustration-2',
          ).toSceneDescription(),
        ),
      ],
    ),
  );
}

/// Creates generation context without bypassing production model validation.
StoryRequest _request(
  AppLanguage language, {
  IllustrationStyle style = IllustrationStyle.pictureBook,
}) {
  return StoryRequest(
    hero: const StoryHero(
      profileId: 'profile-miko',
      name: 'Miko',
      gender: ChildGender.boy,
    ),
    prompt: StoryPrompt(
      theme: 'Stars',
      moral: _moral(language),
      preferences: const ChildStoryPreferences(),
    ),
    presentation: StoryPresentation(
      language: language,
      length: StoryLength.short,
      style: style,
    ),
  );
}

/// Includes Arabic glyphs on the cover in addition to page prose.
String _title(AppLanguage language) {
  return language == AppLanguage.arabic ? 'ميكو بطل النجوم' : 'Miko Hero';
}

/// The lesson printed on the dedication page and the back cover.
String _moral(AppLanguage language) {
  return switch (language) {
    AppLanguage.arabic => 'مشاركة ضوء صغير تجعله أكبر.',
    AppLanguage.swedish => 'Att dela ett litet ljus gör det större.',
    AppLanguage.somali => 'Wadaagista nal yar waxay ka dhigtaa mid weyn.',
    AppLanguage.english => 'Sharing a small light makes it bigger.',
  };
}
