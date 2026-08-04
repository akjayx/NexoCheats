--========================================================
-- NEXO + LINORIA V2 COMBINED SCRIPT (ONE FILE)
--========================================================

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

print("Nexo + Linoria V2 Script Loaded")

--========================================================
-- CONFIG (SHARED TABLE)
--========================================================

_G.NexoConfigs = _G.NexoConfigs or {}
local ConfigStore = _G.NexoConfigs

local Config = {
    Aimbot = {
        Enabled = false,
        Silent = false,
        Smoothness = 0.3,
        FOV = 200,
        TeamCheck = true,
        VisibilityCheck = true,
        AimPart = "Head",
        HitChance = 100,
        Keybind = "LeftAlt",
        ShowFOV = true,
    },
    Triggerbot = {
        Enabled = false,
        AimPart = "Head",
        ReactionTime = 0.05,
        Keybind = "LeftControl",
    },
    Ragebot = { Enabled = false },
    Orbit = { Enabled = false, Speed = 2, Radius = 20, Height = 5 },
    Voidspam = { Enabled = false, Speed = 0.5 },
    ESP = {
        Enabled = false,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        TeamColor = true,
        EnemyColor = Color3.fromRGB(255,50,50),
        FriendColor = Color3.fromRGB(50,255,50),
        MaxDistance = 500,
    },
    Movement = { Speed = 16, Flight = false, FlySpeed = 50 },
    Settings = { ConfigName = "Default", AutoLoad = true },
}

--========================================================
-- DRAWING / FOV
--========================================================

local function SafeDraw(type)
    local ok, obj = pcall(Drawing.new, type)
    if ok and obj then return obj end
    return nil
end

local FOVCircle = SafeDraw("Circle")
if FOVCircle then
    FOVCircle.Visible = Config.Aimbot.ShowFOV
    FOVCircle.Color = Color3.fromRGB(255,255,255)
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 32
    FOVCircle.Transparency = 0.5
    FOVCircle.Radius = Config.Aimbot.FOV
end

local EspObjects = {}

local function IsOnScreen(pos)
    local vp = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X * Camera.ViewportSize.X, vp.Y * Camera.ViewportSize.Y),
        (vp.Z > 0 and vp.X >= 0 and vp.X <= 1 and vp.Y >= 0 and vp.Y <= 1)
end

local function GetPlayerColor(player)
    if Config.ESP.TeamColor and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return Config.ESP.FriendColor
    end
    return Config.ESP.EnemyColor
end

local function TriggerClick()
    pcall(function()
        Mouse:Button1Down()
        task.wait(0.01)
        Mouse:Button1Up()
    end)
end

--========================================================
-- CONFIG SAVE / LOAD
--========================================================

local function SaveConfig(name)
    name = name or Config.Settings.ConfigName
    if not ConfigStore then ConfigStore = {} _G.NexoConfigs = ConfigStore end
    ConfigStore[name] = {
        Aimbot = Config.Aimbot,
        Triggerbot = Config.Triggerbot,
        Ragebot = Config.Ragebot,
        Orbit = Config.Orbit,
        Voidspam = Config.Voidspam,
        ESP = Config.ESP,
        Movement = Config.Movement,
        Settings = Config.Settings,
    }
end

local function LoadConfig(name)
    name = name or Config.Settings.ConfigName
    local data = ConfigStore and ConfigStore[name]
    if data then
        for k, v in pairs(data) do
            if Config[k] then
                for kk, vv in pairs(v) do
                    Config[k][kk] = vv
                end
            end
        end
        if FOVCircle then
            FOVCircle.Radius = Config.Aimbot.FOV
            FOVCircle.Visible = Config.Aimbot.ShowFOV
        end
    end
end

local function GetConfigNames()
    local names = {"Default"}
    if ConfigStore then
        for name in pairs(ConfigStore) do
            table.insert(names, name)
        end
    end
    return names
end

--========================================================
-- ESP
--========================================================

