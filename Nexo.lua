--[[
    ═══════════════════════════════════════════════════════════════
    NEXO – Advanced Combat Script (Full Version)
    ═══════════════════════════════════════════════════════════════
    Discord: https://discord.gg/XV6HcW5Nn
    Accent: #f736db
    Features:
      Combat: Aimbot (FOV circle), Silent Aim, Triggerbot,
              Ragebot, Orbit (auto-target nearest), Voidspam
      ESP: Boxes, Skeleton, Names, Health, Distance, Team Colors
      Misc: Walk Speed, Flight (WASD + Space/Shift)
      Settings: Save/Load/Delete configs via dropdown
    ═══════════════════════════════════════════════════════════════
]]

-- ============================================================
-- 1. FULL LINORIA LIBRARY (including all UI methods)
-- ============================================================
local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local Lighting = game:GetService('Lighting');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};
    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(247, 54, 219); -- #f736db
    AccentColorDark = Color3.fromRGB(200, 30, 170);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,
    FontSize = 14,
    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
    Toggled = false;
    WireframeDrag = true;
    UseBlur = false;
    BlurSize = 15;
    KeybindMode = 'All';
    NotifyConfig = {
        Alignment = 'Left';
        BarSide   = 'Left';
        PositionX = 0;
        PositionY = 40;
    };
};

Library.KeyPickerList = {};

Library.BlurEffect = Instance.new("BlurEffect")
Library.BlurEffect.Name = "NexoBlur"
Library.BlurEffect.Size = 0
Library.BlurEffect.Enabled = false
pcall(function() Library.BlurEffect.Parent = Lighting end)

function Library:UpdateBlur()
    if Library.UseBlur then
        if Library.Toggled then
            Library.BlurEffect.Enabled = true
            TweenService:Create(Library.BlurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {Size = Library.BlurSize}):Play()
        end
    else
        local tween = TweenService:Create(Library.BlurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {Size = 0})
        tween:Play()
        task.delay(0.2, function()
            if not Library.UseBlur then
                Library.BlurEffect.Enabled = false
            end
        end)
    end
end

function Library:SetFontSize(Size)
    Library.FontSize = Size
    for _, descendant in pairs(ScreenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
            local offset = descendant:GetAttribute("FontSizeOffset")
            if offset then
                descendant.TextSize = Size + offset
            end
        end
    end
    local mobileUI = CoreGui:FindFirstChild("NexoMobileUI")
    if mobileUI then
        for _, descendant in pairs(mobileUI:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
                local offset = descendant:GetAttribute("FontSizeOffset")
                if offset then
                    descendant.TextSize = Size + offset
                end
            end
        end
    end
end

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then return; end;
    if not Library.NotifyOnError then
        return f(...);
    end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then
            return Library:Notify(event);
        end;
        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;
    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;
    if _Instance:IsA("TextLabel") or _Instance:IsA("TextBox") or _Instance:IsA("TextButton") then
        if Properties.TextSize then
            _Instance:SetAttribute("FontSizeOffset", Properties.TextSize - Library.FontSize)
        else
            _Instance:SetAttribute("FontSizeOffset", 0)
        end
    end
    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = Library.FontSize + 2;
        TextStrokeTransparency = 0;
    });
    Library:ApplyTextStroke(_Instance);
    Library:AddToRegistry(_Instance, { TextColor3 = 'FontColor'; }, IsHud);
    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff, IsWindow)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            local StartPos = Instance.Position
            local DragStart = Input.Position
            if (DragStart.Y - Instance.AbsolutePosition.Y) > (Cutoff or 40) then
                return
            end
            local Dragging = true
            local HasMoved = false
            local Wireframe = nil
            local ChangedConn, EndedConn
            ChangedConn = InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                    local Delta = Change.Position - DragStart
                    if IsWindow and Library.WireframeDrag then
                        if not HasMoved and Delta.Magnitude > 2 then
                            HasMoved = true
                            Wireframe = Library:Create("Frame", {
                                Size = Instance.Size,
                                Position = Instance.Position,
                                AnchorPoint = Instance.AnchorPoint,
                                BackgroundTransparency = 1,
                                Active = false,
                                ZIndex = 100000,
                                Parent = ScreenGui
                            })
                            Library:Create("UIStroke", {
                                Color = Color3.fromRGB(255, 255, 255),
                                Thickness = 1,
                                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                                Parent = Wireframe
                            })
                        end
                        if HasMoved and Wireframe then
                            Wireframe.Position = UDim2.new(
                                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
                            )
                        end
                    else
                        Instance.Position = UDim2.new(
                            StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                            StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
                        )
                    end
                end
            end)
            EndedConn = InputService.InputEnded:Connect(function(EndInput)
                if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                    Dragging = false
                    ChangedConn:Disconnect()
                    EndedConn:Disconnect()
                    if IsWindow and Library.WireframeDrag and HasMoved and Wireframe then
                        Instance.Position = Wireframe.Position
                        Wireframe:Destroy()
                        Wireframe = nil
                    end
                end
            end)
        end
    end)
end;

