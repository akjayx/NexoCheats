--[[
    NEXO – All-in-One Combat Script
    Discord: https://discord.gg/XV6HcW5Nn
    Open UI: RightShift
]]

task.wait()

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- ============================================================
-- SETTINGS (persistent)
-- ============================================================
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
        Skeleton = false,
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

-- ============================================================
-- DRAWING OBJECTS
-- ============================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(247,54,219)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 32
FOVCircle.Transparency = 0.5

local EspObjects = {}
local esp_counter = 0

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function IsOnScreen(pos)
    local v, on = Camera:WorldToScreenPoint(pos)
    return v, on
end

local function GetPlayerColor(player)
    if Config.ESP.TeamColor and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return Config.ESP.FriendColor
    end
    return Config.ESP.EnemyColor
end

local function GetConfigNames()
    local names = {"Default"}
    if getgenv().NexoConfigs then
        for name in pairs(getgenv().NexoConfigs) do
            table.insert(names, name)
        end
    end
    return names
end

-- ============================================================
-- SAVE / LOAD CONFIG
-- ============================================================
local function SaveConfig(name)
    name = name or Config.Settings.ConfigName
    getgenv().NexoConfigs = getgenv().NexoConfigs or {}
    getgenv().NexoConfigs[name] = {
        Aimbot = Config.Aimbot,
        Triggerbot = Config.Triggerbot,
        Ragebot = Config.Ragebot,
        Orbit = Config.Orbit,
        Voidspam = Config.Voidspam,
        ESP = Config.ESP,
        Movement = Config.Movement,
    }
    print("[Nexo] Config saved: " .. name)
end

local function LoadConfig(name)
    name = name or Config.Settings.ConfigName
    local data = getgenv().NexoConfigs and getgenv().NexoConfigs[name]
    if data then
        for k, v in pairs(data) do
            if Config[k] then
                for kk, vv in pairs(v) do
                    Config[k][kk] = vv
                end
            end
        end
        FOVCircle.Radius = Config.Aimbot.FOV
        print("[Nexo] Config loaded: " .. name)
    else
        print("[Nexo] Config not found: " .. name)
    end
end

-- ============================================================
-- FEATURES
-- ============================================================
-- ESP
local function CreateEspObject(player)
    if EspObjects[player] then
        for _, o in pairs(EspObjects[player]) do
            pcall(o.Remove, o)
        end
        EspObjects[player] = nil
    end
    local objs = {}
    if Config.ESP.Boxes then
        local b = Drawing.new("Square")
        b.Visible = false
        b.Thickness = 1
        b.Transparency = 0.5
        table.insert(objs, b)
    end
    if Config.ESP.Names then
        local n = Drawing.new("Text")
        n.Visible = false
        n.Size = 14
        n.Center = true
        n.Outline = true
        n.OutlineColor = Color3.new(0,0,0)
        table.insert(objs, n)
    end
    if Config.ESP.Distance then
        local d = Drawing.new("Text")
        d.Visible = false
        d.Size = 12
        d.Center = true
        d.Outline = true
        d.OutlineColor = Color3.new(0,0,0)
        table.insert(objs, d)
    end
    if Config.ESP.Health then
        local hbg = Drawing.new("Square")
        hbg.Visible = false
        hbg.Color = Color3.new(0,0,0)
        hbg.Thickness = 1
        hbg.Filled = true
        hbg.Transparency = 0.5
        table.insert(objs, hbg)
        local hbar = Drawing.new("Square")
        hbar.Visible = false
        hbar.Color = Color3.new(0,1,0)
        hbar.Thickness = 1
        hbar.Filled = true
        hbar.Transparency = 0.3
        table.insert(objs, hbar)
    end
    EspObjects[player] = objs
end

local function UpdateESP()
    esp_counter = esp_counter + 1
    if esp_counter % 2 ~= 0 then return end
    if not Config.ESP.Enabled then
        for _, objs in pairs(EspObjects) do
            for _, o in pairs(objs) do
                if o then o.Visible = false end
            end
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
        if not rp or not hp then continue end
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

-- Aimbot
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
            local ray = Ray.new(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 10000)
            local hit = workspace:FindPartOnRay(ray, char)
            if hit and not hit:IsDescendantOf(c) then continue end
        end
        local v, on = IsOnScreen(part.Position)
        if not on then continue end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist > Config.Aimbot.FOV then continue end
        if math.random(1,100) > Config.Aimbot.HitChance then continue end
        table.insert(targets, {
            Player = player,
            Character = c,
            AimPart = part,
            Distance = dist,
            ScreenDist = screenDist,
        })
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

