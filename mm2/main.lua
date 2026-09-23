



if getgenv and getgenv().bleed_rest_loaded then
    pcall(function() getgenv().bleed_rest_loaded() end)
    task.wait(0.5)
end

local LIB_URLS = {
    "https://raw.githubusercontent.com/pandaeatdonuts-byte/bleed.rest/main/lib/Lumen.lua",
    "https://raw.githubusercontent.com/chromatiks/Lumen/main/Library.lua", 
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


Lumen.MenuKey = Enum.KeyCode.RightShift

Lumen:LoadingScreen({ Title = "bleed.rest", Subtitle = "Initializing...", Duration = 1.0 })
Lumen.SetWatermark("bleed.rest", true)
Lumen.SetKeybindList(true)


local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()


local Running = true
local Connections = {}
local function track(conn)
    Connections[#Connections + 1] = conn
    return conn
end

local function getCam()
    return Workspace.CurrentCamera
end

local function screenMouse()
    return UIS:GetMouseLocation()
end
local function toScreen(cam, world)
    local v, on = cam:WorldToViewportPoint(world)
    local inset = GuiService:GetGuiInset()
    return Vector2.new(v.X + inset.X, v.Y + inset.Y), on
end


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


local State = {
    
    KillAura = false, KillRange = 22, KillMethod = "Knife", KillTargets = "Murderer + Sheriff",
    FakeGun = false, Stealth = false,
    AutoCoins = false,
    
    ESP = true, Chams = true, EspName = true, EspRole = true, EspDist = true,
    Tracer = false, TracerFrom = "Bottom", TracerThick = 1,
    EspMaxDist = 600, ShowInnocents = true, ShowDead = false,
    ChamsFill = 0.6, ChamsTop = true,
ColFill = Color3.fromRGB(255, 255, 255), ColOutline = Color3.fromRGB(255, 255, 255),
    MurderESP = true, SheriffESP = true, RoleMode = "Always",
    
    Aimbot = false, AimHeld = false, AimFOV = 120, AimMode = "Mouse",
    AimSens = 1.0, AimSmoothX = 6, AimSmoothY = 6, AimSmooth = 35,
    AimPredict = true, PredictAmt = 100,
    AimPart = "Head", AimTargets = "Auto", AimVisible = true, ShowAimFOV = true,
    
    Silent = false, SilentFOV = 100, HitChance = 100, ExtraLead = 0.05,
    ShowSilentFOV = true,
    
    Trigger = false, TriggerHeld = false, TriggerDelay = 150, TriggerRange = 400,
    TriggerTargets = "Auto",
    
    Fly = false, FlySpeed = 60, WalkSpeed = 16, JumpPower = 50,
    Fullbright = false, NoFog = false, Grav = 196.2, Noclip = false, ClickTP = false,
    AmbientEnabled = false, AmbientColor = Color3.fromRGB(255, 255, 255), OutdoorAmbientColor = Color3.fromRGB(255, 255, 255),
    BloomEnabled = false, BloomIntensity = 0.5, BloomSize = 24, BloomThreshold = 1,
    ColorCorrectionEnabled = false, CCTint = Color3.fromRGB(255, 255, 255), CCBrightness = 0, CCContrast = 0, CCSaturation = 0,
    AtmosphereEnabled = false, AtmosphereColor = Color3.fromRGB(200, 200, 200), AtmosphereDecay = Color3.fromRGB(106, 112, 125), AtmosphereDensity = 0.35, AtmosphereHaze = 0, AtmosphereGlare = 0,
    TimeEnabled = false, TimeOfDay = 14,
    FogEnabled = false, FogColor = Color3.fromRGB(192, 192, 192), FogStart = 0, FogEnd = 100000,
    SkyboxEnabled = false, SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "", SkyboxRt = "", SkyboxUp = "",
    FovOverride = false, FovValue = 70,
    ThirdPerson = false, TpDist = 12, TpHeight = 4,
    SuperJump = false, SuperJumpPower = 200,
    AntiAfk = false,
    AutoClick = false, ClickerMs = 100,
    Spinbot = false, SpinSpeed = 80,
}


local Roles = {} 
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
            track(r.OnClientEvent:Connect(function(...) parseSignal(...) end))
        end
    end
    local rs = Gameplay:FindFirstChild("RoundStart")
    if rs and rs:IsA("RemoteEvent") then
        track(rs.OnClientEvent:Connect(function() table.clear(Roles) end))
    end
end

local function isAlive(plr)
    local a = plr:GetAttribute("Alive")
    if a == nil then return true end
    return a == true
end
local function toolRole(plr, scanBackpack)
    local char = plr and plr.Character
    local tool = char and char:FindFirstChildWhichIsA("Tool")
    if not tool and scanBackpack then
        local bp = plr:FindFirstChild("Backpack")
        if bp then tool = bp:FindFirstChildWhichIsA("Tool") end
    end
    if not tool then return nil end
    local n = tool.Name:lower()
    if n:find("knife") then return "Murderer" end
    if n:find("gun") then return "Sheriff" end
    return "Armed"
end
local function effRole(plr)
    local sig = Roles[plr.UserId]
    if sig then return sig end
    local t = toolRole(plr, State.RoleMode == "Always")
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


task.spawn(function()
    while Running and task.wait(3) do
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            
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
        return true 
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
track(Players.PlayerRemoving:Connect(function(plr)
    local l = tracers[plr.UserId]
    if l then pcall(function() l:Remove() end) tracers[plr.UserId] = nil end
    if currentAimTarget then currentAimTarget = nil end
end))
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
    tag.AlwaysOnTop = false 
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


local lastTriggerShot = 0
local silentOldCF, silentPending, silentScheduled = nil, false, false
local hasMouseMove = typeof(mousemoverel) == "function"
local function round6(v)
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end
track(RunService.RenderStepped:Connect(function()
    local cam = getCam()
    if not cam then return end
    local mousePos = screenMouse()
    local menuOpen = Lumen.MenuOpen == true
    setCircle(fovCircle, State.ShowAimFOV and State.Aimbot and not menuOpen, mousePos, State.AimFOV)
    setCircle(silentCircle, State.ShowSilentFOV and State.Silent and not menuOpen, mousePos, State.SilentFOV)
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
            
            local hl = ensureChams(char)
            hl.Enabled = showPlayer and State.Chams
            if hl.Enabled then
                hl.FillColor = espFill(role)
                hl.FillTransparency = State.ChamsFill
                hl.OutlineColor = espOutline(role)
                hl.OutlineTransparency = 0
                hl.DepthMode = State.ChamsTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            end
            
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
    
    if State.Aimbot and State.AimHeld and not menuOpen then
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
    
    if State.Trigger and State.TriggerHeld and not menuOpen then
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
end))


track(UIS.InputBegan:Connect(function(input, gp)
    if not State.Silent then return end
    if Lumen.MenuOpen == true then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if math.random(1, 100) > State.HitChance then return end
    local cam = getCam()
    if not cam then return end
    local mousePos = screenMouse()
    local plr, char, part = bestTarget(cam, mousePos, State.SilentFOV, State.AimTargets, State.AimPart)
    if plr and part then
        local aimAt = predictPos(part)
        if aimAt then
            if not silentPending then silentOldCF = cam.CFrame end
            silentPending = true
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimAt)
            if not silentScheduled then
                silentScheduled = true
                task.delay(0.04, function()
                    silentScheduled = false
                    silentPending = false
                    local c2 = getCam()
                    if c2 and silentOldCF then pcall(function() c2.CFrame = silentOldCF end) end
                end)
            end
        end
    end
end))


local Window = Lumen:Window({ Title = "bleed.rest", Footer = "bleed.rest" })


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
    while Running and task.wait(1) do
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
TrigOn:Keybind({ Key = Enum.KeyCode.LeftAlt; Type = "Hold"; Flag = "TriggerKey"; Callback = function(v) State.TriggerHeld = v end })
TrigSec:Slider({ Name = "Delay"; Suffix = " ms"; Value = 150; Min = 0; Max = 500; Increment = 10; Flag = "TriggerDelay"; Callback = function(v) State.TriggerDelay = v end })
TrigSec:Slider({ Name = "Max range"; Suffix = " studs"; Value = 400; Min = 20; Max = 2000; Increment = 10; Flag = "TriggerRange"; Callback = function(v) State.TriggerRange = v end })
TrigSec:Dropdown({ Name = "Targets"; Options = { "Auto", "Murderer", "Murderer + Sheriff", "Sheriff", "Everyone" }; Value = "Auto"; Flag = "TriggerTargets"; Callback = function(v) State.TriggerTargets = v end })

local KillerPage = Combat:SubPage({ Name = "Killer" })
local KA = KillerPage:Section({ Name = "Kill Aura"; Side = "Left"; Icon = "crosshair" })
local KALabel = KA:Label({ Text = "Enable kill aura" })
KALabel:Toggle({ State = false; Flag = "KillAura"; Callback = function(v) State.KillAura = v end })
KA:Slider({ Name = "Range"; Suffix = " studs"; Value = 22; Min = 8; Max = 60; Increment = 1; Flag = "KillRange"; Callback = function(v) State.KillRange = v end })
KA:Dropdown({ Name = "Method"; Options = { "Knife", "Gun", "Eliminate" }; Value = "Knife"; Flag = "KillMethod"; Callback = function(v) State.KillMethod = v end })
KA:Dropdown({ Name = "Targets"; Options = { "Murderer + Sheriff", "Murderer", "Sheriff", "Everyone" }; Value = "Murderer + Sheriff"; Flag = "KillTargets"; Callback = function(v) State.KillTargets = v end })
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
    while Running and task.wait(0.25) do
        if State.KillAura then
            local killEvent = Gameplay and Gameplay:FindFirstChild("KillEvent")
            local eliminate = Gameplay and Gameplay:FindFirstChild("EliminatePlayer")
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local c2, role = validTarget(plr, "Everyone", State.KillRange)
                        if c2 and roleAllowed(role, State.KillTargets) then
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
RoleSec:Paragraph({ Title = "Detection"; Body = "Roles auto-detect from round events, scoreboard names and weapons. Clears every round." })
RoleSec:Dropdown({ Name = "Weapon detection"; Options = { "Always", "When held" }; Value = "Always"; Flag = "RoleMode"; Callback = function(v) State.RoleMode = v end })
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


local FarmPage = Window:Page({ Icon = "box" })
local Coins = FarmPage:SubPage({ Name = "Coins" })
local CoinSec = Coins:Section({ Name = "Auto Farm"; Side = "Left"; Icon = "box" })
local CoinLabel = CoinSec:Label({ Text = "Auto collect coins" })
CoinLabel:Toggle({ State = false; Flag = "AutoCoins"; Callback = function(v) State.AutoCoins = v end })

task.spawn(function()
    while Running and task.wait(0.5) do
        local getCoin = Gameplay and Gameplay:FindFirstChild("GetCoin")
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


local PlayerPage = Window:Page({ Icon = "user" })
local Move = PlayerPage:SubPage({ Name = "Movement" })
local MoveSec = Move:Section({ Name = "Character"; Side = "Left"; Icon = "move" })
MoveSec:Slider({ Name = "WalkSpeed"; Suffix = ""; Value = 16; Min = 1; Max = 500; Increment = 1; Flag = "WalkSpeed"; Callback = function(v)
    State.WalkSpeed = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end })
MoveSec:Slider({ Name = "JumpPower"; Suffix = ""; Value = 50; Min = 1; Max = 500; Increment = 1; Flag = "JumpPower"; Callback = function(v)
    State.JumpPower = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = v end
end })
local FlyLabel = MoveSec:Label({ Text = "Fly" })
local setFly 
local FlyToggle = FlyLabel:Toggle({ State = false; Flag = "Fly"; Callback = function(v)
    State.Fly = v
    if setFly then setFly(v) end
end })
FlyLabel:Keybind({ Key = Enum.KeyCode.F; Type = "Toggle"; Flag = "FlyKey"; Callback = function()
    if FlyToggle then FlyToggle.Set() end
end })
MoveSec:Slider({ Name = "Fly speed"; Suffix = ""; Value = 60; Min = 1; Max = 500; Increment = 5; Flag = "FlySpeed"; Callback = function(v) State.FlySpeed = v end })
local NoclipOn = MoveSec:Label({ Text = "Noclip" })
NoclipOn:Toggle({ State = false; Flag = "Noclip"; Callback = function(v) State.Noclip = v end })
local ClickTpOn = MoveSec:Label({ Text = "Ctrl+Click teleport" })
ClickTpOn:Toggle({ State = false; Flag = "ClickTP"; Callback = function(v) State.ClickTP = v end })

local savedFov = nil
local MiscPage = Window:Page({ Icon = "star" })
local MiscSub = MiscPage:SubPage({ Name = "Misc" })
local CamSec = MiscSub:Section({ Name = "Camera"; Side = "Left"; Icon = "settings" })
local FovOn = CamSec:Label({ Text = "Field of view override" })
FovOn:Toggle({ State = false; Flag = "FovOverride"; Callback = function(v)
    if v and not savedFov then
        local cam = getCam()
        if cam then savedFov = cam.FieldOfView end
    elseif not v and savedFov then
        local cam = getCam()
        if cam then pcall(function() cam.FieldOfView = savedFov end) end
    end
    State.FovOverride = v
end })
CamSec:Slider({ Name = "FOV"; Suffix = ""; Value = 70; Min = 20; Max = 120; Increment = 1; Flag = "FovValue"; Callback = function(v) State.FovValue = v end })
local TpOn = CamSec:Label({ Text = "Third person" })
TpOn:Toggle({ State = false; Flag = "ThirdPerson"; Callback = function(v) State.ThirdPerson = v end })
CamSec:Slider({ Name = "Distance"; Suffix = ""; Value = 12; Min = 3; Max = 30; Increment = 1; Flag = "TpDist"; Callback = function(v) State.TpDist = v end })
CamSec:Slider({ Name = "Height"; Suffix = ""; Value = 4; Min = 0; Max = 15; Increment = 0.5; Flag = "TpHeight"; Callback = function(v) State.TpHeight = v end })
local CharSec = MiscSub:Section({ Name = "Character"; Side = "Right"; Icon = "user" })
local SjOn = CharSec:Label({ Text = "Super jump" })
SjOn:Toggle({ State = false; Flag = "SuperJump"; Callback = function(v) State.SuperJump = v end })
CharSec:Slider({ Name = "Jump power"; Suffix = ""; Value = 200; Min = 50; Max = 500; Increment = 10; Flag = "SuperJumpPower"; Callback = function(v) State.SuperJumpPower = v end })
local AfkOn = CharSec:Label({ Text = "Anti-AFK" })
AfkOn:Toggle({ State = false; Flag = "AntiAfk"; Callback = function(v) State.AntiAfk = v end })
local AcOn = CharSec:Label({ Text = "Auto-clicker" })
AcOn:Toggle({ State = false; Flag = "AutoClick"; Callback = function(v) State.AutoClick = v end })
CharSec:Slider({ Name = "Click interval"; Suffix = " ms"; Value = 100; Min = 10; Max = 1000; Increment = 10; Flag = "ClickerMs"; Callback = function(v) State.ClickerMs = v end })
local SpinOn = CharSec:Label({ Text = "Spinbot" })
SpinOn:Toggle({ State = false; Flag = "Spinbot"; Callback = function(v) State.Spinbot = v end })
CharSec:Slider({ Name = "Spin speed"; Suffix = " deg/s"; Value = 80; Min = 10; Max = 500; Increment = 5; Flag = "SpinSpeed"; Callback = function(v) State.SpinSpeed = v end })
local ServerPar = CharSec:Paragraph({ Title = "Server"; Body = "Players: ?   Ping: ?" })
CharSec:Button({ Name = "Reset character"; Callback = function()
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)
end })

track(RunService.RenderStepped:Connect(function(dt)
    local cam = getCam()
    if not cam then return end
    if State.FovOverride then cam.FieldOfView = State.FovValue end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if State.Spinbot and hrp then
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(State.SpinSpeed) * dt, 0)
    end
    if State.ThirdPerson and hrp then
        local look = cam.CFrame.LookVector
        cam.CFrame = CFrame.new(hrp.Position - look * State.TpDist + Vector3.new(0, State.TpHeight, 0), hrp.Position + Vector3.new(0, 1.5, 0))
    end
end))
track(UIS.InputBegan:Connect(function(input, gp)
    if not State.SuperJump then return end
    if Lumen.MenuOpen == true then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Velocity = Vector3.new(hrp.Velocity.X, State.SuperJumpPower, hrp.Velocity.Z) end
end))
task.spawn(function()
    while Running and task.wait(60) do
        if State.AntiAfk then
            pcall(function()
                local VU = game:GetService("VirtualUser")
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
    end
end)
task.spawn(function()
    while Running do
        if State.AutoClick and not (Lumen.MenuOpen == true) and typeof(mouse1click) == "function" then
            pcall(function() mouse1click() end)
            task.wait(State.ClickerMs / 1000)
        else
            task.wait()
        end
    end
end)
task.spawn(function()
    while Running and task.wait(1) do
        pcall(function()
            local n = #Players:GetPlayers()
            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            ServerPar:SetBody("Players: " .. n .. "   Ping: " .. ping .. "ms")
        end)
    end
end)


local Lighting = game:GetService("Lighting")
local defaultGravity = Workspace.Gravity
local noclipSaved = {}
local savedLight = nil
local savedAtmo = {}
local savedFog = nil
local savedWorld = nil
local worldBloom, worldColorCorrection, worldAtmosphere, worldSky = nil, nil, nil, nil

local function assetUrl(id)
    id = tostring(id or ""):gsub("%s+", "")
    if id == "" then return "" end
    if id:find("^rbxassetid://") or id:find("^http") then return id end
    return "rbxassetid://" .. id
end

local function captureWorld()
    if savedWorld then return end
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    local sky = Lighting:FindFirstChildOfClass("Sky")
    savedWorld = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
        FogColor = Lighting.FogColor,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        Atmosphere = atmosphere,
        AtmosphereProps = atmosphere and {
            Color = atmosphere.Color,
            Decay = atmosphere.Decay,
            Density = atmosphere.Density,
            Haze = atmosphere.Haze,
            Glare = atmosphere.Glare,
        } or nil,
        Sky = sky,
        SkyProps = sky and {
            SkyboxBk = sky.SkyboxBk,
            SkyboxDn = sky.SkyboxDn,
            SkyboxFt = sky.SkyboxFt,
            SkyboxLf = sky.SkyboxLf,
            SkyboxRt = sky.SkyboxRt,
            SkyboxUp = sky.SkyboxUp,
            CelestialBodiesShown = sky.CelestialBodiesShown,
            StarCount = sky.StarCount,
        } or nil,
    }
end

local function getManagedEffect(className, current)
    if current and current.Parent == Lighting then return current end
    local effect = Instance.new(className)
    effect.Name = "bleed_rest_" .. className
    effect.Parent = Lighting
    return effect
end

local function restoreWorld()
    if not savedWorld then return end
    pcall(function()
        Lighting.Ambient = savedWorld.Ambient
        Lighting.OutdoorAmbient = savedWorld.OutdoorAmbient
        Lighting.Brightness = savedWorld.Brightness
        Lighting.ClockTime = savedWorld.ClockTime
        Lighting.GlobalShadows = savedWorld.GlobalShadows
        Lighting.FogColor = savedWorld.FogColor
        Lighting.FogStart = savedWorld.FogStart
        Lighting.FogEnd = savedWorld.FogEnd
    end)
    if savedWorld.Atmosphere and savedWorld.Atmosphere.Parent and savedWorld.AtmosphereProps then
        local props = savedWorld.AtmosphereProps
        pcall(function()
            savedWorld.Atmosphere.Color = props.Color
            savedWorld.Atmosphere.Decay = props.Decay
            savedWorld.Atmosphere.Density = props.Density
            savedWorld.Atmosphere.Haze = props.Haze
            savedWorld.Atmosphere.Glare = props.Glare
        end)
    end
    if savedWorld.Sky and savedWorld.Sky.Parent and savedWorld.SkyProps then
        local props = savedWorld.SkyProps
        pcall(function()
            savedWorld.Sky.SkyboxBk = props.SkyboxBk
            savedWorld.Sky.SkyboxDn = props.SkyboxDn
            savedWorld.Sky.SkyboxFt = props.SkyboxFt
            savedWorld.Sky.SkyboxLf = props.SkyboxLf
            savedWorld.Sky.SkyboxRt = props.SkyboxRt
            savedWorld.Sky.SkyboxUp = props.SkyboxUp
            savedWorld.Sky.CelestialBodiesShown = props.CelestialBodiesShown
            savedWorld.Sky.StarCount = props.StarCount
        end)
    end
end

local function worldControlsActive()
    return State.AmbientEnabled or State.BloomEnabled or State.ColorCorrectionEnabled or State.AtmosphereEnabled or State.TimeEnabled or State.FogEnabled or State.SkyboxEnabled
end

local function applyOverrides()
    pcall(function()
        if State.AmbientEnabled then
            Lighting.Ambient = State.AmbientColor
            Lighting.OutdoorAmbient = State.OutdoorAmbientColor
        end
        if State.TimeEnabled then
            Lighting.ClockTime = State.TimeOfDay
        end
        if State.FogEnabled then
            Lighting.FogColor = State.FogColor
            Lighting.FogStart = State.FogStart
            Lighting.FogEnd = State.FogEnd
        end
    end)
    if State.BloomEnabled then
        worldBloom = getManagedEffect("BloomEffect", worldBloom)
        pcall(function()
            worldBloom.Enabled = true
            worldBloom.Intensity = State.BloomIntensity
            worldBloom.Size = State.BloomSize
            worldBloom.Threshold = State.BloomThreshold
        end)
    elseif worldBloom then
        pcall(function() worldBloom.Enabled = false end)
    end
    if State.ColorCorrectionEnabled then
        worldColorCorrection = getManagedEffect("ColorCorrectionEffect", worldColorCorrection)
        pcall(function()
            worldColorCorrection.Enabled = true
            worldColorCorrection.TintColor = State.CCTint
            worldColorCorrection.Brightness = State.CCBrightness
            worldColorCorrection.Contrast = State.CCContrast
            worldColorCorrection.Saturation = State.CCSaturation
        end)
    elseif worldColorCorrection then
        pcall(function() worldColorCorrection.Enabled = false end)
    end
    if State.AtmosphereEnabled then
        worldAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or worldAtmosphere
        worldAtmosphere = getManagedEffect("Atmosphere", worldAtmosphere)
        pcall(function()
            worldAtmosphere.Color = State.AtmosphereColor
            worldAtmosphere.Decay = State.AtmosphereDecay
            worldAtmosphere.Density = State.AtmosphereDensity
            worldAtmosphere.Haze = State.AtmosphereHaze
            worldAtmosphere.Glare = State.AtmosphereGlare
        end)
    end
    if State.SkyboxEnabled then
        worldSky = Lighting:FindFirstChildOfClass("Sky") or worldSky
        worldSky = getManagedEffect("Sky", worldSky)
        pcall(function()
            worldSky.SkyboxBk = assetUrl(State.SkyboxBk)
            worldSky.SkyboxDn = assetUrl(State.SkyboxDn)
            worldSky.SkyboxFt = assetUrl(State.SkyboxFt)
            worldSky.SkyboxLf = assetUrl(State.SkyboxLf)
            worldSky.SkyboxRt = assetUrl(State.SkyboxRt)
            worldSky.SkyboxUp = assetUrl(State.SkyboxUp)
        end)
    end
end

local function applyWorld()
    if worldControlsActive() then captureWorld() end
    if savedWorld then restoreWorld() end
    applyOverrides()
    if not State.AtmosphereEnabled and worldAtmosphere and savedWorld and not savedWorld.Atmosphere then
        pcall(function() worldAtmosphere:Destroy() end)
        worldAtmosphere = nil
    end
    if not State.SkyboxEnabled and worldSky and savedWorld and not savedWorld.Sky then
        pcall(function() worldSky:Destroy() end)
        worldSky = nil
    end
    if not worldControlsActive() then
        restoreWorld()
        savedWorld = nil
    end
end


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
track(RunService.RenderStepped:Connect(function()
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
end))


track(LocalPlayer.CharacterAdded:Connect(function()
    table.clear(noclipSaved)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = State.WalkSpeed
            hum.JumpPower = State.JumpPower
        end
        if State.Fly then setFly(true) end
    end)
end))
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
track(RunService.Stepped:Connect(function()
    if State.Noclip then
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    if noclipSaved[p] == nil then noclipSaved[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        end
    elseif next(noclipSaved) ~= nil then
        for p, collide in pairs(noclipSaved) do
            if p and p.Parent then pcall(function() p.CanCollide = collide end) end
        end
        table.clear(noclipSaved)
    end
    if State.Fullbright or State.NoFog then
        pcall(function()
            if State.Fullbright then
                Lighting.Brightness = 2
                if not State.TimeEnabled then Lighting.ClockTime = 14 end
                Lighting.GlobalShadows = false
                if not State.AmbientEnabled then Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255) end
            end
            if State.NoFog then
                if not State.FogEnabled then
                    Lighting.FogEnd = 100000
                    Lighting.FogStart = 0
                end
                for _, a in ipairs(Lighting:GetDescendants()) do
                    if a:IsA("Atmosphere") then a.Density = 0 end
                end
            end
        end)
    end
    if State.Grav ~= defaultGravity then
        pcall(function() Workspace.Gravity = State.Grav end)
    end
    if worldControlsActive() then
        applyOverrides()
    end
end))
track(UIS.InputBegan:Connect(function(input, gp)
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
end))


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
        applyWorld()
    end
