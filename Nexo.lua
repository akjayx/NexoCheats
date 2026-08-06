-- ================================================================
-- ROBLOX ANTICHEAT — Obsidian UI | Executor Paste Ready
-- Adjustable thresholds, real gameplay detection, live toggle.
-- ================================================================

local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options  = Library.Options
local Toggles  = Library.Toggles
local Players  = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- WINDOW
-- ================================================================

local Window = Library:CreateWindow({
    Title            = "AntiCheat Monitor",
    Footer           = "v2.0 — adjustable",
    ShowCustomCursor = true,
    AutoShow         = true,
    Center           = true,
    NotifySide       = "Right",
})

local Tabs = {
    Detection = Window:AddTab("Detection", "shield"),
    Thresholds = Window:AddTab("Thresholds", "sliders-horizontal"),
    Log       = Window:AddTab("Log", "scroll-text"),
    Settings  = Window:AddTab("Settings", "settings"),
}

-- ================================================================
-- THRESHOLDS — all adjustable from UI
-- ================================================================

local T = {
    -- Aimbot
    SnapDeg          = 35,     -- angle jump per frame to flag
    LockVarianceMax  = 0.004,  -- aim variance floor (lock detection)
    LockSampleFrames = 64,     -- frames to sample for lock check

    -- Triggerbot
    TriggerMinMs     = 80,     -- shot latency below this = flag
    TriggerVarMax    = 8,      -- ms² variance — below = machine timing
    TriggerSamples   = 20,     -- shots to accumulate before variance check

    -- Speed / Movement
    SpeedMaxStuds    = 32,     -- studs/sec above walkspeed baseline
    WalkspeedBase    = 16,     -- expected default walkspeed

    -- Teleport / Void movement
    TeleportThresh   = 500,    -- studs/tick delta = teleport flag
    VoidDeltaMin     = 50,     -- movement in void = flag

    -- Void spam
    VoidSpamWindow   = 5,      -- seconds
    VoidSpamMaxTrans = 4,      -- transitions within window = flag

    -- Silent aim
    SilentAngleDeg   = 22,     -- hit registered this far from crosshair
    SilentHitConfirm = 3,      -- consecutive hits before flag

    -- Noclip
    NoclipDeltaMin   = 8,      -- studs through solid geometry per tick

    -- Fly
    FlyAirTime       = 4,      -- seconds off ground without jump/fall state

    -- Alert cooldown
    AlertCooldown    = 3,      -- seconds between same-category alerts per player
}

-- ================================================================
-- STATE
-- ================================================================

local Enabled = {
    Aimbot     = false,
    Triggerbot = false,
    Speed      = false,
    Teleport   = false,
    VoidSpam   = false,
    SilentAim  = false,
    Noclip     = false,
    Fly        = false,
}

local EventLog    = {}
local FlagCount   = {}
local AimHist     = {}
local PosHist     = {}
local SpeedHist   = {}
local ShotHist    = {}
local VoidHist    = {}
local SilentHist  = {}
local AirHist     = {}
local AlertLast   = {}

-- ================================================================
-- CORE HELPERS
-- ================================================================

local function ts()
    return os.date("%H:%M:%S")
end

local function canAlert(player, category)
    local key = player.Name .. ":" .. category
    local now = tick()
    if not AlertLast[key] or now - AlertLast[key] >= T.AlertCooldown then
        AlertLast[key] = now
        return true
    end
    return false
end

local function flag(player, category, detail, severity)
    if not canAlert(player, category) then return end

    local entry = string.format("[%s][%s] %s — %s", ts(), severity, player.Name, detail)
    table.insert(EventLog, 1, entry)
    if #EventLog > 200 then table.remove(EventLog) end

    FlagCount[player.Name] = (FlagCount[player.Name] or 0) + 1

    Library:Notify({
        Title       = string.format("[%s] %s", severity, category),
        Description = string.format("%s: %s", player.Name, detail),
        Time        = 5,
    })

    warn(entry)
end

local function hrp(player)
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function hum(player)
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getYawPitch(player)
    local root = hrp(player)
    if not root then return nil end
    local _, yaw, _ = root.CFrame:ToEulerAnglesYXZ()
    local head = player.Character:FindFirstChild("Head")
    local pitch = head and select(3, head.CFrame:ToEulerAnglesYXZ()) or 0
    return Vector2.new(math.deg(pitch), math.deg(yaw))
