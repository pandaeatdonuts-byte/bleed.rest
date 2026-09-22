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

-- Menu toggle default. Change anytime: Settings > Menu > Menu key.
Lumen.MenuKey = Enum.KeyCode.RightShift

Lumen:LoadingScreen({ Title = "bleed.rest", Subtitle = "Initializing...", Duration = 1.0 })
Lumen.SetWatermark("bleed.rest", true)
Lumen.SetKeybindList(true)

-- // Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local _unpack = table.unpack or unpack

local function getCam()
    return Workspace.CurrentCamera
end
-- screen-space mouse (Drawing + viewport math must share one origin)
local function screenMouse()
    return UIS:GetMouseLocation()
end
local function toScreen(cam, world)
    local v, on = cam:WorldToViewportPoint(world)
    local inset = GuiService:GetGuiInset()
    return Vector2.new(v.X + inset.X, v.Y + inset.Y), on
end

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

local function fire1(remote, arg)
    if not remote then return end
    if arg == nil then
        pcall(function() remote:FireServer() end)
    else
        pcall(function() remote:FireServer(arg) end)
    end
end
local function invoke1(remote, arg)
    if not remote then return nil end
    local ok, res
    if arg == nil then
        ok, res = pcall(function() return remote:InvokeServer() end)
    else
        ok, res = pcall(function() return remote:InvokeServer(arg) end)
    end
    return ok and res or nil
end

-- // State
local State = {
    -- kill aura (legacy)
    KillAura = false, KillRange = 22, KillMethod = "Knife",
    FakeGun = false, Stealth = false,
    AutoCoins = false,
    -- esp
    ESP = true, Chams = true, EspName = true, EspRole = true, EspDist = true,
    Tracer = false, TracerFrom = "Bottom", TracerThick = 1,
    EspMaxDist = 600, ShowInnocents = true, ShowDead = false,
    ChamsFill = 0.6, ChamsTop = true,
    ColFill = Color3.fromRGB(255, 255, 255), ColOutline = Color3.fromRGB(255, 255, 255),
    MurderESP = true, SheriffESP = true,
    -- aimbot
    Aimbot = false, AimHeld = false, AimFOV = 120, AimMode = "Mouse",
    AimSens = 1.0, AimSmoothX = 6, AimSmoothY = 6, AimSmooth = 35,
    AimPredict = true, PredictAmt = 100,
    AimPart = "Head", AimTargets = "Auto", AimVisible = true, ShowAimFOV = true,
    -- silent
    Silent = false, SilentFOV = 100, HitChance = 100, ExtraLead = 0.05,
    ShowSilentFOV = true,
    -- trigger
    Trigger = false, TriggerHeld = false, TriggerDelay = 150, TriggerRange = 400,
    TriggerTargets = "Auto",
    -- player/misc
    Fly = false, FlySpeed = 60, WalkSpeed = 16, JumpPower = 50,
    Fullbright = false, NoFog = false, Grav = 196.2, Noclip = false, ClickTP = false,
}

-- // Role tracker (multi-signal: remote args, scoreboard names, held tools)
local Roles = {} -- [userId] = "Murderer" | "Sheriff"
local function parseSignal(...)
    local plr, role
    local args = { ... }
    for i = 1, #args do
        local a = args[i]
        if typeof(a) == "Instance" and a:IsA("Player") then
            plr = a
        elseif type(a) == "string" then
            local s = a:lower()
            if s:find("murder") or s:find("knife") then role = "Murderer"
            elseif s:find("sheriff") or s:find("gun") then role = "Sheriff" end
        end
    end
    if plr and role then Roles[plr.UserId] = role end
end
if Gameplay then
    for _, n in ipairs({ "ShowTeammates", "RoleSelect", "ShowRoleSelectNew", "GiveWeapon", "KillEvent", "VictoryScreen" }) do
        local r = Gameplay:FindFirstChild(n)
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(...) parseSignal(...) end)
        end
    end
    local rs = Gameplay:FindFirstChild("RoundStart")
    if rs and rs:IsA("RemoteEvent") then
        rs.OnClientEvent:Connect(function() table.clear(Roles) end)
    end
end

local function isAlive(plr)
    local a = plr:GetAttribute("Alive")
    if a == nil then return true end
    return a == true
end
local function toolRole(char)
    if not char then return nil end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return nil end
    local n = tool.Name:lower()
    if n:find("knife") then return "Murderer" end
    if n:find("gun") then return "Sheriff" end
    return "Armed"
end
local function effRole(plr)
    local sig = Roles[plr.UserId]
    if sig then return sig end
    local t = toolRole(plr.Character)
    if t then return t end
    return "Innocent"
