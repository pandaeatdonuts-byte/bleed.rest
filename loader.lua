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
local ok, src = pcall(function() return game:HttpGet(BASE .. file) end)
if not ok or not src or #src < 1000 then
    warn("[bleed.rest] fetch failed for " .. file .. " (private repo or bad URL?)")
    return
end
loadstring(src)()
