import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'custom_quest.g.dart';

/// A user-created custom quest from the `custom_quests` collection.
@HiveType(typeId: 2)
class CustomQuest {
  const CustomQuest({
    required this.id,
    required this.uid,
    required this.name,
    this.xp = 0,
    this.createdAt,
  });

  /// Firestore document ID (used for delete operations).
  @HiveField(0) final String id;

  /// Owner UID.
  @HiveField(1) final String uid;

  /// Quest name displayed in the UI.
  @HiveField(2) final String name;

  /// XP reward (currently always 0 for custom quests).
  @HiveField(3) final int xp;

  /// When the quest was created (ISO string).
  @HiveField(4) final String? createdAt;

  /// Creates a [CustomQuest] from a Firestore document snapshot.
  factory CustomQuest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    String? createdAtStr;
    if (ts is Timestamp) {
      createdAtStr = ts.toDate().toIso8601String();
    }

    return CustomQuest(
      id: doc.id,
      uid: (data['uid'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      xp: (data['xp'] ?? 0) as int,
      createdAt: createdAtStr,
    );
  }
}
