-- ══════════════════════════════════════════════════════════════════════════════
-- nexo.gg  |  v2.2  |  Skinchanger removed, ESP corner-anchored
-- ══════════════════════════════════════════════════════════════════════════════
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
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
    AimbotTeamCheck = true,
    AimbotVisCheck  = false,
    SilentFOV       = 200,
    SilentHitpart   = "Head",
    FlightSpeed     = 60,
    SpeedMultiplier = 2,
    OffsetX = 0, OffsetY = 0, OffsetZ = 0,
    OrbitRadius = 8, OrbitSpeed = 2,
    OrbitTarget = nil,
    VoidSpeed   = 0.05,
}

-- ── Utilities ─────────────────────────────────────────────────────────────────
local function GetHRP(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(p)
    local hum = GetHum(p)
    return hum and hum.Health > 0
end

local function SameTeam(p)
    if not Cfg.AimbotTeamCheck then return false end
    return p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team
end

-- ── Visibility raycast ────────────────────────────────────────────────────────
local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(targetPart)
    local char = LocalPlayer.Character
    if not char then return true end
    RAY_PARAMS.FilterDescendantsInstances = { char }
    local origin = Camera.CFrame.Position
    local dir    = targetPart.Position - origin
    local result = workspace:Raycast(origin, dir, RAY_PARAMS)
    if not result then return true end
    return result.Instance and result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ── Target acquisition ────────────────────────────────────────────────────────
local function GetClosest(fov, centerMode, hitpart)
    local closest, closestDist = nil, fov
    local vp  = Camera.ViewportSize
    local ref = centerMode
        and Vector2.new(vp.X * 0.5, vp.Y * 0.5)
        or  UserInputService:GetMouseLocation()

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer   then continue end
        if SameTeam(p)        then continue end
        if not IsAlive(p)     then continue end
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local part = char:FindFirstChild(hitpart or Cfg.AimbotHitpart) or hrp
        if Cfg.AimbotVisCheck and not IsVisible(part) then continue end
        local sp, onscreen = Camera:WorldToScreenPoint(part.Position)
        if not onscreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
        if d < closestDist then closest, closestDist = p, d end
    end
    return closest
end

-- ── ESP ───────────────────────────────────────────────────────────────────────
-- Box derived from 8 world-space corners of the character bounding volume.
-- Projects all corners, takes min/max X and Y — accurate at any camera angle.
-- GUI inset compensation: subtract the top inset so Drawing coords align
-- with what WorldToScreenPoint returns on this executor.

local INSET = game:GetService("GuiService"):GetGuiInset()
local INSET_Y = INSET.Y  -- typically 36px on Roblox default

local ESPCache = {}

local function MakeESP(p)
    local d = {}

    d.Box             = Drawing.new("Square")
    d.Box.Filled      = false
    d.Box.Thickness   = 1.5
    d.Box.Color       = Color3.fromRGB(255, 60, 60)
    d.Box.Visible     = false

    d.BoxOutline          = Drawing.new("Square")
    d.BoxOutline.Filled   = false
    d.BoxOutline.Thickness = 3
    d.BoxOutline.Color    = Color3.fromRGB(0, 0, 0)
    d.BoxOutline.Visible  = false

    d.Name         = Drawing.new("Text")
    d.Name.Size    = 13
    d.Name.Center  = true
    d.Name.Outline = true
    d.Name.Font    = 2
    d.Name.Color   = Color3.fromRGB(255, 255, 255)
    d.Name.Visible = false

    d.Dist         = Drawing.new("Text")
    d.Dist.Size    = 11
    d.Dist.Center  = true
    d.Dist.Outline = true
    d.Dist.Font    = 2
    d.Dist.Color   = Color3.fromRGB(180, 180, 180)
    d.Dist.Visible = false

    d.HBG         = Drawing.new("Square")
    d.HBG.Filled  = true
    d.HBG.Color   = Color3.fromRGB(15, 15, 15)
    d.HBG.Visible = false

    d.HBar         = Drawing.new("Square")
    d.HBar.Filled  = true
    d.HBar.Color   = Color3.fromRGB(60, 220, 80)
    d.HBar.Visible = false

    d.Lines = {}
    for i = 1, 5 do
        local l     = Drawing.new("Line")
        l.Thickness = 1
        l.Color     = Color3.fromRGB(255, 60, 60)
        l.Visible   = false
        d.Lines[i]  = l
    end

    ESPCache[p] = d
end

local function RemoveESP(p)
    local d = ESPCache[p]
    if not d then return end
    for _, v in pairs(d) do
        if typeof(v) == "table" then
            for _, l in pairs(v) do pcall(function() l:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
    ESPCache[p] = nil
end

Players.PlayerRemoving:Connect(RemoveESP)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then MakeESP(p) end
end

-- Project 8 world-space corners of [center ± halfSize] through camera.
-- Returns minX, minY, maxX, maxY in screen space, or nil if all offscreen.
local function GetCornerBounds(center, halfW, halfH)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVis = false

    for _, sx in ipairs({ -halfW, halfW }) do
        for _, sy in ipairs({ -halfH, halfH }) do
            for _, sz in ipairs({ -halfW, halfW }) do
                local world = center + Vector3.new(sx, sy, sz)
                local sp, vis = Camera:WorldToScreenPoint(world)
                if vis then
                    anyVis = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end

    if not anyVis then return nil end
    return minX, minY, maxX, maxY
end

local BONE_PAIRS = {
    { "Head",      "UpperTorso"       },
    { "LeftHand",  "HumanoidRootPart" },
    { "RightHand", "HumanoidRootPart" },
    { "LeftFoot",  "HumanoidRootPart" },
    { "RightFoot", "HumanoidRootPart" },
}

local function HideAll(d)
    d.Box.Visible        = false
    d.BoxOutline.Visible = false
    d.Name.Visible       = false
    d.Dist.Visible       = false
    d.HBG.Visible        = false
    d.HBar.Visible       = false
    for _, l in pairs(d.Lines) do l.Visible = false end
end

RunService.RenderStepped:Connect(function()
    local espOn = Toggles.ESPEnabled and Toggles.ESPEnabled.Value
    if not espOn then
        for _, d in pairs(ESPCache) do HideAll(d) end
        return
    end

    local maxDist    = Options.ESPMaxDist  and Options.ESPMaxDist.Value  or 1000
    local showBoxes  = Toggles.ESPBoxes    and Toggles.ESPBoxes.Value
    local showNames  = Toggles.ESPNames    and Toggles.ESPNames.Value
    local showDist   = Toggles.ESPDist     and Toggles.ESPDist.Value
    local showHealth = Toggles.ESPHealth   and Toggles.ESPHealth.Value
    local showSkel   = Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not ESPCache[p] then MakeESP(p) end

        local d    = ESPCache[p]
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")

        if not char or not hrp or not hum or not head or hum.Health <= 0 then
            HideAll(d); continue
        end

        local camPos = Camera.CFrame.Position
        local dist   = (hrp.Position - camPos).Magnitude
        if dist > maxDist then HideAll(d); continue end

        -- Bounding volume: center between head top and foot bottom
        local topY    = head.Position.Y + head.Size.Y * 0.5 + 0.2
        local botY    = hrp.Position.Y  - hum.HipHeight - 0.1
        local centerY = (topY + botY) * 0.5
        local halfH   = (topY - botY) * 0.5
        local halfW   = 1.2   -- character shoulder half-width in studs

        local bCenter = Vector3.new(hrp.Position.X, centerY, hrp.Position.Z)
        local minX, minY, maxX, maxY = GetCornerBounds(bCenter, halfW, halfH)

        if not minX then HideAll(d); continue end

        -- Apply GUI inset correction so Drawing aligns with viewport
        minY = minY - INSET_Y
        maxY = maxY - INSET_Y

        local bx = minX
        local by = minY
        local bw = maxX - minX
        local bh = maxY - minY

        if bh < 4 or bw < 2 then HideAll(d); continue end

        local hp   = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        local midX = bx + bw * 0.5

        d.BoxOutline.Visible  = showBoxes
        d.BoxOutline.Position = Vector2.new(bx - 1, by - 1)
        d.BoxOutline.Size     = Vector2.new(bw + 2, bh + 2)

        d.Box.Visible         = showBoxes
        d.Box.Position        = Vector2.new(bx, by)
        d.Box.Size            = Vector2.new(bw, bh)

        d.Name.Visible        = showNames
        d.Name.Text           = p.Name
        d.Name.Position       = Vector2.new(midX, by - 16)

        d.Dist.Visible        = showDist
        d.Dist.Text           = math.floor(dist) .. "m"
        d.Dist.Position       = Vector2.new(midX, by + bh + 2)

        local barW = 3
        local barX = bx - barW - 2
        d.HBG.Visible         = showHealth
        d.HBG.Position        = Vector2.new(barX, by)
        d.HBG.Size            = Vector2.new(barW, bh)

        d.HBar.Visible        = showHealth
        d.HBar.Position       = Vector2.new(barX, by + bh * (1 - hp))
        d.HBar.Size           = Vector2.new(barW, bh * hp)
        d.HBar.Color          = Color3.fromRGB(
            math.floor(255 * (1 - hp)),
            math.floor(255 * hp),
            0
        )

        for i, pair in ipairs(BONE_PAIRS) do
            local l     = d.Lines[i]
            local partA = char:FindFirstChild(pair[1])
            local partB = char:FindFirstChild(pair[2])
            if showSkel and partA and partB then
                local spA, visA = Camera:WorldToScreenPoint(partA.Position)
                local spB, visB = Camera:WorldToScreenPoint(partB.Position)
                if visA and visB then
                    l.Visible = true
                    l.From    = Vector2.new(spA.X, spA.Y - INSET_Y)
                    l.To      = Vector2.new(spB.X, spB.Y - INSET_Y)
                else
                    l.Visible = false
                end
            else
                l.Visible = false
            end
        end
    end
end)

-- ── Aimbot ────────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not (Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value) then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local t = GetClosest(Options.AimbotFOV and Options.AimbotFOV.Value or 150, false)
    if not t or not t.Character then return end
    local part = t.Character:FindFirstChild(Cfg.AimbotHitpart)
        or t.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end
    local hrp  = GetHRP(LocalPlayer)
    local dist = hrp and (hrp.Position - part.Position).Magnitude or 100
    local adaptiveFactor = math.clamp(dist / 80, 0.3, 1.0)
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.new(Camera.CFrame.Position, part.Position),
        Cfg.AimbotSmoothing * adaptiveFactor
    )
end)