-- Triggerbot
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
                mouse1click()
                triggerDelay = tick()
            end
        end
    end
end

-- Ragebot
local function Ragebot()
    if not Config.Ragebot.Enabled then return end
    local targets = GetTargets()
    if #targets > 0 then
        local t = targets[1]
        local pos = t.AimPart.Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
    end
end

-- Orbit
local orbitAngle = 0
local orbitTask
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

-- Voidspam
local voidTask
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

-- Movement
local speedTask
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

local flyTask
local function StartFlight()
    if flyTask then flyTask:Disconnect() end
    flyTask = RunService.RenderStepped:Connect(function()
        if not Config.Movement.Flight then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
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

-- ============================================================
-- UI SYSTEM – No external libraries, fully self-contained
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = CoreGui

-- Helper functions for UI elements
local function MakeLabel(text, parent, size, pos, color, align)
    local lbl = Instance.new("TextLabel")
    lbl.Size = size or UDim2.new(1,0,0,20)
    lbl.Position = pos or UDim2.new(0,0,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = align or Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function MakeButton(text, parent, size, pos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(1,0,0,25)
    btn.Position = pos or UDim2.new(0,0,0,0)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.BorderColor3 = Color3.fromRGB(50,50,50)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 13
    btn.Font = Enum.Font.Code
    btn.Parent = parent
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function MakeToggle(parent, label, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,25)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = MakeLabel(label, frame, UDim2.new(0.7,0,1,0), UDim2.new(0,0,0,0))
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,50,0,20)
    btn.Position = UDim2.new(0.7,0,0.5,-10)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(247,54,219) or Color3.fromRGB(40,40,40)
    btn.BorderColor3 = Color3.fromRGB(50,50,50)
    btn.Text = getter() and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 12
    btn.Font = Enum.Font.Code
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(247,54,219) or Color3.fromRGB(40,40,40)
        btn.Text = getter() and "ON" or "OFF"
    end)
end

local function MakeSlider(parent, label, getter, setter, min, max)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,35)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = MakeLabel(label .. ": " .. tostring(getter()), frame, UDim2.new(1,0,0,15), UDim2.new(0,0,0,0))
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.8,0,0,18)
    input.Position = UDim2.new(0.1,0,0,17)
    input.BackgroundColor3 = Color3.fromRGB(30,30,30)
    input.BorderColor3 = Color3.fromRGB(50,50,50)
    input.Text = tostring(getter())
    input.TextColor3 = Color3.fromRGB(255,255,255)
    input.TextSize = 12
    input.Font = Enum.Font.Code
    input.ClearTextOnFocus = false
    input.Parent = frame
    input.FocusLost:Connect(function(enter)
        if enter then
            local v = tonumber(input.Text)
            if v then
                v = math.clamp(v, min or 0, max or 1)
                setter(v)
                lbl.Text = label .. ": " .. tostring(v)
            end
            input.Text = tostring(getter())
        end
    end)
end

local function MakeDropdown(parent, label, values, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = MakeLabel(label, frame, UDim2.new(0.5,0,1,0), UDim2.new(0,0,0,0))
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4,0,0,22)
    btn.Position = UDim2.new(0.5,0,0.5,-11)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.BorderColor3 = Color3.fromRGB(50,50,50)
    btn.Text = tostring(getter())
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 12
    btn.Font = Enum.Font.Code
    btn.Parent = frame

    local list = Instance.new("Frame")
    list.Size = UDim2.new(0.4,0,0, #values*20)
    list.Position = UDim2.new(0.5,0,1,0)
    list.BackgroundColor3 = Color3.fromRGB(25,25,25)
    list.BorderColor3 = Color3.fromRGB(50,50,50)
    list.Visible = false
    list.ZIndex = 2
    list.Parent = frame

    for _, v in pairs(values) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1,0,0,20)
        opt.BackgroundColor3 = Color3.fromRGB(35,35,35)
        opt.Text = v
        opt.TextColor3 = Color3.fromRGB(255,255,255)
        opt.TextSize = 12
        opt.Font = Enum.Font.Code
        opt.Parent = list
        opt.MouseButton1Click:Connect(function()
            setter(v)
            btn.Text = v
            list.Visible = false
        end)
    end

    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
    end)
end

