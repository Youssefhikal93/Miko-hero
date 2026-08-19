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
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/sentence_splitter.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/reader/narration_controller.dart';
import 'package:miko_hero/features/reader/story_export_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';
import 'package:miko_hero/shared/reading_badge_view.dart';
import 'package:miko_hero/shared/reading_text_style.dart';

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
  late final NarrationController _narration;
  int _pageIndex = 0;
  bool _exporting = false;
  bool _bedtime = false;
  bool _sleepTimerChosen = false;
  bool _finishRecorded = false;

  @override
  /// Builds the sentence queue around the provider-owned speech service.
  void initState() {
    super.initState();
    _narration = NarrationController(ref.read(narrationServiceProvider))
      ..onPageChanged = _followNarratedPage
      ..onUnavailable = _showNarrationUnavailable
      ..addListener(_narrationChanged);
  }

  @override
  /// Stops speech before releasing the page controller and route state.
  void dispose() {
    _narration
      ..removeListener(_narrationChanged)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Repaints controls and the sentence highlight as the queue advances.
  void _narrationChanged() {
    if (mounted) setState(() {});
  }

  @override
  /// Resolves the route identity from local state without accepting book payloads.
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
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
      if (story.id == widget.storyId &&
          story.reviewStatus == StoryReviewStatus.approved) {
        return story;
      }
    }
    return null;
  }

  /// Composes page content and controls from one stable story snapshot.
  Widget _reader(AppState state, StoryBook story) {
    final pages = story.content.pages;
    final profile = state.profileById(story.content.request.profileId);
    final readingSettings =
        profile?.readingSettings ?? const ChildReadingSettings();
    _scheduleFinishCheck(story);
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => _changePage(index, story),
            itemBuilder: (context, index) {
              return _ReaderPage(
                story: story,
                page: pages[index],
                profile: profile,
                readingSettings: readingSettings,
                bedtime: _bedtime,
                highlightedSentence: _narration.highlightedSentence(index),
              );
            },
          ),
        ),
        _ReaderControls(
          status: _ReaderStatus(
            pageIndex: _pageIndex,
            pageCount: pages.length,
            playback: _narration.playback,
            exporting: _exporting,
            bedtime: _bedtime,
          ),
          actions: _ReaderActions(
            navigation: _ReaderNavigation(
              previous: _pageIndex == 0 ? null : _previousPage,
              next: _pageIndex == pages.length - 1 ? null : _nextPage,
            ),
            narration: () => _toggleNarration(story),
            stopNarration: () => unawaited(_narration.stop()),
            narrationSettings: _changeNarrationSettings,
            bedtime: _toggleBedtime,
            export: () => _exportStory(story, profile),
          ),
        ),
      ],
    );
  }

  /// Records the visible page and lets narration decide whether to continue.
  ///
  /// A page turn the sentence queue itself requested keeps narrating; a swipe
  /// or arrow tap by the reader stops it and clears the highlight.
  void _changePage(int pageIndex, StoryBook story) {
    unawaited(_narration.handlePageChange(pageIndex));
    setState(() => _pageIndex = pageIndex);
    _noteFinishedStory(story, pageIndex);
  }

  /// Counts a story a child opened directly on its last page, once per session.
  void _scheduleFinishCheck(StoryBook story) {
    if (_finishRecorded || _pageIndex != story.content.pages.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFinishedStory(story, _pageIndex);
    });
  }

  /// Records one finished reading when the last page of a story is reached.
  ///
  /// Guarded per reader session so paging back and forth never celebrates
  /// twice; the profile itself keeps distinct identities, so a story read again
  /// tomorrow still counts only once.
  void _noteFinishedStory(StoryBook story, int pageIndex) {
    if (_finishRecorded || pageIndex != story.content.pages.length - 1) return;
    _finishRecorded = true;
    unawaited(_recordFinishedStory(story));
  }

  /// Persists the finished story and celebrates a badge the moment it is earned.
  Future<void> _recordFinishedStory(StoryBook story) async {
    try {
      final badge = await ref
          .read(profileControllerProvider)
          .recordFinishedStory(story.content.request.profileId, story.id);
      if (badge == null || !mounted) return;
      final text = AppLocalizations.of(context);
      _showMessage(text.badgeEarned(readingBadgeName(text, badge)));
    } on Exception {
      // A profile deleted while its story is open must not break reading.
    }
  }

  /// Dims and warms the reader for one bedtime session without persisting it.
  void _toggleBedtime() {
    setState(() => _bedtime = !_bedtime);
    if (_bedtime && _narration.isActive) _applyBedtimeSleepTimer();
  }

  /// Selects the ten-minute limit unless a timer was already chosen this session.
  void _applyBedtimeSleepTimer() {
    if (_sleepTimerChosen || _narration.sleepTimer.isActive) return;
    _narration.setSleepTimer(NarrationSleepTimer.tenMinutes);
    final duration = NarrationSleepTimer.tenMinutes.duration!;
    _showMessage(
      AppLocalizations.of(context).bedtimeSleepTimerApplied(duration.inMinutes),
    );
  }

  /// Follows the sentence queue into the next page of a rest-of-story reading.
  void _followNarratedPage(int pageIndex) {
    if (!mounted || !_pageController.hasClients) return;
    unawaited(
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      ),
    );
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

  /// Plays, pauses, or resumes sentence-by-sentence narration.
  Future<void> _toggleNarration(StoryBook story) async {
    switch (_narration.playback) {
      case NarrationPlayback.playing:
        await _narration.pause();
      case NarrationPlayback.paused:
        await _narration.resume();
      case NarrationPlayback.idle:
        if (_bedtime) _applyBedtimeSleepTimer();
        await _narration.start(
          pageTexts: story.content.pages
              .map((page) => page.text)
              .toList(growable: false),
          pageIndex: _pageIndex,
          language: story.content.request.presentation.language,
        );
    }
  }

  /// Opens session narration choices and requeues only when the scope changes.
  ///
  /// Pace and sleep timer apply to playback that is already running, so a
  /// bedtime limit never costs the listener their place in the story.
  Future<void> _changeNarrationSettings() async {
    final selected = await showDialog<_NarrationSelection>(
      context: context,
      builder: (_) => _NarrationSettingsDialog(selection: _selection),
    );
    if (selected == null || !mounted) return;
    final requeue = selected.scope != _narration.scope;
    _sleepTimerChosen = _sleepTimerChosen || selected.sleepTimerChosen;
    _narration
      ..setSpeed(selected.speed)
      ..setScope(selected.scope)
      ..setSleepTimer(selected.sleepTimer);
    if (requeue) await _narration.stop();
  }

  /// Returns the current session choices as one immutable dialog value.
  _NarrationSelection get _selection {
    return _NarrationSelection(
      speed: _narration.speed,
      scope: _narration.scope,
      sleepTimer: _narration.sleepTimer,
      remainingSleep: _narration.remainingSleep,
    );
  }

  /// Requests parent access and the cover choice before writing a story file.
  ///
  /// The photo question is only asked when the hero still has a saved photo;
  /// otherwise the photo-free cover is the only possible result.
  Future<void> _exportStory(StoryBook story, ChildProfile? profile) async {
    if (_exporting || !await requestParentAccess(context, ref)) return;
    if (!mounted) return;
    final hasPhoto = profile != null && profile.photoBase64.isNotEmpty;
    var includePhoto = false;
    if (hasPhoto) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (_) => _ExportOptionsDialog(childName: profile.name),
      );
      if (choice == null || !mounted) return;
      includePhoto = choice;
    }
    await _savePdf(story, includePhoto: includePhoto);
  }

  /// Renders and saves the PDF while keeping cancellation non-exceptional.
  Future<void> _savePdf(StoryBook story, {required bool includePhoto}) async {
    final text = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final saved = await ref
          .read(storyExportControllerProvider)
          .export(story, text.exportPdfDialogTitle, includePhoto: includePhoto);
      if (mounted) {
        _showMessage(saved ? text.pdfSaved : text.pdfSaveCancelled);
      }
    } on Exception {
      if (mounted) _showMessage(text.pdfExportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Replaces any reader notice with the latest export outcome.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

/// Export choices asked once per PDF, before any rendering work starts.
class _ExportOptionsDialog extends StatefulWidget {
  /// Creates the dialog for a hero who currently has a saved photo.
  const _ExportOptionsDialog({required this.childName});

  final String childName;

  @override
  /// Creates the checkbox state discarded when the dialog is dismissed.
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

/// Holds the cover-photo choice, which starts included as parents expect.
class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  bool _includePhoto = true;

  @override
  /// Explains that the saved file is unencrypted before the photo is added.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.exportPdfOptionsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includePhoto,
            title: Text(text.includePhotoOnCover(widget.childName)),
            onChanged: (value) {
              setState(() => _includePhoto = value ?? false);
            },
          ),
          const SizedBox(height: 8),
          Text(
            text.exportPdfPhotoNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_includePhoto),
          child: Text(text.exportPdf),
        ),
      ],
    );
  }
}

