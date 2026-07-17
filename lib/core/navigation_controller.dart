import 'package:flutter/foundation.dart';

/// Global tab index notifier. Shared between MainShell and any pushed route
/// that displays the bottom navigation (e.g. CreateDuelScreen).
///
/// Values: 0=Home, 1=Missions, 2=Leaderboard, 3=Duels, 4=Profile.
final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);