local function MakeKeyPicker(parent, label, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,25)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = MakeLabel(label, frame, UDim2.new(0.6,0,1,0), UDim2.new(0,0,0,0))
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.3,0,0,20)
    btn.Position = UDim2.new(0.6,0,0.5,-10)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.BorderColor3 = Color3.fromRGB(50,50,50)
    btn.Text = getter()
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 12
    btn.Font = Enum.Font.Code
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(i)
            local key
            if i.UserInputType == Enum.UserInputType.Keyboard then
                key = i.KeyCode.Name
            elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
                key = "MB1"
            elseif i.UserInputType == Enum.UserInputType.MouseButton2 then
                key = "MB2"
            else
                return
            end
            setter(key)
            btn.Text = key
            conn:Disconnect()
        end)
    end)
end

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local MainWindow = Instance.new("Frame")
MainWindow.Size = UDim2.new(0, 650, 0, 550)
MainWindow.Position = UDim2.new(0.5, -325, 0.5, -275)
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.BackgroundColor3 = Color3.fromRGB(28,28,28)
MainWindow.BorderColor3 = Color3.fromRGB(247,54,219)
MainWindow.BorderSizePixel = 2
MainWindow.Visible = false
MainWindow.Parent = ScreenGui

-- Make draggable
local dragging, dragStart, dragPos
MainWindow.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = i.Position
        dragPos = MainWindow.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        MainWindow.Position = UDim2.new(dragPos.X.Scale, dragPos.X.Offset + delta.X, dragPos.Y.Scale, dragPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,30)
titleBar.BackgroundColor3 = Color3.fromRGB(247,54,219)
titleBar.BackgroundTransparency = 0.2
titleBar.Parent = MainWindow

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Nexo v1.0  |  discord.gg/XV6HcW5Nn"
titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
titleLbl.TextSize = 16
titleLbl.Font = Enum.Font.Code
titleLbl.TextXAlignment = Enum.TextXAlignment.Center
titleLbl.Parent = titleBar

-- Tab bar
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1,0,0,30)
tabContainer.Position = UDim2.new(0,0,0,30)
tabContainer.BackgroundColor3 = Color3.fromRGB(35,35,35)
tabContainer.Parent = MainWindow

-- We'll store tab data
local tabs = {}
local currentTabIndex = 1

-- Function to create a tab
local function AddTab(name)
    local idx = #tabs + 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 1, 0)
    btn.Position = UDim2.new((idx-1) * 0.12, 0, 0, 0) -- approximate positioning
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200,200,200)
    btn.TextSize = 14
    btn.Font = Enum.Font.Code
    btn.Parent = tabContainer

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 1, -20)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundTransparency = 1
    frame.Visible = (idx == 1) -- first tab visible
    frame.Parent = MainWindow

    -- Layout for groupboxes (left/right)
    local layout = Instance.new("UIListLayout")
    layout.Parent = frame
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)

    -- Function to show this tab
    local function showTab()
        for i, f in pairs(tabs) do
            f.frame.Visible = (i == idx)
            f.button.BackgroundTransparency = (i == idx) and 0.3 or 1
            f.button.TextColor3 = (i == idx) and Color3.fromRGB(247,54,219) or Color3.fromRGB(200,200,200)
        end
        currentTabIndex = idx
    end

    btn.MouseButton1Click:Connect(showTab)

    -- Store tab data
    table.insert(tabs, {
        button = btn,
        frame = frame,
        show = showTab,
    })

    return frame
end

-- Function to add a groupbox inside a tab frame (left or right)
local function AddGroupbox(parent, title, side)
    -- Create a container frame for left or right
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.48, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local box = Instance.new("Frame")
    box.Size = UDim2.new(1,0,0,200) -- will resize dynamically
    box.BackgroundColor3 = Color3.fromRGB(20,20,20)
    box.BorderColor3 = Color3.fromRGB(50,50,50)
    box.BorderMode = Enum.BorderMode.Inset
    box.Parent = container

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1,-2,1,-2)
    inner.Position = UDim2.new(0,1,0,1)
    inner.BackgroundColor3 = Color3.fromRGB(20,20,20)
    inner.Parent = box

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,20)
    lbl.Position = UDim2.new(0,4,0,2)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(247,54,219)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = inner

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,-8,1,-24)
    content.Position = UDim2.new(0,4,0,22)
    content.BackgroundTransparency = 1
    content.Parent = inner

    local layout = Instance.new("UIListLayout")
    layout.Parent = content
    layout.Padding = UDim.new(0,4)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function resize()
        local h = 22 + layout.AbsoluteContentSize.Y + 4
        box.Size = UDim2.new(1,0,0,h)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
    task.wait() -- force initial layout
    resize()

    return content
end

