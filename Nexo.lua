--[[
    NEXO – Advanced Combat Script
    Discord: https://discord.gg/XV6HcW5Nn
    Accent: #f736db | Open UI: RightShift
]]

task.wait()

-- ============================================================
-- MINIMAL LINORIA LIBRARY (with CreateWindow)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = CoreGui

local Library = {
    ScreenGui = ScreenGui,
    Toggled = false,
    Font = Enum.Font.Code,
    FontSize = 14,
    AccentColor = Color3.fromRGB(247, 54, 219),
    AccentColorDark = Color3.fromRGB(200, 30, 170),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    FontColor = Color3.fromRGB(255, 255, 255),
    OpenedFrames = {},
    KeyPickerList = {},
    KeybindContainer = nil,
    KeybindFrame = nil,
    Signals = {},
}

function Library:Create(Class, Props)
    local obj = type(Class) == "string" and Instance.new(Class) or Class
    for k, v in pairs(Props) do
        obj[k] = v
    end
    return obj
end

function Library:CreateLabel(Props)
    local lbl = self:Create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Font,
        TextColor3 = self.FontColor,
        TextSize = self.FontSize + 2,
        TextStrokeTransparency = 0,
    })
    for k, v in pairs(Props) do
        lbl[k] = v
    end
    return lbl
end

function Library:AddToRegistry() end -- placeholder

function Library:MakeDraggable(frame)
    frame.Active = true
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local start = i.Position
            local pos = frame.Position
            local conn
            conn = UserInputService.InputChanged:Connect(function(c)
                if c.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = c.Position - start
                    frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset + delta.X, pos.Y.Scale, pos.Y.Offset + delta.Y)
                end
            end)
            local ended
            ended = UserInputService.InputEnded:Connect(function(e)
                if e == i then
                    conn:Disconnect()
                    ended:Disconnect()
                end
            end)
        end
    end)
end

function Library:Notify(text, time)
    local f = self:Create("TextLabel", {
        Size = UDim2.new(0, 300, 0, 30),
        Position = UDim2.new(0.5, -150, 0, 50),
        BackgroundColor3 = self.MainColor,
        BorderColor3 = self.AccentColor,
        BorderSizePixel = 1,
        Text = text,
        TextColor3 = self.FontColor,
        TextSize = 14,
        Font = self.Font,
        ZIndex = 1000,
        Parent = ScreenGui,
    })
    task.delay(time or 3, f.Destroy, f)
end

function Library:SetWatermark() end

-- ============================================================
-- KEYPICKER (minimal)
-- ============================================================
function Library:AddKeyPicker(parent, info)
    local key = info.Default or "None"
    local mode = info.Mode or "Hold"
    local callback = info.Callback or function() end
    local btn = self:Create("TextButton", {
        Size = UDim2.new(0, 80, 0, 20),
        BackgroundColor3 = self.MainColor,
        BorderColor3 = self.OutlineColor,
        Text = key,
        TextColor3 = self.FontColor,
        TextSize = 13,
        Font = self.Font,
        Parent = parent,
    })
    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Keyboard then
                btn.Text = i.KeyCode.Name
                key = i.KeyCode
                callback(key)
                conn:Disconnect()
            elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
                btn.Text = "MB1"
                key = Enum.UserInputType.MouseButton1
                callback(key)
                conn:Disconnect()
            elseif i.UserInputType == Enum.UserInputType.MouseButton2 then
                btn.Text = "MB2"
                key = Enum.UserInputType.MouseButton2
                callback(key)
                conn:Disconnect()
            end
        end)
    end)
    return { Value = key, Mode = mode, Callback = callback }
end

