task.wait()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

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

local function SafeDraw(type)
    local ok, obj = pcall(Drawing.new, type)
    if ok and obj then return obj end
    return nil
end

local FOVCircle = SafeDraw("Circle")
if FOVCircle then
    FOVCircle.Visible = false
    FOVCircle.Color = Color3.fromRGB(255,255,255)
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 32
    FOVCircle.Transparency = 0.5
    FOVCircle.Radius = Config.Aimbot.FOV
end

local EspObjects = {}

local function IsOnScreen(pos)
    local vp = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X * Camera.ViewportSize.X, vp.Y * Camera.ViewportSize.Y), (vp.Z > 0 and vp.X >= 0 and vp.X <= 1 and vp.Y >= 0 and vp.Y <= 1)
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
        if FOVCircle then FOVCircle.Radius = Config.Aimbot.FOV end
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = CoreGui

local BG = Color3.fromRGB(18,18,18)
local SectionBG = Color3.fromRGB(26,26,26)
local Border = Color3.fromRGB(255,255,255)
local TextColor = Color3.fromRGB(255,255,255)
local Accent = Color3.fromRGB(220,220,220)
local ToggleOn = Color3.fromRGB(255,255,255)
local ToggleOff = Color3.fromRGB(60,60,60)

local function safeFont()
    local success, result = pcall(function() return Enum.Font.Gotham end)
    if success then return Enum.Font.Gotham else return Enum.Font.SourceSans end
end
local FONT = safeFont()

local MainWindow = Instance.new("Frame")
MainWindow.Size = UDim2.new(0, 750, 0, 600)
MainWindow.Position = UDim2.new(0.5, -375, 0.5, -300)
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.BackgroundColor3 = BG
MainWindow.BorderColor3 = Border
MainWindow.BorderSizePixel = 2
MainWindow.Visible = false
MainWindow.Parent = ScreenGui

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

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,32)
titleBar.BackgroundColor3 = SectionBG
titleBar.BorderColor3 = Border
titleBar.BorderSizePixel = 1
titleBar.Parent = MainWindow

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "NEXO"
titleLbl.TextColor3 = TextColor
titleLbl.TextSize = 20
titleLbl.Font = FONT
titleLbl.TextXAlignment = Enum.TextXAlignment.Center
titleLbl.Parent = titleBar

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1,0,0,34)
tabContainer.Position = UDim2.new(0,0,0,32)
tabContainer.BackgroundColor3 = BG
tabContainer.BorderColor3 = Border
tabContainer.BorderSizePixel = 1
tabContainer.Parent = MainWindow

local tabData = {}

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.25,0,1,0)
    btn.Position = UDim2.new(#tabData * 0.25,0,0,0)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = TextColor
    btn.TextSize = 16
    btn.Font = FONT
    btn.Parent = tabContainer

    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1,-10,1,-66)
    frame.Position = UDim2.new(0,5,0,66)
    frame.BackgroundTransparency = 1
    frame.CanvasSize = UDim2.new(0,0,0,0)
    frame.ScrollBarThickness = 6
    frame.BorderSizePixel = 0
    frame.Visible = (#tabData == 0)
    frame.Parent = MainWindow

    local layout = Instance.new("UIListLayout")
    layout.Parent = frame
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0,10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 10)
    end)

    table.insert(tabData, { button = btn, frame = frame })

    btn.MouseButton1Click:Connect(function()
        for _, data in pairs(tabData) do
            data.frame.Visible = false
            data.button.TextColor3 = TextColor
        end
        frame.Visible = true
        btn.TextColor3 = Accent
    end)

    return frame, layout
end

