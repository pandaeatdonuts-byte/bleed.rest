-- bleed.rest hub entry (Potassium-friendly small payload).
-- Usage, either dispatch this file or run:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/loader.lua"))()
local BASE = "https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/"

local GAMES = {
    [142823291] = "mm2/main.lua", -- MM2-clone ("Ugc")
}

local file = GAMES[game.PlaceId]
if not file then
    warn("[bleed.rest] unsupported game (PlaceId " .. tostring(game.PlaceId) .. ")")
    return
end
print("[bleed.rest] loading " .. file)
loadstring(game:HttpGet(BASE .. file))()
