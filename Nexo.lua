-- ══════════════════════════════════════════════════════════════════════════════
-- nexo.gg  |  v4.0  |  Full mechanics rebuild — correct Rivals input model
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
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local Cfg = {
    AimbotSmoothing  = 5,       -- mousemoverel pixels per frame (higher = faster)
    AimbotHitpart    = "Head",
    AimbotTeamCheck  = true,
    AimbotVisCheck   = false,
    SilentHitpart    = "Head",
    SilentHitChance  = 100,
    SilentTeamCheck  = true,
    TriggerDelay     = 0.08,
    TriggerFOV       = 25,
    TriggerTeamCheck = true,
    TriggerVisCheck  = true,
    RageAttackTime   = 1.5,
    RageVoidTime     = 1.0,
    RageTeamCheck    = true,
    FlightSpeed      = 60,
    SpeedMultiplier  = 2,
    OffsetX = 0, OffsetY = 0, OffsetZ = 0,
    OrbitRadius = 8, OrbitSpeed = 2,
    OrbitTarget = nil,
    VoidSpeed   = 0.05,
}

-- ── Core utilities ────────────────────────────────────────────────────────────
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
    return hum ~= nil and hum.Health > 0
end

local function IsEnemy(p, teamCheckEnabled)
    if p == LocalPlayer then return false end
    if not teamCheckEnabled then return true end
    local myTeam    = LocalPlayer.Team
    local theirTeam = p.Team
    if not myTeam or not theirTeam then return true end
    return myTeam ~= theirTeam
end

-- ── Aim position ──────────────────────────────────────────────────────────────
local function GetAimPos(char, hitpart)
    local part = char:FindFirstChild(hitpart) or char:FindFirstChild("HumanoidRootPart")
    if not part then return nil end
    if hitpart == "Head" then
        return part.Position + Vector3.new(0, part.Size.Y * 0.35, 0)
    end
    return part.Position
end

-- ── Visibility ────────────────────────────────────────────────────────────────
local RAY_PARAMS      = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(targetPos, targetChar)
    local char = LocalPlayer.Character
    if not char then return true end
    local list = { char }
    if targetChar then table.insert(list, targetChar) end
    RAY_PARAMS.FilterDescendantsInstances = list
    local result = workspace:Raycast(Camera.CFrame.Position, targetPos - Camera.CFrame.Position, RAY_PARAMS)
    return result == nil
end

-- ── Target acquisition ────────────────────────────────────────────────────────
-- Returns player, aimPos, screenPos
local function GetTarget(fov, centerMode, hitpart, teamCheck, visCheck)
    local closest, closestDist, closestPos, closestSP = nil, fov or math.huge, nil, nil
    local vp  = Camera.ViewportSize
    local ref = centerMode
        and Vector2.new(vp.X * 0.5, vp.Y * 0.5)
        or  UserInputService:GetMouseLocation()

    for _, p in ipairs(Players:GetPlayers()) do
        if not IsEnemy(p, teamCheck) then continue end
        if not IsAlive(p) then continue end
        local char = p.Character
        if not char then continue end
        local aimPos = GetAimPos(char, hitpart or "Head")
        if not aimPos then continue end
        if visCheck and not IsVisible(aimPos, char) then continue end
        local sp, onscreen = Camera:WorldToViewportPoint(aimPos)
        if not onscreen or sp.Z <= 0 then continue end
        local screenDist = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
        if fov and screenDist > fov then continue end
        if screenDist < closestDist then
            closest     = p
            closestDist = screenDist
            closestPos  = aimPos
            closestSP   = Vector2.new(sp.X, sp.Y)
        end
    end
    return closest, closestPos, closestSP
end

-- Nearest enemy by world distance (for silent aim / ragebot)
local function GetNearestEnemy(teamCheck)
    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if not IsEnemy(p, teamCheck) then continue end
        if not IsAlive(p) then continue end
        local hrp = GetHRP(p)
        if not hrp then continue end
        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist < closestDist then
            closest     = p
            closestDist = dist
        end
    end
    return closest
end

