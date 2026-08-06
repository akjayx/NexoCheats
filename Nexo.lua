-- Rivals Full Suite
-- UI: Obsidian Theme
-- Features: Aimbot, ESP, Silent Aim, VoidSpam, Character Offset, Orbit

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ─── Obsidian UI Library ──────────────────────────────────────────────────────
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()

local Window = OrionLib:MakeWindow({
    Name = "Rivals Suite",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "RivalsSuite"
})

-- ─── Config ───────────────────────────────────────────────────────────────────
local Config = {
    -- Aimbot
    AimbotEnabled    = false,
    AimbotFOV        = 150,
    AimbotSmoothing  = 0.12,
    AimbotHitpart    = "Head",
    AimbotTeamCheck  = true,
    AimbotVisCheck   = false,
    AimbotKey        = Enum.UserInputKey.MouseButton2,

    -- ESP
    ESPEnabled       = false,
    ESPBoxes         = true,
    ESPNames         = true,
    ESPDistance      = true,
    ESPHealthBar     = true,
    ESPMaxDist       = 1000,
    ESPBoxColor      = Color3.fromRGB(255, 80, 80),
    ESPNameColor     = Color3.fromRGB(255, 255, 255),

    -- Silent Aim
    SilentEnabled    = false,
    SilentHitpart    = "Head",
    SilentFOV        = 200,

    -- VoidSpam
    VoidEnabled      = false,
    VoidKey          = Enum.KeyCode.V,
    VoidSpeed        = 0.05,

    -- Character Offset
    OffsetEnabled    = false,
    OffsetX          = 0,
    OffsetY          = 0,
    OffsetZ          = 0,

    -- Orbit
    OrbitEnabled     = false,
    OrbitRadius      = 8,
    OrbitSpeed       = 2,
    OrbitTarget      = nil,
}