end
local THREAT_RED = Color3.fromRGB(255, 50, 50)
local THREAT_BLUE = Color3.fromRGB(80, 140, 255)
local function espFill(role)
    if role == "Murderer" and State.MurderESP then return THREAT_RED end
    if role == "Sheriff" and State.SheriffESP then return THREAT_BLUE end
    return State.ColFill
end
local function espOutline(role)
    if role == "Murderer" and State.MurderESP then return THREAT_RED end
    if role == "Sheriff" and State.SheriffESP then return THREAT_BLUE end
    return State.ColOutline
end

-- scrape scoreboard + own role label every few seconds
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            -- own role label
            local rs = pg:FindFirstChild("CrossPlatform", true)
            if rs then
                for _, d in ipairs(rs:GetDescendants()) do
                    if d:IsA("TextLabel") and (d.Name == "Role") and #d.Text > 0 and #d.Text < 40 then
                        local t = d.Text:lower()
                        if t:find("murder") then Roles[LocalPlayer.UserId] = "Murderer"
                        elseif t:find("sheriff") then Roles[LocalPlayer.UserId] = "Sheriff" end
                    end
                end
            end
            -- versus frames reveal names
            local sb = pg:FindFirstChild("Scoreboard")
            if sb then
                for _, d in ipairs(sb:GetDescendants()) do
                    if d:IsA("TextLabel") and #d.Text > 1 and #d.Text < 30 then
                        local p = Players:FindFirstChild(d.Text)
                        if p then
                            local parentName = ""
                            local n = d.Parent
                            for _ = 1, 4 do
                                if n then parentName = parentName .. "/" .. n.Name n = n.Parent end
                            end
                            parentName = parentName:lower()
                            if parentName:find("murder") then Roles[p.UserId] = "Murderer"
                            elseif parentName:find("sheriff") then Roles[p.UserId] = "Sheriff" end
                        end
                    end
                end
            end
        end)
    end
end)

-- // Target helpers
local function getPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    local n = tonumber(ok and p or nil)
    if not n or n <= 0 or n > 5 then return 0.12 end
    return n
end
local function leadTime()
    if not State.AimPredict then return 0 end
    local scale = (State.PredictAmt or 100) / 100
    if scale <= 0 then return 0 end
    return (getPing() + (State.ExtraLead or 0)) * scale
