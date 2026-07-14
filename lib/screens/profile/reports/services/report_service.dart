import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hunter_ascend/services/membership_service.dart';

import '../models/report_data.dart';
import '../utils/report_format.dart';

/// Loads and derives all data the Hunter Report needs — read-only, on demand,
/// once per screen open. Reuses ONLY existing collections/fields/indexes.
class ReportService {
  ReportService._();

  /// Number of days the report can look back (hard cap — no yearly reports).
  static const int maxRangeDays = 30;

  /// Loads the last-30-days data set for [uid].
  ///
  /// Each collection is queried independently and wrapped so a single failure
  /// (e.g. a transient error or a missing composite index) degrades that one
  /// metric to "unavailable" instead of breaking the whole report.
  static Future<ReportData> load(String uid) async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: maxRangeDays));
    final cutoffStr = dayKey(cutoff);
    final db = FirebaseFirestore.instance;

    // ── Nutrition (calorie_logs) ──
    // `date` is a 'yyyy-MM-dd' string that sorts chronologically, so a lexical
    // range is a valid 30-day window (served by the existing uid/date index).
    List<MealEntry> meals = [];
    bool nutritionOk = true;
    try {
      final snap = await db
          .collection('calorie_logs')
          .where('uid', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: cutoffStr)
          .get();
      meals = snap.docs.map((d) {
        final m = d.data();
        return MealEntry(
          calories: _asInt(m['calories']),
          protein: _asDouble(m['protein']),
          carbs: _asDouble(m['carbs']),
          fat: _asDouble(m['fat']),
          time: (m['time'] as Timestamp?)?.toDate() ?? now,
        );
      }).toList();
    } catch (_) {
      nutritionOk = false;
    }

    // ── Running (runs) ──
    // Reuses the exact (uid, createdAt desc) query shape used by map_screen,
    // so no new composite index is required. Collection is capped at 10.
    List<RunEntry> runs = [];
    bool runsOk = true;
    try {
      final snap = await db
          .collection('runs')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      runs = snap.docs
          .map((d) {
            final r = d.data();
            return RunEntry(
              distanceKm: _asDouble(r['distanceKm']),
              durationSeconds: _asInt(r['durationSeconds']),
              caloriesBurned: _asInt(r['caloriesBurned']),
              xpEarned: _asInt(r['xpEarned']),
              createdAt: (r['createdAt'] as Timestamp?)?.toDate() ?? now,
            );
          })
          .where((r) => r.createdAt.isAfter(cutoff))
          .toList();
    } catch (_) {
      runsOk = false;
    }

    // ── Weight (weight_history) ──
    // Reuses the existing (uid, date desc) query shape used by the profile.
    List<WeightEntry> weights = [];
    bool weightOk = true;
    try {
      final snap = await db
          .collection('weight_history')
          .where('uid', isEqualTo: uid)
          .orderBy('date', descending: true)
          .get();
      weights = snap.docs.map((d) {
        final w = d.data();
        return WeightEntry(
          weight: _asDouble(w['weight']),
          date: (w['date'] as Timestamp?)?.toDate() ?? now,
        );
      }).toList();
    } catch (_) {
      weightOk = false;
    }

    return ReportData(
      meals: meals,
      runs: runs,
      weights: weights,
      nutritionOk: nutritionOk,
      runsOk: runsOk,
      weightOk: weightOk,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return 0;
  }
}

/// Membership resolution for the report.
///
/// Uses ONLY the current `membershipType` field (never the legacy `membership`
/// field), applying the same expiry rule as [MembershipService]: a premium
/// tier whose `membershipExpiry` is in the past is treated as Basic. Reading
/// the value straight off the live hunter document keeps the gate reactive to
/// Firestore changes without depending on the service cache.
class ReportMembership {
  ReportMembership._();

  /// Effective tier from the live hunter document (current field only).
  /// A premium tier with an expired expiry is treated as Basic.
  static MembershipTier effectiveTier(Map<String, dynamic> data) {
    final stored = MembershipTier.fromString(data['membershipType']?.toString());
    if (stored == MembershipTier.basic) return MembershipTier.basic;
    final expiry = _parseExpiry(data['membershipExpiry']);
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return MembershipTier.basic;
    }
    return stored;
  }

  /// Whether the hunter currently has an active Pro or Max membership.
  static bool isPremium(Map<String, dynamic> data) =>
      effectiveTier(data) != MembershipTier.basic;

  /// Display label: "Basic" / "Pro" / "Max".
  static String label(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.pro:
        return 'Pro';
      case MembershipTier.max:
        return 'Max';
      case MembershipTier.basic:
        return 'Basic';
    }
  }

  static DateTime? _parseExpiry(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
