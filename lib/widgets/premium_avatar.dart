import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

class PremiumAvatar extends StatelessWidget {
  final String membership;
  final double radius;
  final ImageProvider? image;
  final Widget? child;

  const PremiumAvatar({
    super.key,
    required this.membership,
    required this.radius,
    this.image,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tier = membership.toLowerCase();

    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadows = [];

    switch (tier) {
      case 'max':
        borderColor = HunterTheme.purple;
        borderWidth = 3;
        shadows = [
          BoxShadow(
            color: HunterTheme.purple.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: HunterTheme.gold.withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ];
        break;

      case 'pro':
        borderColor = HunterTheme.gold;
        borderWidth = 2.5;
        shadows = [
          BoxShadow(
            color: HunterTheme.gold.withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ];
        break;

      default:
        borderColor = HunterTheme.border;
        borderWidth = 1.2;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: HunterTheme.surface,
        backgroundImage: image,
        child: image == null ? child : null,
      ),
    );
  }
}