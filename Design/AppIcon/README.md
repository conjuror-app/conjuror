# Conjuror app icon

The production icon is `Conjuror/ConjurorGlass.icon`, composed in Apple Icon
Composer from 1024 px PNG layers rendered from the editable SVG artwork under
`Layers`.

The four imported groups are ordered back to front:

1. `01 Background` — opaque radial-gradient backplate with the soft portal,
   spark, and mote bloom plus the faint orbit trail
2. `02 Portal` — continuous rim-lit glass portal
3. `03 Spark` — crisp foreground core
4. `04 Mote` — crisp foreground core

The source artwork contains the intended gradients and broad optical bloom.
The production PNGs preserve SVG gradient and blur features that Icon Composer’s
SVG importer doesn’t retain reliably. Icon Composer owns the dynamic refraction,
specular highlights, and shadows.

## Visual idea

A nearly complete summoning ring implies both a portal and a subtle letter C.
The central spark is the conjured result. The single orbiting mote keeps the
mark directional while preserving a strong silhouette at small macOS icon
sizes.

## Icon Composer treatment

- Target integration: macOS; the document retains reusable shared square geometry
- Portal: one continuous rim-lit gradient layer; 40% translucency, specular
  highlight, 45% neutral shadow
- Spark: its own glass group, 30% translucency and 40% neutral shadow
- Mote: its own glass group, 35% translucency and 35% neutral shadow
- Background: radial midnight backplate with composited bloom and orbit trail;
  glass effects disabled
- Default, Dark, and Mono: system-derived variants with no custom overrides

Xcode compiles the document into `ConjurorGlass.icns` for macOS 14 compatibility
while retaining the Liquid Glass source for current systems.