end })
local FogOn = EnvSec:Label({ Text = "No fog" })
FogOn:Toggle({ State = false; Flag = "NoFog"; Callback = function(v)
    State.NoFog = v
    if v then
        savedAtmo = {}
        savedFog = { Lighting.FogStart, Lighting.FogEnd }
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then savedAtmo[a] = a.Density end
        end
    else
        if next(savedAtmo) ~= nil then
            for a, d in pairs(savedAtmo) do
                pcall(function() a.Density = d end)
            end
            table.clear(savedAtmo)
        end
        if savedFog then
            pcall(function() Lighting.FogStart = savedFog[1] end)
            pcall(function() Lighting.FogEnd = savedFog[2] end)
            savedFog = nil
        end
        applyWorld()
    end
end })
EnvSec:Slider({ Name = "Gravity"; Suffix = ""; Value = 196.2; Min = 0; Max = 500; Increment = 1; Flag = "Grav"; Callback = function(v)
    State.Grav = v
    pcall(function() Workspace.Gravity = v end)
end })
local AmbOn = EnvSec:Label({ Text = "Ambient override" })
AmbOn:Toggle({ State = false; Flag = "AmbientEnabled"; Callback = function(v) State.AmbientEnabled = v; applyWorld() end })
local AmbCol = EnvSec:Label({ Text = "Ambient" })
AmbCol:Colorpicker({ Color = Color3.fromRGB(255, 255, 255); Flag = "AmbientColor"; Callback = function(v) State.AmbientColor = v; applyWorld() end })
local OutdoorAmbCol = EnvSec:Label({ Text = "Outdoor ambient" })
OutdoorAmbCol:Colorpicker({ Color = Color3.fromRGB(255, 255, 255); Flag = "OutdoorAmbientColor"; Callback = function(v) State.OutdoorAmbientColor = v; applyWorld() end })
local TimeOn = EnvSec:Label({ Text = "Time of day override" })
TimeOn:Toggle({ State = false; Flag = "TimeEnabled"; Callback = function(v) State.TimeEnabled = v; applyWorld() end })
EnvSec:Slider({ Name = "Clock time"; Suffix = "h"; Value = 14; Min = 0; Max = 24; Increment = 0.25; Flag = "TimeOfDay"; Callback = function(v) State.TimeOfDay = v; applyWorld() end })