end
local function aimPartOf(char, mode)
    if not char then return nil end
    if mode == "Random" then
        local pool = {}
        for _, n in ipairs({ "Head", "UpperTorso", "HumanoidRootPart" }) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then pool[#pool + 1] = p end
        end
        if #pool == 0 then return nil end
        return pool[math.random(1, #pool)]
    end
    local p = char:FindFirstChild(mode == "Torso" and "UpperTorso" or mode)
    if not p and mode == "Torso" then p = char:FindFirstChild("Torso") end
    if p and p:IsA("BasePart") then return p end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    return char:FindFirstChildWhichIsA("BasePart", true)
end
local function predictPos(part)
    if not part then return nil end
    local lead = leadTime()
    if lead <= 0 then return part.Position end
    return part.Position + part.Velocity * lead
end
local function rayVisible(cam, from, to, myChar, targetChar)
    local dir = to - from
    local dist = dir.Magnitude
    if dist < 1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar }
    params.IgnoreWater = true
    local hit = Workspace:Raycast(from, dir, params)
    if not hit or not hit.Instance then return true end
    return hit.Instance:IsDescendantOf(targetChar)
end
local function threatKnown()
    for _, r in pairs(Roles) do
        if r == "Murderer" or r == "Sheriff" then return true end
    end
    return false
end
local function roleAllowed(role, mode)
    if mode == "Auto" then
        if threatKnown() then return role == "Murderer" or role == "Sheriff" end
        return true -- no roles detected yet: anyone alive
    end
    if mode == "Everyone" then return true end
    if mode == "Murderer" then return role == "Murderer" end
    if mode == "Sheriff" then return role == "Sheriff" end
    if mode == "Murderer + Sheriff" then return role == "Murderer" or role == "Sheriff" end
    return false
end
local function validTarget(plr, mode, maxDist)
    if plr == LocalPlayer then return nil end
    if not isAlive(plr) and not State.ShowDead then return nil end
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local role = effRole(plr)
    if not roleAllowed(role, mode) then return nil end
    if role == "Innocent" and not State.ShowInnocents and mode == "Everyone" then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    if maxDist and (myHrp.Position - hrp.Position).Magnitude > maxDist then return nil end
    return char, role, hum
end
local function screenPoint(cam, world)
    return toScreen(cam, world)
end
local currentAimTarget = nil
local function bestTarget(cam, mousePos, fovPx, mode, usePart)
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    -- sticky: keep current if still valid + in fov
    if currentAimTarget and currentAimTarget.Parent then
        local plr = Players:GetPlayerFromCharacter(currentAimTarget)
        if plr then
            local char, role = validTarget(plr, mode, State.EspMaxDist)
            if char then
                local part = aimPartOf(char, usePart)
                if part then
                    local sp, on = screenPoint(cam, part.Position)
                    if on and (sp - mousePos).Magnitude <= fovPx then
                        return plr, char, part, role
                    end
                end
            end
        end
        currentAimTarget = nil
    end
    local best, bestChar, bestPart, bestRole, bestD = nil, nil, nil, nil, fovPx
    for _, plr in ipairs(Players:GetPlayers()) do
        local char, role = validTarget(plr, mode, State.EspMaxDist)
        if char then
            local part = aimPartOf(char, usePart)
            if part then
                local sp, on = screenPoint(cam, part.Position)
                if on then
                    local d = (sp - mousePos).Magnitude
                    if d <= bestD then
                        if not State.AimVisible or rayVisible(cam, cam.CFrame.Position, part.Position, myChar, char) then
                            best, bestChar, bestPart, bestRole, bestD = plr, char, part, role, d
                        end
                    end
                end
            end
        end
    end
    if bestChar then currentAimTarget = bestChar end
    return best, bestChar, bestPart, bestRole
end

-- // ESP engine
local hasDrawing = typeof(Drawing) == "table"
local tracers = {}
local fovCircle, silentCircle
if hasDrawing then
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1 fovCircle.Filled = false
        fovCircle.Color = Color3.fromRGB(255, 255, 255) fovCircle.Visible = false
        silentCircle = Drawing.new("Circle")
        silentCircle.Thickness = 1 silentCircle.Filled = false
        silentCircle.Color = Color3.fromRGB(255, 80, 80) silentCircle.Visible = false
    end)
end
local function setCircle(circle, show, pos, radius)
    if circle then
        circle.Visible = show
        if show then circle.Position = pos circle.Radius = radius end
    end
end
local function getTracer(plr)
    if not hasDrawing then return nil end
    local l = tracers[plr.UserId]
    if l then return l end
    local ok, nl = pcall(function() return Drawing.new("Line") end)
    if not ok or not nl then return nil end
    nl.Thickness = State.TracerThick nl.Visible = false
    tracers[plr.UserId] = nl
    return nl
end
Players.PlayerRemoving:Connect(function(plr)
    local l = tracers[plr.UserId]
    if l then pcall(function() l:Remove() end) tracers[plr.UserId] = nil end
    if currentAimTarget then currentAimTarget = nil end
end)
local function tracerOrigin(cam)
    local vs = cam.ViewportSize
    if State.TracerFrom == "Top" then return Vector2.new(vs.X / 2, 0) end
    if State.TracerFrom == "Mouse" then return screenMouse() end
    return Vector2.new(vs.X / 2, vs.Y)
end
local function ensureTag(char)
    local tag = char:FindFirstChild("bleedTag")
    if tag then
        local stale = tag:FindFirstChild("BarBg")
        if stale then stale:Destroy() end
        return tag
    end
    tag = Instance.new("BillboardGui")
    tag.Name = "bleedTag"
    tag.Size = UDim2.new(0, 140, 0, 28)
    tag.StudsOffset = Vector3.new(0, 3.2, 0)
    tag.AlwaysOnTop = false -- menu (DisplayOrder 1000) draws above ESP
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, 0, 1, 0)
    name.BackgroundTransparency = 1
    name.TextStrokeTransparency = 0
    name.TextScaled = true
    name.Font = Enum.Font.SourceSansBold
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.Parent = tag
    tag.Parent = char
    return tag
end
local function ensureChams(char)
    local hl = char:FindFirstChild("bleedChams")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "bleedChams"
        hl.Parent = char
    end
    return hl
end

