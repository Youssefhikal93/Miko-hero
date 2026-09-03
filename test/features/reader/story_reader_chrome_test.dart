import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the reader chrome a child reads the book through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[_profile()]),
      'story_library': jsonEncode(<Map<String, Object>>[_story()]),
    });
    appRouter.go('/story/story-1');
  });

  testWidgets('turning a page with the button moves the counter and the dot', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(_openDot(0), findsOneWidget);
    expect(_openDot(1), findsNothing);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(_openDot(1), findsOneWidget);
    expect(_openDot(0), findsNothing);

    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(_openDot(0), findsOneWidget);
  });

  testWidgets('swiping the book moves the counter and the dot', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(_openDot(1), findsOneWidget);
  });

  testWidgets('the reader offers its top row and its tool row', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    expect(find.text('Read to me'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Bedtime mode'), findsOneWidget);
    expect(find.byTooltip('Reading speed'), findsOneWidget);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    expect(find.byTooltip('Text size'), findsOneWidget);
    expect(find.byTooltip('Save PDF'), findsOneWidget);
  });

  testWidgets('the text size icon opens the hero saved prose size', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Text size'));
    await tester.pumpAndSettle();

    expect(_sizeSelected(tester, 'medium'), isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('reader-prose-size-large')),
    );
    await tester.pumpAndSettle();

    expect(_sizeSelected(tester, 'large'), isTrue);
    expect(_sizeSelected(tester, 'medium'), isFalse);
  });
}

/// The dot marking the page that is currently open.
Finder _openDot(int index) {
  return find.byKey(ValueKey<String>('page-dot-$index'));
}

/// Reports whether one prose size currently shows as selected.
bool _sizeSelected(WidgetTester tester, String size) {
  return tester
      .widget<ChoiceChip>(
        find.byKey(ValueKey<String>('reader-prose-size-$size')),
      )
      .selected;
}

/// One approved three-page book, so a middle page has a dot on both sides.
Map<String, Object> _story() {
  return <String, Object>{
    'id': 'story-1',
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': 'approved',
    'content': <String, Object>{
      'title': 'The moon garden',
      'request': <String, Object>{
        'profileId': 'miko',
        'heroName': 'Miko',
        'gender': 'girl',
        'prompt': <String, Object>{
          'theme': 'a moon garden',
          'moral': 'kindness',
          'preferences': const ChildStoryPreferences().toJson(),
        },
        'presentation': <String, Object>{
          'language': 'en',
          'length': 'short',
          'style': 'pictureBook',
        },
      },
      'pages': <Map<String, Object>>[
        <String, Object>{
          'number': 1,
          'text': 'Miko woke up.',
          'sceneDescription': 'a glowing garden',
        },
        <String, Object>{
          'number': 2,
          'text': 'She ran outside.',
          'sceneDescription': 'singing stars',
        },
        <String, Object>{
          'number': 3,
          'text': 'The garden closed.',
          'sceneDescription': 'a sleeping garden',
        },
      ],
    },
  };
}

/// One private child profile owning the story under test.
Map<String, Object> _profile() {
  return <String, Object>{
    'id': 'miko',
    'name': 'Miko',
    'age': 7,
    'photoBase64': _transparentPixel,
    'gender': 'girl',
  };
}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