local BloomSec = WorldSub:Section({ Name = "Bloom"; Side = "Right"; Icon = "sparkles" })
local BloomOn = BloomSec:Label({ Text = "Bloom override" })
BloomOn:Toggle({ State = false; Flag = "BloomEnabled"; Callback = function(v) State.BloomEnabled = v; applyWorld() end })
BloomSec:Slider({ Name = "Intensity"; Suffix = ""; Value = 0.5; Min = 0; Max = 10; Increment = 0.1; Flag = "BloomIntensity"; Callback = function(v) State.BloomIntensity = v; applyWorld() end })
BloomSec:Slider({ Name = "Size"; Suffix = ""; Value = 24; Min = 0; Max = 56; Increment = 1; Flag = "BloomSize"; Callback = function(v) State.BloomSize = v; applyWorld() end })
BloomSec:Slider({ Name = "Threshold"; Suffix = ""; Value = 1; Min = 0; Max = 5; Increment = 0.1; Flag = "BloomThreshold"; Callback = function(v) State.BloomThreshold = v; applyWorld() end })

local CCSec = WorldSub:Section({ Name = "Color Correction"; Side = "Left"; Icon = "palette" })
local CCOn = CCSec:Label({ Text = "Color correction override" })
CCOn:Toggle({ State = false; Flag = "ColorCorrectionEnabled"; Callback = function(v) State.ColorCorrectionEnabled = v; applyWorld() end })
local CCTint = CCSec:Label({ Text = "Tint" })
CCTint:Colorpicker({ Color = Color3.fromRGB(255, 255, 255); Flag = "CCTint"; Callback = function(v) State.CCTint = v; applyWorld() end })
CCSec:Slider({ Name = "Brightness"; Suffix = ""; Value = 0; Min = -1; Max = 1; Increment = 0.05; Flag = "CCBrightness"; Callback = function(v) State.CCBrightness = v; applyWorld() end })
CCSec:Slider({ Name = "Contrast"; Suffix = ""; Value = 0; Min = -1; Max = 1; Increment = 0.05; Flag = "CCContrast"; Callback = function(v) State.CCContrast = v; applyWorld() end })
CCSec:Slider({ Name = "Saturation"; Suffix = ""; Value = 0; Min = -1; Max = 1; Increment = 0.05; Flag = "CCSaturation"; Callback = function(v) State.CCSaturation = v; applyWorld() end })