-- ── ESP ───────────────────────────────────────────────────────────────────────
local ESPCache = {}
local CORNERS  = {
    Vector3.new( 1,  1,  1), Vector3.new(-1,  1,  1),
    Vector3.new( 1, -1,  1), Vector3.new(-1, -1,  1),
    Vector3.new( 1,  1, -1), Vector3.new(-1,  1, -1),
    Vector3.new( 1, -1, -1), Vector3.new(-1, -1, -1),
}
local BONE_PAIRS = {
    {"Head","UpperTorso"}, {"Head","Torso"},
    {"LeftHand","HumanoidRootPart"}, {"RightHand","HumanoidRootPart"},
    {"Left Leg","HumanoidRootPart"}, {"Right Leg","HumanoidRootPart"},
}

local function GetBounds(char)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local found = false
    for _, obj in ipairs(char:GetDescendants()) do
        if not obj:IsA("BasePart") then continue end
        if obj.Size.Magnitude < 0.1 then continue end
        local cf, hs = obj.CFrame, obj.Size * 0.5
        for _, c in ipairs(CORNERS) do
            local wp      = cf:PointToWorldSpace(Vector3.new(c.X*hs.X, c.Y*hs.Y, c.Z*hs.Z))
            local sp, vis = Camera:WorldToViewportPoint(wp)
            if vis and sp.Z > 0 then
                found = true
                if sp.X < minX then minX = sp.X end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end
    end
    return found and minX, minY, maxX, maxY
end

local function MakeESP(p)
    if ESPCache[p] then return end
    local d = {}
    d.Box = Drawing.new("Square"); d.Box.Filled=false; d.Box.Thickness=1.5; d.Box.Color=Color3.fromRGB(255,60,60); d.Box.Visible=false
    d.BoxOutline = Drawing.new("Square"); d.BoxOutline.Filled=false; d.BoxOutline.Thickness=3; d.BoxOutline.Color=Color3.fromRGB(0,0,0); d.BoxOutline.Visible=false
    d.Name = Drawing.new("Text"); d.Name.Size=13; d.Name.Center=true; d.Name.Outline=true; d.Name.Font=2; d.Name.Color=Color3.fromRGB(255,255,255); d.Name.Visible=false
    d.Dist = Drawing.new("Text"); d.Dist.Size=11; d.Dist.Center=true; d.Dist.Outline=true; d.Dist.Font=2; d.Dist.Color=Color3.fromRGB(180,180,180); d.Dist.Visible=false
    d.HBG  = Drawing.new("Square"); d.HBG.Filled=true; d.HBG.Color=Color3.fromRGB(15,15,15); d.HBG.Visible=false
    d.HBar = Drawing.new("Square"); d.HBar.Filled=true; d.HBar.Color=Color3.fromRGB(60,220,80); d.HBar.Visible=false
    d.Lines = {}
    for i = 1, 6 do
        local l = Drawing.new("Line"); l.Thickness=1; l.Color=Color3.fromRGB(255,60,60); l.Visible=false
        d.Lines[i] = l
    end
    ESPCache[p] = d
end

local function RemoveESP(p)
    local d = ESPCache[p]; if not d then return end
    for _, v in pairs(d) do
        if typeof(v) == "table" then for _, l in pairs(v) do pcall(function() l:Remove() end) end
        else pcall(function() v:Remove() end) end
    end
    ESPCache[p] = nil
end

local function HideESP(d)
    d.Box.Visible=false; d.BoxOutline.Visible=false; d.Name.Visible=false
    d.Dist.Visible=false; d.HBG.Visible=false; d.HBar.Visible=false
    for _, l in pairs(d.Lines) do l.Visible=false end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then MakeESP(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then MakeESP(p) end end)
Players.PlayerRemoving:Connect(RemoveESP)