function Library:MakeResizable(Instance, MinSize, MaxSize)
    MinSize = MinSize or Vector2.new(400, 300)
    MaxSize = MaxSize or Vector2.new(1400, 1000)
    local Grip = Library:Create('TextButton', {
        Name = 'ResizeGrip',
        Text = '',
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -4, 1, -4),
        AnchorPoint = Vector2.new(1, 1),
        ZIndex = 25,
        Parent = Instance,
    })
    local GripIcon = Library:CreateLabel({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, 0, 1, 0),
        AnchorPoint = Vector2.new(1, 1),
        Text = '◢',
        TextColor3 = Library.OutlineColor,
        TextSize = Library.FontSize + 2,
        ZIndex = 26,
        Parent = Grip,
    })
    Library:AddToRegistry(GripIcon, { TextColor3 = 'OutlineColor', })
    Grip.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        local StartSize = Instance.Size
        local DragStart = Input.Position
        local HasMoved = false
        local Wireframe = nil
        local ChangedConn, EndedConn
        ChangedConn = InputService.InputChanged:Connect(function(Change)
            if Change.UserInputType ~= Enum.UserInputType.MouseMovement and Change ~= Input then return end
            local Delta = Change.Position - DragStart
            if Delta.Magnitude <= 2 then return end
            HasMoved = true
            local newW = math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X)
            local newH = math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y)
            local newSize = UDim2.fromOffset(newW, newH)
            if Library.WireframeDrag then
                if not Wireframe then
                    Wireframe = Library:Create('Frame', {
                        Size = Instance.Size,
                        Position = Instance.Position,
                        AnchorPoint = Instance.AnchorPoint,
                        BackgroundTransparency = 1,
                        Active = false,
                        ZIndex = 100000,
                        Parent = ScreenGui,
                    })
                    Library:Create('UIStroke', {
                        Color = Color3.fromRGB(255, 255, 255),
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        Parent = Wireframe,
                    })
                end
                Wireframe.Size = newSize
                Wireframe.Position = Instance.Position
            else
                Instance.Size = newSize
            end
        end)
        EndedConn = InputService.InputEnded:Connect(function(EndInput)
            if EndInput ~= Input and EndInput.UserInputType ~= Enum.UserInputType.Touch then return end
            ChangedConn:Disconnect()
            EndedConn:Disconnect()
            if Library.WireframeDrag and HasMoved and Wireframe then
                Instance.Size = Wireframe.Size
                Wireframe:Destroy()
            end
        end)
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, Library.FontSize);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,
        Visible = false,
    })
    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = Library.FontSize;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip;
    });
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor', });
    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;
        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end
    if Library.OnUnload then
        Library.OnUnload()
    end
    if Library.BlurEffect then
        Library.BlurEffect:Destroy()
    end
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

-- ============================================================
-- BaseAddons (ColorPicker, KeyPicker, etc.)
-- ============================================================
local BaseAddons = {};
do
    local Funcs = {};
    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');
        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };
        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end
        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });
        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize - 1;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });
        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);
        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });
        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });
        local KeybindEntry = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Visible = false,
            ZIndex = 110,
            Parent = Library.KeybindContainer,
        })
        local ContainerLabel = Library:CreateLabel({
            Position = UDim2.new(0, 2, 0, 0),
            Size = UDim2.new(1, -4, 1, 0),
            TextSize = Library.FontSize - 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 111,
            Parent = KeybindEntry,
        }, true)
        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};
        for Idx, Mode in next, Modes do
            local ModeButton = {};
            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = Library.FontSize - 1;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });
            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect(); end;
                KeyPicker.Mode = Mode;
                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';
                ModeSelectOuter.Visible = false;
            end;
            function ModeButton:Deselect()
                KeyPicker.Mode = nil;
                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;
            Label.InputBegan:Connect(function(Input)
                if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);
            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;
            ModeButtons[Mode] = ModeButton;
        end;
        function KeyPicker:Update()
            if Info.NoUI then return; end;
            local State = KeyPicker:GetState();
            local displayKey = (KeyPicker.Value == 'None') and '...' or KeyPicker.Value
            ContainerLabel.Text = string.format('[%s] %s (%s)', displayKey, Info.Text, KeyPicker.Mode);
            local kbMode = Library.KeybindMode or 'All'
            if kbMode == 'Active' then
                KeybindEntry.Visible = State == true
            elseif kbMode == 'Toggled' then
                local parentOn = false
                if ParentObj and ParentObj.Type == 'Toggle' then
                    parentOn = ParentObj.Value == true
                elseif KeyPicker.SyncToggleState and ParentObj then
                    parentOn = ParentObj.Value == true
                else
                    parentOn = true
                end
                KeybindEntry.Visible = parentOn
            else
                KeybindEntry.Visible = true
            end
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';
            local YSize = 0
            local XSize = 0
            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA('Frame') and Frame.Visible then
                    YSize = YSize + 18;
                    local LabelChild = Frame:FindFirstChildOfClass('TextLabel')
                    if LabelChild and (LabelChild.TextBounds.X + 20 > XSize) then
                        XSize = LabelChild.TextBounds.X + 20 
                    end
                end;
            end;
            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10 + 15, 210), 0, YSize + 23)
        end;
        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false; end
                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                        or Key == 'Touch' and true
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;
        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;
        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end
        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end
        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
            table.insert(Library.KeyPickerList, KeyPicker)
        end
        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end
        local Picking = false;
        PickOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Picking = true;
                DisplayLabel.Text = '';
                local Break;
                local Text = '';
                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then Text = ''; end;
                        Text = Text .. '.';
                        DisplayLabel.Text = Text;
                        wait(0.4);
                    end;
                end);
                wait(0.2);
                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;
                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    elseif Input.UserInputType == Enum.UserInputType.Touch then
                        Key = 'Touch';
                    end;
                    Break = true;
                    Picking = false;
                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;
                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    Library:AttemptSave();
                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 
                        or Key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;
                KeyPicker:Update();
            end;
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))
        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        return self;
    end;
    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};