-- ============================================================
-- UI BUILDING FUNCTIONS (CreateWindow)
-- ============================================================
function Library:CreateWindow(config)
    config = config or {}
    local window = {}
    local outer = self:Create("Frame", {
        Size = config.Size or UDim2.new(0, 650, 0, 550),
        Position = config.Position or UDim2.new(0.5, -325, 0.5, -275),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = ScreenGui,
    })
    self:MakeDraggable(outer)

    local inner = self:Create("Frame", {
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = self.MainColor,
        BorderColor3 = self.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Parent = outer,
    })

    local title = self:CreateLabel({
        Size = UDim2.new(1, 0, 0, 25),
        Text = config.Title or "Nexo",
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 1,
        Parent = inner,
    })

    -- Discord link
    self:CreateLabel({
        Size = UDim2.new(1, 0, 0, 25),
        Position = UDim2.new(0, 0, 0, 25),
        Text = "Join Discord: https://discord.gg/XV6HcW5Nn",
        TextColor3 = self.AccentColor,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = inner,
    })

    local tabBar = self:Create("Frame", {
        Size = UDim2.new(1, -16, 0, 29),
        Position = UDim2.new(0, 8, 0, 50),
        BackgroundColor3 = self.BackgroundColor,
        BorderColor3 = self.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Parent = inner,
    })
    local tabArea = self:Create("Frame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundTransparency = 1,
        Parent = tabBar,
    })
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Parent = tabArea
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)

    local content = self:Create("Frame", {
        Size = UDim2.new(1, -16, 1, -66 - 29),
        Position = UDim2.new(0, 8, 0, 58 + 29),
        BackgroundColor3 = self.BackgroundColor,
        BorderColor3 = self.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Parent = inner,
    })
    local contentInner = self:Create("Frame", {
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = self.BackgroundColor,
        Parent = content,
    })
    local tabContainer = self:Create("Frame", {
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = self.MainColor,
        BorderColor3 = self.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Parent = contentInner,
    })

    local function toggleUI()
        self.Toggled = not self.Toggled
        outer.Visible = self.Toggled
    end

    UserInputService.InputBegan:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.RightShift and not i.IsProcessed then
            toggleUI()
        end
    end)

    window.Inner = inner
    window.Tabs = {}

    function window:AddTab(name)
        local tab = {}
        local btn = self:Create("TextButton", {
            Size = UDim2.new(0, 80, 0, 20),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = self.FontColor,
            TextSize = 14,
            Font = self.Font,
            Parent = tabArea,
        })
        local tabFrame = self:Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = tabContainer,
        })
        local left = self:Create("ScrollingFrame", {
            Size = UDim2.new(0.5, -6, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 6,
            Parent = tabFrame,
        })
        local right = self:Create("ScrollingFrame", {
            Size = UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 6,
            Parent = tabFrame,
        })
        local leftLayout = Instance.new("UIListLayout")
        leftLayout.Parent = left
        leftLayout.Padding = UDim.new(0, 8)
        leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        local rightLayout = Instance.new("UIListLayout")
        rightLayout.Parent = right
        rightLayout.Padding = UDim.new(0, 8)
        rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        btn.MouseButton1Click:Connect(function()
            for _, t in pairs(window.Tabs) do
                if t ~= tab then
                    t:SetVisible(false)
                end
            end
            tab:SetVisible(true)
            btn.BackgroundColor3 = self.MainColor
            btn.BackgroundTransparency = 0.3
            btn.TextColor3 = self.AccentColor
        end)

        function tab:SetVisible(v)
            tabFrame.Visible = v
            if v then
                btn.BackgroundColor3 = self.MainColor
                btn.BackgroundTransparency = 0.3
                btn.TextColor3 = self.AccentColor
            else
                btn.BackgroundTransparency = 1
                btn.TextColor3 = self.FontColor
            end
        end

        function tab:AddGroupbox(side, name)
            local parent = side == 1 and left or right
            local box = {}
            local outerBox = self:Create("Frame", {
                Size = UDim2.new(1, 0, 0, 200),
                BackgroundColor3 = self.BackgroundColor,
                BorderColor3 = self.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Parent = parent,
            })
            local innerBox = self:Create("Frame", {
                Size = UDim2.new(1, -2, 1, -2),
                Position = UDim2.new(0, 1, 0, 1),
                BackgroundColor3 = self.BackgroundColor,
                Parent = outerBox,
            })
            local label = self:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 4, 0, 2),
                Text = name,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 14,
                Parent = innerBox,
            })
            local container = self:Create("Frame", {
                Size = UDim2.new(1, -8, 1, -20),
                Position = UDim2.new(0, 4, 0, 20),
                BackgroundTransparency = 1,
                Parent = innerBox,
            })
            local layout = Instance.new("UIListLayout")
            layout.Parent = container
            layout.Padding = UDim.new(0, 4)
            layout.FillDirection = Enum.FillDirection.Vertical
            layout.SortOrder = Enum.SortOrder.LayoutOrder

            function box:AddToggle(info)
                local toggle = { Value = info.Default or false }
                local f = self:Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 25),
                    BackgroundTransparency = 1,
                    Parent = container,
                })
                local lbl = self:CreateLabel({
                    Size = UDim2.new(0.7, 0, 1, 0),
                    Text = info.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 13,
                    Parent = f,
                })
                local btn = self:Create("TextButton", {
                    Size = UDim2.new(0, 50, 0, 20),
                    Position = UDim2.new(0.7, 0, 0.5, -10),
                    BackgroundColor3 = toggle.Value and self.AccentColor or self.MainColor,
                    BorderColor3 = self.OutlineColor,
                    Text = toggle.Value and "ON" or "OFF",
                    TextColor3 = self.FontColor,
                    TextSize = 12,
                    Font = self.Font,
                    Parent = f,
                })
                btn.MouseButton1Click:Connect(function()
                    toggle.Value = not toggle.Value
                    btn.BackgroundColor3 = toggle.Value and self.AccentColor or self.MainColor
                    btn.Text = toggle.Value and "ON" or "OFF"
                    if info.Callback then
                        info.Callback(toggle.Value)
                    end
                end)
                return toggle
            end

            function box:AddSlider(info)
                local slider = { Value = info.Default }
                local f = self:Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 35),
                    BackgroundTransparency = 1,
                    Parent = container,
                })
                local lbl = self:CreateLabel({
                    Size = UDim2.new(1, 0, 0, 15),
                    Text = info.Text .. ": " .. tostring(slider.Value),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 13,
                    Parent = f,
                })
                local input = self:Create("TextBox", {
                    Size = UDim2.new(0.8, 0, 0, 18),
                    Position = UDim2.new(0.1, 0, 0, 17),
                    BackgroundColor3 = self.MainColor,
                    BorderColor3 = self.OutlineColor,
                    Text = tostring(slider.Value),
                    TextColor3 = self.FontColor,
                    TextSize = 12,
                    Font = self.Font,
                    ClearTextOnFocus = false,
                    Parent = f,
                })
                input.FocusLost:Connect(function(enter)
                    if enter then
                        local v = tonumber(input.Text)
                        if v then
                            v = math.clamp(v, info.Min or 0, info.Max or 1)
                            slider.Value = v
                            lbl.Text = info.Text .. ": " .. tostring(v)
                            if info.Callback then
                                info.Callback(v)
                            end
                        end
                        input.Text = tostring(slider.Value)
                    end
                end)
                return slider
            end

            function box:AddDropdown(info)
                local dropdown = { Value = info.Default }
                local f = self:Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Parent = container,
                })
                local lbl = self:CreateLabel({
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Text = info.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 13,
                    Parent = f,
                })
                local btn = self:Create("TextButton", {
                    Size = UDim2.new(0.4, 0, 0, 22),
                    Position = UDim2.new(0.5, 0, 0.5, -11),
                    BackgroundColor3 = self.MainColor,
                    BorderColor3 = self.OutlineColor,
                    Text = tostring(dropdown.Value),
                    TextColor3 = self.FontColor,
                    TextSize = 12,
                    Font = self.Font,
                    Parent = f,
                })
                local list = self:Create("Frame", {
                    Size = UDim2.new(0.4, 0, 0, #info.Values * 20),
                    Position = UDim2.new(0.5, 0, 1, 0),
                    BackgroundColor3 = self.BackgroundColor,
                    BorderColor3 = self.OutlineColor,
                    Visible = false,
                    ZIndex = 2,
                    Parent = f,
                })
                for _, v in pairs(info.Values) do
                    local opt = self:Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 20),
                        BackgroundColor3 = self.MainColor,
                        Text = v,
                        TextColor3 = self.FontColor,
                        TextSize = 12,
                        Font = self.Font,
                        Parent = list,
                    })
                    opt.MouseButton1Click:Connect(function()
                        dropdown.Value = v
                        btn.Text = v
                        list.Visible = false
                        if info.Callback then
                            info.Callback(v)
                        end
                    end)
                end
                btn.MouseButton1Click:Connect(function()
                    list.Visible = not list.Visible
                end)
                return dropdown
            end

            function box:AddButton(info)
                local btn = self:Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 25),
                    BackgroundColor3 = self.MainColor,
                    BorderColor3 = self.OutlineColor,
                    Text = info.Text,
                    TextColor3 = self.FontColor,
                    TextSize = 13,
                    Font = self.Font,
                    Parent = container,
                })
                btn.MouseButton1Click:Connect(info.Func or function() end)
            end

            function box:AddKeyPicker(info)
                return Library:AddKeyPicker(container, info)
            end

            function box:Resize()
                local h = 20 + layout.AbsoluteContentSize.Y + 4
                outerBox.Size = UDim2.new(1, 0, 0, h)
            end
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                box:Resize()
            end)
            box:Resize()
            return box
        end

        tab:AddLeftGroupbox = function(self, name)
            return self:AddGroupbox(1, name)
        end
        tab:AddRightGroupbox = function(self, name)
            return self:AddGroupbox(2, name)
        end

        window.Tabs[name] = tab
        if #window.Tabs == 1 then
            tab:SetVisible(true)
        end
        return tab
    end

    return window