local function CreateEspObject(player)
    if EspObjects[player] then
        for _, o in pairs(EspObjects[player]) do pcall(o.Remove, o) end
        EspObjects[player] = nil
    end
    local objs = {}
    if Config.ESP.Boxes then
        local b = SafeDraw("Square")
        if b then b.Visible = false; b.Thickness = 1; b.Transparency = 0.5; table.insert(objs, b) end
    end
    if Config.ESP.Names then
        local n = SafeDraw("Text")
        if n then n.Visible = false; n.Size = 14; n.Center = true; n.Outline = true; n.OutlineColor = Color3.new(0,0,0); table.insert(objs, n) end
    end
    if Config.ESP.Distance then
        local d = SafeDraw("Text")
        if d then d.Visible = false; d.Size = 12; d.Center = true; d.Outline = true; d.OutlineColor = Color3.new(0,0,0); table.insert(objs, d) end
    end
    if Config.ESP.Health then
        local hbg = SafeDraw("Square")
        if hbg then hbg.Visible = false; hbg.Color = Color3.new(0,0,0); hbg.Thickness = 1; hbg.Filled = true; hbg.Transparency = 0.5; table.insert(objs, hbg) end
        local hbar = SafeDraw("Square")
        if hbar then hbar.Visible = false; hbar.Color = Color3.new(0,1,0); hbar.Thickness = 1; hbar.Filled = true; hbar.Transparency = 0.3; table.insert(objs, hbar) end
    end
    EspObjects[player] = objs
end

local function UpdateESP()
    if not Config.ESP.Enabled then
        for _, objs in pairs(EspObjects) do
            for _, o in pairs(objs) do if o then o.Visible = false end end
        end
        return
    end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local c = player.Character
        if not c then continue end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if not EspObjects[player] then CreateEspObject(player) end
        local objs = EspObjects[player]
        if not objs then continue end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local hp = c:FindFirstChild("Head")
        if not rp or not hp then
            for _, o in pairs(objs) do if o then o.Visible = false end end
            continue
        end
        local dist = (rp.Position - root.Position).Magnitude
        if dist > Config.ESP.MaxDistance * 10 then
            for _, o in pairs(objs) do if o then o.Visible = false end end
            continue
        end
        local _, on = IsOnScreen(rp.Position)
        if not on then
            for _, o in pairs(objs) do if o then o.Visible = false end end
            continue
        end
        local color = GetPlayerColor(player)
        local hPos, hOn = IsOnScreen(hp.Position)
        local rPos, rOn = IsOnScreen(rp.Position)
        if not hOn or not rOn then continue end
        local height = math.abs(hPos.Y - rPos.Y) * 2.2
        local width = height * 0.55
        local top = Vector2.new(rPos.X - width/2, hPos.Y - height*0.15)
        local idx = 1
        if Config.ESP.Boxes and objs[idx] then
            local box = objs[idx]
            pcall(function()
                box.Visible = true
                box.Position = top
                box.Size = Vector2.new(width, height)
                box.Color = color
            end)
            idx = idx + 1
        end
        if Config.ESP.Names and objs[idx] then
            local n = objs[idx]
            pcall(function()
                n.Visible = true
                n.Position = Vector2.new(rPos.X, hPos.Y - height*0.25 - 16)
                n.Text = player.Name
                n.Color = color
            end)
            idx = idx + 1
        end
        if Config.ESP.Distance and objs[idx] then
            local d = objs[idx]
            pcall(function()
                d.Visible = true
                d.Position = Vector2.new(rPos.X, rPos.Y + height*0.55)
                d.Text = math.round(dist/10) .. "m"
                d.Color = color
            end)
            idx = idx + 1
        end
        if Config.ESP.Health and objs[idx] and objs[idx+1] then
            local hbg = objs[idx]
            local hbar = objs[idx+1]
            local bw = width * 0.7
            local bh = 4
            local bp = Vector2.new(rPos.X - bw/2, rPos.Y + height*0.48)
            local hpct = hum.Health / hum.MaxHealth
            pcall(function()
                hbg.Visible = true
                hbg.Position = bp
                hbg.Size = Vector2.new(bw, bh)
                hbar.Visible = true
                hbar.Position = bp
                hbar.Size = Vector2.new(bw * hpct, bh)
                hbar.Color = Color3.new(1-hpct, hpct, 0)
            end)
        end
    end