local AtmoSec = WorldSub:Section({ Name = "Atmosphere"; Side = "Right"; Icon = "cloud" })
local AtmoOn = AtmoSec:Label({ Text = "Atmosphere override" })
AtmoOn:Toggle({ State = false; Flag = "AtmosphereEnabled"; Callback = function(v) State.AtmosphereEnabled = v; applyWorld() end })
local AtmoColor = AtmoSec:Label({ Text = "Color" })
AtmoColor:Colorpicker({ Color = Color3.fromRGB(200, 200, 200); Flag = "AtmosphereColor"; Callback = function(v) State.AtmosphereColor = v; applyWorld() end })
local AtmoDecay = AtmoSec:Label({ Text = "Decay" })
AtmoDecay:Colorpicker({ Color = Color3.fromRGB(106, 112, 125); Flag = "AtmosphereDecay"; Callback = function(v) State.AtmosphereDecay = v; applyWorld() end })
AtmoSec:Slider({ Name = "Density"; Suffix = ""; Value = 0.35; Min = 0; Max = 1; Increment = 0.01; Flag = "AtmosphereDensity"; Callback = function(v) State.AtmosphereDensity = v; applyWorld() end })
AtmoSec:Slider({ Name = "Haze"; Suffix = ""; Value = 0; Min = 0; Max = 10; Increment = 0.1; Flag = "AtmosphereHaze"; Callback = function(v) State.AtmosphereHaze = v; applyWorld() end })
AtmoSec:Slider({ Name = "Glare"; Suffix = ""; Value = 0; Min = 0; Max = 10; Increment = 0.1; Flag = "AtmosphereGlare"; Callback = function(v) State.AtmosphereGlare = v; applyWorld() end })

