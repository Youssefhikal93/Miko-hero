import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/reader/narration_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/hero_face.dart';

/// The reader's chrome above and below the open book.
///
/// Both rows are value in, callback out: [ReaderStatus] says where the child is
/// and what narration is doing, [ReaderActions] says what may be done about it,
/// and nothing here reads a story, a controller, or a provider. The reader page
/// keeps owning every one of those answers.

/// Immutable values needed to render the reader control bar.
class ReaderStatus {
  /// Groups page progress and narration state into one control input.
  const ReaderStatus({
    required this.pageIndex,
    required this.pageCount,
    required this.playback,
    required this.exporting,
  });

  /// Page the child has open, counted from zero.
  final int pageIndex;

  /// Pages the open book has in total.
  final int pageCount;

  /// What the sentence queue is doing right now.
  final NarrationPlayback playback;

  /// Whether a PDF is being written, which disables asking for another.
  final bool exporting;
}

/// User commands exposed by the reader control bar.
class ReaderActions {
  /// Groups navigation and narration commands without boolean action flags.
  const ReaderActions({
    required this.navigation,
    required this.narration,
    required this.stopNarration,
    required this.narrationSettings,
    required this.textSize,
    required this.export,
  });

  /// Page turns, each absent at the end of the book it points past.
  final ReaderNavigation navigation;

  /// Plays, pauses, or resumes narration, following the current playback.
  final VoidCallback narration;

  /// Ends narration and clears the spoken-sentence tint.
  final VoidCallback stopNarration;

  /// Opens the session's pace, spoken scope, and bedtime limit.
  final VoidCallback narrationSettings;

  /// Absent while the story's hero no longer has a local profile to save to.
  final VoidCallback? textSize;

  /// Asks the parent for a PDF of the open book.
  final VoidCallback export;
}

/// Optional page movement commands grouped for the reader control bar.
class ReaderNavigation {
  /// Creates movement callbacks disabled at the beginning and end.
  const ReaderNavigation({required this.previous, required this.next});

  /// Turns back one page, absent on the first page.
  final VoidCallback? previous;

  /// Turns on one page, absent on the last page.
  final VoidCallback? next;
}

/// Hero, exit, and bedtime row printed above the open book.
class ReaderTopRow extends StatelessWidget {
  /// Creates the top row for the child whose story is open.
  const ReaderTopRow({
    required this.profile,
    required this.bedtime,
    required this.onClose,
    required this.onBedtime,
    super.key,
  });

  /// Hero of the open story, absent once their profile has left this device.
  final ChildProfile? profile;

  /// Whether the session's bedtime palette is on.
  final bool bedtime;

  /// Leaves the book for the shelf.
  final VoidCallback onClose;

  /// Turns the session's bedtime palette on or off.
  final VoidCallback onBedtime;

  @override
  /// Keeps the exit and the bedtime toggle clear of mobile system insets.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: <Widget>[
            _HeroAvatar(profile: profile),
            const Spacer(),
            IconButton(
              onPressed: onClose,
              tooltip: text.close,
              icon: const Icon(AppIcons.close),
            ),
            IconButton(
              onPressed: onBedtime,
              tooltip: bedtime ? text.turnOffBedtimeMode : text.bedtimeMode,
              isSelected: bedtime,
              icon: Icon(
                AppIcons.bedtime,
                color: bedtime ? AppTheme.candle : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero's own face, ringed in their accent, drawn without a photo asset.
class _HeroAvatar extends StatelessWidget {
  /// Creates the avatar of the child this book belongs to.
  const _HeroAvatar({required this.profile});

  /// Face diameter that keeps the ringed circle at its 42 px reference.
  static const _faceSize = 34.0;

  final ChildProfile? profile;

  @override
  /// Falls back to the hero's initial when no reference photo is saved.
  Widget build(BuildContext context) {
    final hero = profile;
    if (hero == null) return const SizedBox.shrink();
    return Semantics(
      label: hero.name,
      child: HeroFace(
        profile: hero,
        size: _faceSize,
        ring: true,
        background: AppTheme.tile,
      ),
    );
  }
}

/// Reader actions kept outside story direction so controls follow app locale.
class ReaderControls extends StatelessWidget {
  /// Creates controls for the current reader position and narration state.
  const ReaderControls({
    required this.status,
    required this.actions,
    super.key,
  });

  /// Where the child is in the book and what narration is doing.
  final ReaderStatus status;

  /// What the child and the parent may ask of the open book.
  final ReaderActions actions;

  @override
  /// Stacks the page turns, the position, and the tools above system insets.
  ///
  /// Three short rows rather than one long one, so the narrowest supported
  /// phone keeps every control at a full touch target without wrapping.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: const BoxDecoration(
          color: AppTheme.sunken,
          border: Border(top: BorderSide(color: AppTheme.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _narrationRow(text),
            const SizedBox(height: 12),
            _progressRow(context, text),
            const SizedBox(height: 4),
            _toolRow(text),
          ],
        ),
      ),
    );
  }