end

--========================================================
-- AIMBOT / TARGETING
--========================================================

local function GetTargets()
    local targets = {}
    local char = LocalPlayer.Character
    if not char then return targets end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return targets end
    local mousePos = UserInputService:GetMouseLocation()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local c = player.Character
        if not c then continue end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end
        local part = c:FindFirstChild(Config.Aimbot.AimPart)
        if not part then continue end
        local dist = (part.Position - root.Position).Magnitude
        if dist > 5000 then continue end
        if Config.Aimbot.VisibilityCheck then
            local rayOrigin = Camera.CFrame.Position
            local rayDir = (part.Position - rayOrigin).Unit * 10000
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            local rayResult = workspace:Raycast(rayOrigin, rayDir, raycastParams)
            if rayResult and rayResult.Instance then
                if not rayResult.Instance:IsDescendantOf(c) then continue end
            end
        end
        local v, on = IsOnScreen(part.Position)
        if not on then continue end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist > Config.Aimbot.FOV then continue end
        if math.random(1,100) > Config.Aimbot.HitChance then continue end
        table.insert(targets, { AimPart = part, ScreenDist = screenDist })
    end
    table.sort(targets, function(a,b) return a.ScreenDist < b.ScreenDist end)
    return targets
end

local function AimAt(target)
    if not target then return end
    local pos = target.AimPart.Position
    local current = Camera.CFrame.Position
    local dir = (pos - current).Unit
    local targetCF = CFrame.new(current, current + dir)
    if Config.Aimbot.Silent then
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, 1 - Config.Aimbot.Smoothness)
    else
        Camera.CFrame = targetCF
    end
end

--========================================================
-- TRIGGERBOT / RAGEBOT
--========================================================

local triggerDelay = 0
local function Triggerbot()
    if not Config.Triggerbot.Enabled then return end
    local mousePos = UserInputService:GetMouseLocation()
    local char = LocalPlayer.Character
    if not char then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local c = player.Character
        if not c then continue end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end
        local part = c:FindFirstChild(Config.Triggerbot.AimPart)
        if not part then continue end
        local v, on = IsOnScreen(part.Position)
        if not on then continue end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist < 30 then
            if tick() - triggerDelay >= Config.Triggerbot.ReactionTime then
                TriggerClick()
                triggerDelay = tick()
            end
        end
    end
end

local function Ragebot()
    if not Config.Ragebot.Enabled then return end
    local targets = GetTargets()
    if #targets > 0 then
        local t = targets[1]
        local pos = t.AimPart.Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
    end
end

--========================================================
-- ORBIT / VOIDSPAM / MOVEMENT / FLIGHT
--========================================================

local orbitAngle = 0
local orbitTask = nil
local function StartOrbit()
    if orbitTask then orbitTask:Disconnect() end
    orbitTask = RunService.RenderStepped:Connect(function(dt)
        if not Config.Orbit.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local nearest, nearDist = nil, math.huge
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local c = player.Character
            if not c then continue end
            local r = c:FindFirstChild("HumanoidRootPart")
            if not r then continue end
            local d = (r.Position - root.Position).Magnitude
            if d < nearDist then nearDist = d; nearest = r end
        end
        if not nearest then return end
        orbitAngle = orbitAngle + dt * Config.Orbit.Speed
        local radius = Config.Orbit.Radius
        local height = Config.Orbit.Height
        local center = nearest.Position
        local newPos = center + Vector3.new(math.cos(orbitAngle)*radius, height, math.sin(orbitAngle)*radius)
        root.CFrame = CFrame.new(newPos)
    end)
end

local voidTask = nil
local function StartVoidspam()
    if voidTask then voidTask:Disconnect() end
    voidTask = RunService.RenderStepped:Connect(function()
        if not Config.Voidspam.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = CFrame.new(root.Position.X, -1000, root.Position.Z)
    end)
end

local speedTask = nil
local function StartSpeed()
    if speedTask then speedTask:Disconnect() end
    speedTask = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        hum.WalkSpeed = Config.Movement.Speed
    end)
end

