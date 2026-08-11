# Skin Assets

Placeholder structure for Phase 3+ real skin art. No files here are wired
into `pubspec.yaml` yet — `SkinData.previewAssetPath` (see
`lib/core/skins/skin_data.dart`) already points at these paths so a future
phase can drop in real files without any code changes.

```
assets/skins/
  classic/preview.png
  shadow_monarch/preview.png
  cyber_hunter/preview.png
  frostborn/preview.png
  inferno/preview.png
```

Until real art exists, every screen renders skin identity structurally
(shape, border, motion, corner emblem) via `SkinAwareSurface` — see
`lib/core/skins/skin_aware_surface.dart` — using only the app's existing
theme colors. No screen currently reads an image from this folder.