-- ============================================================
-- BUILD UI (Tabs & Groupboxes)
-- ============================================================
-- Tab: Aimbot
local tabAimbot = AddTab("Aimbot")
local gAimbot = AddGroupbox(tabAimbot, "Aimbot", 1)   -- left
local gTrigger = AddGroupbox(tabAimbot, "Triggerbot", 2) -- right
local gRage = AddGroupbox(tabAimbot, "Ragebot", 1)
local gOrbit = AddGroupbox(tabAimbot, "Orbit", 2)
local gVoid = AddGroupbox(tabAimbot, "Voidspam", 1)

-- Aimbot group
MakeToggle(gAimbot, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v; SaveConfig() end)
MakeToggle(gAimbot, "Silent Aim", function() return Config.Aimbot.Silent end, function(v) Config.Aimbot.Silent = v; SaveConfig() end)
MakeToggle(gAimbot, "Show FOV", function() return Config.Aimbot.ShowFOV end, function(v) Config.Aimbot.ShowFOV = v; SaveConfig() end)
MakeToggle(gAimbot, "Team Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v; SaveConfig() end)
MakeToggle(gAimbot, "Visibility Check", function() return Config.Aimbot.VisibilityCheck end, function(v) Config.Aimbot.VisibilityCheck = v; SaveConfig() end)
MakeKeyPicker(gAimbot, "Aimbot Key", function() return Config.Aimbot.Keybind end, function(v) Config.Aimbot.Keybind = v; SaveConfig() end)
MakeSlider(gAimbot, "Smoothness", function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v; SaveConfig() end, 0, 0.95)
MakeSlider(gAimbot, "FOV", function() return Config.Aimbot.FOV end, function(v) Config.Aimbot.FOV = v; FOVCircle.Radius = v; SaveConfig() end, 30, 500)
MakeSlider(gAimbot, "Hit Chance %", function() return Config.Aimbot.HitChance end, function(v) Config.Aimbot.HitChance = v; SaveConfig() end, 1, 100)
MakeDropdown(gAimbot, "Aim Part", {"Head","UpperTorso","HumanoidRootPart"}, function() return Config.Aimbot.AimPart end, function(v) Config.Aimbot.AimPart = v; SaveConfig() end)

-- Triggerbot group
MakeToggle(gTrigger, "Enable Triggerbot", function() return Config.Triggerbot.Enabled end, function(v) Config.Triggerbot.Enabled = v; SaveConfig() end)
MakeKeyPicker(gTrigger, "Trigger Key", function() return Config.Triggerbot.Keybind end, function(v) Config.Triggerbot.Keybind = v; SaveConfig() end)
MakeDropdown(gTrigger, "Target Part", {"Head","UpperTorso","HumanoidRootPart"}, function() return Config.Triggerbot.AimPart end, function(v) Config.Triggerbot.AimPart = v; SaveConfig() end)
MakeSlider(gTrigger, "Reaction Time (ms)", function() return Config.Triggerbot.ReactionTime*1000 end, function(v) Config.Triggerbot.ReactionTime = v/1000; SaveConfig() end, 10, 500)

-- Ragebot group
MakeToggle(gRage, "Enable Ragebot", function() return Config.Ragebot.Enabled end, function(v) Config.Ragebot.Enabled = v; SaveConfig() end)

-- Orbit group
MakeToggle(gOrbit, "Enable Orbit", function() return Config.Orbit.Enabled end, function(v) Config.Orbit.Enabled = v; if v then StartOrbit() end; SaveConfig() end)
MakeSlider(gOrbit, "Speed", function() return Config.Orbit.Speed end, function(v) Config.Orbit.Speed = v; SaveConfig() end, 0.5, 5)
MakeSlider(gOrbit, "Radius", function() return Config.Orbit.Radius end, function(v) Config.Orbit.Radius = v; SaveConfig() end, 5, 50)
MakeSlider(gOrbit, "Height", function() return Config.Orbit.Height end, function(v) Config.Orbit.Height = v; SaveConfig() end, -10, 20)

-- Voidspam group
MakeToggle(gVoid, "Enable Voidspam", function() return Config.Voidspam.Enabled end, function(v) Config.Voidspam.Enabled = v; if v then StartVoidspam() end; SaveConfig() end)
MakeSlider(gVoid, "Speed (Hz)", function() return Config.Voidspam.Speed end, function(v) Config.Voidspam.Speed = v; SaveConfig() end, 0.1, 2)

-- Tab: ESP
local tabESP = AddTab("ESP")
local gESP = AddGroupbox(tabESP, "ESP", 1)
MakeToggle(gESP, "Enable ESP", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v; SaveConfig() end)
MakeToggle(gESP, "Box ESP", function() return Config.ESP.Boxes end, function(v) Config.ESP.Boxes = v; SaveConfig() end)
MakeToggle(gESP, "Skeleton ESP", function() return Config.ESP.Skeleton end, function(v) Config.ESP.Skeleton = v; SaveConfig() end)
MakeToggle(gESP, "Names", function() return Config.ESP.Names end, function(v) Config.ESP.Names = v; SaveConfig() end)
MakeToggle(gESP, "Health Bars", function() return Config.ESP.Health end, function(v) Config.ESP.Health = v; SaveConfig() end)
MakeToggle(gESP, "Distance", function() return Config.ESP.Distance end, function(v) Config.ESP.Distance = v; SaveConfig() end)
MakeToggle(gESP, "Team Colors", function() return Config.ESP.TeamColor end, function(v) Config.ESP.TeamColor = v; SaveConfig() end)
MakeSlider(gESP, "Max Distance", function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v; SaveConfig() end, 100, 1000)

-- Tab: Misc
local tabMisc = AddTab("Misc")
local gMove = AddGroupbox(tabMisc, "Movement", 1)
local gSet = AddGroupbox(tabMisc, "Settings", 2)

-- Movement
MakeSlider(gMove, "Walk Speed", function() return Config.Movement.Speed end, function(v) Config.Movement.Speed = v; SaveConfig() end, 16, 200)
MakeToggle(gMove, "Flight", function() return Config.Movement.Flight end, function(v) Config.Movement.Flight = v; if v then StartFlight() end; SaveConfig() end)
MakeSlider(gMove, "Fly Speed", function() return Config.Movement.FlySpeed end, function(v) Config.Movement.FlySpeed = v; SaveConfig() end, 10, 200)

-- Settings
MakeDropdown(gSet, "Config", GetConfigNames(), function() return Config.Settings.ConfigName end, function(v) Config.Settings.ConfigName = v; SaveConfig() end)
MakeButton(gSet, "Save Config", function() SaveConfig(Config.Settings.ConfigName) end)
MakeButton(gSet, "Load Config", function() LoadConfig(Config.Settings.ConfigName) end)
MakeButton(gSet, "Delete Config", function()
    if Config.Settings.ConfigName ~= "Default" then
        getgenv().NexoConfigs[Config.Settings.ConfigName] = nil
        print("[Nexo] Config deleted")
    end
end)
MakeToggle(gSet, "Auto-Load", function() return Config.Settings.AutoLoad end, function(v) Config.Settings.AutoLoad = v; SaveConfig() end)

-- ============================================================
-- TOGGLE UI (RightShift)
-- ============================================================
UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.RightShift and not i.IsProcessed then
        MainWindow.Visible = not MainWindow.Visible
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    if Config.Aimbot.Enabled and Config.Aimbot.ShowFOV then
        local mp = UserInputService:GetMouseLocation()
        FOVCircle.Position = mp
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.Aimbot.FOV
    else
        FOVCircle.Visible = false
    end

    -- Aimbot
    if Config.Aimbot.Enabled and UserInputService:IsKeyDown(Enum.KeyCode[Config.Aimbot.Keybind]) then
        local targets = GetTargets()
        if #targets > 0 then AimAt(targets[1]) end
    end

    -- Ragebot
    if Config.Ragebot.Enabled then Ragebot() end

    -- Triggerbot
    if Config.Triggerbot.Enabled and UserInputService:IsKeyDown(Enum.KeyCode[Config.Triggerbot.Keybind]) then
        Triggerbot()
    end

    -- ESP
    UpdateESP()
end)

-- ============================================================
-- INIT
-- ============================================================
if Config.Settings.AutoLoad then LoadConfig("Default") end
StartOrbit()
StartVoidspam()
StartSpeed()
StartFlight()
print("Nexo loaded! Press RightShift to open menu.")

-- ============================================================
-- CLEANUP
-- ============================================================
local function unload()
    if orbitTask then orbitTask:Disconnect() end
    if voidTask then voidTask:Disconnect() end
    if speedTask then speedTask:Disconnect() end
    if flyTask then flyTask:Disconnect() end
    FOVCircle:Remove()
    for _, objs in pairs(EspObjects) do
        for _, o in pairs(objs) do
            if o then pcall(o.Remove, o) end
        end
    end
    ScreenGui:Destroy()
end
Library = { OnUnload = unload }
