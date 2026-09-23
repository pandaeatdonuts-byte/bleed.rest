# AGENTS.md

Roblox exploit script hub (`bleed.rest`). Private GitHub repo (`pandaeatdonuts-byte/bleed.rest`). Game code targets a Roblox executor environment, not Studio or plain Luau: `game`, `getgenv`, `mousemoverel`, `mouse1click`, `Drawing`, `writefile`/`readfile` are assumed to exist. Files cannot be run locally.

## Layout

- `loader.lua` — hub entry; routes by `game.PlaceId`, fetches the game module from GitHub raw.
- `mm2/main.lua` — MM2-clone module (PlaceId `142823291`). The main codebase.
- `lib/Lumen.lua` — vendored [chromatiks/Lumen](https://github.com/chromatiks/lumen) UI library, re-branded (RightShift menu key, `bleed_rest` config folder, cyan accent). Customized; keep changes minimal.
- `lib/Example.lua` — upstream usage example, reference only.

## Verification

- No test suite. Syntax-check with the pinned Luau toolchain (tracked under `.tools/`):
  `& ".tools\luau\0.739-20260922203417\luau-compile.exe" --binary <file>` — must compile.
- `luau-analyze.exe` on game scripts is noisy: hundreds of `Unknown global`/`UnknownType` errors are expected (Roblox globals aren't defined). Filter those out; watch for `TypeError`, `SameLineStatement`, `LocalUnused` only.
- Live-testing: use the Potassium MCP (`potassium_list_clients`, `potassium_execute_script`) on the connected Roblox client. The repo is private, so `game:HttpGet` of repo raw files returns a short `404: Not Found`; clients fall back to upstream Lumen. For live tests, inject the lib source directly or load the upstream URL.

## Conventions (mm2/main.lua)

- Code is comment-free (comments stripped deliberately) — don't add comments.
- Every UI element takes a `Flag`; config save/load drives its callback, so `State` stays in sync automatically.
- Connections must go through `track(...)` into `Connections`; background loops gate on `Running`. Any new connection/loop must also be torn down in `cleanup()` (end of file), which is wired to both `getgenv().bleed_rest_loaded` and a patched `Lumen.Unload` (so the in-menu "Unload" button stops everything).
- World/lighting overrides use `applyWorld()` on toggle change and `applyOverrides()` per-frame (in `RunService.Stepped`) so the game can't revert them — keep both.
- Drawing visuals (tracers, FOV circles) are hidden while the menu is open (Drawing renders above all GUI, so the menu must stay on top); chams/nametags always draw.

## Gotchas

- `mm2/main.lua` builds UI sections before world helpers are defined; `setFly` is forward-declared and assigned later. Order matters — keep it.
- The menu fade lives in `lib/Lumen.lua` `Library.ToggleMenu` (GroupTransparency tween); `Lumen.MenuOpen` is read in mm2/main.lua only to hide Drawing visuals under the menu.