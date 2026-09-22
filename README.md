# bleed.rest

Script hub. Per-game modules + shared vendored UI library.

## Layout

- `loader.lua` — hub entry, routes by `game.PlaceId` (small Potassium-safe payload)
- `lib/Lumen.lua` — vendored UI library, customized for bleed.rest
- `lib/Example.lua` — upstream usage example (reference only)
- `mm2/` — MM2-clone module (PlaceId `142823291`)

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/loader.lua"))()
```

Menu key: **RightShift**. The UI library loads from this repo first,
falls back to upstream if the raw file is unreachable
(note: repo is private, so game clients use the upstream fallback).

## UI credit

UI library by [chromatiks](https://github.com/chromatiks/lumen)
(vendored under `lib/` with branding defaults changed: menu key, config folder, accent).
