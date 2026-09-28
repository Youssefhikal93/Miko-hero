import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// The reader's three modal questions, each a value in and a value out.
///
/// Nothing here reads reader state, a provider, or a story: a dialog receives
/// the choice that is current now and answers with the choice the parent made,
/// or null when they cancelled. The reader page keeps deciding what to do with
/// the answer, which is what makes each dialog a plain round-trip to test.

/// Asks whether one PDF cover carries the hero's saved photo.
///
/// [current] is the answer the checkbox starts on and [childName] names the
/// hero in the question. Returns the confirmed choice, or null when the parent
/// cancelled and no file should be written.
Future<bool?> showExportOptionsDialog(
  BuildContext context, {
  required bool current,
  required String childName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) {
      return _ExportOptionsDialog(current: current, childName: childName);
    },
  );
}

/// Asks which prose size the hero reads at, starting from [current].
///
/// Returns the size showing when the dialog was closed, or null when it was
/// dismissed without an answer. The caller owns saving it.
Future<ReaderTextSize?> showTextSizeDialog(
  BuildContext context, {
  required ReaderTextSize current,
}) {
  return showDialog<ReaderTextSize>(
    context: context,
    builder: (_) => _TextSizeDialog(current: current),
  );
}

/// Asks for the session's speech pace, spoken scope, and bedtime limit.
///
/// Returns the applied [NarrationSelection], or null when the parent cancelled
/// and every current choice stands.
Future<NarrationSelection?> showNarrationSettingsDialog(
  BuildContext context, {
  required NarrationSelection current,
}) {
  return showDialog<NarrationSelection>(
    context: context,
    builder: (_) => _NarrationSettingsDialog(current: current),
  );
}

/// Immutable narration choices carried into and out of the settings dialog.
class NarrationSelection {
  /// Groups speech pace, scope, and bedtime limit as one dialog value.
  const NarrationSelection({
    required this.speed,
    required this.scope,
    required this.sleepTimer,
    this.sleepTimerChosen = false,
    this.remainingSleep,
  });

  /// Device speech pace the narration runs at.
  final NarrationSpeed speed;

  /// How much of the book one play action speaks.
  final NarrationScope scope;

  /// Bedtime limit after which narration stops on its own.
  final NarrationSleepTimer sleepTimer;

  /// Whether the parent touched the sleep timer in this dialog.
  ///
  /// Bedtime mode only suggests a limit; an explicit choice always wins. Always
  /// false on the way in, and meaningful only on the way out.
  final bool sleepTimerChosen;

  /// Time a running countdown still has, shown but never chosen here.
  final Duration? remainingSleep;
}

/// Export choices asked once per PDF, before any rendering work starts.
class _ExportOptionsDialog extends StatefulWidget {
  /// Creates the dialog for a hero who currently has a saved photo.
  const _ExportOptionsDialog({required this.current, required this.childName});

  final bool current;
  final String childName;

  @override
  /// Creates the checkbox state discarded when the dialog is dismissed.
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

/// Holds the cover-photo choice until the parent confirms or cancels.
class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  late bool _includePhoto;

  @override
  /// Copies the incoming answer so dismissing the dialog changes nothing.
  void initState() {
    super.initState();
    _includePhoto = widget.current;
  }

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

/// The hero's prose size, chosen without closing the book.
class _TextSizeDialog extends StatefulWidget {
  /// Creates the size chooser starting from the hero's saved size.
  const _TextSizeDialog({required this.current});

  final ReaderTextSize current;

  @override
  /// Creates the edit buffer the closing action hands back.
  State<_TextSizeDialog> createState() => _TextSizeDialogState();
}

/// Keeps the picked size visible in the chips until the dialog closes.
class _TextSizeDialogState extends State<_TextSizeDialog> {
  late ReaderTextSize _size;

  @override
  /// Copies the saved size so a dismissed dialog changes nothing.
  void initState() {
    super.initState();
    _size = widget.current;
  }

  @override
  /// Marks the chosen step at once and returns it when the parent is done.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.readerTextSize),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ReaderTextSize.values
            .map((size) {
              return ChoiceChip(
                key: ValueKey<String>('reader-prose-size-${size.name}'),
                selected: _size == size,
                onSelected: (_) => setState(() => _size = size),
                label: Text(_textSizeLabel(text, size)),
              );
            })
            .toList(growable: false),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(_size),
          child: Text(text.close),
        ),
      ],
    );
  }

  /// Localizes one prose size while keeping its stable storage name.
  String _textSizeLabel(AppLocalizations text, ReaderTextSize size) {
    return switch (size) {
      ReaderTextSize.small => text.textSizeSmall,
      ReaderTextSize.medium => text.textSizeMedium,
      ReaderTextSize.large => text.textSizeLarge,
      ReaderTextSize.extraLarge => text.textSizeExtraLarge,
    };
  }
}

/// Session-only narration controls that do not alter a child's saved profile.
class _NarrationSettingsDialog extends StatefulWidget {
  /// Creates settings from the reader's current narration choices.
  const _NarrationSettingsDialog({required this.current});

  final NarrationSelection current;

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
  /// Copies incoming values so dismissing the dialog changes nothing.
  void initState() {
    super.initState();
    _speed = widget.current.speed;
    _scope = widget.current.scope;
    _sleepTimer = widget.current.sleepTimer;
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
    final remaining = widget.current.remainingSleep;
    if (remaining == null || _sleepTimer != widget.current.sleepTimer) {
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
          NarrationSelection(
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