local function AddGroupbox(parent, title)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,-10,0,0)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local box = Instance.new("Frame")
    box.Size = UDim2.new(1,0,0,200)
    box.BackgroundColor3 = SectionBG
    box.BorderColor3 = Border
    box.BorderSizePixel = 1
    box.Parent = container

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1,-2,1,-2)
    inner.Position = UDim2.new(0,1,0,1)
    inner.BackgroundColor3 = SectionBG
    inner.Parent = box

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,24)
    lbl.Position = UDim2.new(0,4,0,2)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Accent
    lbl.TextSize = 15
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = inner

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,-8,1,-28)
    content.Position = UDim2.new(0,4,0,24)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = inner

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Parent = content
    contentLayout.Padding = UDim.new(0,2)
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function resize()
        local h = 24 + contentLayout.AbsoluteContentSize.Y + 6
        box.Size = UDim2.new(1,0,0,h)
    end
    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
    task.wait()
    resize()

    local function addControl(control)
        control.Parent = content
        return control
    end

    local function addToggle(label, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,24)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TextColor
        lbl.TextSize = 13
        lbl.Font = FONT
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3,0,0,20)
        btn.Position = UDim2.new(0.7,0,0.5,-10)
        btn.BackgroundColor3 = getter() and ToggleOn or ToggleOff
        btn.BorderColor3 = Border
        btn.BorderSizePixel = 1
        btn.Text = getter() and "ON" or "OFF"
        btn.TextColor3 = getter() and BG or TextColor
        btn.TextSize = 12
        btn.Font = FONT
        btn.Parent = frame
        btn.MouseButton1Click:Connect(function()
            setter(not getter())
            btn.BackgroundColor3 = getter() and ToggleOn or ToggleOff
            btn.Text = getter() and "ON" or "OFF"
            btn.TextColor3 = getter() and BG or TextColor
            SaveConfig()
        end)

        addControl(frame)
    end

    local function addSlider(label, getter, setter, min, max)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,34)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,0,14)
        lbl.BackgroundTransparency = 1
        lbl.Text = label .. ": " .. tostring(getter())
        lbl.TextColor3 = TextColor
        lbl.TextSize = 13
        lbl.Font = FONT
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0.8,0,0,18)
        input.Position = UDim2.new(0.1,0,0,14)
        input.BackgroundColor3 = BG
        input.BorderColor3 = Border
        input.BorderSizePixel = 1
        input.Text = tostring(getter())
        input.TextColor3 = TextColor
        input.TextSize = 12
        input.Font = FONT
        input.ClearTextOnFocus = false
        input.Parent = frame
        input.FocusLost:Connect(function(enter)
            if enter then
                local v = tonumber(input.Text)
                if v then
                    v = math.clamp(v, min or 0, max or 1)
                    setter(v)
                    lbl.Text = label .. ": " .. tostring(v)
                    SaveConfig()
                end
                input.Text = tostring(getter())
            end
        end)

        addControl(frame)
    end

    local function addDropdown(label, values, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,30)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TextColor
        lbl.TextSize = 13
        lbl.Font = FONT
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.4,0,0,22)
        btn.Position = UDim2.new(0.5,0,0.5,-11)
        btn.BackgroundColor3 = BG
        btn.BorderColor3 = Border
        btn.BorderSizePixel = 1
        btn.Text = tostring(getter())
        btn.TextColor3 = TextColor
        btn.TextSize = 12
        btn.Font = FONT
        btn.Parent = frame

        local list = Instance.new("Frame")
        list.Size = UDim2.new(0.4,0,0, #values*20)
        list.Position = UDim2.new(0.5,0,1,0)
        list.BackgroundColor3 = BG
        list.BorderColor3 = Border
        list.BorderSizePixel = 1
        list.Visible = false
        list.ZIndex = 2
        list.Parent = frame

        for _, v in pairs(values) do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1,0,0,20)
            opt.BackgroundColor3 = SectionBG
            opt.BorderColor3 = Border
            opt.BorderSizePixel = 1
            opt.Text = v
            opt.TextColor3 = TextColor
            opt.TextSize = 12
            opt.Font = FONT
            opt.Parent = list
            opt.MouseButton1Click:Connect(function()
                setter(v)
                btn.Text = v
                list.Visible = false
                SaveConfig()
            end)
        end

        btn.MouseButton1Click:Connect(function()
            list.Visible = not list.Visible
        end)

        addControl(frame)
    end

    local function addKeyPicker(label, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,24)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TextColor
        lbl.TextSize = 13
        lbl.Font = FONT
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3,0,0,20)
        btn.Position = UDim2.new(0.7,0,0.5,-10)
        btn.BackgroundColor3 = BG
        btn.BorderColor3 = Border
        btn.BorderSizePixel = 1
        btn.Text = getter()
        btn.TextColor3 = TextColor
        btn.TextSize = 12
        btn.Font = FONT
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
                SaveConfig()
            end)
        end)

        addControl(frame)
    end

    local function addButton(label, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,28)
        frame.BackgroundTransparency = 1

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-4,0,22)
        btn.Position = UDim2.new(0,2,0,3)
        btn.BackgroundColor3 = BG
        btn.BorderColor3 = Border
        btn.BorderSizePixel = 1
        btn.Text = label
        btn.TextColor3 = TextColor
        btn.TextSize = 13
        btn.Font = FONT
        btn.Parent = frame
        btn.MouseButton1Click:Connect(callback)

        addControl(frame)
    end

    return {
        addToggle = addToggle,
        addSlider = addSlider,
        addDropdown = addDropdown,
        addKeyPicker = addKeyPicker,
        addButton = addButton,
    }
