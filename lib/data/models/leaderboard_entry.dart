import 'package:hive/hive.dart';

part 'leaderboard_entry.g.dart';

/// Lightweight model for a single leaderboard row.
///
/// Only stores fields needed for leaderboard display — much smaller than
/// the full HunterData model. ProfilePicture base64 is stored here because
/// the leaderboard needs to display avatars, but it's the only large field.
@HiveType(typeId: 3)
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.hunterName,
    required this.level,
    required this.xp,
    this.weeklyXp = 0,
    this.dailyXp = 0,
    this.dungeonScore = 0,
    this.profilePicture,
    this.membership,
    this.membershipExpiry,
    this.equippedBadgeId,
    this.equippedProfileEffect,
    this.effectExpiry,
  });

  @HiveField(0)
  final String uid;
  @HiveField(1)
  final String hunterName;
  @HiveField(2)
  final int level;
  @HiveField(3)
  final int xp;
  @HiveField(4)
  final int weeklyXp;
  @HiveField(5)
  final int dailyXp;

  /// Permanent ALL-TIME dungeon leaderboard score — incremented only when
  /// a dungeon clear reward is claimed. NEVER resets (no period key).
  @HiveField(10)
  final int dungeonScore;
  @HiveField(6)
  final String? profilePicture;
  @HiveField(7)
  final String? membership;
  @HiveField(8)
  final String? membershipExpiry;

  /// The single publicly-equipped badge id, or `null` if none equipped.
  /// Parsed straight from the `equippedBadgeId` field already present on
  /// every hunter document returned by the leaderboard query — no extra
  /// Firestore read is required to populate this.
  @HiveField(9)
  final String? equippedBadgeId;

  /// The currently equipped leaderboard effect id (e.g. 'effect_fire_aura'),
  /// or `null` if no effect is active. Parsed from `equippedProfileEffect`
  /// on the hunter document — no additional Firestore read is required.
  @HiveField(11)
  final String? equippedProfileEffect;

  /// ISO 8601 expiry timestamp of the equipped effect, or `null`. Effects are
  /// temporary (7 days via coins, 3 days via ad). An expired effect must NOT
  /// be rendered — the leaderboard checks this before applying the glow.
  @HiveField(12)
  final String? effectExpiry;

  /// Creates a [LeaderboardEntry] from a Firestore document.
  factory LeaderboardEntry.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return LeaderboardEntry(
      uid: docId,
      hunterName: (data['hunterName'] ?? 'Hunter').toString(),
      level: (data['level'] ?? 1) as int,
      xp: (data['xp'] ?? 0) as int,
      weeklyXp: (data['weeklyXp'] ?? 0) as int,
      dailyXp: (data['dailyXp'] ?? 0) as int,
      dungeonScore: (data['dungeonScore'] ?? 0) as int,
      profilePicture: data['profilePicture'] as String?,
      membership:
          data['membershipType']?.toString() ?? data['membership']?.toString(),
      membershipExpiry: _parseExpiryToString(data['membershipExpiry']),
      equippedBadgeId: data['equippedBadgeId']?.toString(),
      equippedProfileEffect: data['equippedProfileEffect']?.toString(),
      effectExpiry: _parseExpiryToString(data['effectExpiry']),
    );
  }

  static String? _parseExpiryToString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    // Timestamp from Firestore
    try {
      return (raw as dynamic).toDate().toIso8601String();
    } catch (_) {
      return raw.toString();
    }
  }

  /// Returns the equipped effect id ONLY if it has not expired. Expired
  /// effects must not be rendered — they are treated as if no effect is
  /// equipped. This avoids a per-row Firestore read just to check expiry;
  /// the data is already loaded in the entry.
  String? get activeEffect {
    if (equippedProfileEffect == null || equippedProfileEffect!.isEmpty) {
      return null;
    }
    if (effectExpiry == null) return null;
    final expiry = DateTime.tryParse(effectExpiry!);
    if (expiry == null) return null;
    if (DateTime.now().isAfter(expiry)) return null;
    return equippedProfileEffect;
  }
}