-- ─── Utility ──────────────────────────────────────────────────────────────────
local function GetClosestPlayer(fov)
    local closest, closestDist = nil, fov
    local mousePos = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Config.AimbotTeamCheck and plr.Team == LocalPlayer.Team then continue end
        if not plr.Character then continue end

        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        if Config.AimbotVisCheck then
            local ray = Ray.new(Camera.CFrame.Position, (hrp.Position - Camera.CFrame.Position).Unit * 1000)
            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Workspace.Terrain})
            if hit and not hit:IsDescendantOf(plr.Character) then continue end
        end

        local target = plr.Character:FindFirstChild(Config.AimbotHitpart) or hrp
        local screenPos, onScreen = Camera:WorldToScreenPoint(target.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closest = plr
            closestDist = dist
        end
    end

    return closest
end

local function GetClosestPlayerSilent(fov)
    local closest, closestDist = nil, fov
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not plr.Character then continue end

        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        local target = plr.Character:FindFirstChild(Config.SilentHitpart) or hrp
        local screenPos, onScreen = Camera:WorldToScreenPoint(target.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closest = plr
            closestDist = dist
        end
    end

    return closest
end

-- ─── ESP Drawing Cache ────────────────────────────────────────────────────────
local ESPCache = {}

local function CreateESP(plr)
    local drawings = {}

    drawings.Box = Drawing.new("Square")
    drawings.Box.Visible = false
    drawings.Box.Color = Config.ESPBoxColor
    drawings.Box.Thickness = 1.5
    drawings.Box.Filled = false

    drawings.Name = Drawing.new("Text")
    drawings.Name.Visible = false
    drawings.Name.Color = Config.ESPNameColor
    drawings.Name.Size = 14
    drawings.Name.Outline = true
    drawings.Name.Center = true
    drawings.Name.Font = 2

    drawings.Dist = Drawing.new("Text")
    drawings.Dist.Visible = false
    drawings.Dist.Color = Color3.fromRGB(200, 200, 200)
    drawings.Dist.Size = 12
    drawings.Dist.Outline = true
    drawings.Dist.Center = true
    drawings.Dist.Font = 2

    drawings.HealthBG = Drawing.new("Square")
    drawings.HealthBG.Visible = false
    drawings.HealthBG.Color = Color3.fromRGB(30, 30, 30)
    drawings.HealthBG.Thickness = 1
    drawings.HealthBG.Filled = true

    drawings.HealthBar = Drawing.new("Square")
    drawings.HealthBar.Visible = false
    drawings.HealthBar.Color = Color3.fromRGB(60, 220, 80)
    drawings.HealthBar.Thickness = 1
    drawings.HealthBar.Filled = true

    ESPCache[plr] = drawings
end

local function RemoveESP(plr)
    if ESPCache[plr] then
        for _, d in pairs(ESPCache[plr]) do d:Remove() end
        ESPCache[plr] = nil
    end
end

local function UpdateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not ESPCache[plr] then CreateESP(plr) end

        local d = ESPCache[plr]
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not Config.ESPEnabled or not char or not hrp or not hum or hum.Health <= 0 then
            for _, drawing in pairs(d) do drawing.Visible = false end
            continue
        end

        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist > Config.ESPMaxDist then
            for _, drawing in pairs(d) do drawing.Visible = false end
            continue
        end

        local rootScreen, rootVis = Camera:WorldToScreenPoint(hrp.Position)
        local headScreen, headVis = Camera:WorldToScreenPoint((head or hrp).Position + Vector3.new(0, 0.5, 0))

        if not rootVis or not headVis then
            for _, drawing in pairs(d) do drawing.Visible = false end
            continue
        end

        local height = math.abs(headScreen.Y - rootScreen.Y) * 2.2
        local width = height * 0.55
        local x = rootScreen.X - width / 2
        local y = headScreen.Y - (height * 0.05)

        -- Box
        d.Box.Visible = Config.ESPBoxes
        d.Box.Size = Vector2.new(width, height)
        d.Box.Position = Vector2.new(x, y)

        -- Name
        d.Name.Visible = Config.ESPNames
        d.Name.Text = plr.Name
        d.Name.Position = Vector2.new(rootScreen.X, y - 16)

        -- Distance
        d.Dist.Visible = Config.ESPDistance
        d.Dist.Text = string.format("[%d]", math.floor(dist))
        d.Dist.Position = Vector2.new(rootScreen.X, y + height + 2)

        -- Health bar
        local barW = 4
        local barH = height
        local barX = x - barW - 3
        local barY = y
        local hpFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

        d.HealthBG.Visible = Config.ESPHealthBar
        d.HealthBG.Size = Vector2.new(barW, barH)
        d.HealthBG.Position = Vector2.new(barX, barY)

        d.HealthBar.Visible = Config.ESPHealthBar
        d.HealthBar.Size = Vector2.new(barW, barH * hpFrac)
        d.HealthBar.Position = Vector2.new(barX, barY + barH * (1 - hpFrac))
        d.HealthBar.Color = Color3.fromRGB(
            math.floor(255 * (1 - hpFrac)),
            math.floor(255 * hpFrac),
            0
        )
    end
end

Players.PlayerRemoving:Connect(RemoveESP)

-- ─── Aimbot ───────────────────────────────────────────────────────────────────
local AimbotCon
RunService.Heartbeat:Connect(function()
    if not Config.AimbotEnabled then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then return end

    local target = GetClosestPlayer(Config.AimbotFOV)
    if not target or not target.Character then return end

    local hitpart = target.Character:FindFirstChild(Config.AimbotHitpart)
        or target.Character:FindFirstChild("HumanoidRootPart")
    if not hitpart then return end

    local targetCF = CFrame.new(Camera.CFrame.Position, hitpart.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.AimbotSmoothing)
end)

-- ─── Silent Aim ───────────────────────────────────────────────────────────────
local SilentMT = getrawmetatable(game)
local OldNamecall = SilentMT.__namecall
setreadonly(SilentMT, false)

SilentMT.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if Config.SilentEnabled and method == "FireServer" then
        local args = {...}
        local target = GetClosestPlayerSilent(Config.SilentFOV)
        if target and target.Character then
            local hitpart = target.Character:FindFirstChild(Config.SilentHitpart)
                or target.Character:FindFirstChild("HumanoidRootPart")
            if hitpart then
                for i, v in pairs(args) do
                    if typeof(v) == "Instance" and v:IsA("BasePart")
                        and v.Parent and Players:GetPlayerFromCharacter(v.Parent)
                        and Players:GetPlayerFromCharacter(v.Parent) ~= LocalPlayer then
                        args[i] = hitpart
                    end
                end
                return OldNamecall(self, table.unpack(args))
            end
        end
    end
    return OldNamecall(self, ...)
end)

setreadonly(SilentMT, true)

-- ─── VoidSpam ─────────────────────────────────────────────────────────────────
local VoidActive = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.VoidKey then
        VoidActive = not VoidActive
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.VoidEnabled or not VoidActive then return end
    if not LocalPlayer.Character then return end

    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = CFrame.new(
        hrp.Position.X,
        hrp.Position.Y - 100,
        hrp.Position.Z
    )
    task.wait(Config.VoidSpeed)
    hrp.CFrame = CFrame.new(
        hrp.Position.X,
        hrp.Position.Y + 100,
        hrp.Position.Z
    )
end)

