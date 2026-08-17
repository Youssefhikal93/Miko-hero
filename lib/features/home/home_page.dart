import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Personalized dashboard for profile setup and recent family stories.
class HomePage extends ConsumerWidget {
  /// Creates the routed home destination.
  const HomePage({super.key});

  @override
  /// Observes persisted state and delegates transient states to one boundary.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _HomeContent(state: snapshot),
    );
  }
}

/// Loaded home content kept independent from asynchronous state plumbing.
class _HomeContent extends StatelessWidget {
  /// Creates the dashboard from one immutable state snapshot.
  const _HomeContent({required this.state});

  final AppState state;

  @override
  /// Composes the welcome panel, profile prompt, and recent story grid.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _WelcomePanel(state: state),
          const SizedBox(height: 30),
          if (state.profiles.isEmpty) _ProfilePrompt(text: text),
          if (state.profiles.isNotEmpty)
            _RecentStories(state: state, text: text),
        ],
      ),
    );
  }
}

/// High-emphasis introduction and primary story action.
class _WelcomePanel extends StatelessWidget {
  /// Creates a welcome panel tailored to profile completion state.
  const _WelcomePanel({required this.state});

  final AppState state;

  @override
  /// Adapts the call to action while retaining one responsive composition.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final profileReady = state.profiles.isNotEmpty;
    return AccentPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = _welcomeCopy(context, text, profileReady);
          if (constraints.maxWidth < 660) return copy;
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: copy),
              const SizedBox(width: 28),
              const Expanded(flex: 2, child: _HeroEmblem()),
            ],
          );
        },
      ),
    );
  }

  /// Builds localized copy and routes to the next required user action.
  Widget _welcomeCopy(
    BuildContext context,
    AppLocalizations text,
    bool profileReady,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Iam - hero',
          style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          text.welcomeTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        Text(text.welcomeBody, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () =>
              context.go(profileReady ? '/create' : '/profiles/new'),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(
            profileReady ? text.createAnotherStory : text.setUpProfile,
          ),
        ),
      ],
    );
  }
}

/// Abstract hero artwork that does not expose or bundle any child's photo.
class _HeroEmblem extends StatelessWidget {
  /// Creates static placeholder art with no family image dependency.
  const _HeroEmblem();

  @override
  /// Uses layered shapes to provide visual identity before real illustrations exist.
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppTheme.orange, Color(0xFF7A42F4)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Icon(
          Icons.auto_stories_rounded,
          size: 92,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Setup prompt shown only before a private profile exists.
class _ProfilePrompt extends StatelessWidget {
  /// Creates localized setup guidance.
  const _ProfilePrompt({required this.text});

  final AppLocalizations text;

  @override
  /// Presents the single blocking requirement without adding onboarding steps.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: <Widget>[
            const Icon(Icons.face_retouching_natural_rounded, size: 38),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text.profileIncompleteTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(text.profileIncompleteBody),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.go('/profiles/new'),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent-book section or an empty-library invitation for completed profiles.
class _RecentStories extends StatelessWidget {
  /// Creates the section from a loaded state snapshot and localized copy.
  const _RecentStories({required this.state, required this.text});

  final AppState state;
  final AppLocalizations text;

  @override
  /// Shows at most three books to keep the home page focused.
  Widget build(BuildContext context) {
    if (state.stories.isEmpty) {
      return _EmptyLibrary(text: text);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeading(title: text.recentStories),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 32) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: state.stories.take(3).map((story) {
                return SizedBox(
                  width: width,
                  child: StoryCard(
                    story: story,
                    onOpen: () => context.go('/story/${story.id}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Empty library state with a direct path to story creation.
class _EmptyLibrary extends StatelessWidget {
  /// Creates the invitation from localized copy.
  const _EmptyLibrary({required this.text});

  final AppLocalizations text;

  @override
  /// Keeps an empty state actionable instead of presenting a blank shelf.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppTheme.amber,
            ),
            const SizedBox(height: 14),
            Text(
              text.emptyLibraryTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(text.emptyLibraryBody, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/create'),
              child: Text(text.createFirstStory),
            ),
          ],
        ),
      ),
    );
  }
}
