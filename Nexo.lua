local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options  = Library.Options
local Toggles  = Library.Toggles

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local Cfg = {
    AimbotSmoothing = 0.12,
    AimbotHitpart   = "Head",
    SilentFOV       = 200,
    SilentHitpart   = "Head",
    VoidSpeed       = 0.05,
    OffsetX = 0, OffsetY = 0, OffsetZ = 0,
    OrbitRadius = 8, OrbitSpeed = 2,
    OrbitTarget = nil,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function GetClosest(fov, centerMode)
    local closest, closestDist = nil, fov
    local ref = centerMode
        and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        or  UserInputService:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(Cfg.AimbotHitpart) or hrp
        local sp, on = Camera:WorldToScreenPoint(part.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
        if d < closestDist then closest, closestDist = p, d end
    end
    return closest
end

-- ── ESP — bounding box from character parts ───────────────────────────────────
local ESPCache = {}

local PARTS = {
    "Head","UpperTorso","LowerTorso","HumanoidRootPart",
    "RightUpperArm","RightLowerArm","RightHand",
    "LeftUpperArm","LeftLowerArm","LeftHand",
    "RightUpperLeg","RightLowerLeg","RightFoot",
    "LeftUpperLeg","LeftLowerLeg","LeftFoot",
}

local function GetCharacterScreenBounds(char)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false

    for _, name in ipairs(PARTS) do
        local part = char:FindFirstChild(name)
        if not part then continue end
        -- sample 8 corners of the part's bounding box
        local cf   = part.CFrame
        local size = part.Size / 2
        for _, offset in ipairs({
            Vector3.new( size.X,  size.Y,  size.Z),
            Vector3.new(-size.X,  size.Y,  size.Z),
            Vector3.new( size.X, -size.Y,  size.Z),
            Vector3.new(-size.X, -size.Y,  size.Z),
            Vector3.new( size.X,  size.Y, -size.Z),
            Vector3.new(-size.X,  size.Y, -size.Z),
            Vector3.new( size.X, -size.Y, -size.Z),
            Vector3.new(-size.X, -size.Y, -size.Z),
        }) do
            local worldPos = cf:PointToWorldSpace(offset)
            local sp, onScreen = Camera:WorldToScreenPoint(worldPos)
            if onScreen then
                visible = true
                if sp.X < minX then minX = sp.X end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end
    end

    if not visible then return nil end
    return minX, minY, maxX, maxY
end

local function MakeESP(p)
    local d = {}
    d.Box  = Drawing.new("Square")
    d.Box.Visible = false; d.Box.Thickness = 1.5; d.Box.Filled = false
    d.Box.Color   = Color3.fromRGB(255, 80, 80)

    d.Name = Drawing.new("Text")
    d.Name.Visible = false; d.Name.Size = 13; d.Name.Outline = true
    d.Name.Center  = true;  d.Name.Font = 2
    d.Name.Color   = Color3.fromRGB(255, 255, 255)

    d.Dist = Drawing.new("Text")
    d.Dist.Visible = false; d.Dist.Size = 12; d.Dist.Outline = true
    d.Dist.Center  = true;  d.Dist.Font = 2
    d.Dist.Color   = Color3.fromRGB(200, 200, 200)

    d.HBG  = Drawing.new("Square")
    d.HBG.Visible = false; d.HBG.Filled = true
    d.HBG.Color   = Color3.fromRGB(20, 20, 20)

    d.HBar = Drawing.new("Square")
    d.HBar.Visible = false; d.HBar.Filled = true
    d.HBar.Color   = Color3.fromRGB(60, 220, 80)

    ESPCache[p] = d
end

Players.PlayerRemoving:Connect(function(p)
    if ESPCache[p] then
        for _, v in pairs(ESPCache[p]) do v:Remove() end
        ESPCache[p] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if not Toggles.ESPEnabled or not Toggles.ESPEnabled.Value then
        for _, d in pairs(ESPCache) do for _, v in pairs(d) do v.Visible = false end end
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not ESPCache[p] then MakeESP(p) end
        local d    = ESPCache[p]
        local char = p.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hrp or not hum or hum.Health <= 0 then
            for _, v in pairs(d) do v.Visible = false end; continue
        end

        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        local maxDist = Options.ESPMaxDist and Options.ESPMaxDist.Value or 1000
        if dist > maxDist then
            for _, v in pairs(d) do v.Visible = false end; continue
        end

        local minX, minY, maxX, maxY = GetCharacterScreenBounds(char)
        if not minX then
            for _, v in pairs(d) do v.Visible = false end; continue
        end

        local pad = 2
        local bx = minX - pad
        local by = minY - pad
        local bw = (maxX - minX) + pad * 2
        local bh = (maxY - minY) + pad * 2
        local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

        -- Box
        d.Box.Visible   = Toggles.ESPBoxes and Toggles.ESPBoxes.Value or false
        d.Box.Position  = Vector2.new(bx, by)
        d.Box.Size      = Vector2.new(bw, bh)

        -- Name
        d.Name.Visible  = Toggles.ESPNames and Toggles.ESPNames.Value or false
        d.Name.Text     = p.Name
        d.Name.Position = Vector2.new(bx + bw / 2, by - 15)

        -- Distance
        d.Dist.Visible  = Toggles.ESPDist and Toggles.ESPDist.Value or false
        d.Dist.Text     = "[" .. math.floor(dist) .. "]"
        d.Dist.Position = Vector2.new(bx + bw / 2, by + bh + 2)

        -- Health bar (left side, vertical)
        local barW = 3
        local barX = bx - barW - 2
        d.HBG.Visible   = Toggles.ESPHealth and Toggles.ESPHealth.Value or false
        d.HBG.Position  = Vector2.new(barX, by)
        d.HBG.Size      = Vector2.new(barW, bh)

        d.HBar.Visible  = Toggles.ESPHealth and Toggles.ESPHealth.Value or false
        d.HBar.Position = Vector2.new(barX, by + bh * (1 - hp))
        d.HBar.Size     = Vector2.new(barW, bh * hp)
        d.HBar.Color    = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(255*hp), 0)
    end
end)

-- ── Aimbot ────────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not Toggles.AimbotEnabled or not Toggles.AimbotEnabled.Value then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then return end
    local t = GetClosest(Options.AimbotFOV and Options.AimbotFOV.Value or 150, false)
    if not t or not t.Character then return end
    local part = t.Character:FindFirstChild(Cfg.AimbotHitpart)
        or t.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.new(Camera.CFrame.Position, part.Position),
        Cfg.AimbotSmoothing
    )
