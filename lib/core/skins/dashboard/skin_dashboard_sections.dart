import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skins/classic_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skins/shadow_monarch_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skins/cyber_hunter_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skins/frostborn_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skins/inferno_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';

/// Per-skin factory contract for all 5 Dashboard sections. Every non-classic
/// skin implements exactly one of these; adding a 6th skin later means
/// creating one new file implementing this interface plus one new
/// `switch` case in [_resolverFor] below — never a new screen, never
/// touching Basic/Pro/Max's own layout files beyond the single resolver
/// call each already makes.
abstract class DashboardSkinSections {
  Widget hero(HeroSectionData data);
  Widget quest(QuestSectionData data);
  Widget stats(StatsSectionData data);
  Widget water(WaterSectionData data);
  Widget quickActions(QuickActionsSectionData data);
}

/// Public accessor for call sites that need to resolve a skin's section
/// implementations directly (bypassing the reactive `Skin*Section` widgets
/// above) — used by Quick Actions, whose fallback/skin branches need
/// different async-resolution strategies (see home_dashboard_screen.dart).
DashboardSkinSections dashboardSkinSectionsFor(SkinId id) => _resolverFor(id);

DashboardSkinSections _resolverFor(SkinId id) {
  switch (id) {
    case SkinId.classic:
      return const ClassicDashboardSections();
    case SkinId.shadowMonarch:
      return const ShadowMonarchDashboardSections();
    case SkinId.cyberHunter:
      return const CyberHunterDashboardSections();
    case SkinId.frostborn:
      return const FrostbornDashboardSections();
    case SkinId.inferno:
      return const InfernoDashboardSections();
  }
}

/// Resolves which [DashboardSkinSections] implementation is currently
/// active, reacting to both [SkinService.activeSkinNotifier] and
/// [SkinService.skinAppearanceActiveNotifier] (a skin never renders its
/// structure while suppressed in favor of a Premium Theme — see Phase 4,
/// not yet implemented, for how that suppression is triggered; this
/// resolver only *respects* the existing flag, it does not set it).
class _SkinSectionResolver extends StatelessWidget {
  const _SkinSectionResolver({required this.builder});

  final Widget Function(BuildContext context, DashboardSkinSections sections) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SkinId>(
      valueListenable: SkinService.instance.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SkinService.instance.skinAppearanceActiveNotifier,
          builder: (context, appearanceActive, __) {
            final effective = (appearanceActive && activeSkin != SkinId.classic)
                ? activeSkin
                : SkinId.classic;
            return builder(context, _resolverFor(effective));
          },
        );
      },
    );
  }
}

/// Public per-section entry points. Every tier's dashboard layout calls
/// exactly one of these per section, in place of directly instantiating its
/// own section widget. When Classic is active (or no skin is active), the
/// resolved [DashboardSkinSections.hero]/etc. is [ClassicDashboardSections],
/// whose implementation is REQUIRED to return [fallback] completely
/// unmodified — guaranteeing byte-for-byte identical rendering to the
/// pre-Phase-3 UI for every user who has never touched a skin.

class SkinHeroSection extends StatelessWidget {
  const SkinHeroSection({super.key, required this.data, required this.fallback});
  final HeroSectionData data;

  /// The tier's own existing hero widget (`_PremiumHero`, `_EliteHeroBanner`,
  /// or Basic's `_buildHunterCard()` result) — rendered as-is whenever no
  /// skin is active.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return _SkinSectionResolver(
      builder: (context, sections) =>
          sections is ClassicDashboardSections ? fallback : sections.hero(data),
    );
  }
}

class SkinQuestSection extends StatelessWidget {
  const SkinQuestSection({super.key, required this.data, required this.fallback});
  final QuestSectionData data;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return _SkinSectionResolver(
      builder: (context, sections) =>
          sections is ClassicDashboardSections ? fallback : sections.quest(data),
    );
  }
}

class SkinStatsSection extends StatelessWidget {
  const SkinStatsSection({super.key, required this.data, required this.fallback});
  final StatsSectionData data;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return _SkinSectionResolver(
      builder: (context, sections) =>
          sections is ClassicDashboardSections ? fallback : sections.stats(data),
    );
  }
}

class SkinWaterSection extends StatelessWidget {
  const SkinWaterSection({super.key, required this.data, required this.fallback});
  final WaterSectionData data;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return _SkinSectionResolver(
      builder: (context, sections) =>
          sections is ClassicDashboardSections ? fallback : sections.water(data),
    );
  }
}

class SkinQuickActionsSection extends StatelessWidget {
  const SkinQuickActionsSection({super.key, required this.data, required this.fallback});
  final QuickActionsSectionData data;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return _SkinSectionResolver(
      builder: (context, sections) =>
          sections is ClassicDashboardSections ? fallback : sections.quickActions(data),
    );
  }
}