end

-- ============================================================
-- NEXO CONFIG
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
        Keybind = Enum.KeyCode.LeftAlt,
        ShowFOV = true,
    },
    Triggerbot = {
        Enabled = false,
        AimPart = "Head",
        ReactionTime = 0.05,
        Keybind = Enum.KeyCode.LeftControl,
    },
    Ragebot = {
        Enabled = false,
    },
    Orbit = {
        Enabled = false,
        Speed = 2,
        Radius = 20,
        Height = 5,
    },
    Voidspam = {
        Enabled = false,
        Speed = 0.5,
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        Skeleton = false,
        Names = true,
        Health = true,
        Distance = true,
        TeamColor = true,
        EnemyColor = Color3.fromRGB(255, 50, 50),
        FriendColor = Color3.fromRGB(50, 255, 50),
        MaxDistance = 500,
    },
    Movement = {
        Speed = 16,
        Flight = false,
        FlySpeed = 50,
    },
    Settings = {
        ConfigName = "Default",
        AutoLoad = true,
    },
}

local Camera = workspace.CurrentCamera

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(247, 54, 219)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 32
FOVCircle.Transparency = 0.5

local EspObjects = {}
local esp_counter = 0

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

-- ============================================================
-- ESP
-- ============================================================
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
        n.OutlineColor = Color3.new(0, 0, 0)
        table.insert(objs, n)
    end
    if Config.ESP.Distance then
        local d = Drawing.new("Text")
        d.Visible = false
        d.Size = 12
        d.Center = true
        d.Outline = true
        d.OutlineColor = Color3.new(0, 0, 0)
        table.insert(objs, d)
    end
    if Config.ESP.Health then
        local hbg = Drawing.new("Square")
        hbg.Visible = false
        hbg.Color = Color3.new(0, 0, 0)
        hbg.Thickness = 1
        hbg.Filled = true
        hbg.Transparency = 0.5
        table.insert(objs, hbg)
        local hbar = Drawing.new("Square")
        hbar.Visible = false
        hbar.Color = Color3.new(0, 1, 0)
        hbar.Thickness = 1
        hbar.Filled = true
        hbar.Transparency = 0.3
        table.insert(objs, hbar)
    end
    EspObjects[player] = objs