-- // Main loop: ESP + tracers + aimbot + trigger
local lastTriggerShot = 0
local hasMouseMove = typeof(mousemoverel) == "function"
local function round6(v)
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end
RunService.RenderStepped:Connect(function()
    local cam = getCam()
    if not cam then return end
    local mousePos = screenMouse()
    -- fov circles
    -- Drawing renders above all Roblox GUI: hide overlays while menu is open
    local menuOpen = Lumen.MenuOpen == true
    setCircle(fovCircle, State.ShowAimFOV and State.Aimbot and not menuOpen, mousePos, State.AimFOV)
    setCircle(silentCircle, State.ShowSilentFOV and State.Silent and not menuOpen, mousePos, State.SilentFOV)
    -- per-player visuals
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local alive = isAlive(plr) and hum and hum.Health > 0
            local role = effRole(plr)
            local showPlayer = State.ESP and (alive or State.ShowDead)
            if showPlayer and role == "Innocent" and not State.ShowInnocents then showPlayer = false end
            local dist = 0
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if hrp and myHrp then dist = (myHrp.Position - hrp.Position).Magnitude end
            if showPlayer and dist > State.EspMaxDist then showPlayer = false end
            -- chams
            local hl = ensureChams(char)
            hl.Enabled = showPlayer and State.Chams
            if hl.Enabled then
                hl.FillColor = espFill(role)
                hl.FillTransparency = State.ChamsFill
                hl.OutlineColor = espOutline(role)
                hl.OutlineTransparency = 0
                hl.DepthMode = State.ChamsTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            end
            -- nametag
            local tag = ensureTag(char)
            local showTag = showPlayer and (State.EspName or State.EspRole or State.EspDist)
            tag.Enabled = showTag
            if showTag and hum and hrp then
                local parts = {}
                if State.EspName then parts[#parts + 1] = plr.DisplayName end
                if State.EspRole then parts[#parts + 1] = "[" .. role:upper() .. "]" end
                if State.EspDist then parts[#parts + 1] = math.floor(dist) .. "m" end
                local nl = tag:FindFirstChild("Name")
                if nl then
                    nl.Text = table.concat(parts, " ")
                    nl.TextColor3 = espFill(role)
                end
            end
            -- tracer
            local line = getTracer(plr)
            if line then
                local showLine = showPlayer and State.Tracer and hrp ~= nil and not menuOpen
                local sp, onScreen = Vector2.new(0, 0), false
                if hrp then sp, onScreen = screenPoint(cam, hrp.Position) end
                line.Visible = showLine and onScreen
                if line.Visible then
                    line.From = tracerOrigin(cam)
                    line.To = sp
                    line.Color = espFill(role)
                    line.Thickness = State.TracerThick
                end
            end
        end
    end
    -- aimbot (mouse move default, camera lock fallback)
    if State.Aimbot and State.AimHeld then
        local plr, char, part = bestTarget(cam, mousePos, State.AimFOV, State.AimTargets, State.AimPart)
        if plr and part then
            local aimAt = predictPos(part)
            if aimAt then
                if State.AimMode == "Mouse" and hasMouseMove then
                    local sp = toScreen(cam, aimAt)
                    local sx = ((sp.X - mousePos.X) / math.max(State.AimSmoothX, 1)) * State.AimSens
                    local sy = ((sp.Y - mousePos.Y) / math.max(State.AimSmoothY, 1)) * State.AimSens
                    local ix, iy = round6(sx), round6(sy)
                    if ix ~= 0 or iy ~= 0 then
                        pcall(function() mousemoverel(ix, iy) end)
                    end
                else
                    local alpha = math.clamp(1 - (State.AimSmooth / 100), 0.05, 1)
                    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimAt), alpha)
                end
            end
        end
    else
        if currentAimTarget and not State.AimHeld then currentAimTarget = nil end
    end
    -- triggerbot (click when crosshair sits on a valid target)
    if State.Trigger and State.TriggerHeld then
        local t = Mouse.Target
        if t then
            local model = t:FindFirstAncestorOfClass("Model")
            local tplr = model and Players:GetPlayerFromCharacter(model)
            if tplr then
                local char, role = validTarget(tplr, State.TriggerTargets, State.TriggerRange)
                if char and typeof(mouse1click) == "function" then
                    local now = os.clock()
                    if (now - lastTriggerShot) * 1000 >= State.TriggerDelay then
                        lastTriggerShot = now
                        pcall(function() mouse1click() end)
                    end
                end
            end
        end
    end
end)

-- silent aim: micro-snap on fire (hit% roll + prediction)
UIS.InputBegan:Connect(function(input, gp)
    if not State.Silent then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if math.random(1, 100) > State.HitChance then return end
    local cam = getCam()
    if not cam then return end
    local mousePos = screenMouse()
    local plr, char, part = bestTarget(cam, mousePos, State.SilentFOV, State.AimTargets, State.AimPart)
    if plr and part then
        local aimAt = predictPos(part)
        if aimAt then
            local old = cam.CFrame
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimAt)
            task.delay(0.04, function()
                local c2 = getCam()
                if c2 then pcall(function() c2.CFrame = old end) end
            end)
        end
    end
end)

-- // UI
local Window = Lumen:Window({ Title = "bleed.rest", Footer = "bleed.rest" })