-- ─── Character Offset ─────────────────────────────────────────────────────────
local OffsetCon
RunService.Heartbeat:Connect(function()
    if not Config.OffsetEnabled then return end
    if not LocalPlayer.Character then return end

    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = hrp.CFrame * CFrame.new(
        Config.OffsetX,
        Config.OffsetY,
        Config.OffsetZ
    )
end)

-- ─── Orbit ────────────────────────────────────────────────────────────────────
local OrbitAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if not Config.OrbitEnabled or not Config.OrbitTarget then return end
    if not LocalPlayer.Character then return end

    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local target = Config.OrbitTarget
    if not target.Character then return end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    OrbitAngle = OrbitAngle + Config.OrbitSpeed * dt
    local x = targetHRP.Position.X + Config.OrbitRadius * math.cos(OrbitAngle)
    local z = targetHRP.Position.Z + Config.OrbitRadius * math.sin(OrbitAngle)
    hrp.CFrame = CFrame.new(x, targetHRP.Position.Y, z)
end)

-- ─── ESP Update Loop ──────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(UpdateESP)

-- ─── UI Tabs ──────────────────────────────────────────────────────────────────
local AimbotTab  = Window:MakeTab({ Name = "Aimbot",  Icon = "rbxassetid://4483345998", PremiumOnly = false })
local ESPTab     = Window:MakeTab({ Name = "ESP",     Icon = "rbxassetid://4483345998", PremiumOnly = false })
local SilentTab  = Window:MakeTab({ Name = "Silent",  Icon = "rbxassetid://4483345998", PremiumOnly = false })
local MiscTab    = Window:MakeTab({ Name = "Misc",    Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- ── Aimbot Tab ────────────────────────────────────────────────────────────────
local AimbotSection = AimbotTab:AddSection({ Name = "Aimbot" })

AimbotSection:AddToggle({
    Name = "Enable Aimbot",
    Default = false,
    Save = true,
    Flag = "AimbotEnabled",
    Callback = function(v) Config.AimbotEnabled = v end
})

AimbotSection:AddSlider({
    Name = "FOV",
    Min = 10, Max = 500, Default = 150,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "px",
    Save = true, Flag = "AimbotFOV",
    Callback = function(v) Config.AimbotFOV = v end
})

AimbotSection:AddSlider({
    Name = "Smoothing",
    Min = 1, Max = 100, Default = 12,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "%",
    Save = true, Flag = "AimbotSmoothing",
    Callback = function(v) Config.AimbotSmoothing = v / 100 end
})

AimbotSection:AddDropdown({
    Name = "Hitpart",
    Default = "Head",
    Options = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Save = true, Flag = "AimbotHitpart",
    Callback = function(v) Config.AimbotHitpart = v end
})

AimbotSection:AddToggle({
    Name = "Team Check",
    Default = true,
    Save = true, Flag = "AimbotTeamCheck",
    Callback = function(v) Config.AimbotTeamCheck = v end
})

AimbotSection:AddToggle({
    Name = "Visibility Check",
    Default = false,
    Save = true, Flag = "AimbotVisCheck",
    Callback = function(v) Config.AimbotVisCheck = v end
})

-- ── ESP Tab ───────────────────────────────────────────────────────────────────
local ESPSection = ESPTab:AddSection({ Name = "ESP" })

ESPSection:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Save = true, Flag = "ESPEnabled",
    Callback = function(v) Config.ESPEnabled = v end
})

ESPSection:AddToggle({
    Name = "Boxes",
    Default = true,
    Save = true, Flag = "ESPBoxes",
    Callback = function(v) Config.ESPBoxes = v end
})

ESPSection:AddToggle({
    Name = "Names",
    Default = true,
    Save = true, Flag = "ESPNames",
    Callback = function(v) Config.ESPNames = v end
})

ESPSection:AddToggle({
    Name = "Distance",
    Default = true,
    Save = true, Flag = "ESPDistance",
    Callback = function(v) Config.ESPDistance = v end
})

ESPSection:AddToggle({
    Name = "Health Bar",
    Default = true,
    Save = true, Flag = "ESPHealthBar",
    Callback = function(v) Config.ESPHealthBar = v end
})

