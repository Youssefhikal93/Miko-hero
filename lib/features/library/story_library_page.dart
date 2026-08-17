import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Complete local bookshelf with explicit permanent deletion controls.
class StoryLibraryPage extends ConsumerWidget {
  /// Creates the routed library destination.
  const StoryLibraryPage({super.key});

  @override
  /// Rebuilds immediately after local generation or deletion changes the shelf.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _LibraryContent(state: snapshot),
    );
  }
}

/// Loaded bookshelf independent from persistence state plumbing.
class _LibraryContent extends ConsumerWidget {
  /// Creates the bookshelf from one immutable application snapshot.
  const _LibraryContent({required this.state});

  final AppState state;

  @override
  /// Shows an invitation for an empty shelf or an adaptive card grid.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.libraryTitle,
            subtitle: text.librarySubtitle,
          ),
          const SizedBox(height: 24),
          if (state.stories.isEmpty)
            _EmptyShelf(text: text)
          else
            _storyGrid(context, ref),
        ],
      ),
    );
  }

  /// Creates a one-, two-, or three-column shelf from available width.
  Widget _storyGrid(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: state.stories.map((story) {
            return SizedBox(
              width: cardWidth,
              child: StoryCard(
                story: story,
                onOpen: () => context.go('/story/${story.id}'),
                onDelete: () => _confirmDelete(context, ref, story),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Requires an explicit confirmation before permanent local deletion.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StoryBook story,
  ) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.deleteStoryTitle),
        content: Text(text.deleteStoryBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).deleteStory(story.id);
    }
  }
}

/// Empty shelf with a direct creation action.
class _EmptyShelf extends StatelessWidget {
  /// Creates the empty state from localized copy.
  const _EmptyShelf({required this.text});

  final AppLocalizations text;

  @override
  /// Makes the no-content state useful without inventing sample books.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: <Widget>[
              const Icon(Icons.auto_stories_outlined, size: 54),
              const SizedBox(height: 16),
              Text(
                text.emptyLibraryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(text.emptyLibraryBody, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/create'),
                child: Text(text.createFirstStory),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
