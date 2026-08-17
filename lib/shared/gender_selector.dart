import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Required Girl/Boy choice shared by profile and story forms.
class GenderSelector extends StatelessWidget {
  /// Creates a two-option selector with form validation and no default choice.
  const GenderSelector({
    required this.selectedGender,
    required this.onSelected,
    required this.enabled,
    super.key,
  });

  /// Current parent choice, or null while a decision is still required.
  final ChildGender? selectedGender;

  /// Reports a deliberate Girl/Boy selection to the owning form.
  final ValueChanged<ChildGender> onSelected;

  /// Whether the parent can change the selection.
  final bool enabled;

  @override
  /// Presents localized labels and reports a missing choice during validation.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return FormField<ChildGender>(
      initialValue: selectedGender,
      validator: (gender) {
        return gender?.isSpecified == true ? null : text.genderRequired;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.genderTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<ChildGender>(
              emptySelectionAllowed: true,
              segments: <ButtonSegment<ChildGender>>[
                ButtonSegment<ChildGender>(
                  value: ChildGender.girl,
                  icon: const Icon(Icons.face_3_rounded),
                  label: Text(text.girl),
                ),
                ButtonSegment<ChildGender>(
                  value: ChildGender.boy,
                  icon: const Icon(Icons.face_6_rounded),
                  label: Text(text.boy),
                ),
              ],
              selected: selectedGender == null
                  ? const <ChildGender>{}
                  : <ChildGender>{selectedGender!},
              onSelectionChanged: enabled
                  ? (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      final gender = selection.single;
                      field.didChange(gender);
                      onSelected(gender);
                    }
                  : null,
            ),
            if (field.hasError) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}