-- ── AIMBOT — mousemoverel based (works with Rivals' input model) ───────────────
-- Rivals reads raw mouse delta via UserInputService, not Camera.CFrame.
-- mousemoverel moves the actual OS mouse cursor, which Rivals picks up correctly.
RunService.RenderStepped:Connect(function()
    if not (Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value) then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then return end

    local t, _, targetSP = GetTarget(
        Options.AimbotFOV and Options.AimbotFOV.Value or 150,
        false, Cfg.AimbotHitpart, Cfg.AimbotTeamCheck, Cfg.AimbotVisCheck
    )
    if not t or not targetSP then return end

    local vp     = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local dx     = targetSP.X - cx
    local dy     = targetSP.Y - cy
    local smooth = Cfg.AimbotSmoothing

    -- Move mouse toward target by smooth pixels per frame
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 1 then return end
    local stepX = math.clamp(dx, -smooth, smooth)
    local stepY = math.clamp(dy, -smooth, smooth)
    mousemoverel(stepX, stepY)
end)

-- ── SILENT AIM — __index hook on WorldRoot:Raycast (how Rivals detects hits) ──
-- Rivals uses workspace:Raycast to compute hit position server-side confirmation.
-- We hook __namecall and redirect when the method is InvokeServer OR FireServer,
-- replacing any enemy BasePart with the target hitpart.
-- Additionally hook Raycast to redirect bullet raycast origin toward target.
local mt  = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()

    -- FireServer hook (weapon fire remotes)
    if (method == "FireServer" or method == "InvokeServer")
    and Toggles.SilentEnabled
    and Toggles.SilentEnabled.Value then
        local args   = {...}
        local hasHit = false

        for _, v in ipairs(args) do
            if typeof(v) == "Instance" and v:IsA("BasePart") then
                local owner = Players:GetPlayerFromCharacter(v.Parent)
                if owner and owner ~= LocalPlayer then hasHit = true; break end
            end
        end

        if hasHit then
            local chance = Options.SilentHitChance and Options.SilentHitChance.Value or 100
            if math.random(1, 100) <= chance then
                local t = GetNearestEnemy(Cfg.SilentTeamCheck)
                if t and t.Character then
                    local targetPart = t.Character:FindFirstChild(Cfg.SilentHitpart)
                        or t.Character:FindFirstChild("UpperTorso")
                        or t.Character:FindFirstChild("Torso")
                        or t.Character:FindFirstChild("HumanoidRootPart")
                    local aimPos = targetPart and GetAimPos(t.Character, Cfg.SilentHitpart)

                    if targetPart and aimPos then
                        for i, v in ipairs(args) do
                            if typeof(v) == "Instance" and v:IsA("BasePart") then
                                local owner = Players:GetPlayerFromCharacter(v.Parent)
                                if owner and owner ~= LocalPlayer then
                                    args[i] = targetPart
                                end
                            elseif typeof(v) == "Vector3" then
                                args[i] = aimPos
                            elseif typeof(v) == "CFrame" then
                                args[i] = CFrame.new(aimPos)
                            end
                        end
                        if method == "InvokeServer" then
                            return old(self, table.unpack(args))
                        end
                        return old(self, table.unpack(args))
                    end
                end
            end
        end
    end

    return old(self, ...)
end)

setreadonly(mt, true)

-- ── HITBOX EXPANDER — makes enemy hitboxes massive for any hit to register ────
-- This is how silent aim actually works in Rivals: expand the hitbox so any
-- shot registers, combined with the namecall hook as backup.
local ExpandedParts = {}
local HITBOX_SIZE   = Vector3.new(8, 8, 8)  -- adjustable

local function ExpandHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not IsEnemy(p, Cfg.SilentTeamCheck) then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if not ExpandedParts[hrp] then
            ExpandedParts[hrp] = hrp.Size
        end
        hrp.Size = HITBOX_SIZE
    end
end

local function RestoreHitboxes()
    for part, origSize in pairs(ExpandedParts) do
        pcall(function() part.Size = origSize end)
    end
    ExpandedParts = {}
end

-- ── TRIGGERBOT — checks if enemy HRP is near screen center, uses mouse1click ─
local triggerLastFire = 0

RunService.Heartbeat:Connect(function()
    if not (Toggles.TriggerEnabled and Toggles.TriggerEnabled.Value) then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then return end

    local now = tick()
    if now - triggerLastFire < Cfg.TriggerDelay then return end

    local fov    = Options.TriggerFOV and Options.TriggerFOV.Value or 25
    local t, pos = GetTarget(fov, true, "Head", Cfg.TriggerTeamCheck, Cfg.TriggerVisCheck)
    if not t then return end

    mouse1click()
    triggerLastFire = now
end)