-- Combat
local Combat = Window:Page({ Icon = "swords" })
local AimPage = Combat:SubPage({ Name = "Aimbot" })
local AimSec = AimPage:Section({ Name = "Aimbot"; Side = "Left"; Icon = "crosshair" })
local AimOn = AimSec:Label({ Text = "Enable aimbot" })
AimOn:Toggle({ State = false; Flag = "Aimbot"; Callback = function(v) State.Aimbot = v end })
AimOn:Keybind({ Key = Enum.UserInputType.MouseButton2; Type = "Hold"; Flag = "AimKey"; Callback = function(v) State.AimHeld = v end })
AimSec:Dropdown({ Name = "Mode"; Options = { "Mouse", "Camera" }; Value = "Mouse"; Flag = "AimMode"; Callback = function(v) State.AimMode = v end })
AimSec:Slider({ Name = "FOV"; Suffix = " px"; Value = 120; Min = 10; Max = 400; Increment = 5; Flag = "AimFOV"; Callback = function(v) State.AimFOV = v end })
AimSec:Slider({ Name = "Sensitivity"; Suffix = "x"; Value = 1.0; Min = 0.1; Max = 3.0; Increment = 0.1; Flag = "AimSens"; Callback = function(v) State.AimSens = v end })
AimSec:Slider({ Name = "X smoothing"; Suffix = ""; Value = 6; Min = 1; Max = 50; Increment = 1; Flag = "AimSmoothX"; Callback = function(v) State.AimSmoothX = v end })
AimSec:Slider({ Name = "Y smoothing"; Suffix = ""; Value = 6; Min = 1; Max = 50; Increment = 1; Flag = "AimSmoothY"; Callback = function(v) State.AimSmoothY = v end })
AimSec:Slider({ Name = "Camera smoothing"; Suffix = "%"; Value = 35; Min = 0; Max = 95; Increment = 1; Flag = "AimSmooth"; Callback = function(v) State.AimSmooth = v end })
local PredOn = AimSec:Label({ Text = "Prediction" })
PredOn:Toggle({ State = true; Flag = "AimPredict"; Callback = function(v) State.AimPredict = v end })
AimSec:Slider({ Name = "Prediction amount"; Suffix = "%"; Value = 100; Min = 0; Max = 200; Increment = 5; Flag = "PredictAmt"; Callback = function(v) State.PredictAmt = v end })
AimSec:Dropdown({ Name = "Target part"; Options = { "Head", "Torso", "HumanoidRootPart", "Random" }; Value = "Head"; Flag = "AimPart"; Callback = function(v) State.AimPart = v end })
AimSec:Dropdown({ Name = "Targets"; Options = { "Auto", "Murderer", "Murderer + Sheriff", "Sheriff", "Everyone" }; Value = "Auto"; Flag = "AimTargets"; Callback = function(v) State.AimTargets = v end })
local VisCheck = AimSec:Label({ Text = "Visible check" })
VisCheck:Toggle({ State = true; Flag = "AimVisible"; Callback = function(v) State.AimVisible = v end })
local ShowFov = AimSec:Label({ Text = "Show FOV" })
ShowFov:Toggle({ State = true; Flag = "ShowAimFOV"; Callback = function(v) State.ShowAimFOV = v end })
local AimStatus = AimSec:Paragraph({ Title = "Status"; Body = "Detecting roles..." })

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local m, s = "?", "?"
            for _, p in ipairs(Players:GetPlayers()) do
                local r = Roles[p.UserId]
                if r == "Murderer" then m = p.DisplayName
                elseif r == "Sheriff" then s = p.DisplayName end
            end
            AimStatus:SetBody("Murderer: " .. m .. "   Sheriff: " .. s)
        end)
    end
end)

local SilSec = AimPage:Section({ Name = "Silent Aim"; Side = "Right"; Icon = "zap" })
local SilOn = SilSec:Label({ Text = "Enable silent aim" })
SilOn:Toggle({ State = false; Flag = "Silent"; Callback = function(v) State.Silent = v end })
SilSec:Slider({ Name = "FOV"; Suffix = " px"; Value = 100; Min = 10; Max = 400; Increment = 5; Flag = "SilentFOV"; Callback = function(v) State.SilentFOV = v end })
SilSec:Slider({ Name = "Hit chance"; Suffix = "%"; Value = 100; Min = 1; Max = 100; Increment = 1; Flag = "HitChance"; Callback = function(v) State.HitChance = v end })
SilSec:Slider({ Name = "Extra lead"; Suffix = "s"; Value = 0.05; Min = 0; Max = 0.5; Increment = 0.01; Flag = "ExtraLead"; Callback = function(v) State.ExtraLead = v end })
SilSec:Paragraph({ Title = "Note"; Body = "Uses the aimbot Prediction toggle + amount above." })
local ShowSilFov = SilSec:Label({ Text = "Show FOV" })
ShowSilFov:Toggle({ State = true; Flag = "ShowSilentFOV"; Callback = function(v) State.ShowSilentFOV = v end })
SilSec:Paragraph({ Title = "How it works"; Body = "On every shot, rolls hit chance then micro-snaps the camera to the predicted target for one frame." })

