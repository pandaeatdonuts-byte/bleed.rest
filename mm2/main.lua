-- mm2/main.lua | bleed.rest hub | MM2-clone (PlaceId 142823291) | vendored Lumen UI
-- UI upstream: https://github.com/chromatiks/lumen/tree/main (vendored + rebranded in lib/)
-- Loaded via hub loader.lua (per-game entry). Can also run standalone.

if getgenv and getgenv().bleed_rest_loaded then
    pcall(function() getgenv().bleed_rest_loaded() end)
    task.wait(0.5)
end

local LIB_URLS = {
    "https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/lib/Lumen.lua",
    "https://raw.githubusercontent.com/chromatiks/Lumen/main/Library.lua", -- upstream fallback
}

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res and #res > 1000 then return res end
    return nil, tostring(res):sub(1, 200)
end

local libSrc, libErr
for _, url in ipairs(LIB_URLS) do
    libSrc, libErr = httpGet(url)
    if libSrc then break end
end
assert(libSrc, "[bleed.rest] could not fetch UI lib.")
local Lumen = loadstring(libSrc)()

pcall(function() Lumen.SetConfigFolder("bleed_rest") end)

-- Menu toggle: LeftAlt is Lumen default. Force RightShift too + force-show.
Lumen.MenuKey = Enum.KeyCode.RightShift

Lumen:LoadingScreen({ Title = "bleed.rest", Subtitle = "Initializing...", Duration = 1.0 })
Lumen.SetWatermark("bleed.rest", true)
Lumen.SetKeybindList(true)

-- // Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- // Remotes (non-blocking: game may still be loading, UI must show regardless)
local Remotes = RS:FindFirstChild("Remotes")
if not Remotes then
    Remotes = RS:WaitForChild("Remotes", 15)
end
local function safeChild(parent, name, timeout)
    if not parent then return nil end
    local c = parent:FindFirstChild(name)
    if c then return c end
    return parent:WaitForChild(name, timeout or 5)
end
local Gameplay = safeChild(Remotes, "Gameplay")
local InventoryR = safeChild(Remotes, "Inventory")
local ShopR = safeChild(Remotes, "Shop")
local ExtrasR = safeChild(Remotes, "Extras")
local CustomGames = safeChild(Remotes, "CustomGames")
local TrapSystem = RS:FindFirstChild("TrapSystem")

local function fire(remote, ...)
    if remote then pcall(function() remote:FireServer(...) end) end
end
local function invoke(remote, ...)
    if not remote then return nil end
    local ok, res = pcall(function() return remote:InvokeServer(...) end)
    return ok and res or nil
end

-- // State
local State = {
    KillAura = false, KillRange = 22, KillMethod = "Knife",
    FakeGun = false, Stealth = false,
    AutoCoins = false, CoinESP = false,
    RoleESP = false, BoxESP = false, NameESP = false,
    Fly = false, FlySpeed = 60, Noclip = false,
    WalkSpeed = 16, JumpPower = 50,
}

local Window = Lumen:Window({ Title = "bleed.rest", Footer = "bleed.rest" })

-- // Combat (icons must exist in Lumen Lucide table or they render blank)
local Combat = Window:Page({ Icon = "swords" })
local Killer = Combat:SubPage({ Name = "Killer" })

local KA = Killer:Section({ Name = "Kill Aura"; Side = "Left"; Icon = "crosshair" })
local KALabel = KA:Label({ Text = "Enable kill aura" })
KALabel:Toggle({ State = false; Flag = "KillAura"; Callback = function(v) State.KillAura = v end })
KA:Slider({ Name = "Range"; Suffix = " studs"; Value = 22; Min = 8; Max = 60; Increment = 1; Flag = "KillRange"; Callback = function(v) State.KillRange = v end })
KA:Dropdown({ Name = "Method"; Options = { "Knife", "Gun", "Eliminate" }; Value = "Knife"; Flag = "KillMethod"; Callback = function(v) State.KillMethod = v end })

local Perks = Killer:Section({ Name = "Perks"; Side = "Right"; Icon = "star" })
local FakeLabel = Perks:Label({ Text = "Fake gun" })
FakeLabel:Toggle({ State = false; Flag = "FakeGun"; Callback = function(v)
    State.FakeGun = v
    if Gameplay then fire(Gameplay:FindFirstChild("FakeGun"), v) end
end })
local StealthLabel = Perks:Label({ Text = "Stealth" })
StealthLabel:Toggle({ State = false; Flag = "Stealth"; Callback = function(v)
    State.Stealth = v
    if Gameplay then fire(Gameplay:FindFirstChild("Stealth"), v) end
end })
Perks:Paragraph({ Title = "Perks"; Body = "Activate via Remotes/Gameplay.ActivatePerk with the perk name." })