-- ── RAGEBOT — velocity-based void cycling ────────────────────────────────────
-- Server-authoritative position can be influenced via BodyVelocity and
-- BodyPosition — these ARE replicated. We use BodyPosition to slam into
-- target then BodyPosition to drop into void.
local ragePlaying = false
local rageBP      = nil
local rageBV      = nil

local function CleanRageBodies()
    if rageBP then pcall(function() rageBP:Destroy() end); rageBP = nil end
    if rageBV then pcall(function() rageBV:Destroy() end); rageBV = nil end
end

local function SetPosition(pos)
    local hrp = GetHRP(LocalPlayer)
    if not hrp then return end
    CleanRageBodies()
    local bp        = Instance.new("BodyPosition")
    bp.Position     = pos
    bp.MaxForce     = Vector3.new(math.huge, math.huge, math.huge)
    bp.P            = 1e6
    bp.D            = 1e4
    bp.Parent       = hrp
    rageBP          = bp
end

local function RagebotLoop()
    while Toggles.RageEnabled and Toggles.RageEnabled.Value do
        local t = GetNearestEnemy(Cfg.RageTeamCheck)
        if not t or not t.Character then task.wait(0.1); continue end

        local thrp = t.Character:FindFirstChild("HumanoidRootPart")
        if not thrp then task.wait(0.1); continue end

        -- Surface next to target
        local attackPos = thrp.Position + Vector3.new(2, 0, 0)
        SetPosition(attackPos)
        task.wait(0.05)

        -- Attack phase: stay on target
        local attackEnd = tick() + Cfg.RageAttackTime
        while tick() < attackEnd do
            if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) then break end
            local ct = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
            if ct and rageBP then
                rageBP.Position = ct.Position + Vector3.new(2, 0, 0)
            end
            task.wait(0.05)
        end

        if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) then break end

        -- Void phase: drop deep
        local hrp = GetHRP(LocalPlayer)
        if hrp then
            SetPosition(Vector3.new(hrp.Position.X, hrp.Position.Y - 1000, hrp.Position.Z))
        end

        local voidEnd = tick() + Cfg.RageVoidTime
        while tick() < voidEnd do
            if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) then break end
            task.wait(0.05)
        end
    end
    CleanRageBodies()
    ragePlaying = false
end

RunService.Heartbeat:Connect(function()
    if Toggles.RageEnabled and Toggles.RageEnabled.Value and not ragePlaying then
        ragePlaying = true
        task.spawn(RagebotLoop)
    end
    if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) and ragePlaying then
        CleanRageBodies()
    end
end)

-- ── VOIDSPAM — BodyPosition based ────────────────────────────────────────────
local voidBP     = nil
local voidActive = false

local function VoidDown()
    local hrp = GetHRP(LocalPlayer)
    if not hrp then return end
    if voidBP then pcall(function() voidBP:Destroy() end) end
    local bp    = Instance.new("BodyPosition")
    bp.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 500, hrp.Position.Z)
    bp.MaxForce = Vector3.new(0, math.huge, 0)
    bp.P        = 1e6
    bp.D        = 1e4
    bp.Parent   = hrp
    voidBP      = bp
end

local function VoidUp()
    if voidBP then pcall(function() voidBP:Destroy() end); voidBP = nil end
end

RunService.Heartbeat:Connect(function()
    local on = Toggles.VoidEnabled and Toggles.VoidEnabled.Value
    if on and not voidActive then
        VoidDown(); voidActive = true
        task.delay(Cfg.VoidSpeed, function()
            VoidUp(); voidActive = false
        end)
    end
end)

-- ── HITBOX EXPANDER loop ──────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if Toggles.SilentEnabled and Toggles.SilentEnabled.Value then
        ExpandHitboxes()
    else
        RestoreHitboxes()
    end
end)

