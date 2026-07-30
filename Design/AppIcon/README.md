# Conjuror app icon

The production icon is `Conjuror/Conjuror.icon`, composed in Apple Icon Composer
from the flat SVG artwork under `Layers`.

The three imported groups are ordered back to front:

1. `01 Background`
2. `02 Portal`
3. `03 Spark`

The source artwork intentionally contains no gradients, blur, shadows, or
specular effects. Icon Composer owns those dynamic Liquid Glass treatments.

## Visual idea

A nearly complete summoning ring implies both a portal and a subtle letter C.
The central spark is the conjured result. The single orbiting mote keeps the
mark directional while preserving a strong silhouette at small macOS icon
sizes.

## Icon Composer treatment

- Target integration: macOS; the document retains reusable shared square geometry
- Portal: combined glass, 50% translucency, specular highlight, 50% neutral shadow
- Spark: combined glass, 50% translucency, specular highlight, 50% neutral shadow
- Background: opaque artwork with glass effects disabled
- Default, Dark, and Mono: system-derived variants with no custom overrides

Xcode compiles the document into `Conjuror.icns` for macOS 14 compatibility
while retaining the Liquid Glass source for current systems.