local flyTask = nil
local function StartFlight()
    if flyTask then flyTask:Disconnect() end
    flyTask = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not root or not hum then return end
        if not Config.Movement.Flight then
            hum.PlatformStand = false
            return
        end
        hum.PlatformStand = true
        local move = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector * Vector3.new(1,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector * Vector3.new(1,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
        if move.Magnitude > 0 then
            move = move.Unit * Config.Movement.FlySpeed
            root.Velocity = move
        else
            root.Velocity = Vector3.new(0,0,0)
        end
    end)
end

--========================================================
-- MAIN LOOP (AIMBOT / ESP / TRIGGER / RAGE)
--========================================================

RunService.RenderStepped:Connect(function()
    UpdateESP()
    Triggerbot()
    Ragebot()

    if Config.Aimbot.Enabled then
        local targets = GetTargets()
        if #targets > 0 then
            AimAt(targets[1])
        end
    end

    if FOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Visible = Config.Aimbot.ShowFOV
    end
end)

StartSpeed()
StartFlight()
StartOrbit()
StartVoidspam()

--========================================================
-- LINORIA V2 UI (TABBOXES)
--========================================================

-- NOTE: You must replace this with your actual Linoria V2 loader.
-- Example (you fill in the URL or loader you use):
-- local Library = loadstring(game:HttpGet("YOUR_LINORIA_V2_URL_HERE"))()
-- local ThemeManager = loadstring(game:HttpGet("YOUR_THEME_MANAGER_URL_HERE"))()
-- local SaveManager = loadstring(game:HttpGet("YOUR_SAVE_MANAGER_URL_HERE"))()

local Library = require(...) -- put your Linoria V2 library here
local Window = Library:CreateWindow({
    Title = "RIVALS ULTIMATE",
    Center = true,
    AutoShow = true,
})

-- Combat Tab
local CombatTab = Window:AddTab("Combat")
local CombatTabbox = CombatTab:AddTabbox("Combat Modes")
local SilentTab = CombatTabbox:AddTab("Silent Aim")
local TriggerTab = CombatTabbox:AddTab("Triggerbot")
local RageTabbox = CombatTab:AddTabbox("Rage")
local RageTab = RageTabbox:AddTab("Ragebot")

-- Visuals Tab
local VisualsTab = Window:AddTab("Visuals")
local VisualsTabbox = VisualsTab:AddTabbox("Visuals")
local ESPTab = VisualsTabbox:AddTab("ESP")
local FOVTab = VisualsTabbox:AddTab("FOV")

-- Movement Tab
local MovementTab = Window:AddTab("Movement")
local MovementTabbox = MovementTab:AddTabbox("Movement")
local MoveTab = MovementTabbox:AddTab("Movement")
local OrbitTab = MovementTabbox:AddTab("Orbit")
local VoidTab = MovementTabbox:AddTab("Voidspam")

-- Config Tab
local ConfigTab = Window:AddTab("Config")
local ConfigTabbox = ConfigTab:AddTabbox("Config")
local ConfigMainTab = ConfigTabbox:AddTab("Main")

-- Silent Aim UI
SilentTab:AddToggle("SilentAimEnabled", {
    Text = "Enable Silent Aim",
    Default = Config.Aimbot.Enabled,
    Callback = function(v) Config.Aimbot.Enabled = v end
})

SilentTab:AddToggle("SilentAimSilent", {
    Text = "Silent Mode",
    Default = Config.Aimbot.Silent,
    Callback = function(v) Config.Aimbot.Silent = v end
})

SilentTab:AddToggle("SilentAimTeamCheck", {
    Text = "Team Check",
    Default = Config.Aimbot.TeamCheck,
    Callback = function(v) Config.Aimbot.TeamCheck = v end
})

SilentTab:AddToggle("SilentAimVisibility", {
    Text = "Visibility Check",
    Default = Config.Aimbot.VisibilityCheck,
    Callback = function(v) Config.Aimbot.VisibilityCheck = v end
})

SilentTab:AddDropdown("SilentAimPart", {
    Text = "Aim Part",
    Default = Config.Aimbot.AimPart,
    Values = {"Head", "HumanoidRootPart"},
    Callback = function(v) Config.Aimbot.AimPart = v end
})

SilentTab:AddSlider("SilentAimFOV", {
    Text = "FOV",
    Default = Config.Aimbot.FOV,
    Min = 10,
    Max = 600,
    Rounding = 0,
    Callback = function(v)
        Config.Aimbot.FOV = v
        if FOVCircle then FOVCircle.Radius = v end
    end
})

SilentTab:AddSlider("SilentAimSmooth", {
    Text = "Smoothness",
    Default = Config.Aimbot.Smoothness,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(v) Config.Aimbot.Smoothness = v end
})

SilentTab:AddSlider("SilentAimHitChance", {
    Text = "Hit Chance",
    Default = Config.Aimbot.HitChance,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v) Config.Aimbot.HitChance = v end
})

