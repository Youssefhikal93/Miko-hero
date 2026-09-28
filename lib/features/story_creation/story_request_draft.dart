import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// The one thing a story request is still waiting for.
///
/// Ordered the way the form reads, so the first gap is the one the parent
/// meets first going down the screen.
enum StoryRequestGap {
  /// No child has been tapped as the hero yet.
  hero,

  /// The chosen hero carries no Girl/Boy choice, and none has been made.
  gender,

  /// The adventure field is still empty.
  theme,

  /// The lesson field is still empty.
  moral,
}

/// Raised when a draft that is not ready yet is asked for its request.
///
/// A programming error rather than a parent-facing state: the form's own
/// validators refuse an incomplete request long before this can be reached.
class IncompleteStoryRequestException implements Exception {
  /// Names the gap that stopped the request being built.
  const IncompleteStoryRequestException(this.gap);

  /// What the draft was still missing.
  final StoryRequestGap gap;

  @override
  /// Names the gap without quoting anything the parent typed.
  String toString() => 'IncompleteStoryRequestException(${gap.name})';
}

/// The story request a parent is still tapping together.
///
/// Every decision the creation form used to make between seven mutable fields
/// lives here instead: what a chosen hero seeds, which Girl/Boy choice a card
/// should show, whether the request can be written, and what the request is.
/// The form keeps only its text controllers, its layout, and the transaction.
class StoryRequestDraft {
  /// Creates a draft, at minimum in the language the form opened in.
  const StoryRequestDraft({
    required this.language,
    this.hero,
    this.gender,
    this.theme = '',
    this.moral = '',
    this.length = StoryLength.short,
    this.style = IllustrationStyle.pictureBook,
    this.isGenerating = false,
    this.isSavingHero = false,
  });

  /// Child this story is about, absent until one has been tapped.
  ///
  /// Only the identity, the name, and the saved story preferences are read
  /// from it, and this screen changes none of the three. [withRefreshedHero]
  /// re-reads the stored profile for the one field this screen does change.
  final ChildProfile? hero;

  /// Girl or Boy for this story, absent while a legacy profile has neither.
  final ChildGender? gender;

  /// Adventure the parent typed, trimmed only when the request is built.
  final String theme;

  /// Lesson the parent typed, trimmed only when the request is built.
  final String moral;

  /// Language the story itself will be written in.
  final AppLanguage language;

  /// Page count the parent chose.
  final StoryLength length;

  /// Illustration direction the parent chose.
  final IllustrationStyle style;

  /// Whether a request from this draft is running right now.
  final bool isGenerating;

  /// Whether the hero's Girl/Boy choice is being written to storage.
  final bool isSavingHero;

  /// Adopts a tapped hero, seeding what that child already decided.
  ///
  /// The saved default story language follows the child, so a family that
  /// reads in Swedish does not re-pick it every time. A legacy profile with no
  /// Girl/Boy choice leaves [gender] absent, which is what makes the form ask.
  StoryRequestDraft withHero(ChildProfile chosen) {
    final specified = chosen.gender.isSpecified;
    return _copy(
      hero: chosen,
      gender: specified ? chosen.gender : null,
      clearGender: !specified,
      language: chosen.storyPreferences.defaultLanguage,
    );
  }

  /// Follows the hero into the profile storage now holds for them.
  ///
  /// Keeps every tapped choice: only the profile the request is written from
  /// is replaced. A draft whose hero is gone, or was never chosen, is
  /// unchanged.
  StoryRequestDraft withRefreshedHero(ChildProfile stored) {
    if (hero == null || stored.id != hero!.id) return this;
    return _copy(hero: stored);
  }

  /// Records the Girl/Boy choice a parent just made.
  StoryRequestDraft withGender(ChildGender chosen) => _copy(gender: chosen);

  /// Restores the Girl/Boy choice to the one storage actually kept.
  ///
  /// The rollback after a failed write: the hero the parent tapped stays
  /// chosen, and only the choice that did not reach storage is given up.
  StoryRequestDraft withPersistedGender(ChildProfile? stored) {
    final persisted = stored?.gender;
    return _copy(
      gender: persisted != null && persisted.isSpecified ? persisted : null,
      clearGender: persisted == null || !persisted.isSpecified,
    );
  }