/// Story page with explicit direction independent of the application locale.
class _ReaderPage extends StatelessWidget {
  /// Creates one responsive page spread from local story and profile content.
  const _ReaderPage({
    required this.story,
    required this.page,
    required this.profile,
    required this.readingSettings,
    required this.bedtime,
    required this.highlightedSentence,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;
  final ChildReadingSettings readingSettings;
  final bool bedtime;
  final int? highlightedSentence;

  @override
  /// Switches between stacked phone content and a desktop two-column spread.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustration = _PageIllustration(
          story: story,
          page: page,
          profile: profile,
          bedtime: bedtime,
        );
        final prose = _StoryProse(
          story: story,
          page: page,
          readingSettings: readingSettings,
          bedtime: bedtime,
          highlightedSentence: highlightedSentence,
        );
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
    required this.bedtime,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildProfile? profile;
  final bool bedtime;

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
          if (bedtime)
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

  /// Keeps placeholder art stable for each selected illustration style.
  LinearGradient _pageGradient() {
    final primary = AppTheme.primaryFor(story.content.request.gender);
    final secondary = AppTheme.secondaryFor(story.content.request.gender);
    return switch (story.content.request.presentation.style) {
      IllustrationStyle.pictureBook => LinearGradient(
        colors: <Color>[primary, secondary],
      ),
      IllustrationStyle.watercolor => LinearGradient(
        colors: <Color>[secondary, primary.withValues(alpha: 0.78)],
      ),
      IllustrationStyle.colorful3d => LinearGradient(
        colors: <Color>[primary, secondary, const Color(0xFF8A31CB)],
      ),
    };
  }
}

/// Scrollable story prose with language-specific direction and alignment.
class _StoryProse extends StatelessWidget {
  /// Creates prose for one page without inheriting the interface direction.
  const _StoryProse({
    required this.story,
    required this.page,
    required this.readingSettings,
    required this.bedtime,
    required this.highlightedSentence,
  });

