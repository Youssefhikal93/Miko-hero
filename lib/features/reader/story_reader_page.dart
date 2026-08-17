import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';

/// Full-screen illustrated reader with free device narration.
class StoryReaderPage extends ConsumerStatefulWidget {
  /// Creates a reader route for one locally persisted story identity.
  const StoryReaderPage({required this.storyId, super.key});

  /// Story identity resolved from the current local library.
  final String storyId;

  @override
  /// Creates page and narration state scoped to this reader session.
  ConsumerState<StoryReaderPage> createState() => _StoryReaderPageState();
}

/// Controls reader page position and active platform narration.
class _StoryReaderPageState extends ConsumerState<StoryReaderPage> {
  final _pageController = PageController();
  late final NarrationService _narration;
  int _pageIndex = 0;
  bool _speaking = false;

  @override
  /// Retains the provider-owned speech service before disposal becomes unsafe.
  void initState() {
    super.initState();
    _narration = ref.read(narrationServiceProvider);
  }

  @override
  /// Stops speech before releasing the page controller and route state.
  void dispose() {
    unawaited(_narration.stop());
    _pageController.dispose();
    super.dispose();
  }

  @override
  /// Resolves the route identity from local state without accepting book payloads.
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(AppLocalizations.of(context).readStory),
      ),
      body: AppStateBoundary(
        state: state,
        builder: (snapshot) {
          final story = _storyFrom(snapshot);
          if (story == null) return const _MissingStory();
          return _reader(snapshot, story);
        },
      ),
    );
  }

  /// Finds the requested book while treating a deleted identity as absent.
  StoryBook? _storyFrom(AppState state) {
    for (final story in state.stories) {
      if (story.id == widget.storyId) return story;
    }
    return null;
  }

  /// Composes page content and controls from one stable story snapshot.
  Widget _reader(AppState state, StoryBook story) {
    final pages = story.content.pages;
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: _changePage,
            itemBuilder: (context, index) {
              return _ReaderPage(
                story: story,
                page: pages[index],
                profile: state.profileById(story.content.request.profileId),
              );
            },
          ),
        ),
        _ReaderControls(
          position: _ReaderPosition(
            pageIndex: _pageIndex,
            pageCount: pages.length,
            speaking: _speaking,
          ),
          actions: _ReaderActions(
            previous: _pageIndex == 0 ? null : _previousPage,
            next: _pageIndex == pages.length - 1 ? null : _nextPage,
            narration: () => _toggleNarration(story),
          ),
        ),
      ],
    );
  }

  /// Changes page state and stops speech so narration never overlaps pages.
  void _changePage(int pageIndex) {
    unawaited(_narration.stop());
    setState(() {
      _pageIndex = pageIndex;
      _speaking = false;
    });
  }

  /// Moves one page backward using the reader's semantic page order.
  Future<void> _previousPage() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Moves one page forward using the reader's semantic page order.
  Future<void> _nextPage() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Starts or stops narration with graceful unsupported-language recovery.
  Future<void> _toggleNarration(StoryBook story) async {
    if (_speaking) {
      await _narration.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final language = story.content.request.presentation.language;
    try {
      final supported = await _narration.supports(language);
      if (!supported) {
        _showNarrationUnavailable();
        return;
      }
      setState(() => _speaking = true);
      await _narration.speak(story.content.pages[_pageIndex].text, language);
      if (mounted) setState(() => _speaking = false);
    } on Exception {
      if (mounted) setState(() => _speaking = false);
      _showNarrationUnavailable();
    }
  }

  /// Explains a missing platform voice without blocking text-based reading.
  void _showNarrationUnavailable() {
    if (!mounted) return;
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.narrationUnavailable)));
  }
}

