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
    this.profilePicture,
    this.membership,
    this.membershipExpiry,
    this.equippedBadgeId,
  });

  @HiveField(0) final String uid;
  @HiveField(1) final String hunterName;
  @HiveField(2) final int level;
  @HiveField(3) final int xp;
  @HiveField(4) final int weeklyXp;
  @HiveField(5) final int dailyXp;
  @HiveField(6) final String? profilePicture;
  @HiveField(7) final String? membership;
  @HiveField(8) final String? membershipExpiry;

  /// The single publicly-equipped badge id, or `null` if none equipped.
  /// Parsed straight from the `equippedBadgeId` field already present on
  /// every hunter document returned by the leaderboard query — no extra
  /// Firestore read is required to populate this.
  @HiveField(9) final String? equippedBadgeId;

  /// Creates a [LeaderboardEntry] from a Firestore document.
  factory LeaderboardEntry.fromFirestore(String docId, Map<String, dynamic> data) {
    return LeaderboardEntry(
      uid: docId,
      hunterName: (data['hunterName'] ?? 'Hunter').toString(),
      level: (data['level'] ?? 1) as int,
      xp: (data['xp'] ?? 0) as int,
      weeklyXp: (data['weeklyXp'] ?? 0) as int,
      dailyXp: (data['dailyXp'] ?? 0) as int,
      profilePicture: data['profilePicture'] as String?,
      membership: data['membershipType']?.toString() ?? data['membership']?.toString(),
      membershipExpiry: _parseExpiryToString(data['membershipExpiry']),
      equippedBadgeId: data['equippedBadgeId']?.toString(),
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
}