ESPSection:AddSlider({
    Name = "Max Distance",
    Min = 100, Max = 5000, Default = 1000,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 50, ValueName = "studs",
    Save = true, Flag = "ESPMaxDist",
    Callback = function(v) Config.ESPMaxDist = v end
})

ESPSection:AddColorpicker({
    Name = "Box Color",
    Default = Color3.fromRGB(255, 80, 80),
    Flag = "ESPBoxColor",
    Callback = function(v)
        Config.ESPBoxColor = v
        for _, d in pairs(ESPCache) do
            if d.Box then d.Box.Color = v end
        end
    end
})

-- ── Silent Aim Tab ────────────────────────────────────────────────────────────
local SilentSection = SilentTab:AddSection({ Name = "Silent Aim" })

SilentSection:AddToggle({
    Name = "Enable Silent Aim",
    Default = false,
    Save = true, Flag = "SilentEnabled",
    Callback = function(v) Config.SilentEnabled = v end
})

SilentSection:AddDropdown({
    Name = "Hitpart",
    Default = "Head",
    Options = { "Head", "HumanoidRootPart", "UpperTorso" },
    Save = true, Flag = "SilentHitpart",
    Callback = function(v) Config.SilentHitpart = v end
})

SilentSection:AddSlider({
    Name = "FOV",
    Min = 10, Max = 800, Default = 200,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 10, ValueName = "px",
    Save = true, Flag = "SilentFOV",
    Callback = function(v) Config.SilentFOV = v end
})

-- ── Misc Tab ──────────────────────────────────────────────────────────────────
local VoidSection   = MiscTab:AddSection({ Name = "VoidSpam" })
local OffsetSection = MiscTab:AddSection({ Name = "Character Offset" })
local OrbitSection  = MiscTab:AddSection({ Name = "Orbit" })

-- VoidSpam
VoidSection:AddToggle({
    Name = "Enable VoidSpam",
    Default = false,
    Save = true, Flag = "VoidEnabled",
    Callback = function(v) Config.VoidEnabled = v end
})

VoidSection:AddSlider({
    Name = "Speed",
    Min = 1, Max = 20, Default = 5,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "x0.01s",
    Save = true, Flag = "VoidSpeed",
    Callback = function(v) Config.VoidSpeed = v / 100 end
})

VoidSection:AddLabel("Keybind: V — toggles VoidSpam on/off")

-- Character Offset
OffsetSection:AddToggle({
    Name = "Enable Offset",
    Default = false,
    Save = true, Flag = "OffsetEnabled",
    Callback = function(v) Config.OffsetEnabled = v end
})

OffsetSection:AddSlider({
    Name = "Offset X",
    Min = -20, Max = 20, Default = 0,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "",
    Save = true, Flag = "OffsetX",
    Callback = function(v) Config.OffsetX = v end
})

OffsetSection:AddSlider({
    Name = "Offset Y",
    Min = -20, Max = 20, Default = 0,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "",
    Save = true, Flag = "OffsetY",
    Callback = function(v) Config.OffsetY = v end
})

OffsetSection:AddSlider({
    Name = "Offset Z",
    Min = -20, Max = 20, Default = 0,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "",
    Save = true, Flag = "OffsetZ",
    Callback = function(v) Config.OffsetZ = v end
})

-- Orbit
OrbitSection:AddToggle({
    Name = "Enable Orbit",
    Default = false,
    Save = true, Flag = "OrbitEnabled",
    Callback = function(v) Config.OrbitEnabled = v end
})

OrbitSection:AddSlider({
    Name = "Radius",
    Min = 2, Max = 50, Default = 8,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "studs",
    Save = true, Flag = "OrbitRadius",
    Callback = function(v) Config.OrbitRadius = v end
})

OrbitSection:AddSlider({
    Name = "Speed",
    Min = 1, Max = 20, Default = 2,
    Color = Color3.fromRGB(255, 80, 80),
    Increment = 1, ValueName = "rad/s",
    Save = true, Flag = "OrbitSpeed",
    Callback = function(v) Config.OrbitSpeed = v end
})

OrbitSection:AddDropdown({
    Name = "Target Player",
    Default = "Select Target",
    Options = (function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(names, p.Name)
            end
        end
        return names
    end)(),
    Callback = function(v)
        Config.OrbitTarget = Players:FindFirstChild(v)
    end
})

-- ─── Init ─────────────────────────────────────────────────────────────────────
OrionLib:Init()