/// Story page with explicit direction independent of the application locale.
class _ReaderPage extends StatelessWidget {
  /// Creates one responsive page spread from local story and profile content.
  const _ReaderPage({
    required this.story,
    required this.page,
    required this.profile,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;

  @override
  /// Switches between stacked phone content and a desktop two-column spread.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustration = _PageIllustration(
          story: story,
          page: page,
          profile: profile,
        );
        final prose = _StoryProse(story: story, page: page);
        if (constraints.maxWidth < 760) {
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

/// Honest placeholder composition for the future ComfyUI page illustration.
class _PageIllustration extends StatelessWidget {
  /// Creates placeholder art from story styling and optional private photo bytes.
  const _PageIllustration({
    required this.story,
    required this.page,
    required this.profile,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;

  @override
  /// Uses local photo bytes only and marks the surface as demo output.
  Widget build(BuildContext context) {
    final photo = profile?.photoBase64;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _pageGradient(),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 72,
              backgroundColor: Colors.white24,
              backgroundImage: photo == null
                  ? null
                  : MemoryImage(base64Decode(photo)),
              child: photo == null
                  ? const Icon(
                      Icons.face_rounded,
                      size: 74,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
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
        ],
      ),
    );
  }

  /// Keeps placeholder art stable for each selected illustration style.
  LinearGradient _pageGradient() {
    return switch (story.content.request.presentation.style) {
      IllustrationStyle.pictureBook => const LinearGradient(
        colors: <Color>[Color(0xFF4C33A5), Color(0xFFDA5B67)],
      ),
      IllustrationStyle.watercolor => const LinearGradient(
        colors: <Color>[Color(0xFF26778A), Color(0xFF8E6487)],
      ),
      IllustrationStyle.colorful3d => const LinearGradient(
        colors: <Color>[AppTheme.orange, Color(0xFF8A31CB)],
      ),
    };
  }
}

/// Scrollable story prose with language-specific direction and alignment.
class _StoryProse extends StatelessWidget {
  /// Creates prose for one page without inheriting the interface direction.
  const _StoryProse({required this.story, required this.page});

  final StoryBook story;
  final StoryPage page;

  @override
  /// Applies right-to-left direction only when the story language is Arabic.
  Widget build(BuildContext context) {
    final language = story.content.request.presentation.language;
    final direction = language == AppLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Card(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                story.content.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              Text(page.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reader actions kept outside story direction so controls follow app locale.
class _ReaderControls extends StatelessWidget {
  /// Creates controls for the current reader position and narration state.
  const _ReaderControls({required this.position, required this.actions});

  final _ReaderPosition position;
  final _ReaderActions actions;

  @override
  /// Keeps page progress and actions reachable above mobile system insets.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF11141D),
          border: Border(top: BorderSide(color: Color(0xFF2A2E3B))),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: actions.previous,
              tooltip: text.previousPage,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                text.pageProgress(position.pageIndex + 1, position.pageCount),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton.filledTonal(
              onPressed: actions.narration,
              tooltip: position.speaking
                  ? text.stopNarration
                  : text.playNarration,
              icon: Icon(
                position.speaking
                    ? Icons.stop_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: actions.next,
              tooltip: text.nextPage,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immutable values needed to render the reader control bar.
class _ReaderPosition {
  /// Groups page progress and narration state into one control input.
  const _ReaderPosition({
    required this.pageIndex,
    required this.pageCount,
    required this.speaking,
  });

  final int pageIndex;
  final int pageCount;
  final bool speaking;
}

/// User commands exposed by the reader control bar.
class _ReaderActions {
  /// Groups navigation and narration commands without boolean action flags.
  const _ReaderActions({
    required this.previous,
    required this.next,
    required this.narration,
  });

  final VoidCallback? previous;
  final VoidCallback? next;
  final VoidCallback narration;
}

/// Safe destination when a deep link targets a deleted local story.
class _MissingStory extends StatelessWidget {
  /// Creates a non-sensitive recovery view for an unresolved story identity.
  const _MissingStory();

  @override
  /// Offers a library exit without leaking the missing route identity.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Center(
      child: FilledButton.tonal(
        onPressed: () => context.go('/library'),
        child: Text(text.somethingWentWrong),
      ),
    );
  }
}
