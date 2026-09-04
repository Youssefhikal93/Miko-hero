import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/sentence_splitter.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/hero_face.dart';
import 'package:miko_hero/shared/reading_text_style.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_artwork.dart';

/// One open page of a book: its picture, its prose, and nothing else.
///
/// The spread is handed a [ReaderPageContext] and reads no reader state, no
/// controller, and no route: everything it draws arrives in that one value, so
/// a page can be built for a story and a hero without a reader around it.

/// Everything one open page of a book is drawn from.
///
/// One value rather than six forwarded fields, so the reader page hands the
/// spread a page the same way the dialogs are handed a choice.
class ReaderPageContext {
  /// Groups one page with the story, hero, and session state it is drawn in.
  const ReaderPageContext({
    required this.story,
    required this.page,
    required this.profile,
    required this.readingSettings,
    required this.bedtime,
    required this.highlightedSentence,
  });

  /// Book the page belongs to, read for its title, artwork, and language.
  final StoryBook story;

  /// The page being read.
  final StoryPage page;

  /// Hero of the story, absent once their profile has left this device.
  final ChildProfile? profile;

  /// Prose size and font this child reads at.
  final ChildReadingSettings readingSettings;

  /// Whether the session's bedtime palette is on.
  final bool bedtime;

  /// Sentence narration is speaking, or null while nothing is being read.
  final int? highlightedSentence;
}

/// Story page with explicit direction independent of the application locale.
class ReaderSpread extends StatelessWidget {
  /// Creates one responsive page spread from a single reader page value.
  const ReaderSpread({required this.pageContext, super.key});

  /// Everything this page is drawn from.
  final ReaderPageContext pageContext;

  @override
  /// Switches between stacked phone content and a desktop two-column spread.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustration = _PageIllustration(pageContext: pageContext);
        final prose = _StoryProse(pageContext: pageContext);
        if (!isWideReaderWidth(constraints.maxWidth)) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                Expanded(flex: 3, child: illustration),
                const SizedBox(height: 16),
                Expanded(flex: 2, child: prose),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: <Widget>[
              Expanded(child: illustration),
              const SizedBox(width: 24),
              Expanded(child: prose),
            ],
          ),
        );
      },
    );
  }
}

/// The page's drawn picture, or the honest placeholder while it has none.
class _PageIllustration extends ConsumerWidget {
  /// Creates page art from the cached picture, or from story styling.
  const _PageIllustration({required this.pageContext});

  final ReaderPageContext pageContext;

  @override
  /// Shows the PC's picture once this device has it, and the gradient until
  /// then. No spinner ever appears over a child's page: a book that is waiting
  /// for artwork simply looks like the book it already was. Demo stories keep
  /// their DEMO chip, and the page number stays on top in both cases.
  Widget build(BuildContext context, WidgetRef ref) {
    final story = pageContext.story;
    final page = pageContext.page;
    final illustration = StoryArtwork.pageOf(ref, page);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: StoryArtwork.gradientOf(story),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        // The drawn page fills the frame, so the stack has to take the space
        // the layout gives it rather than shrink to its positioned children.
        fit: StackFit.expand,
        children: <Widget>[
          if (illustration == null)
            _placeholderFace()
          else
            _drawnPage(illustration),
          if (!BridgeStoryProvenance.marksStory(story))
            PositionedDirectional(
              top: 18,
              start: 18,
              child: Chip(
                avatar: const Icon(Icons.science_outlined, size: 16),
                label: Text(AppLocalizations.of(context).demoBadge),
              ),
            ),
          PositionedDirectional(
            end: 18,
            bottom: 18,
            child: Text(
              '${page.number}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
          ),
          if (pageContext.bedtime)
            Positioned.fill(
              key: const ValueKey<String>('bedtime-page-wash'),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.bedtimeWash,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fills the page with the drawn picture inside the same rounded frame.
  Widget _drawnPage(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.memory(
        bytes,
        key: const ValueKey<String>('page-illustration'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }

  /// Centres the child's own photo, or a friendly face, over the gradient.
  Widget _placeholderFace() {
    return Center(
      child: HeroFace(
        key: const ValueKey<String>('page-placeholder-face'),
        profile: pageContext.profile,
        size: 144,
        background: Colors.white24,
        fallbackIcon: Icons.face_rounded,
        fallbackColor: Colors.white,
      ),
    );
  }
}

/// Scrollable story prose with language-specific direction and alignment.
class _StoryProse extends StatelessWidget {
  /// Creates prose for one page without inheriting the interface direction.
  const _StoryProse({required this.pageContext});

  final ReaderPageContext pageContext;

  @override
  /// Applies right-to-left direction only when the story language is Arabic.
  ///
  /// The child's saved size and font, and the optional bedtime palette, both
  /// travel through the single prose style so highlighting composes with them
  /// in either text direction.
  Widget build(BuildContext context) {
    final story = pageContext.story;
    final language = story.content.request.presentation.language;
    final direction = language == AppLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Card(
        color: pageContext.bedtime ? AppTheme.bedtimeSurface : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                story.content.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: pageContext.bedtime ? AppTheme.bedtimeProse : null,
                ),
              ),
              const SizedBox(height: 22),
              Text.rich(
                _prose(context),
                key: const ValueKey<String>('story-prose'),
                style: _proseStyle(context, language),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the child's reading comfort plus the bedtime prose color.
  TextStyle _proseStyle(BuildContext context, AppLanguage language) {
    final style = readingProseStyle(
      context,
      settings: pageContext.readingSettings,
      language: language,
    );
    return pageContext.bedtime
        ? style.copyWith(color: AppTheme.bedtimeProse)
        : style;
  }

  /// Tints the sentence being spoken without rewriting the child's story text.
  ///
  /// The narrated sentence is located by offset inside the original page text,
  /// so the rendered prose stays character-for-character the same in both
  /// left-to-right and Arabic right-to-left layouts.
  InlineSpan _prose(BuildContext context) {
    final text = pageContext.page.text;
    final sentences = locateNarrationSentences(text);
    final index = pageContext.highlightedSentence;
    if (index == null || index >= sentences.length) {
      return TextSpan(text: text);
    }
    final spoken = sentences[index];
    return TextSpan(
      children: <InlineSpan>[
        TextSpan(text: text.substring(0, spoken.start)),
        TextSpan(
          text: text.substring(spoken.start, spoken.end),
          style: TextStyle(
            backgroundColor: _highlightColor(context).withValues(alpha: 0.3),
            color: pageContext.bedtime
                ? AppTheme.bedtimeProse
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: text.substring(spoken.end)),
      ],
    );
  }

  /// Keeps the spoken-sentence tint warm while bedtime mode is on.
  Color _highlightColor(BuildContext context) {
    return pageContext.bedtime
        ? AppTheme.candle
        : Theme.of(context).colorScheme.primary;
  }
}