local TrigPage = Combat:SubPage({ Name = "Triggerbot" })
local TrigSec = TrigPage:Section({ Name = "Triggerbot"; Side = "Left"; Icon = "mouse-pointer" })
local TrigOn = TrigSec:Label({ Text = "Enable triggerbot" })
TrigOn:Toggle({ State = false; Flag = "Trigger"; Callback = function(v) State.Trigger = v end })
TrigOn:Keybind({ Key = Enum.UserInputType.MouseButton2; Type = "Hold"; Flag = "TriggerKey"; Callback = function(v) State.TriggerHeld = v end })
TrigSec:Slider({ Name = "Delay"; Suffix = " ms"; Value = 150; Min = 0; Max = 500; Increment = 10; Flag = "TriggerDelay"; Callback = function(v) State.TriggerDelay = v end })
TrigSec:Slider({ Name = "Max range"; Suffix = " studs"; Value = 400; Min = 20; Max = 2000; Increment = 10; Flag = "TriggerRange"; Callback = function(v) State.TriggerRange = v end })
TrigSec:Dropdown({ Name = "Targets"; Options = { "Auto", "Murderer", "Murderer + Sheriff", "Sheriff", "Everyone" }; Value = "Auto"; Flag = "TriggerTargets"; Callback = function(v) State.TriggerTargets = v end })

local KillerPage = Combat:SubPage({ Name = "Killer" })
local KA = KillerPage:Section({ Name = "Kill Aura"; Side = "Left"; Icon = "crosshair" })
local KALabel = KA:Label({ Text = "Enable kill aura" })
KALabel:Toggle({ State = false; Flag = "KillAura"; Callback = function(v) State.KillAura = v end })
KA:Slider({ Name = "Range"; Suffix = " studs"; Value = 22; Min = 8; Max = 60; Increment = 1; Flag = "KillRange"; Callback = function(v) State.KillRange = v end })
KA:Dropdown({ Name = "Method"; Options = { "Knife", "Gun", "Eliminate" }; Value = "Knife"; Flag = "KillMethod"; Callback = function(v) State.KillMethod = v end })
local Perks = KillerPage:Section({ Name = "Perks"; Side = "Right"; Icon = "star" })
local FakeLabel = Perks:Label({ Text = "Fake gun" })
FakeLabel:Toggle({ State = false; Flag = "FakeGun"; Callback = function(v)
    State.FakeGun = v
    if Gameplay then fire1(Gameplay:FindFirstChild("FakeGun"), v) end
end })
local StealthLabel = Perks:Label({ Text = "Stealth" })
StealthLabel:Toggle({ State = false; Flag = "Stealth"; Callback = function(v)
    State.Stealth = v
    if Gameplay then fire1(Gameplay:FindFirstChild("Stealth"), v) end
end })