SilentTab:AddToggle("SilentAimShowFOV", {
    Text = "Show FOV Circle",
    Default = Config.Aimbot.ShowFOV,
    Callback = function(v)
        Config.Aimbot.ShowFOV = v
        if FOVCircle then FOVCircle.Visible = v end
    end
})

SilentTab:AddKeyPicker("SilentAimKey", {
    Text = "Silent Aim Keybind",
    Default = Config.Aimbot.Keybind,
    SyncToggleState = false,
    Mode = "Hold",
    Callback = function(key) Config.Aimbot.Keybind = key end
})

-- Triggerbot UI
TriggerTab:AddToggle("TriggerbotEnabled", {
    Text = "Enable Triggerbot",
    Default = Config.Triggerbot.Enabled,
    Callback = function(v) Config.Triggerbot.Enabled = v end
})

TriggerTab:AddDropdown("TriggerbotPart", {
    Text = "Trigger Part",
    Default = Config.Triggerbot.AimPart,
    Values = {"Head", "HumanoidRootPart"},
    Callback = function(v) Config.Triggerbot.AimPart = v end
})

TriggerTab:AddSlider("TriggerbotReaction", {
    Text = "Reaction Time",
    Default = Config.Triggerbot.ReactionTime,
    Min = 0,
    Max = 0.5,
    Rounding = 3,
    Callback = function(v) Config.Triggerbot.ReactionTime = v end
})

TriggerTab:AddKeyPicker("TriggerbotKey", {
    Text = "Triggerbot Keybind",
    Default = Config.Triggerbot.Keybind,
    SyncToggleState = false,
    Mode = "Hold",
    Callback = function(key) Config.Triggerbot.Keybind = key end
})

-- Ragebot UI
RageTab:AddToggle("RagebotEnabled", {
    Text = "Enable Ragebot",
    Default = Config.Ragebot.Enabled,
    Callback = function(v) Config.Ragebot.Enabled = v end
})

-- ESP UI
ESPTab:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = Config.ESP.Enabled,
    Callback = function(v) Config.ESP.Enabled = v end
})

ESPTab:AddToggle("ESPBoxes", {
    Text = "Boxes",
    Default = Config.ESP.Boxes,
    Callback = function(v) Config.ESP.Boxes = v end
})

ESPTab:AddToggle("ESPNames", {
    Text = "Names",
    Default = Config.ESP.Names,
    Callback = function(v) Config.ESP.Names = v end
})

ESPTab:AddToggle("ESPHealth", {
    Text = "Health Bar",
    Default = Config.ESP.Health,
    Callback = function(v) Config.ESP.Health = v end
})

ESPTab:AddToggle("ESPDistance", {
    Text = "Distance",
    Default = Config.ESP.Distance,
    Callback = function(v) Config.ESP.Distance = v end
})

ESPTab:AddToggle("ESPTeamColor", {
    Text = "Use Team Colors",
    Default = Config.ESP.TeamColor,
    Callback = function(v) Config.ESP.TeamColor = v end
})

ESPTab:AddSlider("ESPMaxDistance", {
    Text = "Max Distance",
    Default = Config.ESP.MaxDistance,
    Min = 50,
    Max = 2000,
    Rounding = 0,
    Callback = function(v) Config.ESP.MaxDistance = v end
})

