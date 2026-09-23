



local Lumen = loadstring(game:HttpGet("https://raw.githubusercontent.com/chromatiks/Lumen/main/Library.lua"))()

Lumen.SetConfigFolder("Lumen")

Lumen:KeySystem({
	Title = "Lumen Login";
	Placeholder = "License key";
	ButtonText = "Sign in";
	Remember = true;
	ShowExpiry = true;
	WatermarkExpiry = true;
	GetKey = "discord.gg/noctro";
	Validate = function(key, finish)
		if key == "lumen" then
			return true, os.time() + (7 * 86400)
		end
		return false, nil, "Invalid key, try lumen"
	end;
})

Lumen:LoadingScreen({ Title = "Lumen"; Subtitle = "Initializing…"; Duration = 1.25 })

Lumen.SetWatermark("Lumen", true)
Lumen.SetKeybindList(true)

local Window = Lumen:Window({
	Title = "Lumen";
	Footer = ".gg/noctro";
})

local Combat = Window:Page({ Icon = "swords" })
local Aimbot = Combat:SubPage({ Name = "Aimbot" })
local AntiAim = Combat:SubPage({ Name = "Anti-Aim" })
local Trigger = Combat:SubPage({ Name = "Triggerbot" })

local AimMain = Aimbot:Section({ Name = "Main"; Side = "Left"; Icon = "crosshair" })
local AimTarget = Aimbot:Section({ Name = "Targeting"; Side = "Left"; Icon = "target" })
local AimMisc = Aimbot:Section({ Name = "Misc"; Side = "Right"; Icon = "layers" })
local AimExtra = Aimbot:Section({ Name = "Extra"; Side = "Right"; Icon = "star" })

local EnableAim = AimMain:Label({ Text = "Enable aimbot" })
EnableAim:Toggle({ State = false; Flag = "AimbotEnabled"; Callback = function() end })
EnableAim:Keybind({ Key = Enum.KeyCode.RightShift; Type = "Hold"; Flag = "AimbotKey"; Callback = function() end })
EnableAim:Colorpicker({ Color = Color3.fromRGB(255, 80, 80); Flag = "AimbotColor"; Callback = function() end })

AimMain:Slider({ Name = "Field of view"; Suffix = "°"; Value = 90; Min = 1; Max = 180; Increment = 1; Flag = "AimbotFOV"; Callback = function() end })
AimMain:Slider({ Name = "Smoothness"; Suffix = "%"; Value = 35; Min = 0; Max = 100; Increment = 1; Flag = "AimbotSmooth"; Callback = function() end })
AimMain:Dropdown({ Name = "Target part"; Options = { "Head", "Torso", "HumanoidRootPart", "Random" }; Value = "Head"; Flag = "AimbotPart"; Callback = function() end })

AimTarget:Dropdown({ Name = "Priority"; Options = { "Closest", "Lowest health", "Crosshair", "Threat" }; Value = "Closest"; Flag = "AimbotPriority"; Callback = function() end })
AimTarget:Slider({ Name = "Max distance"; Suffix = " studs"; Value = 400; Min = 50; Max = 2000; Increment = 25; Flag = "AimbotDistance"; Callback = function() end })
AimTarget:Dropdown({ Name = "Team check"; Options = { "Off", "Friendly", "Enemy only" }; Value = "Enemy only"; Flag = "AimbotTeam"; Callback = function() end })

local PlayerNames = {}
for _, Plr in game:GetService("Players"):GetPlayers() do
	table.insert(PlayerNames, Plr.Name)
end
AimTarget:Dropdown({
	Name = "Priority player";
	Options = PlayerNames;
	Value = PlayerNames[1] or "";
	Search = true;
	Flag = "PriorityPlayer";
	Callback = function() end;
})

AimMisc:Paragraph({ Title = "Discord"; Body = "discord.gg/noctro" })
local EspModes = AimMisc:Label({ Text = "ESP modes" })
EspModes:Toggle({ State = true; Flag = "ESPEnabled"; Callback = function() end })
AimMisc:Dropdown({
	Name = "ESP";
	Multi = true;
	Options = { "Box", "Name", "Health", "Distance", "Tracer" };
	Value = { "Box", "Name" };
	Flag = "ESPModes";
	Callback = function() end;
})
AimMisc:Slider({ Name = "ESP range"; Suffix = " studs"; Value = 500; Min = 50; Max = 3000; Increment = 50; Flag = "ESPRange"; Callback = function() end })