local FogSec = WorldSub:Section({ Name = "Fog"; Side = "Left"; Icon = "cloud-fog" })
local FogOverride = FogSec:Label({ Text = "Fog override" })
FogOverride:Toggle({ State = false; Flag = "FogEnabled"; Callback = function(v) State.FogEnabled = v; applyWorld() end })
local FogCol = FogSec:Label({ Text = "Fog color" })
FogCol:Colorpicker({ Color = Color3.fromRGB(192, 192, 192); Flag = "FogColor"; Callback = function(v) State.FogColor = v; applyWorld() end })
FogSec:Slider({ Name = "Fog start"; Suffix = ""; Value = 0; Min = 0; Max = 10000; Increment = 25; Flag = "FogStart"; Callback = function(v) State.FogStart = v; applyWorld() end })
FogSec:Slider({ Name = "Fog end"; Suffix = ""; Value = 100000; Min = 0; Max = 100000; Increment = 100; Flag = "FogEnd"; Callback = function(v) State.FogEnd = v; applyWorld() end })

local SkySec = WorldSub:Section({ Name = "Skybox"; Side = "Right"; Icon = "image" })
local SkyOn = SkySec:Label({ Text = "Skybox override" })
local SkyToggle = SkyOn:Toggle({ State = false; Flag = "SkyboxEnabled"; Callback = function(v) State.SkyboxEnabled = v; applyWorld() end })
local SkyboxPresets = {
    ["Classic Blue"] = {
        "271042516", "271077243", "271042556", "271042310", "271042467", "271077958",
    },
    ["Warm Interior"] = {
        "162001887", "161998893", "162001897", "162001904", "162001919", "162001926",
    },
    ["Sunset"] = {
        "323494035", "323494368", "323494130", "323494252", "323494067", "323493360",
    },
    ["Red Night"] = {
        "401664839", "401664862", "401664960", "401664881", "401664901", "401664936",
    },
    ["Orange Sunset"] = {
        "458016711", "458016826", "458016532", "458016655", "458016782", "458016792",
    },
    ["Night"] = {
        "15470149279", "15470151245", "15470153860", "15470155938", "15470158022", "15470160563",
    },
    ["Galaxy"] = {
        "159454299", "159454296", "159454293", "159454286", "159454300", "159454288",
    },
    ["Purple Space"] = {
        "14543264135", "14543358958", "14543257810", "14543275895", "14543280890", "14543371676",
    },
    ["Spring"] = {
        "12216109205", "12216109875", "12216109489", "12216110170", "12216110471", "12216108877",
    },
    ["Beach Cloudy"] = {
        "125067016223038", "92271588990078", "123041572863662", "112713940757545", "134783689249068", "138659726817305",
    },
    ["Beach Parking"] = {
        "91970493661089", "70755555055104", "72267757354285", "120452757655371", "105981014339947", "104044841574911",
    },
    ["Belfast Farmhouse"] = {
        "115324744121944", "88950898640266", "71742543735820", "133893021751248", "88068379379339", "126989244212693",
    },
    ["Belfast Open Field"] = {
        "133352059518785", "78972161636066", "128211522618755", "122194691487246", "105942074651229", "112492340176616",
    },
    ["Belfast Sunset"] = {
        "107786237452160", "109953709194446", "100735950859096", "74233469362020", "117169951089259", "113912446184349",
    },
}
local SkyInputBk, SkyInputDn, SkyInputFt, SkyInputLf, SkyInputRt, SkyInputUp
SkySec:Dropdown({ Name = "Preset"; Options = {
    "Custom", "Classic Blue", "Warm Interior", "Sunset", "Red Night", "Orange Sunset",
    "Night", "Galaxy", "Purple Space", "Spring", "Beach Cloudy", "Beach Parking",
    "Belfast Farmhouse", "Belfast Open Field", "Belfast Sunset",
}; Value = "Custom"; Flag = "WorldSkyPreset"; Callback = function(name)
    local faces = SkyboxPresets[name]
    if not faces then return end
    State.SkyboxBk, State.SkyboxDn, State.SkyboxFt = faces[1], faces[2], faces[3]
    State.SkyboxLf, State.SkyboxRt, State.SkyboxUp = faces[4], faces[5], faces[6]
    State.SkyboxEnabled = true
    if SkyToggle then SkyToggle.Set(true) end
    if SkyInputBk then SkyInputBk.Set(faces[1]) end
    if SkyInputDn then SkyInputDn.Set(faces[2]) end
    if SkyInputFt then SkyInputFt.Set(faces[3]) end
    if SkyInputLf then SkyInputLf.Set(faces[4]) end
    if SkyInputRt then SkyInputRt.Set(faces[5]) end
    if SkyInputUp then SkyInputUp.Set(faces[6]) end
    applyWorld()
end })
SkyInputBk = SkySec:Input({ Name = "Back asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxBk"; Callback = function(v) State.SkyboxBk = v; applyWorld() end })
SkyInputDn = SkySec:Input({ Name = "Down asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxDn"; Callback = function(v) State.SkyboxDn = v; applyWorld() end })
SkyInputFt = SkySec:Input({ Name = "Front asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxFt"; Callback = function(v) State.SkyboxFt = v; applyWorld() end })
SkyInputLf = SkySec:Input({ Name = "Left asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxLf"; Callback = function(v) State.SkyboxLf = v; applyWorld() end })
SkyInputRt = SkySec:Input({ Name = "Right asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxRt"; Callback = function(v) State.SkyboxRt = v; applyWorld() end })
SkyInputUp = SkySec:Input({ Name = "Up asset id"; Placeholder = "rbxassetid://..."; Flag = "SkyboxUp"; Callback = function(v) State.SkyboxUp = v; applyWorld() end })

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