task.spawn(function()
    local killEvent = Gameplay and Gameplay:FindFirstChild("KillEvent")
    local eliminate = Gameplay and Gameplay:FindFirstChild("EliminatePlayer")
    while task.wait(0.25) do
        if State.KillAura then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local c2, role = validTarget(plr, "Everyone", State.KillRange)
                        if c2 and (role == "Murderer" or role == "Sheriff" or State.ShowInnocents) then
                            if State.KillMethod == "Eliminate" then
                                invoke1(eliminate, plr)
                            else
                                fire1(killEvent, plr)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- Visuals
local Visuals = Window:Page({ Icon = "eye" })
local EspPage = Visuals:SubPage({ Name = "ESP" })
local EspSec = EspPage:Section({ Name = "Players"; Side = "Left"; Icon = "users" })
local EspOn = EspSec:Label({ Text = "Enable ESP" })
EspOn:Toggle({ State = true; Flag = "ESP"; Callback = function(v) State.ESP = v end })
local ChamsOn = EspSec:Label({ Text = "Chams" })
ChamsOn:Toggle({ State = true; Flag = "Chams"; Callback = function(v) State.Chams = v end })
local FillCol = EspSec:Label({ Text = "Chams fill" })
FillCol:Colorpicker({ Color = Color3.fromRGB(255, 255, 255); Flag = "ColFill"; Callback = function(v) State.ColFill = v end })
local OutCol = EspSec:Label({ Text = "Chams outline" })
OutCol:Colorpicker({ Color = Color3.fromRGB(255, 255, 255); Flag = "ColOutline"; Callback = function(v) State.ColOutline = v end })
local NameOn = EspSec:Label({ Text = "Nametags" })
NameOn:Toggle({ State = true; Flag = "EspName"; Callback = function(v) State.EspName = v end })
local RoleOn = EspSec:Label({ Text = "Role text" })
RoleOn:Toggle({ State = true; Flag = "EspRole"; Callback = function(v) State.EspRole = v end })
local DistOn = EspSec:Label({ Text = "Distance" })
DistOn:Toggle({ State = true; Flag = "EspDist"; Callback = function(v) State.EspDist = v end })
local TracerOn = EspSec:Label({ Text = "Tracers" })
TracerOn:Toggle({ State = false; Flag = "Tracer"; Callback = function(v) State.Tracer = v end })
EspSec:Dropdown({ Name = "Tracer origin"; Options = { "Bottom", "Top", "Mouse" }; Value = "Bottom"; Flag = "TracerFrom"; Callback = function(v) State.TracerFrom = v end })
EspSec:Slider({ Name = "Tracer thickness"; Suffix = "px"; Value = 1; Min = 1; Max = 4; Increment = 1; Flag = "TracerThick"; Callback = function(v) State.TracerThick = v end })
EspSec:Slider({ Name = "Max distance"; Suffix = " studs"; Value = 600; Min = 50; Max = 3000; Increment = 25; Flag = "EspMaxDist"; Callback = function(v) State.EspMaxDist = v end })
EspSec:Slider({ Name = "Chams transparency"; Suffix = ""; Value = 0.6; Min = 0; Max = 1; Increment = 0.05; Flag = "ChamsFill"; Callback = function(v) State.ChamsFill = v end })

local RoleSec = EspPage:Section({ Name = "Roles"; Side = "Right"; Icon = "target" })
RoleSec:Paragraph({ Title = "Detection"; Body = "Roles auto-detect from round events, scoreboard names and held weapons. Clears every round." })
local InnoOn = RoleSec:Label({ Text = "Show innocents" })
InnoOn:Toggle({ State = true; Flag = "ShowInnocents"; Callback = function(v) State.ShowInnocents = v end })
local DeadOn = RoleSec:Label({ Text = "Show dead" })
DeadOn:Toggle({ State = false; Flag = "ShowDead"; Callback = function(v) State.ShowDead = v end })
local TopOn = RoleSec:Label({ Text = "Chams through walls" })
TopOn:Toggle({ State = true; Flag = "ChamsTop"; Callback = function(v) State.ChamsTop = v end })
local MurEsp = RoleSec:Label({ Text = "Murderer ESP" })
MurEsp:Toggle({ State = true; Flag = "MurderESP"; Callback = function(v) State.MurderESP = v end })
local SheEsp = RoleSec:Label({ Text = "Sheriff ESP" })
SheEsp:Toggle({ State = true; Flag = "SheriffESP"; Callback = function(v) State.SheriffESP = v end })
RoleSec:Paragraph({ Title = "Override"; Body = "Murderer forces red, sheriff forces blue on every active ESP option. Innocents untouched." })

-- Farm
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
                            fire1(getCoin, coin)
                        elseif coin:IsA("Model") then
                            local p = coin:FindFirstChildWhichIsA("BasePart", true)
                            if p then fire1(getCoin, p) end
                        end
                    end
                end
            end
        end
    end
end)

-- Player
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
local setFly -- forward: defined in world helpers below
FlyLabel:Toggle({ State = false; Flag = "Fly"; Callback = function(v)
    State.Fly = v
    setFly(v)
end })
FlyLabel:Keybind({ Key = Enum.KeyCode.F; Type = "Toggle"; Flag = "FlyKey"; Callback = function() end })
MoveSec:Slider({ Name = "Fly speed"; Suffix = ""; Value = 60; Min = 10; Max = 250; Increment = 5; Flag = "FlySpeed"; Callback = function(v) State.FlySpeed = v end })
local NoclipOn = MoveSec:Label({ Text = "Noclip" })
NoclipOn:Toggle({ State = false; Flag = "Noclip"; Callback = function(v) State.Noclip = v end })
local ClickTpOn = MoveSec:Label({ Text = "Ctrl+Click teleport" })
ClickTpOn:Toggle({ State = false; Flag = "ClickTP"; Callback = function(v) State.ClickTP = v end })

-- // World helpers (client-side only)
local Lighting = game:GetService("Lighting")
local savedLight = nil
local savedAtmo = {}
-- fly rig
local flyBV, flyBG = nil, nil
setFly = function(on)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
    if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
    if on and hrp and hum then
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBG.P = 10000
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBV.Velocity = Vector3.new(0, 0, 0)
        flyBV.Parent = hrp
    elseif hum then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