-- ── ESP render ────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    local espOn       = Toggles.ESPEnabled  and Toggles.ESPEnabled.Value
    local espTeamChk  = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not ESPCache[p] then MakeESP(p) end
        local d    = ESPCache[p]
        local char = p.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        if not espOn or not IsEnemy(p, espTeamChk) or not char or not hrp or not hum or hum.Health <= 0 then
            HideESP(d); continue
        end

        local maxDist = Options.ESPMaxDist and Options.ESPMaxDist.Value or 1000
        local dist    = (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist > maxDist then HideESP(d); continue end

        local minX, minY, maxX, maxY = GetBounds(char)
        if not minX then HideESP(d); continue end

        local pad  = 2
        local bx   = minX - pad
        local by   = minY - pad
        local bw   = (maxX - minX) + pad * 2
        local bh   = (maxY - minY) + pad * 2
        local midX = bx + bw * 0.5
        local hp   = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        if bw < 2 or bh < 4 then HideESP(d); continue end

        local showBoxes  = Toggles.ESPBoxes    and Toggles.ESPBoxes.Value    or false
        local showNames  = Toggles.ESPNames    and Toggles.ESPNames.Value    or false
        local showDist   = Toggles.ESPDist     and Toggles.ESPDist.Value     or false
        local showHealth = Toggles.ESPHealth   and Toggles.ESPHealth.Value   or false
        local showSkel   = Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value or false

        d.BoxOutline.Visible=showBoxes; d.BoxOutline.Position=Vector2.new(bx-1,by-1); d.BoxOutline.Size=Vector2.new(bw+2,bh+2)
        d.Box.Visible=showBoxes; d.Box.Position=Vector2.new(bx,by); d.Box.Size=Vector2.new(bw,bh)
        d.Name.Visible=showNames; d.Name.Text=p.Name; d.Name.Position=Vector2.new(midX,by-15)
        d.Dist.Visible=showDist; d.Dist.Text=math.floor(dist).."m"; d.Dist.Position=Vector2.new(midX,by+bh+2)

        local barW=3; local barX=bx-barW-2
        d.HBG.Visible=showHealth; d.HBG.Position=Vector2.new(barX,by); d.HBG.Size=Vector2.new(barW,bh)
        d.HBar.Visible=showHealth; d.HBar.Position=Vector2.new(barX,by+bh*(1-hp)); d.HBar.Size=Vector2.new(barW,bh*hp)
        d.HBar.Color=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),0)

        for i, pair in ipairs(BONE_PAIRS) do
            local l=d.Lines[i]; if not l then continue end
            local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
            if showSkel and pA and pB then
                local spA,visA=Camera:WorldToViewportPoint(pA.Position)
                local spB,visB=Camera:WorldToViewportPoint(pB.Position)
                if visA and visB then
                    l.Visible=true; l.From=Vector2.new(spA.X,spA.Y); l.To=Vector2.new(spB.X,spB.Y)
                else l.Visible=false end
            else l.Visible=false end
        end
    end
end)

-- ── Flight ────────────────────────────────────────────────────────────────────
local flightBV, flightBG
local wasFlightOn = false

local function EnableFlight()
    local hrp = GetHRP(LocalPlayer); if not hrp then return end
    flightBV=Instance.new("BodyVelocity"); flightBV.Velocity=Vector3.zero
    flightBV.MaxForce=Vector3.new(1e5,1e5,1e5); flightBV.P=1e4; flightBV.Parent=hrp
    flightBG=Instance.new("BodyGyro"); flightBG.MaxTorque=Vector3.new(1e5,1e5,1e5)
    flightBG.P=1e4; flightBG.D=500; flightBG.CFrame=hrp.CFrame; flightBG.Parent=hrp
    local hum=GetHum(LocalPlayer); if hum then hum.PlatformStand=true end
end

local function DisableFlight()
    if flightBV then flightBV:Destroy(); flightBV=nil end
    if flightBG then flightBG:Destroy(); flightBG=nil end
    local hum=GetHum(LocalPlayer); if hum then hum.PlatformStand=false end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Toggles.FlightEnabled and Toggles.FlightEnabled.Value then EnableFlight() end
end)