end

local combatFrame, combatLayout = CreateTab("Combat")
local gAimbot = AddGroupbox(combatFrame, "Aimbot")
gAimbot.addToggle("Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v end)
gAimbot.addToggle("Silent Aim", function() return Config.Aimbot.Silent end, function(v) Config.Aimbot.Silent = v end)
gAimbot.addToggle("Show FOV", function() return Config.Aimbot.ShowFOV end, function(v) Config.Aimbot.ShowFOV = v end)
gAimbot.addToggle("Team Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
gAimbot.addToggle("Visibility Check", function() return Config.Aimbot.VisibilityCheck end, function(v) Config.Aimbot.VisibilityCheck = v end)
gAimbot.addKeyPicker("Aimbot Key", function() return Config.Aimbot.Keybind end, function(v) Config.Aimbot.Keybind = v end)
gAimbot.addSlider("Smoothness", function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end, 0, 0.95)
gAimbot.addSlider("FOV", function() return Config.Aimbot.FOV end, function(v) Config.Aimbot.FOV = v; if FOVCircle then FOVCircle.Radius = v end end, 30, 500)
gAimbot.addSlider("Hit Chance %", function() return Config.Aimbot.HitChance end, function(v) Config.Aimbot.HitChance = v end, 1, 100)
gAimbot.addDropdown("Aim Part", {"Head","UpperTorso","HumanoidRootPart"}, function() return Config.Aimbot.AimPart end, function(v) Config.Aimbot.AimPart = v end)

local gTrigger = AddGroupbox(combatFrame, "Triggerbot")
gTrigger.addToggle("Enable Triggerbot", function() return Config.Triggerbot.Enabled end, function(v) Config.Triggerbot.Enabled = v end)
gTrigger.addKeyPicker("Trigger Key", function() return Config.Triggerbot.Keybind end, function(v) Config.Triggerbot.Keybind = v end)
gTrigger.addDropdown("Target Part", {"Head","UpperTorso","HumanoidRootPart"}, function() return Config.Triggerbot.AimPart end, function(v) Config.Triggerbot.AimPart = v end)
gTrigger.addSlider("Reaction Time (ms)", function() return Config.Triggerbot.ReactionTime*1000 end, function(v) Config.Triggerbot.ReactionTime = v/1000 end, 10, 500)

local gRage = AddGroupbox(combatFrame, "Ragebot")
gRage.addToggle("Enable Ragebot", function() return Config.Ragebot.Enabled end, function(v) Config.Ragebot.Enabled = v end)

local gOrbit = AddGroupbox(combatFrame, "Orbit")
gOrbit.addToggle("Enable Orbit", function() return Config.Orbit.Enabled end, function(v) Config.Orbit.Enabled = v; if v then StartOrbit() end end)
gOrbit.addSlider("Speed", function() return Config.Orbit.Speed end, function(v) Config.Orbit.Speed = v end, 0.5, 5)
gOrbit.addSlider("Radius", function() return Config.Orbit.Radius end, function(v) Config.Orbit.Radius = v end, 5, 50)
gOrbit.addSlider("Height", function() return Config.Orbit.Height end, function(v) Config.Orbit.Height = v end, -10, 20)

local gVoid = AddGroupbox(combatFrame, "Voidspam")
gVoid.addToggle("Enable Voidspam", function() return Config.Voidspam.Enabled end, function(v) Config.Voidspam.Enabled = v; if v then StartVoidspam() end end)
gVoid.addSlider("Speed (Hz)", function() return Config.Voidspam.Speed end, function(v) Config.Voidspam.Speed = v end, 0.1, 2)

local espFrame, espLayout = CreateTab("ESP")
local gESP = AddGroupbox(espFrame, "ESP")
gESP.addToggle("Enable ESP", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)
gESP.addToggle("Box ESP", function() return Config.ESP.Boxes end, function(v) Config.ESP.Boxes = v end)
gESP.addToggle("Names", function() return Config.ESP.Names end, function(v) Config.ESP.Names = v end)
gESP.addToggle("Health Bars", function() return Config.ESP.Health end, function(v) Config.ESP.Health = v end)
gESP.addToggle("Distance", function() return Config.ESP.Distance end, function(v) Config.ESP.Distance = v end)
gESP.addToggle("Team Colors", function() return Config.ESP.TeamColor end, function(v) Config.ESP.TeamColor = v end)
gESP.addSlider("Max Distance", function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v end, 100, 1000)

local miscFrame, miscLayout = CreateTab("Misc")
local gMove = AddGroupbox(miscFrame, "Movement")
gMove.addSlider("Walk Speed", function() return Config.Movement.Speed end, function(v) Config.Movement.Speed = v end, 16, 200)
gMove.addToggle("Flight", function() return Config.Movement.Flight end, function(v) Config.Movement.Flight = v; if v then StartFlight() end end)
gMove.addSlider("Fly Speed", function() return Config.Movement.FlySpeed end, function(v) Config.Movement.FlySpeed = v end, 10, 200)

local settingsFrame, settingsLayout = CreateTab("Settings")
local gSet = AddGroupbox(settingsFrame, "Config")
gSet.addDropdown("Config", GetConfigNames(), function() return Config.Settings.ConfigName end, function(v) Config.Settings.ConfigName = v end)
gSet.addButton("Save Config", function() SaveConfig(Config.Settings.ConfigName) end)
gSet.addButton("Load Config", function() LoadConfig(Config.Settings.ConfigName) end)
gSet.addButton("Delete Config", function()
    if Config.Settings.ConfigName ~= "Default" then
        ConfigStore[Config.Settings.ConfigName] = nil
    end
end)
gSet.addToggle("Auto-Load", function() return Config.Settings.AutoLoad end, function(v) Config.Settings.AutoLoad = v end)

UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.RightShift then
        MainWindow.Visible = not MainWindow.Visible
    end
end)

RunService.RenderStepped:Connect(function()
    if FOVCircle then
        if Config.Aimbot.Enabled and Config.Aimbot.ShowFOV then
            FOVCircle.Position = UserInputService:GetMouseLocation()
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    end

    if Config.Aimbot.Enabled and UserInputService:IsKeyDown(Enum.KeyCode[Config.Aimbot.Keybind]) then
        local targets = GetTargets()
        if #targets > 0 then AimAt(targets[1]) end
    end

    if Config.Ragebot.Enabled then Ragebot() end

    if Config.Triggerbot.Enabled and UserInputService:IsKeyDown(Enum.KeyCode[Config.Triggerbot.Keybind]) then
        Triggerbot()
    end

    UpdateESP()
end)

if Config.Settings.AutoLoad then LoadConfig("Default") end
StartOrbit()
StartVoidspam()
StartSpeed()
StartFlight()

local function unload()
    if orbitTask then orbitTask:Disconnect() end
    if voidTask then voidTask:Disconnect() end
    if speedTask then speedTask:Disconnect() end
    if flyTask then flyTask:Disconnect() end
    if FOVCircle then pcall(FOVCircle.Remove, FOVCircle) end
    for _, objs in pairs(EspObjects) do
        for _, o in pairs(objs) do
            if o then pcall(o.Remove, o) end
        end
    end
    ScreenGui:Destroy()
end
Library = { OnUnload = unload }