end

local function UpdateESP()
    esp_counter = esp_counter + 1
    if esp_counter % 2 ~= 0 then
        return
    end
    if not Config.ESP.Enabled then
        for _, objs in pairs(EspObjects) do
            for _, o in pairs(objs) do
                if o then
                    o.Visible = false
                end
            end
        end
        return
    end
    local char = LocalPlayer.Character
    if not char then
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end
        local c = player.Character
        if not c then
            continue
        end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            continue
        end
        if not EspObjects[player] then
            CreateEspObject(player)
        end
        local objs = EspObjects[player]
        if not objs then
            continue
        end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local hp = c:FindFirstChild("Head")
        if not rp or not hp then
            continue
        end
        local dist = (rp.Position - root.Position).Magnitude
        if dist > Config.ESP.MaxDistance * 10 then
            for _, o in pairs(objs) do
                if o then
                    o.Visible = false
                end
            end
            continue
        end
        local _, on = IsOnScreen(rp.Position)
        if not on then
            for _, o in pairs(objs) do
                if o then
                    o.Visible = false
                end
            end
            continue
        end
        local color = GetPlayerColor(player)
        local hPos, hOn = IsOnScreen(hp.Position)
        local rPos, rOn = IsOnScreen(rp.Position)
        if not hOn or not rOn then
            continue
        end
        local height = math.abs(hPos.Y - rPos.Y) * 2.2
        local width = height * 0.55
        local top = Vector2.new(rPos.X - width / 2, hPos.Y - height * 0.15)
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
                n.Position = Vector2.new(rPos.X, hPos.Y - height * 0.25 - 16)
                n.Text = player.Name
                n.Color = color
            end)
            idx = idx + 1
        end
        if Config.ESP.Distance and objs[idx] then
            local d = objs[idx]
            pcall(function()
                d.Visible = true
                d.Position = Vector2.new(rPos.X, rPos.Y + height * 0.55)
                d.Text = math.round(dist / 10) .. "m"
                d.Color = color
            end)
            idx = idx + 1
        end
        if Config.ESP.Health and objs[idx] and objs[idx + 1] then
            local hbg = objs[idx]
            local hbar = objs[idx + 1]
            local bw = width * 0.7
            local bh = 4
            local bp = Vector2.new(rPos.X - bw / 2, rPos.Y + height * 0.48)
            local hpct = hum.Health / hum.MaxHealth
            pcall(function()
                hbg.Visible = true
                hbg.Position = bp
                hbg.Size = Vector2.new(bw, bh)
                hbar.Visible = true
                hbar.Position = bp
                hbar.Size = Vector2.new(bw * hpct, bh)
                hbar.Color = Color3.new(1 - hpct, hpct, 0)
            end)
        end
    end