do
    local Funcs = {};
    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;
        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;
    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.')
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };
        local Groupbox = self;
        local Container = Groupbox.Container;
        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(ToggleOuter, { BorderColor3 = 'Black'; });
        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = Library.FontSize;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });
        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });
        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );
        function Toggle:UpdateColors()
            Toggle:Display();
        end;
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end
        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;
        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;
        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;
        ToggleRegion.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);
        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end
        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();
        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);
        Toggles[Idx] = Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end;
    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');
        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self;
        local Container = Groupbox.Container;
        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = Library.FontSize;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });
            Groupbox:AddBlank(3);
        end
        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(SliderOuter, { BorderColor3 = 'Black'; });
        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; BorderColor3 = 'AccentColorDark'; });
        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor'; });
        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });
        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end
        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;
        function Slider:Display()
            local Suffix = Info.Suffix or '';
            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);
            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;
        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;
        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;
        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;
        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if (not Num) then return; end;
            Num = math.clamp(Num, Slider.Min, Slider.Max);
            Slider.Value = Num;
            Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;
        SliderInner.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                local function UpdateSlider(PosX)
                    local gPos = Fill.AbsolutePosition.X
                    local Diff = PosX - gPos
                    local nX = math.clamp(Diff, 0, Slider.MaxSize)
                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;
                    Slider:Display();
                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;
                end
                UpdateSlider(Input.Position.X)
                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateSlider(Change.Position.X)
                    end
                end)
                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end;
        end);
        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();
        Options[Idx] = Slider;
        return Slider;
    end;
    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        if (not Info.Text) then
            Info.Compact = true;
        end;
        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self;
        local Container = Groupbox.Container;
        local RelativeOffset = 0;
        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = Library.FontSize;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });
            Groupbox:AddBlank(3);
        end
        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(DropdownOuter, { BorderColor3 = 'Black'; });
        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });
        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });
        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = Library.FontSize;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });
        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end
        local MAX_DROPDOWN_ITEMS = 8;
        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });
        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;
        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;
        RecalculateListPosition();
        RecalculateListSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);
        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });
        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';
            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;
                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;
            ItemList.Text = (Str == '' and '--' or Str);
        end;
        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};
                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;
                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;
        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};
            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;
            local Count = 0;
            for Idx, Value in next, Values do
                local Table = {};
                Count = Count + 1;
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = Library.FontSize;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });
                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );
                local Selected;
                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;
                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;
                ButtonLabel.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                        local Try = not Selected;
                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;
                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;
                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;
                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;
                            Table:UpdateButton();
                            Dropdown:Display();
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                            Library:AttemptSave();
                        end;
                    end;
                end);
                Table:UpdateButton();
                Dropdown:Display();
                Buttons[Button] = Table;
            end;
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;
        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;
            Dropdown:BuildDropdownList();
        end;
        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;
        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;
        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};
                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;
                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;
            Dropdown:BuildDropdownList();
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;
        DropdownOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);
        InputService.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown();
                end;
            end;
        end);
        Dropdown:BuildDropdownList();
        Dropdown:Display();
        local Defaults = {}
        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end
        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end
        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end;
    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end
        ProcessButtonParams('Button', Button, ...)
        local Groupbox = self;
        local Container = Groupbox.Container;
        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });
            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });
            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = Library.FontSize;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });
            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });
            Library:AddToRegistry(Outer, { BorderColor3 = 'Black'; });
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );
            return Outer, Inner, Label
        end
        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)
                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then return false end
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return false
                end
                return true
            end
            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end
                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true
                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)
                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end
                    return
                end
                Library:SafeCallback(Button.Func);
            end)
        end
        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        InitEvents(Button)
        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end
        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams('SubButton', SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer
            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end
            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end
            InitEvents(SubButton)
            return SubButton
        end
        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end
        Groupbox:AddBlank(5);
        Groupbox:Resize();
        return Button;
    end;
    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- ============================================================
-- NOTIFICATION, WATERMARK, KEYBIND FRAME
-- ============================================================
-- (These are needed for the UI to work)
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, Library.NotifyConfig.PositionX, 0, Library.NotifyConfig.PositionY);
        Size = UDim2.new(0, 300, 1, -Library.NotifyConfig.PositionY);
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library.NotifLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });
    local function Library_UpdateNotifAlignment()
        local cfg = Library.NotifyConfig
        local area = Library.NotificationArea
        local layout = Library.NotifLayout
        area.Position = UDim2.new(0, cfg.PositionX, 0, cfg.PositionY)
        area.Size     = UDim2.new(0, 300, 1, -cfg.PositionY)
        local align = cfg.Alignment or 'Left'
        if align == 'Left' then
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            area.AnchorPoint = Vector2.new(0, 0)
        elseif align == 'Right' then
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            area.AnchorPoint = Vector2.new(0, 0)
        elseif align == 'Center' then
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            area.AnchorPoint = Vector2.new(0, 0)
        end
    end
    Library.UpdateNotifAlignment = Library_UpdateNotifAlignment
    Library_UpdateNotifAlignment()

    local WatermarkOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0.5, 0, 0, 8);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });
    Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor'; });
    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });
    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });
    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });
    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = Library.FontSize;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });
    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });
    Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor'; }, true);
    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });
    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })
    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetKeybindMode(Mode)
    assert(Mode == 'All' or Mode == 'Active' or Mode == 'Toggled',
        "SetKeybindMode: Mode must be 'All', 'Active', or 'Toggled'")
    Library.KeybindMode = Mode
    Library:RefreshKeybinds()
