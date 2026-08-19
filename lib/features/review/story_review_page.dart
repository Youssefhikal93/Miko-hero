import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/reading_text_style.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Parent-only queue of generated stories waiting for approval.
class StoryReviewQueuePage extends ConsumerWidget {
  /// Creates the routed draft-review queue.
  const StoryReviewQueuePage({super.key});

  @override
  /// Rebuilds as drafts are approved or permanently deleted.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _ReviewQueue(drafts: snapshot.draftStories),
    );
  }
}

/// Loaded draft queue independent from asynchronous persistence state.
class _ReviewQueue extends StatelessWidget {
  /// Creates a queue from newest-first draft stories.
  const _ReviewQueue({required this.drafts});

  final List<StoryBook> drafts;

  @override
  /// Shows a clear empty state or adaptive draft preview cards.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.reviewStoriesTitle,
            subtitle: text.reviewStoriesBody,
          ),
          const SizedBox(height: 22),
          if (drafts.isEmpty)
            _NoDrafts(text: text)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: drafts
                      .map((story) {
                        return SizedBox(
                          width: width,
                          child: StoryCard(
                            story: story,
                            actions: StoryCardActions(
                              open: () => context.go('/review/${story.id}'),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Parent-only full text review and approval surface for one draft.
class StoryReviewPage extends ConsumerWidget {
  /// Creates a review route for one locally stored story identity.
  const StoryReviewPage({required this.storyId, super.key});

  /// Draft identity resolved from current application state.
  final String storyId;

  @override
  /// Resolves the current book so approval updates cannot use stale payloads.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) {
        final story = _draftFrom(snapshot);
        return story == null
            ? const _MissingDraft()
            : _ReviewContent(
                story: story,
                profile: snapshot.profileById(story.content.request.profileId),
              );
      },
    );
  }

  /// Finds only unapproved content, treating approved or removed IDs as absent.
  StoryBook? _draftFrom(AppState state) {
    for (final story in state.draftStories) {
      if (story.id == storyId) return story;
    }
    return null;
  }
}

/// Review details and commands for one current draft snapshot.
class _ReviewContent extends ConsumerWidget {
  /// Creates review content for one generated draft and its hero's profile.
  const _ReviewContent({required this.story, required this.profile});

  final StoryBook story;

  /// Child the draft belongs to, whose reading comfort the preview mirrors.
  final ChildProfile? profile;

  @override
  /// Shows request context, every page, and explicit approval or deletion.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.reviewStoryTitle,
            subtitle: text.reviewStoryBody,
          ),
          const SizedBox(height: 20),
          StoryCover(story: story, height: 240),
          const SizedBox(height: 20),
          _RequestSummary(story: story),
          const SizedBox(height: 20),
          ...story.content.pages.map(
            (page) => _ReviewPage(
              page: page,
              readingSettings:
                  profile?.readingSettings ?? const ChildReadingSettings(),
              language: story.content.request.presentation.language,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => _approve(context, ref),
                icon: const Icon(Icons.verified_rounded),
                label: Text(text.approveStory),
              ),
              OutlinedButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(text.deleteDraft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Approves the current draft and opens its child-facing reader.
  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final text = AppLocalizations.of(context);
    try {
      await ref.read(storyControllerProvider).approveStory(story.id);
      if (!context.mounted) return;
      // Replaces any still-queued creation snackbar so the approval message
      // never waits behind it and overstays on the reader controls.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.storyApproved)));
      context.go('/story/${story.id}');
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }

  /// Confirms permanent draft removal before changing local storage.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.deleteDraftTitle),
        content: Text(text.deleteDraftBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.deleteDraft),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(storyControllerProvider).deleteStory(story.id);
    if (context.mounted) context.go('/review');
  }
}

/// Read-only parent prompt context shown above generated pages.
class _RequestSummary extends StatelessWidget {
  /// Creates a summary from one complete generated book.
  const _RequestSummary({required this.story});

  final StoryBook story;

  @override
  /// Displays hero, theme, moral, and active safety count for review.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final request = story.content.request;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              story.content.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(text.reviewHero(request.heroName)),
            Text(text.reviewTheme(request.theme)),
            Text(text.reviewMoral(request.moral)),
            Text(
              text.safetyRulesValue(
                request.prompt.preferences.excludedTopics.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One complete generated page shown as readable text before approval.
class _ReviewPage extends StatelessWidget {
  /// Creates a review card from one ordered story page.
  const _ReviewPage({
    required this.page,
    required this.readingSettings,
    required this.language,
  });

  final StoryPage page;
  final ChildReadingSettings readingSettings;
  final AppLanguage language;

  @override
  /// Keeps long prose selectable and vertically scrollable with the screen.
  ///
  /// Shows the page in the child's saved size and font, so the parent reviews
  /// the text exactly as it will be read.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.reviewPageNumber(page.number),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              page.text,
              key: const ValueKey<String>('review-page-text'),
              style: readingProseStyle(
                context,
                settings: readingSettings,
                language: language,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty review queue after every generated story has been decided.
class _NoDrafts extends StatelessWidget {
  /// Creates localized empty review guidance.
  const _NoDrafts({required this.text});

  final AppLocalizations text;

  @override
  /// Routes back to the child-facing library without inventing drafts.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const Icon(Icons.fact_check_outlined, size: 48),
            const SizedBox(height: 12),
            Text(text.noDrafts, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.go('/library'),
              child: Text(text.library),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recovery view for a removed, approved, or unknown draft identity.
class _MissingDraft extends StatelessWidget {
  /// Creates the safe missing-draft destination.
  const _MissingDraft();

  @override
  /// Returns to the current review queue without exposing route details.
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonal(
        onPressed: () => context.go('/review'),
        child: Text(AppLocalizations.of(context).reviewStoriesTitle),
      ),
    );
  }
}