local Silent = AimExtra:Label({ Text = "Silent aim" })
Silent:Toggle({ State = false; Flag = "SilentAim"; Callback = function() end })
Silent:Keybind({ Key = Enum.KeyCode.E; Type = "Toggle"; Flag = "SilentKey"; Callback = function() end })
AimExtra:Slider({ Name = "Hit chance"; Suffix = "%"; Value = 100; Min = 1; Max = 100; Increment = 1; Flag = "HitChance"; Callback = function() end })
AimExtra:Dropdown({ Name = "Prediction"; Options = { "None", "Linear", "Velocity" }; Value = "Linear"; Flag = "Prediction"; Callback = function() end })

local AAMain = AntiAim:Section({ Name = "Angles"; Side = "Left"; Icon = "move" })
local AAExtra = AntiAim:Section({ Name = "Desync"; Side = "Right"; Icon = "activity" })
local AAEnable = AAMain:Label({ Text = "Enable anti-aim" })
AAEnable:Toggle({ State = false; Flag = "AAEnabled"; Callback = function() end })
AAEnable:Keybind({ Key = Enum.KeyCode.X; Type = "Toggle"; Flag = "AAKey"; Callback = function() end })
AAMain:Dropdown({ Name = "Yaw mode"; Options = { "Static", "Jitter", "Spin", "Random" }; Value = "Jitter"; Flag = "AAYaw"; Callback = function() end })

local TBMain = Trigger:Section({ Name = "Main"; Side = "Left"; Icon = "mouse-pointer" })
local TBEnable = TBMain:Label({ Text = "Enable triggerbot" })
TBEnable:Toggle({ State = false; Flag = "TriggerEnabled"; Callback = function() end })
TBEnable:Keybind({ Key = Enum.UserInputType.MouseButton2; Type = "Hold"; Flag = "TriggerKey"; Callback = function() end })

local Rage = Window:Page({ Icon = "flame" })
local RageAim = Rage:SubPage({ Name = "Aimbot" })
local RB = RageAim:Section({ Name = "Ragebot"; Side = "Left"; Icon = "crosshair" })
local REnable = RB:Label({ Text = "Enable ragebot" })
REnable:Toggle({ State = false; Flag = "RageEnabled"; Callback = function() end })
REnable:Keybind({ Key = Enum.KeyCode.R; Type = "Toggle"; Flag = "RageKey"; Callback = function() end })

local Legit = Window:Page({ Icon = "crosshair" })
local LegitAim = Legit:SubPage({ Name = "Aim Assist" })
local LA = LegitAim:Section({ Name = "Assist"; Side = "Left"; Icon = "target" })
local LAE = LA:Label({ Text = "Enable assist" })
LAE:Toggle({ State = false; Flag = "LegitAssist"; Callback = function() end })
LAE:Keybind({ Key = Enum.UserInputType.MouseButton2; Type = "Hold"; Flag = "LegitKey"; Callback = function() end })

local Visuals = Window:Page({ Icon = "eye" })
local ESP = Visuals:SubPage({ Name = "ESP" })
local ESPP = ESP:Section({ Name = "Players"; Side = "Left"; Icon = "users" })
local Box = ESPP:Label({ Text = "Box ESP" })
Box:Toggle({ State = true; Flag = "BoxESP"; Callback = function() end })

local Player = Window:Page({ Icon = "user" })
local Movement = Player:SubPage({ Name = "Movement" })
local Flight = Movement:Section({ Name = "Flight"; Side = "Right"; Icon = "move" })
local Fly = Flight:Label({ Text = "Fly" })
Fly:Toggle({ State = false; Flag = "Fly"; Callback = function() end })
Fly:Keybind({ Key = Enum.KeyCode.F; Type = "Toggle"; Flag = "FlyKey"; Callback = function() end })

local Misc = Window:Page({ Icon = "wrench" })
local Scripts = Window:Page({ Icon = "terminal" })
local Settings = Window:Page({ Icon = "settings" })
local Meta = Settings:Section({ Name = "About"; Side = "Right"; Icon = "info" })
Meta:Paragraph({ Title = "Build"; Body = "Lumen UI" })

Lumen:BuildConfigPage(Window)
Lumen.Notify({ Title = "Lumen"; Text = "Loaded successfully"; Type = "Success"; Duration = 3 })