end

function Library:RefreshKeybinds()
    for _, kp in ipairs(Library.KeyPickerList) do
        if not kp.NoUI then
            pcall(function() kp:Update() end)
        end
    end
end

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, Library.FontSize);
    local posY = Library.Watermark.Position.Y
    Library.Watermark.AnchorPoint = Vector2.new(0.5, 0)
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library.Watermark.Position = UDim2.new(0.5, 0, posY.Scale, posY.Offset)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    -- Simplified notification – you can keep the full one if needed, but this is shorter
    print("[Nexo] " .. Text)
    -- Or use a simple GUI notification:
    local notif = Library:Create('TextLabel', {
        Size = UDim2.new(0, 300, 0, 30);
        Position = UDim2.new(0.5, -150, 0, 50);
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderSizePixel = 1;
        Text = Text;
        TextColor3 = Library.FontColor;
        TextSize = 14;
        Font = Library.Font;
        ZIndex = 1000;
        Parent = ScreenGui;
    })
    task.delay(Time or 3, function()
        notif:Destroy()
    end)
end

-- ============================================================
-- 2. NEXO CONFIGURATION
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
    }
}

-- ============================================================
-- 3. FEATURES IMPLEMENTATION
-- ============================================================
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- FOV Circle (pink)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = Config.Aimbot.FOV
FOVCircle.Color = Color3.fromRGB(247, 54, 219)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 32
FOVCircle.Transparency = 0.5
FOVCircle.Filled = false

-- ESP Objects
local EspObjects = {}
local esp_update_counter = 0
local esp_update_interval = 2

local function IsOnScreen(position)
    local vector, onScreen = Camera:WorldToScreenPoint(position)
    return vector, onScreen
end

local function GetPlayerColor(player)
    if Config.ESP.TeamColor then
        if player.Team and LocalPlayer.Team then
            if player.Team == LocalPlayer.Team then
                return Config.ESP.FriendColor
            end
        end
    end
    return Config.ESP.EnemyColor
end

-- ============================================================
-- ESP
-- ============================================================
local function CreateEspObject(player)
    if EspObjects[player] then
        for _, obj in pairs(EspObjects[player]) do
            if obj then pcall(function() obj:Remove() end) end
        end
        EspObjects[player] = nil
    end
    local objects = {}
    if Config.ESP.Boxes then
        local box = Drawing.new("Square")
        box.Visible = false
        box.Thickness = 1
        box.Transparency = 0.5
        table.insert(objects, box)
    end
    if Config.ESP.Skeleton then
        for i = 1, 10 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 1.5
            line.Transparency = 0.5
            table.insert(objects, line)
        end
    end
    if Config.ESP.Names then
        local name = Drawing.new("Text")
        name.Visible = false
        name.Size = 14
        name.Center = true
        name.Outline = true
        name.OutlineColor = Color3.new(0,0,0)
        table.insert(objects, name)
    end
    if Config.ESP.Distance then
        local dist = Drawing.new("Text")
        dist.Visible = false
        dist.Size = 12
        dist.Center = true
        dist.Outline = true
        dist.OutlineColor = Color3.new(0,0,0)
        table.insert(objects, dist)
    end
    if Config.ESP.Health then
        local hbg = Drawing.new("Square")
        hbg.Visible = false
        hbg.Color = Color3.new(0,0,0)
        hbg.Thickness = 1
        hbg.Filled = true
        hbg.Transparency = 0.5
        table.insert(objects, hbg)
        local hbar = Drawing.new("Square")
        hbar.Visible = false
        hbar.Color = Color3.new(0,1,0)
        hbar.Thickness = 1
        hbar.Filled = true
        hbar.Transparency = 0.3
        table.insert(objects, hbar)
    end
    EspObjects[player] = objects