end
RunService.RenderStepped:Connect(function()
    if not State.Fly then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not flyBV or not flyBG or flyBV.Parent ~= hrp then
        if State.Fly then setFly(true) else return end
    end
    local cam = getCam()
    if not cam then return end
    local fwd = (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
    local side = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
    local vert = (UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
    local move = cam.CFrame.LookVector * fwd + cam.CFrame.RightVector * side + Vector3.new(0, 1, 0) * vert
    if move.Magnitude > 0 then move = move.Unit * State.FlySpeed else move = Vector3.new(0, 0, 0) end
    flyBV.Velocity = move
    flyBG.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + cam.CFrame.LookVector)
end)
local function tpTo(pos)
    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end
local function charPosOfRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and effRole(p) == role and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp.Position end
        end
    end
    return nil
end
local function nearestCoinPos()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local folder = RS:FindFirstChild("Coins")
    if not folder then return nil end
    local bestPos, bestD = nil, math.huge
    for _, objFolder in ipairs(folder:GetChildren()) do
        for _, coin in ipairs(objFolder:GetChildren()) do
            local p = nil
            if coin:IsA("BasePart") then p = coin.Position
            elseif coin:IsA("Model") then
                local b = coin:FindFirstChildWhichIsA("BasePart", true)
                if b then p = b.Position end
            end
            if p then
                local d = (myHrp.Position - p).Magnitude
                if d < bestD then bestD, bestPos = d, p end
            end
        end
    end
    return bestPos
end
RunService.Stepped:Connect(function()
    if State.Noclip then
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
    if State.Fullbright or State.NoFog then
        pcall(function()
            if State.Fullbright then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            end
            if State.NoFog then
                Lighting.FogEnd = 100000
                Lighting.FogStart = 0
                for _, a in ipairs(Lighting:GetDescendants()) do
                    if a:IsA("Atmosphere") then a.Density = 0 end
                end
            end
        end)
    end
end)
UIS.InputBegan:Connect(function(input, gp)
    if not State.ClickTP then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not UIS:IsKeyDown(Enum.KeyCode.LeftControl) then return end
    local cam = getCam()
    if not cam then return end
    local ray = cam:ScreenPointToRay(Mouse.X, Mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local myChar = LocalPlayer.Character
    if myChar then params.FilterDescendantsInstances = { myChar } end
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if hit and hit.Position then tpTo(hit.Position) end
end)

-- World
local WorldPage = Window:Page({ Icon = "cloud" })
local WorldSub = WorldPage:SubPage({ Name = "World" })
local EnvSec = WorldSub:Section({ Name = "Environment"; Side = "Left"; Icon = "sun" })
local BrightOn = EnvSec:Label({ Text = "Fullbright" })
BrightOn:Toggle({ State = false; Flag = "Fullbright"; Callback = function(v)
    State.Fullbright = v
    if v and not savedLight then
        savedLight = {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient,
        }
    elseif not v and savedLight then
        pcall(function()
            Lighting.Brightness = savedLight.Brightness
            Lighting.ClockTime = savedLight.ClockTime
            Lighting.GlobalShadows = savedLight.GlobalShadows
            Lighting.OutdoorAmbient = savedLight.OutdoorAmbient
        end)
    end
end })
local FogOn = EnvSec:Label({ Text = "No fog" })
FogOn:Toggle({ State = false; Flag = "NoFog"; Callback = function(v)
    State.NoFog = v
    if v then
        savedAtmo = {}
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then savedAtmo[a] = a.Density end
        end
    else
        for a, d in pairs(savedAtmo) do
            pcall(function() a.Density = d end)
        end
        table.clear(savedAtmo)
        pcall(function() Lighting.FogEnd = 100000 end)
    end
end })
EnvSec:Slider({ Name = "Gravity"; Suffix = ""; Value = 196.2; Min = 0; Max = 500; Increment = 1; Flag = "Grav"; Callback = function(v)
    State.Grav = v
    pcall(function() Workspace.Gravity = v end)
end })
local TpSec = WorldSub:Section({ Name = "Teleports"; Side = "Right"; Icon = "zap" })
TpSec:Button({ Name = "To murderer"; Callback = function()
    local pos = charPosOfRole("Murderer")
    if pos then tpTo(pos) else Lumen.Notify({ Title = "bleed.rest"; Text = "No murderer found"; Duration = 2 }) end
end })
TpSec:Button({ Name = "To sheriff"; Callback = function()
    local pos = charPosOfRole("Sheriff")
    if pos then tpTo(pos) else Lumen.Notify({ Title = "bleed.rest"; Text = "No sheriff found"; Duration = 2 }) end
end })
TpSec:Button({ Name = "To nearest coin"; Callback = function()
    local pos = nearestCoinPos()
    if pos then tpTo(pos) else Lumen.Notify({ Title = "bleed.rest"; Text = "No coins found"; Duration = 2 }) end
end })
TpSec:Button({ Name = "To lobby"; Callback = function()
    local lobby = Workspace:FindFirstChild("RegularLobby")
    local spawn = lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
    if not spawn then spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true) end
    if spawn then tpTo(spawn.Position) else Lumen.Notify({ Title = "bleed.rest"; Text = "No spawn found"; Duration = 2 }) end
end })

if getgenv then getgenv().bleed_rest_loaded = function() pcall(function() Lumen.Unload() end) end end

Lumen:BuildConfigPage(Window)
Lumen.ToggleMenu(true)
Lumen.Notify({ Title = "bleed.rest"; Text = "Loaded (RightShift to toggle)"; Type = "Success"; Duration = 3 })