end)

-- ── Silent Aim ────────────────────────────────────────────────────────────────
local mt  = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if (Toggles.SilentEnabled and Toggles.SilentEnabled.Value) and method == "FireServer" then
        local args = {...}
        local t = GetClosest(Cfg.SilentFOV, true)
        if t and t.Character then
            local part = t.Character:FindFirstChild(Cfg.SilentHitpart)
                or t.Character:FindFirstChild("HumanoidRootPart")
            if part then
                for i, v in pairs(args) do
                    if typeof(v) == "Instance" and v:IsA("BasePart") and v.Parent then
                        local owner = Players:GetPlayerFromCharacter(v.Parent)
                        if owner and owner ~= LocalPlayer then
                            args[i] = part
                        end
                    end
                end
                return old(self, table.unpack(args))
            end
        end
    end
    return old(self, ...)
end)
setreadonly(mt, true)

-- ── VoidSpam ──────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not Toggles.VoidEnabled or not Toggles.VoidEnabled.Value then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 100, hrp.Position.Z)
    task.wait(Cfg.VoidSpeed)
    hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y + 100, hrp.Position.Z)
end)

-- ── Character Offset ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not Toggles.OffsetEnabled or not Toggles.OffsetEnabled.Value then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = hrp.CFrame * CFrame.new(Cfg.OffsetX, Cfg.OffsetY, Cfg.OffsetZ)
end)

-- ── Orbit ─────────────────────────────────────────────────────────────────────
local orbitAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if not Toggles.OrbitEnabled or not Toggles.OrbitEnabled.Value then return end
    if not Cfg.OrbitTarget then return end
    local hrp  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local tc   = Cfg.OrbitTarget.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if not hrp or not thrp then return end
    orbitAngle = orbitAngle + Cfg.OrbitSpeed * dt
    hrp.CFrame = CFrame.new(
        thrp.Position.X + Cfg.OrbitRadius * math.cos(orbitAngle),
        thrp.Position.Y,
        thrp.Position.Z + Cfg.OrbitRadius * math.sin(orbitAngle)
    )
end)

-- ── Window ────────────────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title         = "Nexo",
    Footer        = "v1.0",
    Center        = true,
    AutoShow      = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

-- ── Tabs ──────────────────────────────────────────────────────────────────────
local CombatTab   = Window:AddTab("Combat",   "sword")
local ESPTab      = Window:AddTab("ESP",      "eye")
local SettingsTab = Window:AddTab("Settings", "settings")

-- ── Combat Tab ────────────────────────────────────────────────────────────────
local AimbotGroup = CombatTab:AddLeftGroupbox("Aimbot")
local UtilGroup   = CombatTab:AddRightGroupbox("Utilities")
local OrbitGroup  = CombatTab:AddRightGroupbox("Orbit")