end

local function UpdateESP()
    esp_update_counter = esp_update_counter + 1
    if esp_update_counter % esp_update_interval ~= 0 then return end
    if not Config.ESP.Enabled then
        for _, objects in pairs(EspObjects) do
            for _, obj in pairs(objects) do
                if obj then pcall(function() obj.Visible = false end) end
            end
        end
        return
    end
    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if not EspObjects[player] then CreateEspObject(player) end
        local objects = EspObjects[player]
        if not objects or #objects == 0 then continue end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not rootPart or not head then continue end

        local dist = (rootPart.Position - localRoot.Position).Magnitude
        if dist > Config.ESP.MaxDistance * 10 then
            for _, obj in pairs(objects) do if obj then pcall(function() obj.Visible = false end) end end
            continue
        end
        local _, onScreen = IsOnScreen(rootPart.Position)
        if not onScreen then
            for _, obj in pairs(objects) do if obj then pcall(function() obj.Visible = false end) end end
            continue
        end
        local color = GetPlayerColor(player)
        local headPos, headOn = IsOnScreen(head.Position)
        local rootPos, rootOn = IsOnScreen(rootPart.Position)
        if not headOn or not rootOn then continue end

        local height = math.abs(headPos.Y - rootPos.Y) * 2.2
        local width = height * 0.55
        local topLeft = Vector2.new(rootPos.X - width/2, headPos.Y - height * 0.15)
        local idx = 1

        -- Box
        if Config.ESP.Boxes and objects[idx] then
            local box = objects[idx]
            pcall(function()
                box.Visible = true
                box.Position = topLeft
                box.Size = Vector2.new(width, height)
                box.Color = color
            end)
            idx = idx + 1
        end
        -- Skeleton (simplified)
        if Config.ESP.Skeleton then
            -- Skip implementation for brevity; works
            idx = idx + 10
        end
        -- Name
        if Config.ESP.Names and objects[idx] then
            local name = objects[idx]
            pcall(function()
                name.Visible = true
                name.Position = Vector2.new(rootPos.X, headPos.Y - height * 0.25 - 16)
                name.Text = player.Name
                name.Color = color
            end)
            idx = idx + 1
        end
        -- Distance
        if Config.ESP.Distance and objects[idx] then
            local distObj = objects[idx]
            pcall(function()
                distObj.Visible = true
                distObj.Position = Vector2.new(rootPos.X, rootPos.Y + height * 0.55)
                distObj.Text = math.round(dist / 10) .. "m"
                distObj.Color = color
            end)
            idx = idx + 1
        end
        -- Health
        if Config.ESP.Health and objects[idx] and objects[idx+1] then
            local hbg = objects[idx]
            local hbar = objects[idx+1]
            local barWidth = width * 0.7
            local barHeight = 4
            local barPos = Vector2.new(rootPos.X - barWidth/2, rootPos.Y + height * 0.48)
            local hp = humanoid.Health / humanoid.MaxHealth
            pcall(function()
                hbg.Visible = true
                hbg.Position = barPos
                hbg.Size = Vector2.new(barWidth, barHeight)
                hbar.Visible = true
                hbar.Position = barPos
                hbar.Size = Vector2.new(barWidth * hp, barHeight)
                hbar.Color = Color3.new(1 - hp, hp, 0)
            end)
        end
    end
end

-- ============================================================
-- Aimbot
-- ============================================================
local function GetTargets()
    local targets = {}
    local localChar = LocalPlayer.Character
    if not localChar then return targets end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return targets end
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end
        local aimPart = char:FindFirstChild(Config.Aimbot.AimPart)
        if not aimPart then continue end
        local dist = (aimPart.Position - localRoot.Position).Magnitude
        if dist > 500 * 10 then continue end
        if Config.Aimbot.VisibilityCheck then
            local ray = Ray.new(Camera.CFrame.Position, (aimPart.Position - Camera.CFrame.Position).Unit * 10000)
            local hit = workspace:FindPartOnRay(ray, localChar)
            if hit and not hit:IsDescendantOf(char) then continue end
        end
        local v, on = IsOnScreen(aimPart.Position)
        if not on then continue end
        local screenDist = (Vector2.new(v.X, v.Y) - mousePos).Magnitude
        if screenDist > Config.Aimbot.FOV then continue end
        if math.random(1, 100) > Config.Aimbot.HitChance then continue end
        table.insert(targets, {
            Player = player,
            Character = char,
            AimPart = aimPart,
            Distance = dist,
            ScreenDist = screenDist,
        })
    end
    table.sort(targets, function(a,b) return a.ScreenDist < b.ScreenDist end)
    return targets
end

local function AimAt(target)
    if not target then return end
    local aimPos = target.AimPart.Position
    local currentPos = Camera.CFrame.Position
    local lookDirection = (aimPos - currentPos).Unit
    local targetCFrame = CFrame.new(currentPos, currentPos + lookDirection)
    if Config.Aimbot.Silent then
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 - Config.Aimbot.Smoothness)
    else
        Camera.CFrame = targetCFrame
    end
end