  final StoryBook story;
  final StoryPage page;
  final ChildReadingSettings readingSettings;
  final bool bedtime;
  final int? highlightedSentence;

  @override
  /// Applies right-to-left direction only when the story language is Arabic.
  ///
  /// The child's saved size and font, and the optional bedtime palette, both
  /// travel through the single prose style so highlighting composes with them
  /// in either text direction.
  Widget build(BuildContext context) {
    final language = story.content.request.presentation.language;
    final direction = language == AppLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Card(
        color: bedtime ? AppTheme.bedtimeSurface : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                story.content.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: bedtime ? AppTheme.bedtimeProse : null,
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
      settings: readingSettings,
      language: language,
    );
    return bedtime ? style.copyWith(color: AppTheme.bedtimeProse) : style;
  }

  /// Tints the sentence being spoken without rewriting the child's story text.
  ///
  /// The narrated sentence is located by offset inside the original page text,
  /// so the rendered prose stays character-for-character the same in both
  /// left-to-right and Arabic right-to-left layouts.
  InlineSpan _prose(BuildContext context) {
    final sentences = locateNarrationSentences(page.text);
    final index = highlightedSentence;
    if (index == null || index >= sentences.length) {
      return TextSpan(text: page.text);
    }
    final spoken = sentences[index];
    return TextSpan(
      children: <InlineSpan>[
        TextSpan(text: page.text.substring(0, spoken.start)),
        TextSpan(
          text: page.text.substring(spoken.start, spoken.end),
          style: TextStyle(
            backgroundColor: _highlightColor(context).withValues(alpha: 0.3),
            color: bedtime
                ? AppTheme.bedtimeProse
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: page.text.substring(spoken.end)),
      ],
    );
  }

  /// Keeps the spoken-sentence tint warm while bedtime mode is on.
  Color _highlightColor(BuildContext context) {
    return bedtime ? AppTheme.amber : Theme.of(context).colorScheme.primary;
  }
}

/// Reader actions kept outside story direction so controls follow app locale.
class _ReaderControls extends StatelessWidget {
  /// Creates controls for the current reader position and narration state.
  const _ReaderControls({required this.status, required this.actions});