-- ── Silent Aim ────────────────────────────────────────────────────────────────
local mt  = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if Toggles.SilentEnabled and Toggles.SilentEnabled.Value and method == "FireServer" then
        local args = { ... }
        local t = GetClosest(Cfg.SilentFOV, true, Cfg.SilentHitpart)
        if t and t.Character then
            local targetPart = t.Character:FindFirstChild(Cfg.SilentHitpart)
                or t.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then
                for i, v in pairs(args) do
                    if typeof(v) == "Instance" and v:IsA("BasePart") then
                        local owner = Players:GetPlayerFromCharacter(v.Parent)
                        if owner and owner ~= LocalPlayer then
                            args[i] = targetPart
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

-- ── Flight ────────────────────────────────────────────────────────────────────
local flightBV, flightBG
local wasFlightOn = false

local function EnableFlight()
    local hrp = GetHRP(LocalPlayer)
    if not hrp then return end
    flightBV           = Instance.new("BodyVelocity")
    flightBV.Velocity  = Vector3.zero
    flightBV.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    flightBV.P         = 1e4
    flightBV.Parent    = hrp
    flightBG           = Instance.new("BodyGyro")
    flightBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flightBG.P         = 1e4
    flightBG.D         = 500
    flightBG.CFrame    = hrp.CFrame
    flightBG.Parent    = hrp
    local hum = GetHum(LocalPlayer)
    if hum then hum.PlatformStand = true end