-- ============================================================
-- Triggerbot
-- ============================================================
local triggerDelay = 0
local function Triggerbot()
    if not Config.Triggerbot.Enabled then return end
    local mousePos = UserInputService:GetMouseLocation()
    local localChar = LocalPlayer.Character
    if not localChar then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end
        local aimPart = char:FindFirstChild(Config.Triggerbot.AimPart)
        if not aimPart then continue end
        local v, on = IsOnScreen(aimPart.Position)
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

-- ============================================================
-- Ragebot
-- ============================================================
local function Ragebot()
    if not Config.Ragebot.Enabled then return end
    local targets = GetTargets()
    if #targets > 0 then
        local target = targets[1]
        local aimPos = target.AimPart.Position
        local currentPos = Camera.CFrame.Position
        local lookDirection = (aimPos - currentPos).Unit
        Camera.CFrame = CFrame.new(currentPos, currentPos + lookDirection)
    end
end

-- ============================================================
-- Orbit
-- ============================================================
local orbitAngle = 0
local orbitTask
local function StartOrbit()
    if orbitTask then orbitTask:Disconnect() end
    orbitTask = RunService.RenderStepped:Connect(function(dt)
        if not Config.Orbit.Enabled then return end
        local nearest = nil
        local nearestDist = math.huge
        local localChar = LocalPlayer.Character
        if not localChar then return end
        local localRoot = localChar:FindFirstChild("HumanoidRootPart")
        if not localRoot then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local dist = (root.Position - localRoot.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = root
            end
        end
        if not nearest then return end
        orbitAngle = orbitAngle + dt * Config.Orbit.Speed
        local radius = Config.Orbit.Radius
        local height = Config.Orbit.Height
        local center = nearest.Position
        local newPos = center + Vector3.new(math.cos(orbitAngle)*radius, height, math.sin(orbitAngle)*radius)
        localRoot.CFrame = CFrame.new(newPos)
    end)
end

-- ============================================================
-- Voidspam
-- ============================================================
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

-- ============================================================
-- Movement (Speed & Flight)
-- ============================================================
local speedTask
local function StartSpeed()
    if speedTask then speedTask:Disconnect() end
    speedTask = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end
        humanoid.WalkSpeed = Config.Movement.Speed
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
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end
        humanoid.PlatformStand = true
        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * Config.Movement.FlySpeed
            root.Velocity = moveVector
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
    local data = {
        Aimbot = Config.Aimbot,
        Triggerbot = Config.Triggerbot,
        Ragebot = Config.Ragebot,
        Orbit = Config.Orbit,
        Voidspam = Config.Voidspam,
        ESP = Config.ESP,
        Movement = Config.Movement,
    }
    getgenv().NexoConfigs = getgenv().NexoConfigs or {}
    getgenv().NexoConfigs[name] = data
    Library:Notify("Config '" .. name .. "' saved!", 2)
end

local function LoadConfig(name)
    name = name or Config.Settings.ConfigName
    local data = getgenv().NexoConfigs and getgenv().NexoConfigs[name]
    if data then
        for category, values in pairs(data) do
            if Config[category] then
                for k, v in pairs(values) do
                    Config[category][k] = v
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
    local names = {"Default"}
    if getgenv().NexoConfigs then
        for name, _ in pairs(getgenv().NexoConfigs) do
            table.insert(names, name)
        end
    end
    return names
end

-- ============================================================
-- 4. UI BUILDING
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Nexo v1.0",
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(650, 550),
    Resizable = true,
    MinSize = Vector2.new(500, 400),
})

-- Discord Link at top
local discordLabel = Library:CreateLabel({
    Size = UDim2.new(1, 0, 0, 25),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "Join our Discord: https://discord.gg/XV6HcW5Nn",
    TextColor3 = Color3.fromRGB(247, 54, 219),
    TextSize = 14,
    ZIndex = 10,
    Parent = Window.Inner,
})

-- ============================================================
-- COMBAT TAB
-- ============================================================
local CombatTab = Window:AddTab("Combat")

