import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Premium marketplace UI kit for the Coin Shop.
///
/// ## Architecture rule this file follows
/// - **SHOP DESIGN** owns: layout, components, hierarchy, animation, feel.
/// - **PREMIUM THEME** owns: colors.
///
/// This file contains **no hardcoded color values**. Every color resolves
/// through [_T], a thin semantic alias over the existing `HunterTheme` /
/// `MembershipTheme` tokens — so switching Premium Theme (or membership
/// tier) recolors the entire shop automatically with no extra wiring.
///
/// Nothing here performs Firestore reads/writes, owns state that belongs to
/// the screen, or touches coin/purchase/unlock/ad logic. Every component is
/// presentational: it receives already-loaded values plus callbacks.

/// Semantic color roles for the shop. Zero literal colors.
class _T {
  _T._();

  static Color get bg => HunterTheme.background;
  static Color get panel => HunterTheme.cardColor;
  static Color get panelAlt => HunterTheme.surface;
  static Color get line => HunterTheme.border;

  static Color get accent => MembershipTheme.current.accent;
  static Color get accentAlt => MembershipTheme.current.accentAlt;
  static List<Color> get accentRamp => MembershipTheme.current.gradient;

  static Color get textStrong => HunterTheme.textPrimary;
  static Color get textSoft => HunterTheme.textSecondary;
  static Color get textFaint => HunterTheme.textTertiary;

  static Color get coin => HunterTheme.gold;
  static Color get owned => HunterTheme.success;
  static Color get warn => HunterTheme.danger;

  static double get glow => HunterTheme.glowStrength;
}

// ═══════════════════════════════════════════════════════════════════════
// Motion primitives (deliberately lightweight — no continuous animations)
// ═══════════════════════════════════════════════════════════════════════

/// One-shot staggered entrance (fade + rise). Runs once per mount and then
/// stops, so there is no ongoing ticker cost while browsing the shop.
class ShopEntrance extends StatefulWidget {
  const ShopEntrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<ShopEntrance> createState() => _ShopEntranceState();
}

class _ShopEntranceState extends State<ShopEntrance> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    // Cap the stagger so long grids never feel slow to appear.
    final ms = 20 * (widget.index.clamp(0, 8));
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _in ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Tap-scale press feedback. Used instead of a raw GestureDetector so every
/// interactive surface in the shop feels physical.
class ShopPressable extends StatefulWidget {
  const ShopPressable({super.key, required this.child, this.onTap, this.borderRadius = 20});
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<ShopPressable> createState() => _ShopPressableState();
}

class _ShopPressableState extends State<ShopPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════════

/// Premium marketplace header: back affordance, store title/subtitle, and a
/// prominent coin balance treated as the hero element.
class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key, required this.coins, required this.onBack});
  final int coins;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShopPressable(
            onTap: onBack,
            borderRadius: 14,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _T.panel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _T.line),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: _T.textSoft),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MARKETPLACE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _T.textStrong,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spend your spoils, Hunter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _T.textFaint,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CoinBalance(coins: coins),
        ],
      ),
    );
  }
}

