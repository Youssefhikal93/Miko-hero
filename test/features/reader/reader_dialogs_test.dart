import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/features/reader/reader_dialogs.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Verifies each reader dialog as the value round-trip it is.
///
/// Nothing here builds a reader, a story, or a seeded device: a dialog is
/// opened with the values that are current, driven the way a parent drives it,
/// and the value it hands back is the whole of what it did.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export options', () {
    testWidgets('confirming keeps the photo the question started on', (
      tester,
    ) async {
      final answer = await _answerOf<bool>(
        tester,
        (context) =>
            showExportOptionsDialog(context, current: true, childName: 'Miko'),
        (tester) async {
          expect(
            find.text("Include Miko's photo on the cover"),
            findsOneWidget,
          );
          await tester.tap(find.text('Save PDF'));
        },
      );

      expect(answer, isTrue);
    });

    testWidgets('clearing the checkbox returns a photo-free cover', (
      tester,
    ) async {
      final answer = await _answerOf<bool>(
        tester,
        (context) =>
            showExportOptionsDialog(context, current: true, childName: 'Miko'),
        (tester) async {
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save PDF'));
        },
      );

      expect(answer, isFalse);
    });

    testWidgets('a question that starts off stays off until it is ticked', (
      tester,
    ) async {
      final answer = await _answerOf<bool>(
        tester,
        (context) =>
            showExportOptionsDialog(context, current: false, childName: 'Miko'),
        (tester) async {
          expect(_checkbox(tester).value, isFalse);
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save PDF'));
        },
      );

      expect(answer, isTrue);
    });

    testWidgets('cancelling returns nothing at all', (tester) async {
      final answer = await _answerOf<bool>(
        tester,
        (context) =>
            showExportOptionsDialog(context, current: true, childName: 'Miko'),
        (tester) async {
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
        },
      );

      expect(answer, isNull);
    });
  });

  group('text size', () {
    testWidgets('the saved size is the one marked when the chooser opens', (
      tester,
    ) async {
      final answer = await _answerOf<ReaderTextSize>(
        tester,
        (context) =>
            showTextSizeDialog(context, current: ReaderTextSize.medium),
        (tester) async {
          expect(_sizeSelected(tester, ReaderTextSize.medium), isTrue);
          expect(_sizeSelected(tester, ReaderTextSize.large), isFalse);
          await tester.tap(find.text('Close'));
        },
      );

      expect(answer, ReaderTextSize.medium);
    });

    testWidgets('a picked size marks itself and comes back on closing', (
      tester,
    ) async {
      final answer = await _answerOf<ReaderTextSize>(
        tester,
        (context) =>
            showTextSizeDialog(context, current: ReaderTextSize.medium),
        (tester) async {
          await tester.tap(_sizeChip(ReaderTextSize.extraLarge));
          await tester.pumpAndSettle();
          expect(_sizeSelected(tester, ReaderTextSize.extraLarge), isTrue);
          expect(_sizeSelected(tester, ReaderTextSize.medium), isFalse);
          await tester.tap(find.text('Close'));
        },
      );

      expect(answer, ReaderTextSize.extraLarge);
    });

    testWidgets('dismissing the chooser returns nothing at all', (
      tester,
    ) async {
      final answer = await _answerOf<ReaderTextSize>(
        tester,
        (context) =>
            showTextSizeDialog(context, current: ReaderTextSize.medium),
        (tester) async {
          await tester.tap(_sizeChip(ReaderTextSize.small));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(4, 4));
        },
      );

      expect(answer, isNull);
    });
  });

  group('narration settings', () {
    testWidgets('applying hands back every current choice unchanged', (
      tester,
    ) async {
      final answer = await _answerOf<NarrationSelection>(
        tester,
        (context) => showNarrationSettingsDialog(
          context,
          current: const NarrationSelection(
            speed: NarrationSpeed.fast,
            scope: NarrationScope.remainingStory,
            sleepTimer: NarrationSleepTimer.twentyMinutes,
          ),
        ),
        (tester) async => tester.tap(find.text('Apply')),
      );

      expect(answer!.speed, NarrationSpeed.fast);
      expect(answer.scope, NarrationScope.remainingStory);
      expect(answer.sleepTimer, NarrationSleepTimer.twentyMinutes);
      expect(answer.sleepTimerChosen, isFalse);
    });

    testWidgets('pace, scope, and bedtime limit come back as one value', (
      tester,
    ) async {
      final answer = await _answerOf<NarrationSelection>(
        tester,
        (context) => showNarrationSettingsDialog(
          context,
          current: const NarrationSelection(
            speed: NarrationSpeed.normal,
            scope: NarrationScope.currentPage,
            sleepTimer: NarrationSleepTimer.off,
          ),
        ),
        (tester) async {
          await tester.tap(find.text('Slow'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('From this page to the end'));
          await tester.pumpAndSettle();
          await tester.tap(_timerChip(NarrationSleepTimer.fiveMinutes));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Apply'));
        },
      );

      expect(answer!.speed, NarrationSpeed.slow);
      expect(answer.scope, NarrationScope.remainingStory);
      expect(answer.sleepTimer, NarrationSleepTimer.fiveMinutes);
      expect(answer.sleepTimerChosen, isTrue);
    });

    testWidgets('a running countdown is reported until the limit changes', (
      tester,
    ) async {
      await _answerOf<NarrationSelection>(
        tester,
        (context) => showNarrationSettingsDialog(
          context,
          current: const NarrationSelection(
            speed: NarrationSpeed.normal,
            scope: NarrationScope.currentPage,
            sleepTimer: NarrationSleepTimer.tenMinutes,
            remainingSleep: Duration(minutes: 3, seconds: 30),
          ),
        ),
        (tester) async {
          expect(find.text('Narration stops in about 4 min.'), findsOneWidget);
          await tester.tap(_timerChip(NarrationSleepTimer.twentyMinutes));
          await tester.pumpAndSettle();
          expect(find.text('Narration stops in about 4 min.'), findsNothing);
          await tester.tap(find.text('Cancel'));
        },
      );
    });

    testWidgets('cancelling returns nothing at all', (tester) async {
      final answer = await _answerOf<NarrationSelection>(
        tester,
        (context) => showNarrationSettingsDialog(
          context,
          current: const NarrationSelection(
            speed: NarrationSpeed.normal,
            scope: NarrationScope.currentPage,
            sleepTimer: NarrationSleepTimer.off,
          ),
        ),
        (tester) async {
          await tester.tap(find.text('Fast'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
        },
      );

      expect(answer, isNull);
    });
  });
}

/// Opens one dialog, drives it, and returns exactly what it handed back.
///
/// The host is a bare localized app: the dialog under test is the only thing
/// on screen, so a value that comes back could only have come from it.
Future<T?> _answerOf<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext context) open,
  Future<void> Function(WidgetTester tester) drive,
) async {
  Future<T?>? answer;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () => answer = open(context),
              child: const Text('open'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await drive(tester);
  await tester.pumpAndSettle();

  return answer;
}

/// The one cover-photo checkbox the export question is asked through.
CheckboxListTile _checkbox(WidgetTester tester) {
  return tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
}

/// The chip standing for one prose size.
Finder _sizeChip(ReaderTextSize size) {
  return find.byKey(ValueKey<String>('reader-prose-size-${size.name}'));
}

/// Reports whether one prose size currently shows as selected.
bool _sizeSelected(WidgetTester tester, ReaderTextSize size) {
  return tester.widget<ChoiceChip>(_sizeChip(size)).selected;
}

/// The chip standing for one bedtime limit.
Finder _timerChip(NarrationSleepTimer timer) {
  return find.byKey(ValueKey<String>('sleep-timer-${timer.name}'));
}
