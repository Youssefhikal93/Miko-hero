import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Opens a parent edit buffer for one story's collection labels.
Future<List<String>?> showStoryCollectionsDialog(
  BuildContext context,
  List<String> initialCollections,
) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) {
      return _StoryCollectionsDialog(initialCollections: initialCollections);
    },
  );
}

/// Disposable collection-name editor that returns only confirmed labels.
class _StoryCollectionsDialog extends StatefulWidget {
  /// Creates an edit buffer from current persisted collection names.
  const _StoryCollectionsDialog({required this.initialCollections});

  final List<String> initialCollections;

  @override
  /// Creates the text controller retained only during this modal.
  State<_StoryCollectionsDialog> createState() {
    return _StoryCollectionsDialogState();
  }
}

/// Parses comma or line-separated labels with bounded validation.
class _StoryCollectionsDialogState extends State<_StoryCollectionsDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  /// Seeds one label per line for readable editing on narrow screens.
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialCollections.join('\n'),
    );
  }

  @override
  /// Releases collection text as soon as the modal closes.
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  /// Explains limits and exposes a single multiline local input.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.manageCollections),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text.collectionsHint(maximumStoryCollections)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: text.collectionNames,
                hintText: text.collectionNamesHint,
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton(onPressed: _save, child: Text(text.saveCollections)),
      ],
    );
  }

  /// Parses, validates, and returns collection labels in parent-entered order.
  void _save() {
    final text = AppLocalizations.of(context);
    final collections = _normalizedCollections(_controller.text);
    final error = collections.length > maximumStoryCollections
        ? text.tooManyCollections(maximumStoryCollections)
        : collections.any(
            (name) => name.length > maximumStoryCollectionNameLength,
          )
        ? text.collectionNameTooLong(maximumStoryCollectionNameLength)
        : null;
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    context.pop(collections);
  }
}

/// Splits comma or line-separated names and removes case-insensitive duplicates.
List<String> _normalizedCollections(String text) {
  final collections = <String>[];
  final normalizedNames = <String>{};
  for (final value in text.split(RegExp('[,\n]'))) {
    final name = value.trim();
    if (name.isEmpty || !normalizedNames.add(name.toLowerCase())) continue;
    collections.add(name);
  }
  return collections;
}