AimbotGroup:AddToggle("AimbotEnabled", {
    Text    = "Enable Aimbot",
    Default = false,
    Tooltip = "Hold RMB to lock on",
})
AimbotGroup:AddSlider("AimbotFOV", {
    Text    = "FOV",
    Default = 150, Min = 10, Max = 500, Rounding = 0,
    Suffix  = "px",
})
AimbotGroup:AddSlider("AimbotSmooth", {
    Text     = "Smoothing",
    Default  = 12, Min = 1, Max = 100, Rounding = 0,
    Suffix   = "%",
    Callback = function(v) Cfg.AimbotSmoothing = v / 100 end,
})
AimbotGroup:AddDropdown("AimbotHitpart", {
    Text     = "Hitpart",
    Default  = "Head",
    Values   = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Callback = function(v) Cfg.AimbotHitpart = v end,
})
AimbotGroup:AddToggle("AimbotTeamCheck", { Text = "Team Check",       Default = true  })
AimbotGroup:AddToggle("AimbotVisCheck",  { Text = "Visibility Check", Default = false })

local SilentGroup = CombatTab:AddLeftGroupbox("Silent Aim")
SilentGroup:AddToggle("SilentEnabled", { Text = "Enable Silent Aim", Default = false })
SilentGroup:AddDropdown("SilentHitpart", {
    Text     = "Hitpart",
    Default  = "Head",
    Values   = {"Head", "HumanoidRootPart", "UpperTorso"},
    Callback = function(v) Cfg.SilentHitpart = v end,
})
SilentGroup:AddSlider("SilentFOV", {
    Text     = "FOV",
    Default  = 200, Min = 10, Max = 800, Rounding = 0,
    Suffix   = "px",
    Callback = function(v) Cfg.SilentFOV = v end,
})

UtilGroup:AddToggle("VoidEnabled", { Text = "VoidSpam", Default = false })
UtilGroup:AddSlider("VoidSpeed", {
    Text     = "Void Speed",
    Default  = 5, Min = 1, Max = 20, Rounding = 0,
    Suffix   = "x0.01s",
    Callback = function(v) Cfg.VoidSpeed = v / 100 end,
})
UtilGroup:AddToggle("OffsetEnabled", { Text = "Character Offset", Default = false })
UtilGroup:AddSlider("OffsetX", { Text = "Offset X", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetX = v end })
UtilGroup:AddSlider("OffsetY", { Text = "Offset Y", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetY = v end })
UtilGroup:AddSlider("OffsetZ", { Text = "Offset Z", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetZ = v end })

OrbitGroup:AddToggle("OrbitEnabled", { Text = "Enable Orbit", Default = false })
OrbitGroup:AddSlider("OrbitRadius", {
    Text = "Radius", Default = 8, Min = 2, Max = 50, Rounding = 0,
    Suffix = " studs",
    Callback = function(v) Cfg.OrbitRadius = v end,
})
OrbitGroup:AddSlider("OrbitSpeed", {
    Text = "Speed", Default = 2, Min = 1, Max = 20, Rounding = 0,
    Suffix = " rad/s",
    Callback = function(v) Cfg.OrbitSpeed = v end,
})
OrbitGroup:AddDropdown("OrbitTarget", {
    Text    = "Target Player",
    Default = "None",
    Values  = (function()
        local names = {"None"}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        return names
    end)(),
    Callback = function(v)
        Cfg.OrbitTarget = v ~= "None" and Players:FindFirstChild(v) or nil
    end,
})

-- ── ESP Tab ───────────────────────────────────────────────────────────────────
local EL = ESPTab:AddLeftGroupbox("ESP")
local ER = ESPTab:AddRightGroupbox("Options")

EL:AddToggle("ESPEnabled", { Text = "Enable ESP",  Default = false })
EL:AddToggle("ESPBoxes",   { Text = "Boxes",       Default = true  })
EL:AddToggle("ESPNames",   { Text = "Names",       Default = true  })
EL:AddToggle("ESPDist",    { Text = "Distance",    Default = true  })
EL:AddToggle("ESPHealth",  { Text = "Health Bar",  Default = true  })
ER:AddSlider("ESPMaxDist", {
    Text    = "Max Distance",
    Default = 1000, Min = 100, Max = 5000, Rounding = 0,
    Suffix  = " studs",
})

-- ── Settings Tab ──────────────────────────────────────────────────────────────
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("Nexo")
SaveManager:BuildConfigSection(SettingsTab)

ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(SettingsTab)

-- ── Cleanup ───────────────────────────────────────────────────────────────────
Library:OnUnload(function()
    for _, d in pairs(ESPCache) do for _, v in pairs(d) do v:Remove() end end
    setreadonly(mt, false)
    mt.__namecall = old
    setreadonly(mt, true)
end)

SaveManager:LoadAutoloadConfig()
