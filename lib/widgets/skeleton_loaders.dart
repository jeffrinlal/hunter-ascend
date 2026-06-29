import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer skeleton loaders shown while Firebase data loads.
/// Base color: #E0E0E0, Highlight: #FFF0E8 (light orange), left-to-right.

const Color _skeletonBase = Color(0xFFE0E0E0);
const Color _skeletonHighlight = Color(0xFFFFF0E8);

Widget _shimmerWrap(Widget child) => Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      direction: ShimmerDirection.ltr,
      child: child,
    );

Widget _box({double? width, double height = 16, double radius = 8}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

Widget _circle(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );

/// Dashboard skeleton: profile card, level/XP bar, stats row,
/// mission card, water card, nutrition/map buttons.
Widget buildDashboardSkeleton() {
  return _shimmerWrap(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile card: circle avatar + 2 bars (name/rank)
        Row(
          children: [
            _circle(64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 150, height: 16),
                  const SizedBox(height: 10),
                  _box(width: 90, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Level / XP bar
        _box(height: 14, radius: 7),
        const SizedBox(height: 20),
        // Stats row (3 boxes)
        Row(
          children: [
            Expanded(child: _box(height: 72, radius: 12)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 72, radius: 12)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 72, radius: 12)),
          ],
        ),
        const SizedBox(height: 20),
        // Today's mission card
        _box(height: 90, radius: 16),
        const SizedBox(height: 16),
        // Water intake card
        _box(height: 120, radius: 16),
        const SizedBox(height: 16),
        // Nutrition / Map buttons
        Row(
          children: [
            Expanded(child: _box(height: 56, radius: 14)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 56, radius: 14)),
          ],
        ),
      ],
    ),
  );
}

/// Leaderboard skeleton: top-3 podium (3 boxes) + list of rows.
Widget buildLeaderboardSkeleton() {
  return _shimmerWrap(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Podium: 3 boxes, center elevated
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _box(height: 110, radius: 12)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 150, radius: 12)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 90, radius: 12)),
          ],
        ),
        const SizedBox(height: 24),
        // List rows (circle + 2 bars + trailing)
        ...List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                _circle(44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 140, height: 13),
                      const SizedBox(height: 8),
                      _box(width: 80, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _box(width: 40, height: 13),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Profile skeleton: circle avatar, name + rank bars, level/XP bar, stats.
Widget buildProfileSkeleton() {
  return _shimmerWrap(
    Column(
      children: [
        const SizedBox(height: 20),
        _circle(110),
        const SizedBox(height: 18),
        _box(width: 160, height: 18),
        const SizedBox(height: 10),
        _box(width: 100, height: 13),
        const SizedBox(height: 24),
        // Level / XP bar
        _box(height: 14, radius: 7),
        const SizedBox(height: 28),
        // Stats section: rows of bars
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _box(width: 50, height: 13),
                const SizedBox(width: 14),
                Expanded(child: _box(height: 12, radius: 6)),
                const SizedBox(width: 12),
                _box(width: 36, height: 13),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
