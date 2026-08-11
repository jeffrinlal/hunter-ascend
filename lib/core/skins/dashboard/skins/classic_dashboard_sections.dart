import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';

/// The "no skin" implementation. Never actually invoked to build a widget —
/// every resolver in `skin_dashboard_sections.dart` special-cases
/// `sections is ClassicDashboardSections` and returns the tier's own
/// existing `fallback` widget directly instead. This class exists purely so
/// [DashboardSkinSections] has a complete, type-safe set of implementations
/// and so the resolver's `switch` in `_resolverFor` is exhaustive.
///
/// If one of these methods is ever reached, that is a bug in the resolver
/// (not a valid skin state) — hence the explicit [UnsupportedError] rather
/// than silently rendering an empty box, which would be much harder to spot.
class ClassicDashboardSections implements DashboardSkinSections {
  const ClassicDashboardSections();

  @override
  Widget hero(HeroSectionData data) => throw UnsupportedError(
      'ClassicDashboardSections.hero should never be called — the resolver '
      'must render the tier fallback widget directly for Classic.');

  @override
  Widget quest(QuestSectionData data) => throw UnsupportedError(
      'ClassicDashboardSections.quest should never be called — the resolver '
      'must render the tier fallback widget directly for Classic.');

  @override
  Widget stats(StatsSectionData data) => throw UnsupportedError(
      'ClassicDashboardSections.stats should never be called — the resolver '
      'must render the tier fallback widget directly for Classic.');

  @override
  Widget water(WaterSectionData data) => throw UnsupportedError(
      'ClassicDashboardSections.water should never be called — the resolver '
      'must render the tier fallback widget directly for Classic.');

  @override
  Widget quickActions(QuickActionsSectionData data) => throw UnsupportedError(
      'ClassicDashboardSections.quickActions should never be called — the '
      'resolver must render the tier fallback widget directly for Classic.');
}