end

-- ============================================================
-- Aimbot
-- ============================================================
local function GetTargets()
    local targets = {}
    local char = LocalPlayer.Character
    if not char then
        return targets
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        return targets
    end
    local mousePos = UserInputService:GetMouseLocation()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end
        local c = player.Character
        if not c then
            continue
        end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            continue
        end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            continue
        end
        local part = c:FindFirstChild(Config.Aimbot.AimPart)
        if not part then
            continue
        end
        local dist = (part.Position - root.Position).Magnitude
        if dist > 5000 then
            continue
        end
        if Config.Aimbot.VisibilityCheck then
            local ray = Ray.new(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 10000)
            local hit = workspace:FindPartOnRay(ray, char)
            if hit and not hit:IsDescendantOf(c) then
                continue
            end
        end
        local v, on = IsOnScreen(part.Position)
        if not on then
            continue
        end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist > Config.Aimbot.FOV then
            continue
        end
        if math.random(1, 100) > Config.Aimbot.HitChance then
            continue
        end
        table.insert(targets, {
            Player = player,
            Character = c,
            AimPart = part,
            Distance = dist,
            ScreenDist = screenDist,
        })
    end
    table.sort(targets, function(a, b)
        return a.ScreenDist < b.ScreenDist
    end)
    return targets
end

local function AimAt(target)
    if not target then
        return
    end
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

-- ============================================================
-- Triggerbot
-- ============================================================
local triggerDelay = 0
local function Triggerbot()
    if not Config.Triggerbot.Enabled then
        return
    end
    local mousePos = UserInputService:GetMouseLocation()
    local char = LocalPlayer.Character
    if not char then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end
        local c = player.Character
        if not c then
            continue
        end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            continue
        end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            continue
        end
        local part = c:FindFirstChild(Config.Triggerbot.AimPart)
        if not part then
            continue
        end
        local v, on = IsOnScreen(part.Position)
        if not on then
            continue
        end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist < 30 then
            if tick() - triggerDelay >= Config.Triggerbot.ReactionTime then
                mouse1click()
                triggerDelay = tick()
            end
        end
    end
end

-- ============================================================
-- Ragebot
-- ============================================================
local function Ragebot()
    if not Config.Ragebot.Enabled then
        return
    end
    local targets = GetTargets()
    if #targets > 0 then
        local t = targets[1]
        local pos = t.AimPart.Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
    end
end

-- ============================================================
-- Orbit
-- ============================================================
local orbitAngle = 0
local orbitTask
local function StartOrbit()
    if orbitTask then
        orbitTask:Disconnect()
    end
    orbitTask = RunService.RenderStepped:Connect(function(dt)
        if not Config.Orbit.Enabled then
            return
        end
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        local nearest, nearDist = nil, math.huge
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then
                continue
            end
            local c = player.Character
            if not c then
                continue
            end
            local r = c:FindFirstChild("HumanoidRootPart")
            if not r then
                continue
            end
            local d = (r.Position - root.Position).Magnitude
            if d < nearDist then
                nearDist = d
                nearest = r
            end
        end
        if not nearest then
            return
        end
        orbitAngle = orbitAngle + dt * Config.Orbit.Speed
        local radius = Config.Orbit.Radius
        local height = Config.Orbit.Height
        local center = nearest.Position
        local newPos = center + Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
        root.CFrame = CFrame.new(newPos)
    end)
