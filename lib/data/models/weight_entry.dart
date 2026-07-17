import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'weight_entry.g.dart';

/// A single weight history entry.
@HiveType(typeId: 1)
class WeightEntry {
  const WeightEntry({
    required this.weight,
    required this.date,
  });

  @HiveField(0) final double weight;
  @HiveField(1) final String date; // ISO 8601 string

  /// Creates a [WeightEntry] from a Firestore document.
  factory WeightEntry.fromFirestore(Map<String, dynamic> data) {
    final dateRaw = data['date'];
    String dateStr;
    if (dateRaw is Timestamp) {
      dateStr = dateRaw.toDate().toIso8601String();
    } else if (dateRaw is String) {
      dateStr = dateRaw;
    } else {
      dateStr = DateTime.now().toIso8601String();
    }

    return WeightEntry(
      weight: ((data['weight'] ?? 0) as num).toDouble(),
      date: dateStr,
    );
  }

  /// Parsed DateTime from the stored ISO string.
  DateTime get dateTime => DateTime.parse(date);
}