end

local function DisableFlight()
    if flightBV then flightBV:Destroy(); flightBV = nil end
    if flightBG then flightBG:Destroy(); flightBG = nil end
    local hum = GetHum(LocalPlayer)
    if hum then hum.PlatformStand = false end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Toggles.FlightEnabled and Toggles.FlightEnabled.Value then
        EnableFlight()
    end
end)

RunService.Heartbeat:Connect(function()
    local flightOn = Toggles.FlightEnabled and Toggles.FlightEnabled.Value
    if flightOn and not wasFlightOn then
        EnableFlight(); wasFlightOn = true
    elseif not flightOn and wasFlightOn then
        DisableFlight(); wasFlightOn = false
    end
    if flightOn and flightBV then
        local hrp = GetHRP(LocalPlayer)
        if not hrp then return end
        local spd = Cfg.FlightSpeed
        local cf  = Camera.CFrame
        local vel = Vector3.zero
        local uis = UserInputService
        if uis:IsKeyDown(Enum.KeyCode.W)         then vel = vel + cf.LookVector  * spd end
        if uis:IsKeyDown(Enum.KeyCode.S)         then vel = vel - cf.LookVector  * spd end
        if uis:IsKeyDown(Enum.KeyCode.A)         then vel = vel - cf.RightVector * spd end
        if uis:IsKeyDown(Enum.KeyCode.D)         then vel = vel + cf.RightVector * spd end
        if uis:IsKeyDown(Enum.KeyCode.Space)     then vel = vel + Vector3.yAxis  * spd end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.yAxis  * spd end
        flightBV.Velocity = vel
        flightBG.CFrame   = cf
    end
end)