end

-- ============================================================
-- Voidspam
-- ============================================================
local voidTask
local function StartVoidspam()
    if voidTask then
        voidTask:Disconnect()
    end
    voidTask = RunService.RenderStepped:Connect(function()
        if not Config.Voidspam.Enabled then
            return
        end
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        root.CFrame = CFrame.new(root.Position.X, -1000, root.Position.Z)
    end)
end

-- ============================================================
-- Movement (Speed & Flight)
-- ============================================================
local speedTask
local function StartSpeed()
    if speedTask then
        speedTask:Disconnect()
    end
    speedTask = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then
            return
        end
        hum.WalkSpeed = Config.Movement.Speed
    end)
end

local flyTask
local function StartFlight()
    if flyTask then
        flyTask:Disconnect()
    end
    flyTask = RunService.RenderStepped:Connect(function()
        if not Config.Movement.Flight then
            return
        end
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then
            return
        end
        hum.PlatformStand = true
        local move = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            move = move + Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            move = move - Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            move = move - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            move = move + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, 1, 0)
        end
        if move.Magnitude > 0 then
            move = move.Unit * Config.Movement.FlySpeed
            root.Velocity = move
        else
            root.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ============================================================
-- Config Save/Load
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
    Library:Notify("Config '" .. name .. "' saved!", 2)
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
        Library:Notify("Config '" .. name .. "' loaded!", 2)
    else
        Library:Notify("Config '" .. name .. "' not found!", 2)
    end
end

local function GetConfigNames()
    local names = { "Default" }
    if getgenv().NexoConfigs then
        for name, _ in pairs(getgenv().NexoConfigs) do
            table.insert(names, name)
        end
    end
    return names
end

-- ============================================================
-- BUILD UI
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Nexo v1.0",
    Size = UDim2.new(0, 650, 0, 550),
})

-- Combat Tab
local Combat = Window:AddTab("Combat")

-- Aimbot Group (Left)
local AimGroup = Combat:AddLeftGroupbox("Aimbot")
AimGroup:AddToggle({
    Text = "Enable Aimbot",
    Default = Config.Aimbot.Enabled,
    Callback = function(v)
        Config.Aimbot.Enabled = v
        SaveConfig()
    end,
})
AimGroup:AddToggle({
    Text = "Silent Aim",
    Default = Config.Aimbot.Silent,
    Callback = function(v)
        Config.Aimbot.Silent = v
        SaveConfig()
    end,
})
AimGroup:AddToggle({
    Text = "Show FOV",
    Default = Config.Aimbot.ShowFOV,
    Callback = function(v)
        Config.Aimbot.ShowFOV = v
        SaveConfig()
    end,
})
AimGroup:AddToggle({
    Text = "Team Check",
    Default = Config.Aimbot.TeamCheck,
    Callback = function(v)
        Config.Aimbot.TeamCheck = v
        SaveConfig()
    end,
})
AimGroup:AddToggle({
    Text = "Visibility Check",
    Default = Config.Aimbot.VisibilityCheck,
    Callback = function(v)
        Config.Aimbot.VisibilityCheck = v
        SaveConfig()
    end,
})
AimGroup:AddKeyPicker({
    Text = "Aimbot Key",
    Default = "LeftAlt",
    Mode = "Hold",
    Callback = function(k)
        Config.Aimbot.Keybind = k
        SaveConfig()
    end,
})
AimGroup:AddSlider({
    Text = "Smoothness",
    Default = Config.Aimbot.Smoothness,
    Min = 0,
    Max = 0.95,
    Callback = function(v)
        Config.Aimbot.Smoothness = v
        SaveConfig()
    end,
})
AimGroup:AddSlider({
    Text = "FOV",
    Default = Config.Aimbot.FOV,
    Min = 30,
    Max = 500,
    Callback = function(v)
        Config.Aimbot.FOV = v
        FOVCircle.Radius = v
        SaveConfig()
    end,
})
AimGroup:AddSlider({
    Text = "Hit Chance %",
    Default = Config.Aimbot.HitChance,
    Min = 1,
    Max = 100,
    Callback = function(v)
        Config.Aimbot.HitChance = v
        SaveConfig()
    end,
})
AimGroup:AddDropdown({
    Text = "Aim Part",
    Values = { "Head", "UpperTorso", "HumanoidRootPart" },
    Default = Config.Aimbot.AimPart,
    Callback = function(v)
        Config.Aimbot.AimPart = v
        SaveConfig()
    end,
})

