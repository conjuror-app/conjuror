# Conjuror app icon

The production icon is `Conjuror/Conjuror.icon`, composed in Apple Icon Composer
from 1024 px PNG layers rendered from the editable SVG artwork under `Layers`.

The four imported groups are ordered back to front:

1. `01 Background` — transparent compatibility layer; the document fill supplies
   the smooth midnight backdrop
2. `02 Portal`
3. `03 Spark`
4. `04 Mote`

The source artwork contains the intended color gradients, but no blur, shadows,
or specular effects. The production PNGs preserve SVG gradient features that
Icon Composer’s SVG importer doesn’t retain reliably. Icon Composer owns the
dynamic Liquid Glass treatments.

## Visual idea

A nearly complete summoning ring implies both a portal and a subtle letter C.
The central spark is the conjured result. The single orbiting mote keeps the
mark directional while preserving a strong silhouette at small macOS icon
sizes.

## Icon Composer treatment

- Target integration: macOS; the document retains reusable shared square geometry
- Portal: one continuous gradient layer, 40% translucency, specular highlight,
  45% neutral shadow
- Spark: its own glass group, 30% translucency and 40% neutral shadow
- Mote: its own glass group, 35% translucency and 35% neutral shadow
- Background: Icon Composer automatic gradient; transparent compatibility layer
  with glass effects disabled
- Default, Dark, and Mono: system-derived variants with no custom overrides

Xcode compiles the document into `Conjuror.icns` for macOS 14 compatibility
while retaining the Liquid Glass source for current systems.
