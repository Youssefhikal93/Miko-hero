import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/story_creation/story_request_draft.dart';

/// Verifies the decisions the creation form used to make between its fields.
void main() {
  test('an empty draft opens in the language the form was opened in', () {
    const draft = StoryRequestDraft(language: AppLanguage.arabic);

    expect(draft.language, AppLanguage.arabic);
    expect(draft.gap, StoryRequestGap.hero);
    expect(draft.isSubmittable, isFalse);
  });

  test('a hero seeds their own saved story language', () {
    const draft = StoryRequestDraft(language: AppLanguage.english);

    final chosen = draft.withHero(
      _profile(gender: ChildGender.girl, language: AppLanguage.swedish),
    );

    expect(chosen.language, AppLanguage.swedish);
    expect(chosen.gender, ChildGender.girl);
  });

  test('a legacy hero leaves the Girl/Boy choice to be made', () {
    const draft = StoryRequestDraft(language: AppLanguage.english);

    final chosen = draft.withHero(_profile(gender: ChildGender.unspecified));

    expect(chosen.gender, isNull);
    expect(chosen.gap, StoryRequestGap.gender);
    expect(chosen.isSubmittable, isFalse);
  });

  test('choosing a second hero drops the Girl/Boy choice of the first', () {
    final draft = const StoryRequestDraft(
      language: AppLanguage.english,
    ).withHero(_profile(gender: ChildGender.girl));

    final legacy = draft.withHero(
      _profile(id: 'abbas', gender: ChildGender.unspecified),
    );

    expect(
      legacy.gender,
      isNull,
      reason: 'the choice made for the first hero is not kept',
    );
  });

  test('a card shows a just-made choice only on the hero it was made for', () {
    final legacy = _profile(gender: ChildGender.unspecified);
    final other = _profile(id: 'abbas', gender: ChildGender.boy);
    final draft = const StoryRequestDraft(
      language: AppLanguage.english,
    ).withHero(legacy).withGender(ChildGender.girl);

    expect(draft.genderOn(legacy), ChildGender.girl);
    expect(draft.genderOn(other), ChildGender.boy);
  });

  test('a failed write gives up only the choice storage refused', () {
    final legacy = _profile(gender: ChildGender.unspecified);
    final draft = const StoryRequestDraft(
      language: AppLanguage.english,
    ).withHero(legacy).withGender(ChildGender.girl);

    final rolledBack = draft.withPersistedGender(legacy);

    expect(rolledBack.gender, isNull);
    expect(rolledBack.hero?.id, legacy.id, reason: 'the hero stays chosen');
  });

  test('a failed write keeps a choice storage did hold', () {
    final saved = _profile(gender: ChildGender.boy);
    final draft = const StoryRequestDraft(
      language: AppLanguage.english,
    ).withHero(saved).withGender(ChildGender.girl);

    expect(draft.withPersistedGender(saved).gender, ChildGender.boy);
  });

  test('the request trims what the parent typed', () {
    final request = _complete()
        .withTheme('  a moon garden \n')
        .withMoral('  kindness  ')
        .toRequest();

    expect(request.theme, 'a moon garden');
    expect(request.moral, 'kindness');
  });

  test('the request carries every tapped choice and the saved preferences', () {
    final request = _complete()
        .withLength(StoryLength.medium)
        .withStyle(IllustrationStyle.watercolor)
        .withLanguage(AppLanguage.somali)
        .toRequest();

    expect(request.profileId, 'miko');
    expect(request.heroName, 'Miko');
    expect(request.gender, ChildGender.girl);
    expect(request.presentation.length, StoryLength.medium);
    expect(request.presentation.style, IllustrationStyle.watercolor);
    expect(request.presentation.language, AppLanguage.somali);
    expect(request.prompt.preferences.recurringWorld, 'the moon garden');
  });

  test('a blank adventure or lesson is a gap, not an empty request', () {
    final blankTheme = _complete().withTheme('   ');
    final blankMoral = _complete().withMoral('');

    expect(blankTheme.gap, StoryRequestGap.theme);
    expect(blankMoral.gap, StoryRequestGap.moral);
    expect(
      blankTheme.toRequest,
      throwsA(isA<IncompleteStoryRequestException>()),
    );
    expect(
      () => blankMoral.toRequest(),
      throwsA(
        isA<IncompleteStoryRequestException>().having(
          (error) => error.gap,
          'gap',
          StoryRequestGap.moral,
        ),
      ),
    );
  });

  test('a draft mid-generation refuses a second request', () {
    final running = _complete().withGenerating(running: true);

    expect(running.canWrite(generatorKnown: true), isFalse);
    expect(running.acceptsInput, isFalse);
  });

  test('a draft waiting on a saved Girl/Boy choice refuses a request', () {
    final saving = _complete().withSavingHero(saving: true);

    expect(saving.canWrite(generatorKnown: true), isFalse);
  });

  test('no request is written before the saved generator is known', () {
    final ready = _complete();

    expect(ready.canWrite(generatorKnown: false), isFalse);
    expect(ready.canWrite(generatorKnown: true), isTrue);
  });

  test('an incomplete draft still reaches the validators of the form', () {
    final empty = const StoryRequestDraft(language: AppLanguage.english);

    expect(empty.isSubmittable, isFalse);
    expect(
      empty.canWrite(generatorKnown: true),
      isTrue,
      reason: 'the button stays tappable so the fields can say what is missing',
    );
  });

  test('the request follows the hero into their stored profile', () {
    final draft = _complete();
    final renamed = _profile(gender: ChildGender.girl, name: 'Miko New');

    final request = draft.withRefreshedHero(renamed).toRequest();

    expect(request.heroName, 'Miko New');
  });

  test('a refresh of another child leaves the draft alone', () {
    final draft = _complete();

    final unchanged = draft.withRefreshedHero(
      _profile(id: 'abbas', gender: ChildGender.boy, name: 'Abbas'),
    );

    expect(unchanged.hero?.id, 'miko');
    expect(unchanged.toRequest().heroName, 'Miko');
  });
}

/// Builds the smallest draft that can be turned into a request.
StoryRequestDraft _complete() {
  return const StoryRequestDraft(language: AppLanguage.english)
      .withHero(_profile(gender: ChildGender.girl))
      .withTheme('a moon garden')
      .withMoral('kindness');
}

/// Builds one stored profile with exactly the fields under test.
ChildProfile _profile({
  required ChildGender gender,
  String id = 'miko',
  String name = 'Miko',
  AppLanguage language = AppLanguage.english,
}) {
  return ChildProfile(
    id: id,
    name: name,
    legacyAge: 7,
    photoBase64: '',
    gender: gender,
    themeColorValue: defaultProfileThemeColorValue(gender),
    hasCustomThemeColor: false,
    storyPreferences: ChildStoryPreferences(
      defaultLanguage: language,
      recurringWorld: 'the moon garden',
    ),
  );
}