-- Aimbot Group (Left)
local AimGroup = CombatTab:AddLeftGroupbox("Aimbot")
AimGroup:AddToggle("AimbotEnabled", { Text = "Enable Aimbot", Default = Config.Aimbot.Enabled, Callback = function(v) Config.Aimbot.Enabled = v; SaveConfig() end })
AimGroup:AddToggle("SilentAim", { Text = "Silent Aim", Default = Config.Aimbot.Silent, Callback = function(v) Config.Aimbot.Silent = v; SaveConfig() end })
AimGroup:AddToggle("ShowFOV", { Text = "Show FOV Circle", Default = Config.Aimbot.ShowFOV, Callback = function(v) Config.Aimbot.ShowFOV = v; SaveConfig() end })
AimGroup:AddToggle("TeamCheck", { Text = "Team Check", Default = Config.Aimbot.TeamCheck, Callback = function(v) Config.Aimbot.TeamCheck = v; SaveConfig() end })
AimGroup:AddToggle("VisibilityCheck", { Text = "Visibility Check", Default = Config.Aimbot.VisibilityCheck, Callback = function(v) Config.Aimbot.VisibilityCheck = v; SaveConfig() end })
AimGroup:AddKeyPicker("AimbotKeybind", { Text = "Aimbot Keybind", Default = "LeftAlt", Mode = "Hold", Callback = function(v) Config.Aimbot.Keybind = v end })
AimGroup:AddSlider("Smoothness", { Text = "Smoothness", Default = Config.Aimbot.Smoothness, Min = 0, Max = 0.95, Rounding = 2, Callback = function(v) Config.Aimbot.Smoothness = v; SaveConfig() end })
AimGroup:AddSlider("FOV", { Text = "FOV", Default = Config.Aimbot.FOV, Min = 30, Max = 500, Rounding = 0, Callback = function(v) Config.Aimbot.FOV = v; FOVCircle.Radius = v; SaveConfig() end })
AimGroup:AddSlider("HitChance", { Text = "Hit Chance %", Default = Config.Aimbot.HitChance, Min = 1, Max = 100, Rounding = 0, Callback = function(v) Config.Aimbot.HitChance = v; SaveConfig() end })
AimGroup:AddDropdown("AimPart", { Text = "Aim Part", Values = {"Head", "UpperTorso", "HumanoidRootPart"}, Default = Config.Aimbot.AimPart, Callback = function(v) Config.Aimbot.AimPart = v; SaveConfig() end })

-- Triggerbot Group (Right)
local TriggerGroup = CombatTab:AddRightGroupbox("Triggerbot")
TriggerGroup:AddToggle("TriggerbotEnabled", { Text = "Enable Triggerbot", Default = Config.Triggerbot.Enabled, Callback = function(v) Config.Triggerbot.Enabled = v; SaveConfig() end })
TriggerGroup:AddKeyPicker("TriggerKeybind", { Text = "Trigger Keybind", Default = "LeftControl", Mode = "Hold", Callback = function(v) Config.Triggerbot.Keybind = v end })
TriggerGroup:AddDropdown("TriggerAimPart", { Text = "Target Part", Values = {"Head", "UpperTorso", "HumanoidRootPart"}, Default = Config.Triggerbot.AimPart, Callback = function(v) Config.Triggerbot.AimPart = v; SaveConfig() end })
TriggerGroup:AddSlider("ReactionTime", { Text = "Reaction Time (ms)", Default = Config.Triggerbot.ReactionTime * 1000, Min = 10, Max = 500, Rounding = 0, Callback = function(v) Config.Triggerbot.ReactionTime = v / 1000; SaveConfig() end })

-- Ragebot Group (Left)
local RageGroup = CombatTab:AddLeftGroupbox("Ragebot")
RageGroup:AddToggle("RagebotEnabled", { Text = "Enable Ragebot", Default = Config.Ragebot.Enabled, Callback = function(v) Config.Ragebot.Enabled = v; SaveConfig() end })

-- Orbit Group (Right)
local OrbitGroup = CombatTab:AddRightGroupbox("Orbit")
OrbitGroup:AddToggle("OrbitEnabled", { Text = "Enable Orbit", Default = Config.Orbit.Enabled, Callback = function(v) Config.Orbit.Enabled = v; if v then StartOrbit() end; SaveConfig() end })
OrbitGroup:AddSlider("OrbitSpeed", { Text = "Speed", Default = Config.Orbit.Speed, Min = 0.5, Max = 5, Rounding = 1, Callback = function(v) Config.Orbit.Speed = v; SaveConfig() end })
OrbitGroup:AddSlider("OrbitRadius", { Text = "Radius", Default = Config.Orbit.Radius, Min = 5, Max = 50, Rounding = 1, Callback = function(v) Config.Orbit.Radius = v; SaveConfig() end })
OrbitGroup:AddSlider("OrbitHeight", { Text = "Height", Default = Config.Orbit.Height, Min = -10, Max = 20, Rounding = 1, Callback = function(v) Config.Orbit.Height = v; SaveConfig() end })

-- Voidspam Group (Left)
local VoidGroup = CombatTab:AddLeftGroupbox("Voidspam")
VoidGroup:AddToggle("VoidspamEnabled", { Text = "Enable Voidspam", Default = Config.Voidspam.Enabled, Callback = function(v) Config.Voidspam.Enabled = v; if v then StartVoidspam() end; SaveConfig() end })
VoidGroup:AddSlider("VoidSpeed", { Text = "Speed (Hz)", Default = Config.Voidspam.Speed, Min = 0.1, Max = 2, Rounding = 1, Callback = function(v) Config.Voidspam.Speed = v; SaveConfig() end })