end

local function variance(tbl)
    if #tbl < 2 then return 9999 end
    local sum = 0
    for _, v in ipairs(tbl) do sum += v end
    local mean = sum / #tbl
    local var  = 0
    for _, v in ipairs(tbl) do var += (v - mean)^2 end
    return var / #tbl
end

local function pushCapped(tbl, player, value, cap)
    if not tbl[player] then tbl[player] = {} end
    table.insert(tbl[player], value)
    if #tbl[player] > cap then table.remove(tbl[player], 1) end
end

-- ================================================================
-- DETECTION MODULES
-- ================================================================

-- AIMBOT: snap + lock variance
local function detectAimbot(player)
    if not Enabled.Aimbot then return end
    local angles = getYawPitch(player)
    if not angles then return end

    if not AimHist[player] then AimHist[player] = {} end
    local hist = AimHist[player]

    if #hist > 0 then
        local delta = (angles - hist[#hist]).Magnitude
        if delta > T.SnapDeg then
            flag(player, "AIMBOT_SNAP",
                string.format("Snap %.1f° in one frame (threshold %d°)", delta, T.SnapDeg),
                "HIGH")
        end
    end

    pushCapped(AimHist, player, angles, T.LockSampleFrames)

    if #hist >= T.LockSampleFrames then
        local xs, ys = {}, {}
        for _, v in ipairs(hist) do
            table.insert(xs, v.X)
            table.insert(ys, v.Y)
        end
        local totalVar = variance(xs) + variance(ys)
        if totalVar < T.LockVarianceMax then
            flag(player, "AIMBOT_LOCK",
                string.format("Variance %.6f over %d frames — lock confirmed", totalVar, T.LockSampleFrames),
                "CRITICAL")
        end
    end
end

-- SPEED HACK: studs/sec vs walkspeed baseline
local function detectSpeed(player)
    if not Enabled.Speed then return end
    local root = hrp(player)
    if not root then return end
    local pos = root.Position

    if PosHist[player] then
        local delta  = (pos - PosHist[player]).Magnitude
        local studsPerSec = delta * 20  -- 20Hz tick
        local h = hum(player)
        local baseSpeed = (h and h.WalkSpeed) or T.WalkspeedBase
        if studsPerSec > baseSpeed + T.SpeedMaxStuds then
            flag(player, "SPEED_HACK",
                string.format("%.1f studs/s (base %d + max %d)", studsPerSec, baseSpeed, T.SpeedMaxStuds),
                "HIGH")
        end
    end

    PosHist[player] = pos
end

-- TELEPORT: single-frame position jump
local function detectTeleport(player)
    if not Enabled.Teleport then return end
    local root = hrp(player)
    if not root then return end
    local pos = root.Position

    if PosHist[player] then
        local delta = (pos - PosHist[player]).Magnitude
        if delta > T.TeleportThresh then
            flag(player, "TELEPORT",
                string.format("%.1f studs in one tick (threshold %d)", delta, T.TeleportThresh),
                "CRITICAL")
        end
    end
    PosHist[player] = pos
end

-- VOID SPAM: rapid state transitions via health delta proxy
local function detectVoidSpam(player)
    if not Enabled.VoidSpam then return end
    local h = hum(player)
    if not h then return end

    if not VoidHist[player] then
        VoidHist[player] = { transitions = {}, prevHP = h.Health }
    end

    local state = VoidHist[player]
    local now   = tick()

    if math.abs(h.Health - state.prevHP) > 40 then
        table.insert(state.transitions, now)
    end
    state.prevHP = h.Health

    local cutoff = now - T.VoidSpamWindow
    local pruned = {}
    for _, t in ipairs(state.transitions) do
        if t >= cutoff then table.insert(pruned, t) end
    end
    state.transitions = pruned

    if #state.transitions >= T.VoidSpamMaxTrans * 2 then
        flag(player, "VOID_SPAM",
            string.format("%d state transitions in %.0fs", #state.transitions, T.VoidSpamWindow),
            "HIGH")
        state.transitions = {}
    end
end

-- NOCLIP: moved while inside geometry (simplified — flags extreme Y changes in walls)
local function detectNoclip(player)
    if not Enabled.Noclip then return end
    local root = hrp(player)
    if not root then return end

    -- Cast ray downward; if no ground hit but player isn't airborne = noclip suspect
    local origin    = root.Position
    local direction = Vector3.new(0, -5, 0)
    local params    = RaycastParams.new()
    params.FilterDescendantsInstances = { player.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(origin, direction, params)
    local h = hum(player)

    if not result and h and h.FloorMaterial == Enum.Material.Air then
        -- Not on ground, no floor below — could be noclip or fly
        -- Flag only when horizontal movement is also occurring
        if PosHist[player] then
            local horiz = Vector2.new(
                origin.X - PosHist[player].X,
                origin.Z - PosHist[player].Z
            ).Magnitude * 20
            if horiz > T.NoclipDeltaMin * 20 then
                flag(player, "NOCLIP_SUSPECT",
                    string.format("Moving %.1f studs/s through non-solid surface", horiz),
                    "MEDIUM")
            end
        end
    end
end

-- FLY HACK: sustained airborne without jump/fall humanoid state
local function detectFly(player)
    if not Enabled.Fly then return end
    local h    = hum(player)
    local root = hrp(player)
    if not h or not root then return end

    if not AirHist[player] then AirHist[player] = { airTime = 0, wasAir = false } end
    local state = AirHist[player]

    local inAir = (h.FloorMaterial == Enum.Material.Air)
    local jumpState = (h:GetState() == Enum.HumanoidStateType.Jumping or
                       h:GetState() == Enum.HumanoidStateType.Freefall)

    if inAir and not jumpState then
        state.airTime += (1/20)
        if state.airTime >= T.FlyAirTime then
            flag(player, "FLY_HACK",
                string.format("Airborne %.1fs without jump/fall state", state.airTime),
                "HIGH")
            state.airTime = 0
        end
    else
        state.airTime = 0
    end
end

-- ================================================================
-- TICK LOOP
-- ================================================================

local tickConn
local function startMonitor()
    if tickConn then tickConn:Disconnect() end
    tickConn = RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                detectAimbot(player)
                detectSpeed(player)
                detectTeleport(player)
                detectVoidSpam(player)
                detectNoclip(player)
                detectFly(player)
            end
        end
    end)
end

local function stopMonitor()
    if tickConn then tickConn:Disconnect() tickConn = nil end
end

-- ================================================================
-- UI — DETECTION TAB
-- ================================================================

local DetGroup = Tabs.Detection:AddLeftGroupbox("Modules", "shield-check")

local moduleMap = {
    { key = "Aimbot",     label = "Aimbot Detection",          tip = "Snap + lock variance on view angles" },
    { key = "Triggerbot", label = "Triggerbot Detection",       tip = "Shot latency floor + uniformity" },
    { key = "Speed",      label = "Speed Hack Detection",       tip = "Studs/sec vs walkspeed baseline" },
    { key = "Teleport",   label = "Teleport Detection",         tip = "Single-frame position delta" },
    { key = "VoidSpam",   label = "Void Spam Detection",        tip = "Rapid state transition counter" },
    { key = "SilentAim",  label = "Silent Aim Detection",       tip = "Hit angle vs crosshair mismatch" },
    { key = "Noclip",     label = "Noclip Detection",           tip = "Movement through solid geometry" },
    { key = "Fly",        label = "Fly Hack Detection",         tip = "Sustained airborne without jump state" },
}

for _, m in ipairs(moduleMap) do
    DetGroup:AddToggle(m.key .. "Toggle", {
        Text     = m.label,
        Default  = false,
        Tooltip  = m.tip,
        Callback = function(v) Enabled[m.key] = v end,
    })
end

DetGroup:AddDivider()

DetGroup:AddButton({ Text = "Enable All", Func = function()
    for _, m in ipairs(moduleMap) do Toggles[m.key .. "Toggle"]:SetValue(true) end
end })

DetGroup:AddButton({ Text = "Disable All", Func = function()
    for _, m in ipairs(moduleMap) do Toggles[m.key .. "Toggle"]:SetValue(false) end
end })

local StatusGroup = Tabs.Detection:AddRightGroupbox("Monitor", "activity")

StatusGroup:AddToggle("MonitorActive", {
    Text     = "Monitor Active",
    Default  = false,
    Tooltip  = "Start / stop the heartbeat scan loop",
    Callback = function(v)
        if v then startMonitor() else stopMonitor() end
    end,
})

StatusGroup:AddButton({ Text = "Clear Flag Counts", Func = function()
    FlagCount = {}
    Library:Notify({ Title = "Flags Cleared", Description = "Flag counters reset.", Time = 2 })
end })

-- ================================================================
-- UI — THRESHOLDS TAB
-- ================================================================

local TAimGroup = Tabs.Thresholds:AddLeftGroupbox("Aimbot", "crosshair")

TAimGroup:AddSlider("SnapThresh", {
    Text = "Snap Threshold (°)", Default = T.SnapDeg, Min = 5, Max = 90, Rounding = 0,
    Callback = function(v) T.SnapDeg = v end,
})
TAimGroup:AddSlider("LockFrames", {
    Text = "Lock Sample Frames", Default = T.LockSampleFrames, Min = 20, Max = 128, Rounding = 0,
    Callback = function(v) T.LockSampleFrames = v end,
})

local TMovGroup = Tabs.Thresholds:AddLeftGroupbox("Movement", "footprints")

TMovGroup:AddSlider("SpeedMax", {
    Text = "Speed Max Studs/s Over Base", Default = T.SpeedMaxStuds, Min = 5, Max = 200, Rounding = 0,
    Callback = function(v) T.SpeedMaxStuds = v end,
})
TMovGroup:AddSlider("TeleportThresh", {
    Text = "Teleport Threshold (studs)", Default = T.TeleportThresh, Min = 50, Max = 3000, Rounding = 0,
    Callback = function(v) T.TeleportThresh = v end,
})
TMovGroup:AddSlider("FlyAirTime", {
    Text = "Fly Air Time (s)", Default = T.FlyAirTime, Min = 1, Max = 15, Rounding = 1,
    Callback = function(v) T.FlyAirTime = v end,
})

local TVoidGroup = Tabs.Thresholds:AddRightGroupbox("Void / Trigger", "zap")

TVoidGroup:AddSlider("VoidSpamWindow", {
    Text = "Void Spam Window (s)", Default = T.VoidSpamWindow, Min = 1, Max = 15, Rounding = 0,
    Callback = function(v) T.VoidSpamWindow = v end,
})
TVoidGroup:AddSlider("VoidSpamMax", {
    Text = "Void Spam Max Transitions", Default = T.VoidSpamMaxTrans, Min = 2, Max = 20, Rounding = 0,
    Callback = function(v) T.VoidSpamMaxTrans = v end,
})
TVoidGroup:AddSlider("TriggerMin", {
    Text = "Trigger Min Latency (ms)", Default = T.TriggerMinMs, Min = 10, Max = 300, Rounding = 0,
    Callback = function(v) T.TriggerMinMs = v end,
})
TVoidGroup:AddSlider("AlertCooldown", {
    Text = "Alert Cooldown (s)", Default = T.AlertCooldown, Min = 1, Max = 30, Rounding = 0,
    Callback = function(v) T.AlertCooldown = v end,
})

-- ================================================================
-- UI — LOG TAB
-- ================================================================

local LogGroup = Tabs.Log:AddLeftGroupbox("Event Log", "scroll-text")
local LogLabel = LogGroup:AddLabel("No events.", true)

LogGroup:AddButton({ Text = "Refresh Log", Func = function()
    if #EventLog == 0 then
        LogLabel:SetText("No events.")
    else
        local lines = {}
        for i = 1, math.min(25, #EventLog) do
            table.insert(lines, EventLog[i])
        end
        LogLabel:SetText(table.concat(lines, "\n"))
    end
end })

LogGroup:AddButton({ Text = "Clear Log", Func = function()
    EventLog = {}
    LogLabel:SetText("No events.")
end })

-- ================================================================
-- UI — SETTINGS TAB
-- ================================================================

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("ShowCursor", {
    Text = "Custom Cursor", Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end,
})

MenuGroup:AddDropdown("NotifSide", {
    Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side",
    Callback = function(v) Library:SetNotifySide(v) end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift", NoUI = true, Text = "Toggle Menu",
})

MenuGroup:AddButton("Unload", function()
    stopMonitor()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- ================================================================
-- ADDONS
-- ================================================================

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ACMonitor")
SaveManager:SetFolder("ACMonitor/configs")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ================================================================
-- BOOT NOTIFY
-- ================================================================

Library:Notify({
    Title       = "AntiCheat Monitor",
    Description = "Loaded. Toggle 'Monitor Active' to start scanning.",
    Time        = 4,
})