  final _ReaderStatus status;
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _stackedControlsWidth) {
              return _stacked(text);
            }
            return _inline(text);
          },
        ),
      ),
    );
  }

  /// Width below which progress moves above the buttons on a small phone.
  ///
  /// Raised when bedtime mode joined the row so a mid-size phone keeps the
  /// page progress readable instead of squeezing it between buttons.
  static const _stackedControlsWidth = 560.0;

  /// Single row used whenever every control still keeps a full touch target.
  Widget _inline(AppLocalizations text) {
    return Row(
      children: <Widget>[
        _previousButton(text),
        Expanded(child: _progress(text)),
        ..._middleButtons(text),
        const SizedBox(width: 8),
        _nextButton(text),
      ],
    );
  }

  /// Two-row fallback that keeps 48 px controls usable on a 360 px phone.
  ///
  /// The action row wraps rather than overflowing, so the narrowest supported
  /// phone can show every control at full size even while narration runs.
  Widget _stacked(AppLocalizations text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _progress(text),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _previousButton(text),
            ..._middleButtons(text),
            _nextButton(text),
          ],
        ),
      ],
    );
  }

  /// Export, bedtime, narration settings, and the play/pause pair with stop.
  List<Widget> _middleButtons(AppLocalizations text) {
    return <Widget>[
      IconButton(
        onPressed: status.exporting ? null : actions.export,
        tooltip: status.exporting ? text.exportingPdf : text.exportPdf,
        icon: status.exporting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_rounded),
      ),
      IconButton(
        onPressed: actions.bedtime,
        tooltip: status.bedtime ? text.turnOffBedtimeMode : text.bedtimeMode,
        isSelected: status.bedtime,
        icon: Icon(
          status.bedtime ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          color: status.bedtime ? AppTheme.amber : null,
        ),
      ),
      IconButton(
        onPressed: actions.narrationSettings,
        tooltip: text.narrationSettings,
        icon: const Icon(Icons.tune_rounded),
      ),
      if (status.playback != NarrationPlayback.idle)
        IconButton(
          onPressed: actions.stopNarration,
          tooltip: text.stopNarration,
          icon: const Icon(Icons.stop_rounded),
        ),
      IconButton.filledTonal(
        onPressed: actions.narration,
        tooltip: _narrationTooltip(text),
        icon: Icon(_narrationIcon()),
      ),
    ];
  }

  /// Localizes the play, pause, or resume meaning of the main narration button.
  String _narrationTooltip(AppLocalizations text) {
    return switch (status.playback) {
      NarrationPlayback.playing => text.pauseNarration,
      NarrationPlayback.paused => text.resumeNarration,
      NarrationPlayback.idle => text.playNarration,
    };
  }

  /// Mirrors the narration state so the control never lies about what it does.
  IconData _narrationIcon() {
    return switch (status.playback) {
      NarrationPlayback.playing => Icons.pause_rounded,
      NarrationPlayback.paused => Icons.play_arrow_rounded,
      NarrationPlayback.idle => Icons.volume_up_rounded,
    };
  }

  /// Shows the reader position in the current interface language.
  Widget _progress(AppLocalizations text) {
    return Text(
      text.pageProgress(status.pageIndex + 1, status.pageCount),
      textAlign: TextAlign.center,
    );
  }

  /// Backward navigation, disabled on the first page.
  Widget _previousButton(AppLocalizations text) {
    return IconButton(
      onPressed: actions.navigation.previous,
      tooltip: text.previousPage,
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  /// Forward navigation, disabled on the last page.
  Widget _nextButton(AppLocalizations text) {
    return IconButton(
      onPressed: actions.navigation.next,
      tooltip: text.nextPage,
      icon: const Icon(Icons.arrow_forward_rounded),
    );
  }
}

/// Immutable values needed to render the reader control bar.
class _ReaderStatus {
  /// Groups page progress and narration state into one control input.
  const _ReaderStatus({
    required this.pageIndex,
    required this.pageCount,
    required this.playback,
    required this.exporting,
    required this.bedtime,
  });

  final int pageIndex;
  final int pageCount;
  final NarrationPlayback playback;
  final bool exporting;
  final bool bedtime;
}

/// User commands exposed by the reader control bar.
class _ReaderActions {
  /// Groups navigation and narration commands without boolean action flags.
  const _ReaderActions({
    required this.navigation,
    required this.narration,
    required this.stopNarration,
    required this.narrationSettings,
    required this.bedtime,
    required this.export,
  });

  final _ReaderNavigation navigation;
  final VoidCallback narration;
  final VoidCallback stopNarration;
  final VoidCallback narrationSettings;
  final VoidCallback bedtime;
  final VoidCallback export;
}

/// Optional page movement commands grouped for the reader control bar.
class _ReaderNavigation {
  /// Creates movement callbacks disabled at the beginning and end.
  const _ReaderNavigation({required this.previous, required this.next});

  final VoidCallback? previous;
  final VoidCallback? next;
}

/// Immutable narration choices returned only after dialog confirmation.
class _NarrationSelection {
  /// Groups speech pace, scope, and bedtime limit as one dialog value.
  const _NarrationSelection({
    required this.speed,
    required this.scope,
    required this.sleepTimer,
    this.sleepTimerChosen = false,
    this.remainingSleep,
  });

  final NarrationSpeed speed;
  final NarrationScope scope;
  final NarrationSleepTimer sleepTimer;

  /// Whether the parent touched the sleep timer in this dialog.
  ///
  /// Bedtime mode only suggests a limit; an explicit choice always wins.
  final bool sleepTimerChosen;

  final Duration? remainingSleep;
}

/// Session-only narration controls that do not alter a child's saved profile.
class _NarrationSettingsDialog extends StatefulWidget {
  /// Creates settings from the reader's current narration choices.
  const _NarrationSettingsDialog({required this.selection});

  final _NarrationSelection selection;

  @override
  /// Creates a disposable edit buffer for pace and spoken scope.
  State<_NarrationSettingsDialog> createState() {
    return _NarrationSettingsDialogState();
  }
}

/// Holds uncommitted narration choices until the reader confirms them.
class _NarrationSettingsDialogState extends State<_NarrationSettingsDialog> {
  late NarrationSpeed _speed;
  late NarrationScope _scope;
  late NarrationSleepTimer _sleepTimer;
  bool _sleepTimerChosen = false;

  @override
  /// Copies reader values so dismissing the dialog changes nothing.
  void initState() {
    super.initState();
    _speed = widget.selection.speed;
    _scope = widget.selection.scope;
    _sleepTimer = widget.selection.sleepTimer;
  }

  @override
  /// Composes localized choice chips and explicit cancel/apply actions.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.narrationSettings),
      content: SingleChildScrollView(child: _content(text)),
      actions: _actions(text),
    );
  }

  /// Separates pace, spoken scope, and bedtime limit into scannable sections.
  Widget _content(AppLocalizations text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(text.narrationSpeed),
        const SizedBox(height: 8),
        _speedChoices(text),
        const SizedBox(height: 20),
        Text(text.narrationScope),
        const SizedBox(height: 8),
        _scopeChoices(text),
        const SizedBox(height: 20),
        Text(text.sleepTimer),
        const SizedBox(height: 8),
        _sleepTimerChoices(text),
        ..._remainingSleep(text),
      ],
    );
  }

  /// Builds the off, five, ten, and twenty minute bedtime limits.
  Widget _sleepTimerChoices(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NarrationSleepTimer.values
          .map((timer) {
            return ChoiceChip(
              key: ValueKey<String>('sleep-timer-${timer.name}'),
              selected: _sleepTimer == timer,
              onSelected: (_) => setState(() {
                _sleepTimer = timer;
                _sleepTimerChosen = true;
              }),
              label: Text(_sleepTimerLabel(text, timer)),
            );
          })
          .toList(growable: false),
    );
  }

  /// Shows how long a running countdown still has, rounded up to whole minutes.
  List<Widget> _remainingSleep(AppLocalizations text) {
    final remaining = widget.selection.remainingSleep;
    if (remaining == null || _sleepTimer != widget.selection.sleepTimer) {
      return const <Widget>[];
    }
    final minutes = (remaining.inSeconds / Duration.secondsPerMinute).ceil();
    return <Widget>[
      const SizedBox(height: 10),
      Text(
        text.sleepTimerRemaining(minutes),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  /// Builds pace choices from the bounded platform-safe enum values.
  Widget _speedChoices(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NarrationSpeed.values
          .map((speed) {
            return ChoiceChip(
              selected: _speed == speed,
              onSelected: (_) => setState(() => _speed = speed),
              label: Text(_speedLabel(text, speed)),
            );
          })
          .toList(growable: false),
    );
  }

  /// Builds visible-page and remaining-story speech scope choices.
  Widget _scopeChoices(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NarrationScope.values
          .map((scope) {
            return ChoiceChip(
              selected: _scope == scope,
              onSelected: (_) => setState(() => _scope = scope),
              label: Text(_scopeLabel(text, scope)),
            );
          })
          .toList(growable: false),
    );
  }

  /// Returns cancel and apply actions without saving dismissed changes.
  List<Widget> _actions(AppLocalizations text) {
    return <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(text.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(
          _NarrationSelection(
            speed: _speed,
            scope: _scope,
            sleepTimer: _sleepTimer,
            sleepTimerChosen: _sleepTimerChosen,
          ),
        ),
        child: Text(text.applyNarrationSettings),
      ),
    ];
  }

  /// Localizes one bedtime limit without duplicating its stored minutes.
  String _sleepTimerLabel(AppLocalizations text, NarrationSleepTimer timer) {
    final duration = timer.duration;
    return duration == null
        ? text.sleepTimerOff
        : text.sleepTimerMinutes(duration.inMinutes);
  }

  /// Localizes one device narration pace.
  String _speedLabel(AppLocalizations text, NarrationSpeed speed) {
    return switch (speed) {
      NarrationSpeed.slow => text.slowSpeed,
      NarrationSpeed.normal => text.normalSpeed,
      NarrationSpeed.fast => text.fastSpeed,
    };
  }

  /// Localizes one reader narration scope.
  String _scopeLabel(AppLocalizations text, NarrationScope scope) {
    return switch (scope) {
      NarrationScope.currentPage => text.currentPage,
      NarrationScope.remainingStory => text.remainingStory,
    };
  }
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
