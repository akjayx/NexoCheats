--========================================================
-- NEXO + LINORIA V2 (FULL SINGLE FILE, RIGHT SHIFT UI)
--========================================================

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

print("RIVALS ULTIMATE Loaded")

--========================================================
-- CONFIG TABLE
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
    local data = ConfigStore[name]
    if data then
        for k, v in pairs(data) do
            for kk, vv in pairs(v) do
                Config[k][kk] = vv
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
    for name in pairs(ConfigStore) do
        table.insert(names, name)
    end
    return names
end

--========================================================
-- ESP
--========================================================

local function CreateEspObject(player)
    if EspObjects[player] then
        for _, o in pairs(EspObjects[player]) do pcall(o.Remove, o) end
    end

    local objs = {}

    local box = SafeDraw("Square")
    if box then box.Visible = false; box.Thickness = 1; box.Transparency = 0.5; objs.Box = box end

    local name = SafeDraw("Text")
    if name then name.Visible = false; name.Size = 14; name.Center = true; name.Outline = true; objs.Name = name end

    local dist = SafeDraw("Text")
    if dist then dist.Visible = false; dist.Size = 12; dist.Center = true; dist.Outline = true; objs.Distance = dist end

    local hbg = SafeDraw("Square")
    local hbar = SafeDraw("Square")
    if hbg and hbar then
        hbg.Visible = false; hbg.Filled = true; hbg.Color = Color3.new(0,0,0)
        hbar.Visible = false; hbar.Filled = true
        objs.HBG = hbg
        objs.HBAR = hbar
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

        local rp = c:FindFirstChild("HumanoidRootPart")
        local hp = c:FindFirstChild("Head")
        if not rp or not hp then continue end

        local dist = (rp.Position - root.Position).Magnitude
        if dist > Config.ESP.MaxDistance * 10 then
            for _, o in pairs(objs) do if o then o.Visible = false end end
            continue
        end

        local hPos, hOn = IsOnScreen(hp.Position)
        local rPos, rOn = IsOnScreen(rp.Position)
        if not hOn or not rOn then
            for _, o in pairs(objs) do if o then o.Visible = false end end
            continue
        end

        local color = GetPlayerColor(player)
        local height = math.abs(hPos.Y - rPos.Y) * 2.2
        local width = height * 0.55
        local top = Vector2.new(rPos.X - width/2, hPos.Y - height*0.15)

        if Config.ESP.Boxes and objs.Box then
            objs.Box.Visible = true
            objs.Box.Position = top
            objs.Box.Size = Vector2.new(width, height)
            objs.Box.Color = color
        end

        if Config.ESP.Names and objs.Name then
            objs.Name.Visible = true
            objs.Name.Position = Vector2.new(rPos.X, hPos.Y - height*0.25 - 16)
            objs.Name.Text = player.Name
            objs.Name.Color = color
        end

        if Config.ESP.Distance and objs.Distance then
            objs.Distance.Visible = true
            objs.Distance.Position = Vector2.new(rPos.X, rPos.Y + height*0.55)
            objs.Distance.Text = math.round(dist/10) .. "m"
            objs.Distance.Color = color
        end

        if Config.ESP.Health and objs.HBG and objs.HBAR then
            local bw = width * 0.7
            local bh = 4
            local bp = Vector2.new(rPos.X - bw/2, rPos.Y + height*0.48)
            local hpct = hum.Health / hum.MaxHealth

            objs.HBG.Visible = true
            objs.HBG.Position = bp
            objs.HBG.Size = Vector2.new(bw, bh)

            objs.HBAR.Visible = true
            objs.HBAR.Position = bp
            objs.HBAR.Size = Vector2.new(bw * hpct, bh)
            objs.HBAR.Color = Color3.new(1-hpct, hpct, 0)
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

        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end

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
            if rayResult and rayResult.Instance and not rayResult.Instance:IsDescendantOf(c) then
                continue
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

        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end

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
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.AimPart.Position)
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
-- MAIN LOOP
--========================================================

RunService.RenderStepped:Connect(function()
    UpdateESP()
    Triggerbot()
    Ragebot()

    if Config.Aimbot.Enabled then
        local targets = GetTargets()
        if #targets > 0 then AimAt(targets[1]) end
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