  /// Page turns around the one control that reads the story aloud.
  ///
  /// The row follows the interface direction, so an Arabic reader turns pages
  /// with previous and next mirrored.
  Widget _narrationRow(AppLocalizations text) {
    return Row(
      children: <Widget>[
        _pageTurnButton(
          tooltip: text.previousPage,
          icon: AppIcons.previousPage,
          onPressed: actions.navigation.previous,
        ),
        const SizedBox(width: 12),
        Expanded(child: _readToMeButton(text)),
        if (status.playback != NarrationPlayback.idle) ...<Widget>[
          const SizedBox(width: 12),
          _pageTurnButton(
            tooltip: text.stopNarration,
            icon: AppIcons.narrationStop,
            onPressed: actions.stopNarration,
          ),
        ],
        const SizedBox(width: 12),
        _pageTurnButton(
          tooltip: text.nextPage,
          icon: AppIcons.nextPage,
          onPressed: actions.navigation.next,
        ),
      ],
    );
  }

  /// The wide candle control that starts, pauses, and resumes narration.
  Widget _readToMeButton(AppLocalizations text) {
    return Tooltip(
      message: _narrationTooltip(text),
      child: FilledButton.icon(
        onPressed: actions.narration,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.candle,
          foregroundColor: AppTheme.onCandle,
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        icon: Icon(_narrationIcon()),
        label: Text(_narrationLabel(text), overflow: TextOverflow.ellipsis),
      ),
    );
  }

  /// One outlined circular control beside the read-aloud button.
  Widget _pageTurnButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppTheme.hairline),
        minimumSize: const Size.square(46),
      ),
    );
  }

  /// Where the child is in the book, in words and in dots.
  Widget _progressRow(BuildContext context, AppLocalizations text) {
    return Row(
      children: <Widget>[
        Text(
          text.pageProgress(status.pageIndex + 1, status.pageCount),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedDeep),
        ),
        const Spacer(),
        _PageDots(pageIndex: status.pageIndex, pageCount: status.pageCount),
      ],
    );
  }

  /// Pace, bedtime limit, prose size, and the PDF the parent can save.
  Widget _toolRow(AppLocalizations text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          onPressed: actions.narrationSettings,
          tooltip: text.narrationSpeed,
          icon: const Icon(AppIcons.narrationSpeed),
        ),
        IconButton(
          onPressed: actions.narrationSettings,
          tooltip: text.sleepTimer,
          icon: const Icon(AppIcons.sleepTimer),
        ),
        IconButton(
          onPressed: actions.textSize,
          tooltip: text.readerTextSize,
          icon: const Icon(AppIcons.readerTextSize),
        ),
        IconButton(
          onPressed: status.exporting ? null : actions.export,
          tooltip: status.exporting ? text.exportingPdf : text.exportPdf,
          icon: status.exporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.savePdf),
        ),
      ],
    );
  }

  /// Localizes the play, pause, or resume meaning of the main narration button.
  String _narrationTooltip(AppLocalizations text) {
    return switch (status.playback) {
      NarrationPlayback.playing => text.pauseNarration,
      NarrationPlayback.paused => text.resumeNarration,
      NarrationPlayback.idle => text.playNarration,
    };
  }

  /// Names the invitation to listen, and what the control does once it runs.
  String _narrationLabel(AppLocalizations text) {
    return switch (status.playback) {
      NarrationPlayback.playing => text.pauseNarration,
      NarrationPlayback.paused => text.resumeNarration,
      NarrationPlayback.idle => text.readToMe,
    };
  }

  /// Mirrors the narration state so the control never lies about what it does.
  IconData _narrationIcon() {
    return switch (status.playback) {
      NarrationPlayback.playing => AppIcons.narrationPause,
      NarrationPlayback.paused => AppIcons.narrationPlay,
      NarrationPlayback.idle => AppIcons.narrationPlay,
    };
  }
}

/// The book's pages as dots, with the open one marked in candle.
class _PageDots extends StatelessWidget {
  /// Creates one dot per page of the open book.
  const _PageDots({required this.pageIndex, required this.pageCount});

  final int pageIndex;
  final int pageCount;

  @override
  /// Names only the current dot, the way the bottom bar names its active one.
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < pageCount; index++)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 5),
            child: index == pageIndex
                ? _PageDot(key: ValueKey<String>('page-dot-$index'), open: true)
                : const _PageDot(open: false),
          ),
      ],
    );
  }
}

/// One page mark, wider and warmer while its page is the one being read.
class _PageDot extends StatelessWidget {
  /// Creates a dot for a page that is either open or still waiting.
  const _PageDot({required this.open, super.key});

  final bool open;

  @override
  /// Keeps every dot on one baseline so only width and colour change.
  Widget build(BuildContext context) {
    return Container(
      width: open ? 22 : 14,
      height: 3,
      decoration: BoxDecoration(
        color: open ? AppTheme.candle : AppTheme.hairline,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
    );
  }
}