-- ── Speedhack ─────────────────────────────────────────────────────────────────
local originalWalkSpeed = 16
local wasSpeedOn        = false

RunService.Heartbeat:Connect(function()
    local speedOn = Toggles.SpeedEnabled and Toggles.SpeedEnabled.Value
    local hum     = GetHum(LocalPlayer)
    if not hum then wasSpeedOn = false; return end
    if speedOn and not wasSpeedOn then
        originalWalkSpeed = hum.WalkSpeed
        wasSpeedOn = true
    elseif not speedOn and wasSpeedOn then
        hum.WalkSpeed = originalWalkSpeed
        wasSpeedOn = false
    end
    if speedOn then
        hum.WalkSpeed = originalWalkSpeed * Cfg.SpeedMultiplier
    end
end)

-- ── Noclip ────────────────────────────────────────────────────────────────────
local wasNoclipOn = false

local function SetCollision(state)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = state end
    end
end

RunService.Heartbeat:Connect(function()
    local noclipOn = Toggles.NoclipEnabled and Toggles.NoclipEnabled.Value
    if noclipOn then
        SetCollision(false)
        wasNoclipOn = true
    elseif wasNoclipOn then
        SetCollision(true)
        wasNoclipOn = false
    end
end)

-- ── VoidSpam ──────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not (Toggles.VoidEnabled and Toggles.VoidEnabled.Value) then return end
    local hrp = GetHRP(LocalPlayer)
    if not hrp then return end
    hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 100, hrp.Position.Z)
    task.wait(Cfg.VoidSpeed)
    hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y + 100, hrp.Position.Z)
end)

-- ── Character Offset ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not (Toggles.OffsetEnabled and Toggles.OffsetEnabled.Value) then return end
    local hrp = GetHRP(LocalPlayer)
    if not hrp then return end
    hrp.CFrame = hrp.CFrame * CFrame.new(Cfg.OffsetX, Cfg.OffsetY, Cfg.OffsetZ)
end)

-- ── Orbit ─────────────────────────────────────────────────────────────────────
local orbitAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if not (Toggles.OrbitEnabled and Toggles.OrbitEnabled.Value) then return end
    if not Cfg.OrbitTarget then return end
    local hrp  = GetHRP(LocalPlayer)
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
    Title         = "nexo.gg",
    Footer        = "v2.2",
    Center        = true,
    AutoShow      = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

local CombatTab   = Window:AddTab("Combat",   "sword")
local MovementTab = Window:AddTab("Movement", "person-running")
local ESPTab      = Window:AddTab("ESP",      "eye")
local SettingsTab = Window:AddTab("Settings", "settings")

-- ── Combat ────────────────────────────────────────────────────────────────────
local AimbotGroup = CombatTab:AddLeftGroupbox("Aimbot")
local SilentGroup = CombatTab:AddLeftGroupbox("Silent Aim")
local UtilGroup   = CombatTab:AddRightGroupbox("Utilities")
local OrbitGroup  = CombatTab:AddRightGroupbox("Orbit")