-- Triggerbot Group (Right)
local TriggerGroup = Combat:AddRightGroupbox("Triggerbot")
TriggerGroup:AddToggle({
    Text = "Enable Triggerbot",
    Default = Config.Triggerbot.Enabled,
    Callback = function(v)
        Config.Triggerbot.Enabled = v
        SaveConfig()
    end,
})
TriggerGroup:AddKeyPicker({
    Text = "Trigger Key",
    Default = "LeftControl",
    Mode = "Hold",
    Callback = function(k)
        Config.Triggerbot.Keybind = k
        SaveConfig()
    end,
})
TriggerGroup:AddDropdown({
    Text = "Target Part",
    Values = { "Head", "UpperTorso", "HumanoidRootPart" },
    Default = Config.Triggerbot.AimPart,
    Callback = function(v)
        Config.Triggerbot.AimPart = v
        SaveConfig()
    end,
})
TriggerGroup:AddSlider({
    Text = "Reaction Time (ms)",
    Default = Config.Triggerbot.ReactionTime * 1000,
    Min = 10,
    Max = 500,
    Callback = function(v)
        Config.Triggerbot.ReactionTime = v / 1000
        SaveConfig()
    end,
})

-- Ragebot Group (Left)
local RageGroup = Combat:AddLeftGroupbox("Ragebot")
RageGroup:AddToggle({
    Text = "Enable Ragebot",
    Default = Config.Ragebot.Enabled,
    Callback = function(v)
        Config.Ragebot.Enabled = v
        SaveConfig()
    end,
})

-- Orbit Group (Right)
local OrbitGroup = Combat:AddRightGroupbox("Orbit")
OrbitGroup:AddToggle({
    Text = "Enable Orbit",
    Default = Config.Orbit.Enabled,
    Callback = function(v)
        Config.Orbit.Enabled = v
        if v then
            StartOrbit()
        end
        SaveConfig()
    end,
})
OrbitGroup:AddSlider({
    Text = "Speed",
    Default = Config.Orbit.Speed,
    Min = 0.5,
    Max = 5,
    Callback = function(v)
        Config.Orbit.Speed = v
        SaveConfig()
    end,
})
OrbitGroup:AddSlider({
    Text = "Radius",
    Default = Config.Orbit.Radius,
    Min = 5,
    Max = 50,
    Callback = function(v)
        Config.Orbit.Radius = v
        SaveConfig()
    end,
})
OrbitGroup:AddSlider({
    Text = "Height",
    Default = Config.Orbit.Height,
    Min = -10,
    Max = 20,
    Callback = function(v)
        Config.Orbit.Height = v
        SaveConfig()
    end,
})

-- Voidspam Group (Left)
local VoidGroup = Combat:AddLeftGroupbox("Voidspam")
VoidGroup:AddToggle({
    Text = "Enable Voidspam",
    Default = Config.Voidspam.Enabled,
    Callback = function(v)
        Config.Voidspam.Enabled = v
        if v then
            StartVoidspam()
        end
        SaveConfig()
    end,
})
VoidGroup:AddSlider({
    Text = "Speed (Hz)",
    Default = Config.Voidspam.Speed,
    Min = 0.1,
    Max = 2,
    Callback = function(v)
        Config.Voidspam.Speed = v
        SaveConfig()
    end,
})