  /// Records the adventure as typed, trimming only when the request is built.
  StoryRequestDraft withTheme(String typed) => _copy(theme: typed);

  /// Records the lesson as typed, trimming only when the request is built.
  StoryRequestDraft withMoral(String typed) => _copy(moral: typed);

  /// Records the chosen page count.
  StoryRequestDraft withLength(StoryLength chosen) => _copy(length: chosen);

  /// Records the chosen illustration direction.
  StoryRequestDraft withStyle(IllustrationStyle chosen) => _copy(style: chosen);

  /// Records the chosen story language.
  StoryRequestDraft withLanguage(AppLanguage chosen) => _copy(language: chosen);

  /// Marks a request as running, or as no longer running.
  StoryRequestDraft withGenerating({required bool running}) {
    return _copy(isGenerating: running);
  }

  /// Marks the hero's Girl/Boy choice as being written, or as written.
  StoryRequestDraft withSavingHero({required bool saving}) {
    return _copy(isSavingHero: saving);
  }

  /// Girl/Boy this draft would show on [profile]'s own card.
  ///
  /// A choice made here shows on the card it was made for, so a legacy profile
  /// reads as the hero the parent just described rather than as unspecified.
  /// Every other card keeps what storage holds.
  ChildGender genderOn(ChildProfile profile) {
    if (profile.id != hero?.id || gender == null) return profile.gender;
    return gender!;
  }

  /// What the request is still waiting for, or null once it is complete.
  StoryRequestGap? get gap {
    if (hero == null) return StoryRequestGap.hero;
    if (gender == null) return StoryRequestGap.gender;
    if (theme.trim().isEmpty) return StoryRequestGap.theme;
    if (moral.trim().isEmpty) return StoryRequestGap.moral;
    return null;
  }

  /// Whether this draft carries a complete request.
  bool get isSubmittable => gap == null;

  /// Whether the form still accepts taps and typing.
  bool get acceptsInput => !isGenerating && !isSavingHero;

  /// Whether the write action may run right now.
  ///
  /// Deliberately not [isSubmittable]: an incomplete request still reaches the
  /// form's own validators, which is how a parent is told which field is
  /// empty. What is refused here is a second request over the first, a request
  /// racing the hero's own saved choice, and a request written before the
  /// saved generator selection is known — which is the only way a Local AI
  /// family can be sure they were never quietly handed the demo.
  bool canWrite({required bool generatorKnown}) {
    return acceptsInput && generatorKnown;
  }

  /// Captures one immutable request from the choices made so far.
  ///
  /// Throws [IncompleteStoryRequestException] rather than inventing a hero or
  /// an empty adventure; [gap] names what is missing before it is called.
  StoryRequest toRequest() {
    final missing = gap;
    if (missing != null) throw IncompleteStoryRequestException(missing);
    final chosen = hero!;
    return StoryRequest(
      hero: StoryHero(profileId: chosen.id, name: chosen.name, gender: gender!),
      prompt: StoryPrompt(
        theme: theme.trim(),
        moral: moral.trim(),
        preferences: chosen.storyPreferences,
      ),
      presentation: StoryPresentation(
        language: language,
        length: length,
        style: style,
      ),
    );
  }

  /// Rebuilds the draft, carrying every field no caller replaced.
  ///
  /// [clearGender] is how the one nullable choice is given up, since an absent
  /// argument has to mean "unchanged" for every other field.
  StoryRequestDraft _copy({
    ChildProfile? hero,
    ChildGender? gender,
    bool clearGender = false,
    String? theme,
    String? moral,
    AppLanguage? language,
    StoryLength? length,
    IllustrationStyle? style,
    bool? isGenerating,
    bool? isSavingHero,
  }) {
    return StoryRequestDraft(
      hero: hero ?? this.hero,
      gender: clearGender ? null : (gender ?? this.gender),
      theme: theme ?? this.theme,
      moral: moral ?? this.moral,
      language: language ?? this.language,
      length: length ?? this.length,
      style: style ?? this.style,
      isGenerating: isGenerating ?? this.isGenerating,
      isSavingHero: isSavingHero ?? this.isSavingHero,
    );
  }
}