task.spawn(function()
    local eliminate = Gameplay and Gameplay:FindFirstChild("EliminatePlayer")
    local killEvent = Gameplay and Gameplay:FindFirstChild("KillEvent")
    while task.wait(0.25) do
        if State.KillAura then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local th = plr.Character:FindFirstChild("HumanoidRootPart")
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if th and hum and hum.Health > 0 and (hrp.Position - th.Position).Magnitude <= State.KillRange then
                            if State.KillMethod == "Eliminate" then
                                invoke(eliminate, plr)
                            else
                                fire(killEvent, plr)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- // Farm ("coins" is NOT a Lumen icon -> use "box")
local FarmPage = Window:Page({ Icon = "box" })
local Coins = FarmPage:SubPage({ Name = "Coins" })
local CoinSec = Coins:Section({ Name = "Auto Farm"; Side = "Left"; Icon = "box" })
local CoinLabel = CoinSec:Label({ Text = "Auto collect coins" })
CoinLabel:Toggle({ State = false; Flag = "AutoCoins"; Callback = function(v) State.AutoCoins = v end })

task.spawn(function()
    local getCoin = Gameplay and Gameplay:FindFirstChild("GetCoin")
    while task.wait(0.5) do
        if State.AutoCoins and getCoin then
            local folder = RS:FindFirstChild("Coins")
            if folder then
                for _, objFolder in ipairs(folder:GetChildren()) do
                    for _, coin in ipairs(objFolder:GetChildren()) do
                        if coin:IsA("BasePart") then
                            fire(getCoin, coin)
                        elseif coin:IsA("Model") then
                            local p = coin:FindFirstChildWhichIsA("BasePart", true)
                            if p then fire(getCoin, p) end
                        end
                    end
                end
            end
        end
    end
end)

-- // Visuals (pure client, no remotes)
local Visuals = Window:Page({ Icon = "eye" })
local ESP = Visuals:SubPage({ Name = "ESP" })
local ESPPlayer = ESP:Section({ Name = "Players"; Side = "Left"; Icon = "users" })
local RoleLabel = ESPPlayer:Label({ Text = "Role ESP" })
RoleLabel:Toggle({ State = false; Flag = "RoleESP"; Callback = function(v) State.RoleESP = v end })
RoleLabel:Colorpicker({ Color = Color3.fromRGB(255, 60, 60); Flag = "RoleColor"; Callback = function() end })
local BoxLabel = ESPPlayer:Label({ Text = "Box ESP" })
BoxLabel:Toggle({ State = false; Flag = "BoxESP"; Callback = function(v) State.BoxESP = v end })
local NameLabel = ESPPlayer:Label({ Text = "Name ESP" })
NameLabel:Toggle({ State = false; Flag = "NameESP"; Callback = function(v) State.NameESP = v end })

local function ensureESP(char)
    local hl = char:FindFirstChild("bleedESP")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "bleedESP"
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.Parent = char
    end
    local tag = char:FindFirstChild("bleedName")
    if not tag then
        tag = Instance.new("BillboardGui")
        tag.Name = "bleedName"
        tag.Size = UDim2.new(0, 120, 0, 30)
        tag.StudsOffset = Vector3.new(0, 3, 0)
        tag.AlwaysOnTop = true
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextStrokeTransparency = 0
        tl.TextScaled = true
        tl.Parent = tag
        tag.Parent = char
    end
    return hl, tag
end

RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hl, tag = ensureESP(plr.Character)
            hl.Enabled = State.RoleESP or State.BoxESP
            tag.Enabled = State.NameESP
            if tag.Enabled then
                tag:FindFirstChildOfClass("TextLabel").Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            end
        end
    end
end)

-- // Player
local PlayerPage = Window:Page({ Icon = "user" })
local Move = PlayerPage:SubPage({ Name = "Movement" })
local MoveSec = Move:Section({ Name = "Character"; Side = "Left"; Icon = "move" })
MoveSec:Slider({ Name = "WalkSpeed"; Suffix = ""; Value = 16; Min = 16; Max = 200; Increment = 1; Flag = "WalkSpeed"; Callback = function(v)
    State.WalkSpeed = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end })
MoveSec:Slider({ Name = "JumpPower"; Suffix = ""; Value = 50; Min = 50; Max = 300; Increment = 5; Flag = "JumpPower"; Callback = function(v)
    State.JumpPower = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = v end
end })
local FlyLabel = MoveSec:Label({ Text = "Fly" })
FlyLabel:Toggle({ State = false; Flag = "Fly"; Callback = function(v) State.Fly = v end })
FlyLabel:Keybind({ Key = Enum.KeyCode.F; Type = "Toggle"; Flag = "FlyKey"; Callback = function() end })

-- // Misc
local Misc = Window:Page({ Icon = "wrench" })
local MiscSub = Misc:SubPage({ Name = "Server" })
local MiscSec = MiscSub:Section({ Name = "Utility"; Side = "Left"; Icon = "terminal" })
MiscSec:Paragraph({ Title = "Codes"; Body = "Uses Remotes/Extras.RedeemCode + CheckCode." })
MiscSec:Dropdown({ Name = "1v1 Queue"; Options = { "Join", "Leave" }; Value = "Join"; Flag = "QueueAction"; Callback = function(v)
    if CustomGames then fire(CustomGames:FindFirstChild(v == "Join" and "Join1v1Queue" or "Leave1v1Queue")) end
end })

if getgenv then getgenv().bleed_rest_loaded = function() pcall(function() Lumen.Unload() end) end end

local Settings = Window:Page({ Icon = "settings" })
local About = Settings:Section({ Name = "About"; Side = "Right"; Icon = "info" })
About:Paragraph({ Title = "bleed.rest"; Body = "MM2-clone build. PlaceId 142823291." })

Lumen:BuildConfigPage(Window)
Lumen.ToggleMenu(true)
Lumen.Notify({ Title = "bleed.rest"; Text = "Loaded successfully (RightShift to toggle)"; Type = "Success"; Duration = 3 })