ESPTab:AddColorPicker("ESPEnemyColor", {
    Text = "Enemy Color",
    Default = Config.ESP.EnemyColor,
    Callback = function(c) Config.ESP.EnemyColor = c end
})

ESPTab:AddColorPicker("ESPFriendColor", {
    Text = "Friend Color",
    Default = Config.ESP.FriendColor,
    Callback = function(c) Config.ESP.FriendColor = c end
})

-- FOV UI
FOVTab:AddToggle("ShowFOVCircle", {
    Text = "Show FOV Circle",
    Default = Config.Aimbot.ShowFOV,
    Callback = function(v)
        Config.Aimbot.ShowFOV = v
        if FOVCircle then FOVCircle.Visible = v end
    end
})

FOVTab:AddSlider("FOVRadius", {
    Text = "FOV Radius",
    Default = Config.Aimbot.FOV,
    Min = 10,
    Max = 600,
    Rounding = 0,
    Callback = function(v)
        Config.Aimbot.FOV = v
        if FOVCircle then FOVCircle.Radius = v end
    end
})

-- Movement UI
MoveTab:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = Config.Movement.Speed,
    Min = 16,
    Max = 100,
    Rounding = 0,
    Callback = function(v) Config.Movement.Speed = v end
})

MoveTab:AddToggle("FlightEnabled", {
    Text = "Enable Flight",
    Default = Config.Movement.Flight,
    Callback = function(v) Config.Movement.Flight = v end
})

MoveTab:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = Config.Movement.FlySpeed,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v) Config.Movement.FlySpeed = v end
})

-- Orbit UI
OrbitTab:AddToggle("OrbitEnabled", {
    Text = "Enable Orbit",
    Default = Config.Orbit.Enabled,
    Callback = function(v)
        Config.Orbit.Enabled = v
        if v then StartOrbit() end
    end
})

OrbitTab:AddSlider("OrbitSpeed", {
    Text = "Orbit Speed",
    Default = Config.Orbit.Speed,
    Min = 0.5,
    Max = 10,
    Rounding = 2,
    Callback = function(v) Config.Orbit.Speed = v end
})

OrbitTab:AddSlider("OrbitRadius", {
    Text = "Orbit Radius",
    Default = Config.Orbit.Radius,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Callback = function(v) Config.Orbit.Radius = v end
})

OrbitTab:AddSlider("OrbitHeight", {
    Text = "Orbit Height",
    Default = Config.Orbit.Height,
    Min = -10,
    Max = 20,
    Rounding = 0,
    Callback = function(v) Config.Orbit.Height = v end
})

-- Voidspam UI
VoidTab:AddToggle("VoidspamEnabled", {
    Text = "Enable Voidspam",
    Default = Config.Voidspam.Enabled,
    Callback = function(v)
        Config.Voidspam.Enabled = v
        if v then StartVoidspam() end
    end
})

VoidTab:AddSlider("VoidspamSpeed", {
    Text = "Voidspam Speed",
    Default = Config.Voidspam.Speed,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
    Callback = function(v) Config.Voidspam.Speed = v end
})

-- Config UI
ConfigMainTab:AddInput("ConfigNameInput", {
    Text = "Config Name",
    Default = Config.Settings.ConfigName,
    Callback = function(v) Config.Settings.ConfigName = v end
})

ConfigMainTab:AddToggle("AutoLoadConfig", {
    Text = "Auto Load on Inject",
    Default = Config.Settings.AutoLoad,
    Callback = function(v) Config.Settings.AutoLoad = v end
})

ConfigMainTab:AddButton("SaveConfigButton", {
    Text = "Save Config",
    Func = function() SaveConfig(Config.Settings.ConfigName) end
})

ConfigMainTab:AddButton("LoadConfigButton", {
    Text = "Load Config",
    Func = function() LoadConfig(Config.Settings.ConfigName) end
})

ConfigMainTab:AddDropdown("ConfigList", {
    Text = "Configs",
    Values = GetConfigNames(),
    Default = Config.Settings.ConfigName,
    Callback = function(v) Config.Settings.ConfigName = v end
})

-- If AutoLoad is enabled, load config on start
if Config.Settings.AutoLoad then
    LoadConfig(Config.Settings.ConfigName)
end