-- ESP Tab
local ESPTab = Window:AddTab("ESP")
local ESPGroup = ESPTab:AddLeftGroupbox("ESP Settings")
ESPGroup:AddToggle({
    Text = "Enable ESP",
    Default = Config.ESP.Enabled,
    Callback = function(v)
        Config.ESP.Enabled = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Box ESP",
    Default = Config.ESP.Boxes,
    Callback = function(v)
        Config.ESP.Boxes = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Skeleton ESP",
    Default = Config.ESP.Skeleton,
    Callback = function(v)
        Config.ESP.Skeleton = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Names",
    Default = Config.ESP.Names,
    Callback = function(v)
        Config.ESP.Names = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Health Bars",
    Default = Config.ESP.Health,
    Callback = function(v)
        Config.ESP.Health = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Distance",
    Default = Config.ESP.Distance,
    Callback = function(v)
        Config.ESP.Distance = v
        SaveConfig()
    end,
})
ESPGroup:AddToggle({
    Text = "Team Colors",
    Default = Config.ESP.TeamColor,
    Callback = function(v)
        Config.ESP.TeamColor = v
        SaveConfig()
    end,
})
ESPGroup:AddSlider({
    Text = "Max Distance",
    Default = Config.ESP.MaxDistance,
    Min = 100,
    Max = 1000,
    Callback = function(v)
        Config.ESP.MaxDistance = v
        SaveConfig()
    end,
})

-- Misc Tab
local MiscTab = Window:AddTab("Misc")
local MoveGroup = MiscTab:AddLeftGroupbox("Movement")
MoveGroup:AddSlider({
    Text = "Walk Speed",
    Default = Config.Movement.Speed,
    Min = 16,
    Max = 200,
    Callback = function(v)
        Config.Movement.Speed = v
        SaveConfig()
    end,
})
MoveGroup:AddToggle({
    Text = "Flight",
    Default = Config.Movement.Flight,
    Callback = function(v)
        Config.Movement.Flight = v
        if v then
            StartFlight()
        end
        SaveConfig()
    end,
})
MoveGroup:AddSlider({
    Text = "Fly Speed",
    Default = Config.Movement.FlySpeed,
    Min = 10,
    Max = 200,
    Callback = function(v)
        Config.Movement.FlySpeed = v
        SaveConfig()
    end,
})

local SettingsGroup = MiscTab:AddRightGroupbox("Settings")
SettingsGroup:AddDropdown({
    Text = "Config",
    Values = GetConfigNames(),
    Default = "Default",
    Callback = function(v)
        Config.Settings.ConfigName = v
        SaveConfig()
    end,
})
SettingsGroup:AddButton({
    Text = "Save Config",
    Func = function()
        SaveConfig(Config.Settings.ConfigName)
    end,
})
SettingsGroup:AddButton({
    Text = "Load Config",
    Func = function()
        LoadConfig(Config.Settings.ConfigName)
    end,
})
SettingsGroup:AddButton({
    Text = "Delete Config",
    Func = function()
        if Config.Settings.ConfigName ~= "Default" then
            getgenv().NexoConfigs[Config.Settings.ConfigName] = nil
            Library:Notify("Config deleted!", 2)
        else
            Library:Notify("Cannot delete Default!", 2)
        end
    end,
})
SettingsGroup:AddToggle({
    Text = "Auto-Load",
    Default = Config.Settings.AutoLoad,
    Callback = function(v)
        Config.Settings.AutoLoad = v
        SaveConfig()
    end,
})

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

    if Config.Aimbot.Enabled and UserInputService:IsKeyDown(Config.Aimbot.Keybind) then
        local targets = GetTargets()
        if #targets > 0 then
            AimAt(targets[1])
        end
    end

    if Config.Ragebot.Enabled then
        Ragebot()
    end
    if Config.Triggerbot.Enabled and UserInputService:IsKeyDown(Config.Triggerbot.Keybind) then
        Triggerbot()
    end
    UpdateESP()
end)

-- ============================================================
-- INITIALIZATION
-- ============================================================
if Config.Settings.AutoLoad then
    LoadConfig("Default")
end

StartOrbit()
StartVoidspam()
StartSpeed()
StartFlight()

Library:Notify("Nexo loaded! Press RightShift to open menu.", 3)

-- ============================================================
-- UNLOAD HANDLER
-- ============================================================
Library.OnUnload = function()
    if voidTask then
        voidTask:Disconnect()
    end
    if orbitTask then
        orbitTask:Disconnect()
    end
    if speedTask then
        speedTask:Disconnect()
    end
    if flyTask then
        flyTask:Disconnect()
    end
    FOVCircle:Remove()
    for _, objs in pairs(EspObjects) do
        for _, o in pairs(objs) do
            if o then
                pcall(o.Remove, o)
            end
        end
    end
    ScreenGui:Destroy()
end

-- ============================================================
-- END OF SCRIPT
-- ============================================================