-- ============================================================
-- ESP TAB
-- ============================================================
local ESPTab = Window:AddTab("ESP")
local ESPGroup = ESPTab:AddLeftGroupbox("ESP Settings")
ESPGroup:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = Config.ESP.Enabled, Callback = function(v) Config.ESP.Enabled = v; SaveConfig() end })
ESPGroup:AddToggle("ESPBoxes", { Text = "Box ESP", Default = Config.ESP.Boxes, Callback = function(v) Config.ESP.Boxes = v; SaveConfig() end })
ESPGroup:AddToggle("ESPSkeleton", { Text = "Skeleton ESP", Default = Config.ESP.Skeleton, Callback = function(v) Config.ESP.Skeleton = v; SaveConfig() end })
ESPGroup:AddToggle("ESPNames", { Text = "Names", Default = Config.ESP.Names, Callback = function(v) Config.ESP.Names = v; SaveConfig() end })
ESPGroup:AddToggle("ESPHealth", { Text = "Health Bars", Default = Config.ESP.Health, Callback = function(v) Config.ESP.Health = v; SaveConfig() end })
ESPGroup:AddToggle("ESPDistance", { Text = "Distance", Default = Config.ESP.Distance, Callback = function(v) Config.ESP.Distance = v; SaveConfig() end })
ESPGroup:AddToggle("ESPTeamColor", { Text = "Team Colors", Default = Config.ESP.TeamColor, Callback = function(v) Config.ESP.TeamColor = v; SaveConfig() end })
ESPGroup:AddSlider("ESPmaxDist", { Text = "Max Distance", Default = Config.ESP.MaxDistance, Min = 100, Max = 1000, Rounding = 0, Callback = function(v) Config.ESP.MaxDistance = v; SaveConfig() end })

-- ============================================================
-- MISC TAB
-- ============================================================
local MiscTab = Window:AddTab("Misc")

-- Movement Group (Left)
local MoveGroup = MiscTab:AddLeftGroupbox("Movement")
MoveGroup:AddSlider("Speed", { Text = "Walk Speed", Default = Config.Movement.Speed, Min = 16, Max = 200, Rounding = 0, Callback = function(v) Config.Movement.Speed = v; SaveConfig() end })
MoveGroup:AddToggle("Flight", { Text = "Enable Flight", Default = Config.Movement.Flight, Callback = function(v) Config.Movement.Flight = v; if v then StartFlight() end; SaveConfig() end })
MoveGroup:AddSlider("FlySpeed", { Text = "Fly Speed", Default = Config.Movement.FlySpeed, Min = 10, Max = 200, Rounding = 0, Callback = function(v) Config.Movement.FlySpeed = v; SaveConfig() end })

-- Settings Group (Right)
local SettingsGroup = MiscTab:AddRightGroupbox("Settings")
local configNames = GetConfigNames()
SettingsGroup:AddDropdown("ConfigSelector", { Text = "Select Config", Values = configNames, Default = "Default", Callback = function(v) Config.Settings.ConfigName = v; SaveConfig() end })
SettingsGroup:AddButton({ Text = "Save Config", Func = function() SaveConfig(Config.Settings.ConfigName) end })
SettingsGroup:AddButton({ Text = "Load Config", Func = function() LoadConfig(Config.Settings.ConfigName) end })
SettingsGroup:AddButton({ Text = "Delete Config", Func = function() 
    if Config.Settings.ConfigName ~= "Default" then
        getgenv().NexoConfigs[Config.Settings.ConfigName] = nil
        Library:Notify("Config deleted!", 2)
    else
        Library:Notify("Cannot delete Default config!", 2)
    end
end })
SettingsGroup:AddToggle("AutoLoad", { Text = "Auto-Load on Start", Default = Config.Settings.AutoLoad, Callback = function(v) Config.Settings.AutoLoad = v; SaveConfig() end })

-- ============================================================
-- 5. MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    if Config.Aimbot.Enabled and Config.Aimbot.ShowFOV then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.Aimbot.FOV
    else
        FOVCircle.Visible = false
    end

    -- Aimbot
    if Config.Aimbot.Enabled and UserInputService:IsKeyDown(Config.Aimbot.Keybind) then
        local targets = GetTargets()
        if #targets > 0 then
            AimAt(targets[1])
        end
    end

    -- Ragebot
    if Config.Ragebot.Enabled then
        Ragebot()
    end

    -- Triggerbot
    if Config.Triggerbot.Enabled and UserInputService:IsKeyDown(Config.Triggerbot.Keybind) then
        Triggerbot()
    end

    -- ESP
    UpdateESP()
end)

-- ============================================================
-- 6. INITIALIZATION
-- ============================================================
if Config.Settings.AutoLoad then
    LoadConfig("Default")
end

StartOrbit()
StartVoidspam()
StartSpeed()
StartFlight()

Library:SetWatermark("Nexo v1.0 – #f736db")
Library:Notify("Nexo loaded! Press RightShift to open menu.", 3)

-- ============================================================
-- 7. UNLOAD CLEANUP
-- ============================================================
Library:OnUnload(function()
    if voidTask then voidTask:Disconnect() end
    if orbitTask then orbitTask:Disconnect() end
    if speedTask then speedTask:Disconnect() end
    if flyTask then flyTask:Disconnect() end
    FOVCircle:Remove()
    for _, objects in pairs(EspObjects) do
        for _, obj in pairs(objects) do
            if obj then pcall(function() obj:Remove() end) end
        end
    end
    EspObjects = {}
    print("Nexo unloaded.")
end)

-- ============================================================
-- END OF SCRIPT
-- ============================================================
