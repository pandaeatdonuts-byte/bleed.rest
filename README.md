# bleed.rest

MM2-clone script (PlaceId `142823291`) with vendored + rebranded UI library.

## Layout

- `bleed.lua` — main script (kill aura, coin farm, ESP, movement, 1v1 queue)
- `loader.lua` — one-line loader (reliable over Potassium, avoids big-payload drops)
- `lib/Lumen.lua` — vendored UI library, customized for bleed.rest
- `lib/Example.lua` — upstream usage example (reference only)

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/bleed.lua"))()
```

Menu key: **RightShift**. UI library loads from this repo first,
falls back to upstream if the raw file is unreachable.

## UI credit

UI library by [chromatiks](https://github.com/chromatiks/lumen)
(vendored under `lib/` with branding defaults changed: menu key, config folder, accent).
