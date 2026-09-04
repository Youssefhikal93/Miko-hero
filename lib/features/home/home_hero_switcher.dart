import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/hero_face.dart';

/// Home's header: who the app is reading as, and the way to change it.
///
/// The whole header is one tap target that opens the family switcher, so a
/// child can hand the app to a sibling without visiting a parent screen. The
/// switch itself runs through the existing active-profile command, which is
/// what makes every other screen follow along.
class HomeHeroHeader extends ConsumerWidget {
  /// Creates the header for one family and its currently active child.
  const HomeHeroHeader({
    required this.profiles,
    required this.activeProfile,
    super.key,
  });

  /// Every child of this family, in their stable persisted order.
  final List<ChildProfile> profiles;

  /// Child the app is reading as, absent until one has been chosen.
  final ChildProfile? activeProfile;

  @override
  /// Names the active child and keeps the switcher one tap away.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final profile = activeProfile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('home-hero-switcher'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => _switchHero(context, ref),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 12, 6),
          child: Row(
            children: <Widget>[
              HomeHeroAvatar(profile: profile),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(text.readingAs, style: AppTheme.overlineSoft),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            profile?.name ?? text.chooseHero,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(
                          AppIcons.expandMore,
                          size: 20,
                          color: AppTheme.mutedDeep,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the switcher and activates only a child the family picked.
  Future<void> _switchHero(BuildContext context, WidgetRef ref) async {
    final selectedProfile = await showModalBottomSheet<ChildProfile>(
      context: context,
      builder: (context) {
        return _HeroSwitcherSheet(
          profiles: profiles,
          activeProfileId: activeProfile?.id,
        );
      },
    );
    if (selectedProfile == null || selectedProfile.id == activeProfile?.id) {
      return;
    }
    try {
      await ref
          .read(profileControllerProvider)
          .activateProfile(selectedProfile.id);
    } on Exception {
      if (!context.mounted) return;
      final text = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}

/// One child's photo inside a ring drawn in that child's own accent.
class HomeHeroAvatar extends StatelessWidget {
  /// Creates the ringed avatar, or the neutral one before a child is active.
  const HomeHeroAvatar({required this.profile, this.radius = 19, super.key});

  /// Child whose locally stored photo fills the ring.
  final ChildProfile? profile;

  /// Photo radius; the ring is drawn just outside it.
  final double radius;

  @override
  /// Rings the photo in the child's own accent, or in the theme's before one.
  ///
  /// The active child's saved colour is exactly what the theme resolved its
  /// primary to, so the header ring is the accent while every child in the
  /// switcher still wears their own.
  Widget build(BuildContext context) {
    return HeroFace(
      profile: profile,
      size: radius * 2,
      ring: true,
      background: AppTheme.sunken,
      fallbackIcon: AppIcons.heroSilhouette,
      fallbackColor: AppTheme.mutedDeep,
    );
  }
}

/// The family list Home opens when the header is tapped.
class _HeroSwitcherSheet extends StatelessWidget {
  /// Creates the list of children this device holds a profile for.
  const _HeroSwitcherSheet({
    required this.profiles,
    required this.activeProfileId,
  });

  /// Children offered as the next active hero.
  final List<ChildProfile> profiles;

  /// Child currently active, marked in the list.
  final String? activeProfileId;

  @override
  /// Returns the picked child to the header instead of switching in place.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            child: Text(
              text.chooseHero,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...profiles.map((profile) {
            final active = profile.id == activeProfileId;
            return ListTile(
              key: ValueKey<String>('home-hero-${profile.id}'),
              onTap: () => Navigator.of(context).pop(profile),
              leading: HomeHeroAvatar(profile: profile, radius: 16),
              title: Text(profile.heroName),
              subtitle: Text(text.yearsOld(profile.age)),
              trailing: active
                  ? Icon(
                      AppIcons.activeHero,
                      color: Color(profile.themeColorValue),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