class _CoinBalance extends StatelessWidget {
  const _CoinBalance({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_T.coin.withOpacity(0.20), _T.coin.withOpacity(0.07)],
        ),
        border: Border.all(color: _T.coin.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: _T.coin.withOpacity(0.16 * _T.glow), blurRadius: 14),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, size: 17, color: _T.coin),
          const SizedBox(width: 7),
          // Bounded so very large balances can never overflow the header.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$coins',
                maxLines: 1,
                style: TextStyle(color: _T.coin, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Category bar
// ═══════════════════════════════════════════════════════════════════════

class ShopCategory {
  const ShopCategory({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Horizontally scrollable premium chip selector with an animated selected
/// state. Scrolls rather than compressing, so labels never truncate awkwardly
/// on small phones.
class ShopCategoryBar extends StatelessWidget {
  const ShopCategoryBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ShopCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, i) => _chip(categories[i], i == selectedIndex, () => onSelect(i)),
      ),
    );
  }

  Widget _chip(ShopCategory c, bool selected, VoidCallback onTap) {
    return ShopPressable(
      onTap: onTap,
      borderRadius: 15,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: selected ? LinearGradient(colors: _T.accentRamp) : null,
          color: selected ? null : _T.panel,
          border: Border.all(color: selected ? Colors.transparent : _T.line),
          boxShadow: selected
              ? [BoxShadow(color: _T.accent.withOpacity(0.28 * _T.glow), blurRadius: 14, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(c.icon, size: 15, color: selected ? _onAccent : _T.textSoft),
            const SizedBox(width: 7),
            Text(
              c.label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? _onAccent : _T.textSoft,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Foreground for accent-filled surfaces. Mirrors the existing convention
  /// used by the Pro/Max dashboards for contrast on accent fills.
  static Color get _onAccent => MembershipTheme.isMax ? Colors.white : Colors.black;
}

// ═══════════════════════════════════════════════════════════════════════
// Shared card shell + parts
// ═══════════════════════════════════════════════════════════════════════

/// Base premium card surface used by every shop tile, so spacing, radius,
/// border and elevation stay consistent across categories.
class ShopCardShell extends StatelessWidget {
  const ShopCardShell({
    super.key,
    required this.child,
    this.highlight = false,
    this.highlightColor,
    this.onTap,
  });

  final Widget child;
  final bool highlight;
  final Color? highlightColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = highlightColor ?? _T.accent;
    return ShopPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _T.panel,
          border: Border.all(
            color: highlight ? hc.withOpacity(0.75) : _T.line,
            width: highlight ? 1.6 : 1,
          ),
          boxShadow: [
            if (highlight)
              BoxShadow(color: hc.withOpacity(0.16 * _T.glow), blurRadius: 16, offset: const Offset(0, 4))
            else
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Preview plate that sits at the top of every card. Gives items a
/// consistent "product shot" area instead of a bare emoji on a flat card.
class ShopPreviewPlate extends StatelessWidget {
  const ShopPreviewPlate({super.key, required this.child, this.tint});
  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? _T.accent;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.withOpacity(0.16), t.withOpacity(0.03)],
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Gold price chip.
class ShopPricePill extends StatelessWidget {
  const ShopPricePill({super.key, required this.price, this.dense = false});
  final int price;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 5),
      decoration: BoxDecoration(
        color: _T.coin.withOpacity(0.13),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _T.coin.withOpacity(0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, size: dense ? 11 : 12, color: _T.coin),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$price',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _T.coin, fontSize: dense ? 11 : 12.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small state badge ("EQUIPPED", "29d LEFT", "EXPIRED", ...).
class ShopStateBadge extends StatelessWidget {
  const ShopStateBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

enum ShopButtonStyle { filled, outline, muted, success }

/// Premium action button with a real ink ripple.
class ShopActionButton extends StatelessWidget {
  const ShopActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.style = ShopButtonStyle.filled,
    this.dense = false,
    this.tint,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final ShopButtonStyle style;
  final bool dense;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? _T.accent;

    late final Color fg;
    late final Color? bg;
    late final Gradient? grad;
    late final Color border;

    switch (style) {
      case ShopButtonStyle.filled:
        fg = ShopCategoryBar._onAccent;
        bg = null;
        grad = LinearGradient(colors: _T.accentRamp);
        border = Colors.transparent;
        break;
      case ShopButtonStyle.outline:
        fg = base;
        bg = base.withOpacity(0.10);
        grad = null;
        border = base.withOpacity(0.6);
        break;
      case ShopButtonStyle.success:
        fg = _T.owned;
        bg = _T.owned.withOpacity(0.13);
        grad = null;
        border = _T.owned.withOpacity(0.6);
        break;
      case ShopButtonStyle.muted:
        fg = _T.textFaint;
        bg = _T.line.withOpacity(0.4);
        grad = null;
        border = _T.line;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: dense ? 9 : 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: bg,
            gradient: grad,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 12 : 14, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: dense ? 10.5 : 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Earn coins panel
// ═══════════════════════════════════════════════════════════════════════

/// Compact premium "earn coins" banner. Collapsed by default (two options),
/// expanding only while the 2-ad sequence is mid-flight.
class ShopEarnCoinsPanel extends StatelessWidget {
  const ShopEarnCoinsPanel({
    super.key,
    required this.adsWatchedInSequence,
    required this.isEarning,
    required this.isLoadingSecondAd,
    required this.adReady,
    required this.adUnavailable,
    required this.onWatchOne,
    required this.onWatchTwo,
    required this.onWatchSecond,
    required this.onRetry,
    required this.onCancel,
  });

  final int adsWatchedInSequence;
  final bool isEarning;
  final bool isLoadingSecondAd;
  final bool adReady;
  final bool adUnavailable;
  final VoidCallback onWatchOne;
  final VoidCallback onWatchTwo;
  final VoidCallback onWatchSecond;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.coin.withOpacity(0.13), _T.panel],
        ),
        border: Border.all(color: _T.coin.withOpacity(0.35)),
      ),
      child: adsWatchedInSequence == 1 ? _sequence() : _collapsed(),
    );
  }

  Widget _collapsed() {
    final disabled = isEarning || !adReady;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _T.coin.withOpacity(0.16),
            border: Border.all(color: _T.coin.withOpacity(0.4)),
          ),
          child: Icon(Icons.play_arrow_rounded, size: 19, color: _T.coin),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EARN COINS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _T.coin, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4),
              ),
              const SizedBox(height: 2),
              Text(
                adReady ? 'Watch ads for instant coins' : 'Preparing ads…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _T.textFaint, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _rewardBtn('+20', disabled ? null : onWatchOne, disabled),
        const SizedBox(width: 7),
        _rewardBtn('+50', disabled ? null : onWatchTwo, disabled),
      ],
    );
  }

  Widget _rewardBtn(String label, VoidCallback? onTap, bool disabled) {
    return ShopPressable(
      onTap: onTap,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: disabled ? _T.line.withOpacity(0.4) : _T.coin.withOpacity(0.16),
          border: Border.all(color: disabled ? _T.line : _T.coin.withOpacity(0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_rounded, size: 12, color: disabled ? _T.textFaint : _T.coin),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: disabled ? _T.textFaint : _T.coin,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sequence() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 15, color: _T.owned),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ad 1 of 2 complete',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _T.owned, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
            ShopPressable(
              onTap: onCancel,
              borderRadius: 8,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _T.textFaint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (isLoadingSecondAd)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _T.coin),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading ad 2 of 2…',
                style: TextStyle(color: _T.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          )
        else if (adUnavailable)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ad 2 failed to load',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _T.warn, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ShopActionButton(
                label: 'RETRY',
                icon: Icons.refresh_rounded,
                style: ShopButtonStyle.outline,
                dense: true,
                onTap: onRetry,
              ),
            ],
          )
        else
          ShopActionButton(
            label: 'WATCH AD 2 OF 2  ·  +50',
            icon: Icons.play_arrow_rounded,
            dense: true,
            onTap: adReady ? onWatchSecond : null,
            style: adReady ? ShopButtonStyle.filled : ShopButtonStyle.muted,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Empty / gate states
// ═══════════════════════════════════════════════════════════════════════

class ShopEmptyState extends StatelessWidget {
  const ShopEmptyState({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _T.panel,
                border: Border.all(color: _T.line),
              ),
              child: Icon(icon, size: 26, color: _T.textFaint),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: _T.textStrong, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _T.textFaint, fontSize: 12, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
