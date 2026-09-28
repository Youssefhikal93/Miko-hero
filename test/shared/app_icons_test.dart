import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// The one icon family, held up by reading the sources the app ships.
void main() {
  test('no screen reaches for a Material icon of its own', () {
    final offenders = <String>[];

    for (final file in _librarySources()) {
      if (_isVocabulary(file)) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (_bareIcons.hasMatch(lines[index])) {
          offenders.add(
            '${_shortPath(file)}:${index + 1}: ${lines[index].trim()}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every glyph is named once in lib/shared/app_icons.dart. Add a '
          'concept there and use its name instead of writing Icons. here:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the vocabulary itself never leaves the rounded family', () {
    final vocabulary = _librarySources().firstWhere(_isVocabulary);
    final glyphs = _bareIcons
        .allMatches(vocabulary.readAsStringSync())
        .map((match) => match.group(1)!)
        .toSet();

    expect(glyphs, isNotEmpty);
    for (final glyph in glyphs) {
      expect(
        glyph.endsWith('_rounded'),
        isTrue,
        reason: 'Icons.$glyph is not the rounded variant of its glyph.',
      );
    }
  });

  test('a concept that once had two variants keeps only the rounded one', () {
    expect(AppIcons.delete, Icons.delete_outline_rounded);
    expect(AppIcons.bedtime, Icons.bedtime_rounded);
    expect(AppIcons.palette, Icons.palette_rounded);
    expect(AppIcons.illustrate, Icons.palette_rounded);
    expect(AppIcons.stories, Icons.auto_stories_rounded);
    expect(AppIcons.heroFamily, Icons.groups_2_rounded);
    expect(AppIcons.factCheck, Icons.fact_check_rounded);
    expect(AppIcons.sparkle, Icons.auto_awesome_rounded);
  });

  test('one action draws the same glyph wherever a parent meets it', () {
    // The shelf tile's overflow, the review screen's button and the profile
    // photo row all delete; the bottom bar and the creation button both create.
    expect(AppIcons.delete, isNot(AppIcons.deleteEverything));
    expect(AppIcons.favourite, isNot(AppIcons.notFavourite));
    expect(AppIcons.forgetDevice, AppIcons.removeDevice);
  });
}

/// Every Dart source the application itself ships.
List<File> _librarySources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

/// True for the one file allowed to name Material glyphs.
bool _isVocabulary(File file) {
  return _shortPath(file) == 'lib/shared/app_icons.dart';
}

/// Reads a path back in the one shape this test prints and compares.
String _shortPath(File file) => file.path.replaceAll(r'\', '/');

/// `Icons.something`, but never the `AppIcons.something` that replaced it.
final RegExp _bareIcons = RegExp(r'(?<![A-Za-z0-9_])Icons\.([a-z0-9_]+)');
