# ══════════════════════════════════════════════════════════════════════════════
# ProGuard / R8 rules for AdMob mediation adapters
# ══════════════════════════════════════════════════════════════════════════════

# ── Meta Audience Network ─────────────────────────────────────────────────────
-keep class com.facebook.ads.** { *; }
-keeppackagenames com.facebook.*
-dontwarn com.facebook.ads.**

# ── Liftoff Monetize (Vungle) ─────────────────────────────────────────────────
-keep class com.vungle.ads.** { *; }
-dontwarn com.vungle.ads.**
-keepattributes *Annotation*

# ── Google Mobile Ads mediation adapters ──────────────────────────────────────
-keep class com.google.ads.mediation.** { *; }
-dontwarn com.google.ads.mediation.**

# ── Unity Ads (already integrated) ───────────────────────────────────────────
-keep class com.unity3d.ads.** { *; }
-dontwarn com.unity3d.ads.**

# ── InMobi (already integrated) ──────────────────────────────────────────────
-keep class com.inmobi.** { *; }
-dontwarn com.inmobi.**