RunService.Heartbeat:Connect(function()
    local on=Toggles.FlightEnabled and Toggles.FlightEnabled.Value
    if on and not wasFlightOn then EnableFlight(); wasFlightOn=true
    elseif not on and wasFlightOn then DisableFlight(); wasFlightOn=false end
    if on and flightBV then
        local hrp=GetHRP(LocalPlayer); if not hrp then return end
        local spd=Cfg.FlightSpeed; local cf=Camera.CFrame; local vel=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel+=cf.LookVector*spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel-=cf.LookVector*spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel-=cf.RightVector*spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel+=cf.RightVector*spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel+=Vector3.yAxis*spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel-=Vector3.yAxis*spd end
        flightBV.Velocity=vel; flightBG.CFrame=cf
    end
end)

-- ── Speedhack ─────────────────────────────────────────────────────────────────
local originalWalkSpeed=16; local wasSpeedOn=false
RunService.Heartbeat:Connect(function()
    local on=Toggles.SpeedEnabled and Toggles.SpeedEnabled.Value
    local hum=GetHum(LocalPlayer)
    if not hum then wasSpeedOn=false; return end
    if on and not wasSpeedOn then originalWalkSpeed=hum.WalkSpeed; wasSpeedOn=true
    elseif not on and wasSpeedOn then hum.WalkSpeed=originalWalkSpeed; wasSpeedOn=false end
    if on then hum.WalkSpeed=originalWalkSpeed*Cfg.SpeedMultiplier end
end)

-- ── Noclip ────────────────────────────────────────────────────────────────────
local wasNoclipOn=false
local function SetCollision(state)
    local char=LocalPlayer.Character; if not char then return end
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide=state end
    end
end
RunService.Heartbeat:Connect(function()
    local on=Toggles.NoclipEnabled and Toggles.NoclipEnabled.Value
    if on then SetCollision(false); wasNoclipOn=true
    elseif wasNoclipOn then SetCollision(true); wasNoclipOn=false end
end)

-- ── Char Offset ───────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not (Toggles.OffsetEnabled and Toggles.OffsetEnabled.Value) then return end
    local hrp=GetHRP(LocalPlayer); if not hrp then return end
    hrp.CFrame=hrp.CFrame*CFrame.new(Cfg.OffsetX,Cfg.OffsetY,Cfg.OffsetZ)
end)

-- ── Orbit ─────────────────────────────────────────────────────────────────────
local orbitAngle=0
RunService.Heartbeat:Connect(function(dt)
    if not (Toggles.OrbitEnabled and Toggles.OrbitEnabled.Value) then return end
    if not Cfg.OrbitTarget then return end
    local hrp=GetHRP(LocalPlayer)
    local tc=Cfg.OrbitTarget.Character
    local thrp=tc and tc:FindFirstChild("HumanoidRootPart")
    if not hrp or not thrp then return end
    orbitAngle=orbitAngle+Cfg.OrbitSpeed*dt
    if rageBP then
        rageBP.Position=Vector3.new(
            thrp.Position.X+Cfg.OrbitRadius*math.cos(orbitAngle),
            thrp.Position.Y,
            thrp.Position.Z+Cfg.OrbitRadius*math.sin(orbitAngle)
        )
    end
end)

-- ── Window ────────────────────────────────────────────────────────────────────
local Window=Library:CreateWindow({
    Title="nexo.gg", Footer="v4.0", Center=true, AutoShow=true,
    ToggleKeybind=Enum.KeyCode.RightShift,
})

local CombatTab  =Window:AddTab("Combat",  "sword")
local MovementTab=Window:AddTab("Movement","footprints")
local ESPTab     =Window:AddTab("ESP",     "eye")
local SettingsTab=Window:AddTab("Settings","settings")

-- Combat
local AimbotGroup =CombatTab:AddLeftGroupbox("Aimbot")
local SilentGroup =CombatTab:AddLeftGroupbox("Silent Aim")
local TriggerGroup=CombatTab:AddLeftGroupbox("Triggerbot")
local RageGroup   =CombatTab:AddRightGroupbox("Ragebot")
local UtilGroup   =CombatTab:AddRightGroupbox("Utilities")
local OrbitGroup  =CombatTab:AddRightGroupbox("Orbit")