AimbotGroup:AddToggle("AimbotEnabled",   { Text = "Enable Aimbot",    Default = false, Tooltip = "Hold RMB" })
AimbotGroup:AddSlider("AimbotFOV",       { Text = "FOV",              Default = 150, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
AimbotGroup:AddSlider("AimbotSmooth",    { Text = "Smoothing",        Default = 12,  Min = 1,  Max = 100, Rounding = 0, Suffix = "%",
    Callback = function(v) Cfg.AimbotSmoothing = v / 100 end })
AimbotGroup:AddDropdown("AimbotHitpart", { Text = "Hitpart",          Default = "Head",
    Values   = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Callback = function(v) Cfg.AimbotHitpart = v end })
AimbotGroup:AddToggle("AimbotTeamCheck", { Text = "Team Check",       Default = true,
    Callback = function(v) Cfg.AimbotTeamCheck = v end })
AimbotGroup:AddToggle("AimbotVisCheck",  { Text = "Visibility Check", Default = false,
    Callback = function(v) Cfg.AimbotVisCheck = v end })

SilentGroup:AddToggle("SilentEnabled",   { Text = "Enable Silent Aim", Default = false })
SilentGroup:AddDropdown("SilentHitpart", { Text = "Hitpart",           Default = "Head",
    Values   = { "Head", "HumanoidRootPart", "UpperTorso" },
    Callback = function(v) Cfg.SilentHitpart = v end })
SilentGroup:AddSlider("SilentFOV",       { Text = "FOV",               Default = 200, Min = 10, Max = 800, Rounding = 0, Suffix = "px",
    Callback = function(v) Cfg.SilentFOV = v end })

UtilGroup:AddToggle("VoidEnabled",   { Text = "VoidSpam",         Default = false })
UtilGroup:AddSlider("VoidSpeed",     { Text = "Void Speed",       Default = 5, Min = 1, Max = 20, Rounding = 0, Suffix = "x0.01s",
    Callback = function(v) Cfg.VoidSpeed = v / 100 end })
UtilGroup:AddToggle("OffsetEnabled", { Text = "Character Offset", Default = false })
UtilGroup:AddSlider("OffsetX", { Text = "Offset X", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetX = v end })
UtilGroup:AddSlider("OffsetY", { Text = "Offset Y", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetY = v end })
UtilGroup:AddSlider("OffsetZ", { Text = "Offset Z", Default = 0, Min = -20, Max = 20, Rounding = 0, Callback = function(v) Cfg.OffsetZ = v end })

OrbitGroup:AddToggle("OrbitEnabled", { Text = "Enable Orbit", Default = false })
OrbitGroup:AddSlider("OrbitRadius",  { Text = "Radius", Default = 8, Min = 2,  Max = 50, Rounding = 0, Suffix = " studs",
    Callback = function(v) Cfg.OrbitRadius = v end })
OrbitGroup:AddSlider("OrbitSpeed",   { Text = "Speed",  Default = 2, Min = 1,  Max = 20, Rounding = 0, Suffix = " rad/s",
    Callback = function(v) Cfg.OrbitSpeed = v end })
OrbitGroup:AddDropdown("OrbitTarget", {
    Text = "Target Player", Default = "None",
    Values = (function()
        local n = { "None" }
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(n, p.Name) end
        end
        return n
    end)(),
    Callback = function(v)
        Cfg.OrbitTarget = v ~= "None" and Players:FindFirstChild(v) or nil
    end,
})

-- ── Movement ──────────────────────────────────────────────────────────────────
local FlightGroup = MovementTab:AddLeftGroupbox("Flight")
local SpeedGroup  = MovementTab:AddLeftGroupbox("Speed")
local NoclipGroup = MovementTab:AddRightGroupbox("Noclip")

FlightGroup:AddToggle("FlightEnabled", { Text = "Enable Flight", Default = false })
FlightGroup:AddSlider("FlightSpeed",   { Text = "Speed",         Default = 60, Min = 10, Max = 300, Rounding = 0, Suffix = " studs/s",
    Callback = function(v) Cfg.FlightSpeed = v end })

SpeedGroup:AddToggle("SpeedEnabled",    { Text = "Enable Speed", Default = false })
SpeedGroup:AddSlider("SpeedMultiplier", { Text = "Multiplier",   Default = 2, Min = 1, Max = 20, Rounding = 1, Suffix = "x",
    Callback = function(v) Cfg.SpeedMultiplier = v end })

NoclipGroup:AddToggle("NoclipEnabled", { Text = "Enable Noclip", Default = false })

-- ── ESP ───────────────────────────────────────────────────────────────────────
local EL = ESPTab:AddLeftGroupbox("ESP")
local ER = ESPTab:AddRightGroupbox("Options")

EL:AddToggle("ESPEnabled",  { Text = "Enable ESP",  Default = false })
EL:AddToggle("ESPBoxes",    { Text = "Boxes",       Default = true  })
EL:AddToggle("ESPNames",    { Text = "Names",       Default = true  })
EL:AddToggle("ESPDist",     { Text = "Distance",    Default = true  })
EL:AddToggle("ESPHealth",   { Text = "Health Bar",  Default = true  })
EL:AddToggle("ESPSkeleton", { Text = "Skeleton",    Default = false })
ER:AddSlider("ESPMaxDist",  { Text = "Max Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0, Suffix = " studs" })

-- ── Settings ──────────────────────────────────────────────────────────────────
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("Nexo")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(SettingsTab)

-- ── Cleanup ───────────────────────────────────────────────────────────────────
Library:OnUnload(function()
    for _, d in pairs(ESPCache) do
        for _, v in pairs(d) do
            if typeof(v) == "table" then
                for _, l in pairs(v) do pcall(function() l:Remove() end) end
            else
                pcall(function() v:Remove() end)
            end
        end
    end
    DisableFlight()
    local hum = GetHum(LocalPlayer)
    if hum then hum.WalkSpeed = originalWalkSpeed end
    setreadonly(mt, false)
    mt.__namecall = old
    setreadonly(mt, true)
end)

SaveManager:LoadAutoloadConfig()