local origUnload = Lumen.Unload

local function cleanup()
    Running = false
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(Connections)
    for _, l in pairs(tracers) do
        pcall(function() l:Remove() end)
    end
    table.clear(tracers)
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    if silentCircle then pcall(function() silentCircle:Remove() end) end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local tag = char:FindFirstChild("bleedTag")
            if tag then pcall(function() tag:Destroy() end) end
            local hl = char:FindFirstChild("bleedChams")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end
    for p, collide in pairs(noclipSaved) do
        if p and p.Parent then pcall(function() p.CanCollide = collide end) end
    end
    table.clear(noclipSaved)
    if setFly then pcall(function() setFly(false) end) end
    if savedFov and State.FovOverride then
        local cam = getCam()
        if cam then pcall(function() cam.FieldOfView = savedFov end) end
    end
    if savedLight then
        pcall(function()
            Lighting.Brightness = savedLight.Brightness
            Lighting.ClockTime = savedLight.ClockTime
            Lighting.GlobalShadows = savedLight.GlobalShadows
            Lighting.OutdoorAmbient = savedLight.OutdoorAmbient
        end)
        savedLight = nil
    end
    if next(savedAtmo) ~= nil then
        for a, d in pairs(savedAtmo) do
            if a and a.Parent then pcall(function() a.Density = d end) end
        end
        table.clear(savedAtmo)
    end
    if savedFog then
        pcall(function() Lighting.FogStart = savedFog[1] end)
        pcall(function() Lighting.FogEnd = savedFog[2] end)
        savedFog = nil
    end
    if savedWorld then
        pcall(restoreWorld)
        savedWorld = nil
    end
    if worldSky and worldSky.Name == "bleed_rest_Sky" then
        pcall(function() worldSky:Destroy() end)
    end
    worldSky = nil
    if worldAtmosphere and worldAtmosphere.Name == "bleed_rest_Atmosphere" then
        pcall(function() worldAtmosphere:Destroy() end)
    end
    worldAtmosphere = nil
    if worldBloom then pcall(function() worldBloom:Destroy() end) worldBloom = nil end
    if worldColorCorrection then pcall(function() worldColorCorrection:Destroy() end) worldColorCorrection = nil end
    pcall(function() Workspace.Gravity = defaultGravity end)
    pcall(origUnload)
end

if getgenv then getgenv().bleed_rest_loaded = cleanup end

Lumen.Unload = function()
    pcall(cleanup)
end

Lumen:BuildConfigPage(Window)
Lumen.ToggleMenu(true)
Lumen.Notify({ Title = "bleed.rest"; Text = "Loaded (RightShift to toggle)"; Type = "Success"; Duration = 3 })