AimbotGroup:AddToggle("AimbotEnabled",  {Text="Enable Aimbot",     Default=false})
AimbotGroup:AddSlider("AimbotFOV",      {Text="FOV",               Default=150,Min=10,Max=500,Rounding=0,Suffix="px"})
AimbotGroup:AddSlider("AimbotSmooth",   {Text="Smoothing Speed",   Default=5,  Min=1,Max=50, Rounding=0,Suffix="px/f",Callback=function(v) Cfg.AimbotSmoothing=v end})
AimbotGroup:AddDropdown("AimbotHitpart",{Text="Hitpart",           Default="Head",Values={"Head","HumanoidRootPart","UpperTorso","LowerTorso"},Callback=function(v) Cfg.AimbotHitpart=v end})
AimbotGroup:AddToggle("AimbotTeamCheck",{Text="Team Check",        Default=true, Callback=function(v) Cfg.AimbotTeamCheck=v end})
AimbotGroup:AddToggle("AimbotVisCheck", {Text="Visibility Check",  Default=false,Callback=function(v) Cfg.AimbotVisCheck=v end})

SilentGroup:AddToggle("SilentEnabled",   {Text="Enable Silent Aim", Default=false})
SilentGroup:AddLabel("Expands hitboxes + redirects remotes")
SilentGroup:AddDropdown("SilentHitpart", {Text="Hitpart",           Default="Head",Values={"Head","HumanoidRootPart","UpperTorso"},Callback=function(v) Cfg.SilentHitpart=v end})
SilentGroup:AddSlider("SilentHitChance", {Text="Hit Chance",        Default=100,Min=1,Max=100,Rounding=0,Suffix="%",Callback=function(v) Cfg.SilentHitChance=v end})
SilentGroup:AddToggle("SilentTeamCheck", {Text="Team Check",        Default=true, Callback=function(v) Cfg.SilentTeamCheck=v end})

TriggerGroup:AddToggle("TriggerEnabled",  {Text="Enable Triggerbot", Default=false})
TriggerGroup:AddLabel("Fires while holding Right Click")
TriggerGroup:AddSlider("TriggerFOV",      {Text="FOV",               Default=25, Min=1, Max=200,Rounding=0,Suffix="px"})
TriggerGroup:AddSlider("TriggerDelay",    {Text="Fire Delay",        Default=8,  Min=1, Max=100,Rounding=0,Suffix="x0.01s",Callback=function(v) Cfg.TriggerDelay=v/100 end})
TriggerGroup:AddToggle("TriggerVisCheck", {Text="Visibility Check",  Default=true, Callback=function(v) Cfg.TriggerVisCheck=v end})
TriggerGroup:AddToggle("TriggerTeamCheck",{Text="Team Check",        Default=true, Callback=function(v) Cfg.TriggerTeamCheck=v end})

RageGroup:AddToggle("RageEnabled",   {Text="Enable Ragebot",  Default=false})
RageGroup:AddSlider("RageAttackTime",{Text="Attack Duration", Default=15, Min=1,Max=100,Rounding=0,Suffix="x0.1s",Callback=function(v) Cfg.RageAttackTime=v/10 end})
RageGroup:AddSlider("RageVoidTime",  {Text="Void Duration",   Default=10, Min=1,Max=100,Rounding=0,Suffix="x0.1s",Callback=function(v) Cfg.RageVoidTime=v/10 end})
RageGroup:AddToggle("RageTeamCheck", {Text="Team Check",      Default=true, Callback=function(v) Cfg.RageTeamCheck=v end})

UtilGroup:AddToggle("VoidEnabled",   {Text="VoidSpam",         Default=false})
UtilGroup:AddSlider("VoidSpeed",     {Text="Void Speed",       Default=5,  Min=1,Max=20,Rounding=0,Suffix="x0.01s",Callback=function(v) Cfg.VoidSpeed=v/100 end})
UtilGroup:AddToggle("OffsetEnabled", {Text="Character Offset", Default=false})
UtilGroup:AddSlider("OffsetX",{Text="Offset X",Default=0,Min=-20,Max=20,Rounding=0,Callback=function(v) Cfg.OffsetX=v end})
UtilGroup:AddSlider("OffsetY",{Text="Offset Y",Default=0,Min=-20,Max=20,Rounding=0,Callback=function(v) Cfg.OffsetY=v end})
UtilGroup:AddSlider("OffsetZ",{Text="Offset Z",Default=0,Min=-20,Max=20,Rounding=0,Callback=function(v) Cfg.OffsetZ=v end})

OrbitGroup:AddToggle("OrbitEnabled",{Text="Enable Orbit",Default=false})
OrbitGroup:AddSlider("OrbitRadius", {Text="Radius",Default=8, Min=2, Max=50, Rounding=0,Suffix=" studs",Callback=function(v) Cfg.OrbitRadius=v end})
OrbitGroup:AddSlider("OrbitSpeed",  {Text="Speed",  Default=2, Min=1, Max=20, Rounding=0,Suffix=" rad/s",Callback=function(v) Cfg.OrbitSpeed=v end})
OrbitGroup:AddDropdown("OrbitTarget",{
    Text="Target Player",Default="None",
    Values=(function() local n={"None"}
        for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(n,p.Name) end end
        return n end)(),
    Callback=function(v) Cfg.OrbitTarget=v~="None" and Players:FindFirstChild(v) or nil end,
})

-- Movement
local FlightGroup =MovementTab:AddLeftGroupbox("Flight")
local SpeedGroup  =MovementTab:AddLeftGroupbox("Speed")
local NoclipGroup =MovementTab:AddRightGroupbox("Noclip")

FlightGroup:AddToggle("FlightEnabled",{Text="Enable Flight",Default=false})
FlightGroup:AddSlider("FlightSpeed",  {Text="Speed",        Default=60,Min=10,Max=300,Rounding=0,Suffix=" studs/s",Callback=function(v) Cfg.FlightSpeed=v end})
SpeedGroup:AddToggle("SpeedEnabled",   {Text="Enable Speed",Default=false})
SpeedGroup:AddSlider("SpeedMultiplier",{Text="Multiplier",  Default=2, Min=1, Max=20, Rounding=1,Suffix="x",       Callback=function(v) Cfg.SpeedMultiplier=v end})
NoclipGroup:AddToggle("NoclipEnabled", {Text="Enable Noclip",Default=false})

-- ESP
local EL=ESPTab:AddLeftGroupbox("ESP")
local ER=ESPTab:AddRightGroupbox("Options")
EL:AddToggle("ESPEnabled",  {Text="Enable ESP",  Default=false})
EL:AddToggle("ESPBoxes",    {Text="Boxes",       Default=true})
EL:AddToggle("ESPNames",    {Text="Names",       Default=true})
EL:AddToggle("ESPDist",     {Text="Distance",    Default=true})
EL:AddToggle("ESPHealth",   {Text="Health Bar",  Default=true})
EL:AddToggle("ESPSkeleton", {Text="Skeleton",    Default=false})
EL:AddToggle("ESPTeamCheck",{Text="Team Check",  Default=true})
ER:AddSlider("ESPMaxDist",  {Text="Max Distance",Default=1000,Min=100,Max=5000,Rounding=0,Suffix=" studs"})

-- Settings
SaveManager:SetLibrary(Library); SaveManager:SetFolder("Nexo"); SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:SetLibrary(Library); ThemeManager:ApplyToTab(SettingsTab)

-- Cleanup
Library:OnUnload(function()
    for _,d in pairs(ESPCache) do
        for _,v in pairs(d) do
            if typeof(v)=="table" then for _,l in pairs(v) do pcall(function() l:Remove() end) end
            else pcall(function() v:Remove() end) end
        end
    end
    DisableFlight()
    RestoreHitboxes()
    CleanRageBodies()
    if voidBP then pcall(function() voidBP:Destroy() end) end
    local hum=GetHum(LocalPlayer)
    if hum then hum.WalkSpeed=originalWalkSpeed end
    setreadonly(mt,false); mt.__namecall=old; setreadonly(mt,true)
end)

SaveManager:LoadAutoloadConfig()
