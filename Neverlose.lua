-- // Neverlose UI Library (Roblox Luau port)
-- // Visual + behavioral 1:1 of the Neverlose Dear ImGui menu
-- //   (colors from gui.hpp, layout from main.cpp of the Neverlose DX9 example)
-- // Builder API in the style of Pandora.lua

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TextService      = game:GetService("TextService")

-- // CoreGui ref (executor-safe; falls back to PlayerGui)
local CoreGui
do
    local ok, cgui = pcall(function()
        if typeof(cloneref) == "function" then
            return cloneref(game:GetService("CoreGui"))
        end
        return game:GetService("CoreGui")
    end)
    CoreGui = ok and cgui or game:GetService("CoreGui")
end

-- =====================================================================
-- // [SECTION] Theme — exact Neverlose palette from gui.hpp
-- =====================================================================
local Theme = {
    -- ImGui ImVec4 (r,g,b,a) → RGB conversions from gui.hpp:26-40
    Accent         = Color3.fromRGB(77, 125, 255),  -- (0.30, 0.49, 1.00)
    Text           = Color3.fromRGB(255, 255, 255), -- (1, 1, 1)
    TextSecondary  = Color3.fromRGB(255, 255, 255), -- text @ 0.5 alpha (used at runtime)
    TextDisabled   = Color3.fromRGB(130, 133, 143), -- (0.51, 0.52, 0.56)
    Border         = Color3.fromRGB(255, 255, 255), -- white @ 0.03 alpha (set via Transparency)
    BorderAlpha    = 0.97,

    FrameInactive  = Color3.fromRGB(6, 10, 18),    -- (0.023, 0.039, 0.070)
    FrameActive    = Color3.fromRGB(11, 18, 35),   -- (0.043, 0.070, 0.137)

    Button         = Color3.fromRGB(8, 9, 15),     -- (0.031, 0.035, 0.058)
    ButtonHover    = Color3.fromRGB(13, 14, 20),   -- (0.050, 0.054, 0.078)
    ButtonActive   = Color3.fromRGB(18, 19, 25),   -- (0.070, 0.074, 0.098)

    GroupBoxBg     = Color3.fromRGB(5, 9, 16),     -- (0.019, 0.035, 0.062)

    -- Convenience extras (derived, not from C++)
    Background     = Color3.fromRGB(6, 10, 18),    -- same as FrameInactive (window root)
    Sidebar        = Color3.fromRGB(5, 9, 16),     -- same as GroupBoxBg
    Success        = Color3.fromRGB(46, 204, 113),
    Danger         = Color3.fromRGB(231, 76, 60),
    Warning        = Color3.fromRGB(241, 196, 15),
    White          = Color3.fromRGB(255, 255, 255),
    Black          = Color3.fromRGB(0, 0, 0),
}

-- =====================================================================
-- // [SECTION] Library state
-- =====================================================================
local Library = {
    Theme           = Theme,
    Toggles         = {},
    Options         = {},
    Unloaded        = false,
    ScreenGui       = nil,
    Window          = nil,
    OverlayFrame    = nil,
    OverlayButton   = nil,
    OpenedPopup     = nil,
    UnloadCallbacks = {},
    Connections     = {},
    ActiveKeybinds  = {},
    WatermarkFrame  = nil,
    KeybindListFrame= nil,
    WatermarkText   = "Neverlose.lua",
    ToggleKey       = Enum.KeyCode.RightControl,
}

-- =====================================================================
-- // [SECTION] Utility helpers
-- =====================================================================
local function Create(Class, Props, Children)
    local Inst = Instance.new(Class)
    for K, V in pairs(Props) do
        if K ~= "Parent" then
            Inst[K] = V
        end
    end
    if Children then
        for _, Child in ipairs(Children) do
            Child.Parent = Inst
        end
    end
    if Props.Parent then
        Inst.Parent = Props.Parent
    end
    return Inst
end

local function Tween(Inst, Time, Props, Style, Dir)
    local Info = TweenInfo.new(Time, Style or Enum.EasingStyle.Quart, Dir or Enum.EasingDirection.Out)
    local T = TweenService:Create(Inst, Info, Props)
    T:Play()
    return T
end

local function AddCorner(Inst, Radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, Radius or 4), Parent = Inst })
end

local function AddStroke(Inst, Color, Thickness, Transparency)
    return Create("UIStroke", {
        Color = Color or Theme.Border,
        Thickness = Thickness or 1,
        Transparency = Transparency or Theme.BorderAlpha,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = Inst,
    })
end

local function AddPadding(Inst, Top, Right, Bottom, Left)
    return Create("UIPadding", {
        PaddingTop    = UDim.new(0, Top or 0),
        PaddingRight  = UDim.new(0, Right or 0),
        PaddingBottom = UDim.new(0, Bottom or 0),
        PaddingLeft   = UDim.new(0, Left or 0),
        Parent = Inst,
    })
end

local function AddGradient(Inst, Color1, Color2, Rotation)
    return Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color1),
            ColorSequenceKeypoint.new(1, Color2),
        }),
        Rotation = Rotation or 0,
        Parent = Inst,
    })
end

local function MakeDraggable(Frame, Handle)
    local Dragging, DragInput, DragStart, StartPos = false

    Handle.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = Input.Position
            StartPos  = Frame.Position
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    Handle.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement
        or Input.UserInputType == Enum.UserInputType.Touch then
            DragInput = Input
        end
    end)

    local DragConn = UserInputService.InputChanged:Connect(function(Input)
        if Dragging and Input == DragInput then
            local Delta = Input.Position - DragStart
            Frame.Position = UDim2.new(
                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
            )
        end
    end)
    table.insert(Library.Connections, DragConn)
end

-- // Convert an icon string into either an ImageLabel asset or a text glyph
local function IsImageIcon(Icon)
    if typeof(Icon) ~= "string" then return false end
    return Icon:match("^rbxassetid://%d+$") ~= nil
        or Icon:match("^rbxasset://") ~= nil
        or Icon:match("^http") ~= nil
end

-- =====================================================================
-- // [SECTION] Popup management
-- =====================================================================
local function CloseActivePopup()
    if Library.OpenedPopup then
        local ok = pcall(Library.OpenedPopup.Close)
        Library.OpenedPopup = nil
    end
    if Library.OverlayButton then
        Library.OverlayButton.Visible = false
    end
end

Library.CloseActivePopup = CloseActivePopup

-- =====================================================================
-- // [SECTION] Element state base
-- =====================================================================
local function CreateElementState(Key, Default)
    local State = {
        Key       = Key,
        Value     = Default,
        Callbacks = {},
    }

    function State:OnChanged(Fn)
        table.insert(self.Callbacks, Fn)
        task.spawn(Fn, self.Value)
        return self
    end

    function State:SetValue(NewVal)
        if self.Value == NewVal and typeof(NewVal) ~= "table" then return end
        self.Value = NewVal
        for _, Fn in ipairs(self.Callbacks) do
            task.spawn(Fn, NewVal)
        end
    end

    return State
end

Library.CreateElementState = CreateElementState

-- =====================================================================
-- // [SECTION] Keybind spectator list updates
-- =====================================================================
local function UpdateKeybindList()
    if not Library.KeybindListFrame then return end
    local Container = Library.KeybindListFrame:FindFirstChild("Container", true)
    if not Container then return end

    for _, Child in ipairs(Container:GetChildren()) do
        if Child:IsA("Frame") then Child:Destroy() end
    end

    local Count = 0
    for Name, Bind in pairs(Library.ActiveKeybinds) do
        if Bind.Active then
            Count = Count + 1
            local Row = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Parent = Container,
            })

            Create("TextLabel", {
                Size = UDim2.new(0.6, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = Name,
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Row,
            })

            Create("TextLabel", {
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = "[" .. Bind.Mode .. "]",
                TextColor3 = Theme.Accent,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = Row,
            })
        end
    end

    Library.KeybindListFrame.Visible = (Count > 0)
end

Library.UpdateKeybindList = UpdateKeybindList

-- =====================================================================
-- // [SECTION] Watermark API
-- =====================================================================
function Library:SetWatermark(Text)
    Library.WatermarkText = Text
    if Library.WatermarkFrame then
        local Label = Library.WatermarkFrame:FindFirstChild("WatermarkLabel", true)
        if Label then Label.Text = Text end
        local TextSize = TextService:GetTextSize(Text, 12, Enum.Font.GothamMedium, Vector2.new(1000, 16))
        Library.WatermarkFrame.Size = UDim2.fromOffset(TextSize.X + 20, 24)
    end
end

function Library:SetWatermarkVisibility(Visible)
    if Library.WatermarkFrame then
        Library.WatermarkFrame.Visible = Visible
    end
end

function Library:SetKeybindsListVisibility(Visible)
    if Library.KeybindListFrame then
        Library.KeybindListFrame.Visible = Visible
    end
end

-- =====================================================================
-- // [SECTION] Notifications
-- =====================================================================
local NotificationHolder

function Library:Notify(Config)
    if not NotificationHolder then return end
    local Title       = Config.Title or "Neverlose"
    local Description = Config.Description or ""
    local Duration    = Config.Time or 5

    local NotifFrame = Create("Frame", {
        Size = UDim2.fromOffset(260, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.GroupBoxBg,
        ClipsDescendants = true,
        Parent = NotificationHolder,
    })
    AddCorner(NotifFrame, 4)
    AddStroke(NotifFrame, Theme.Border, 1, Theme.BorderAlpha)

    -- Accent left stripe
    local Stripe = Create("Frame", {
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = NotifFrame,
    })

    local Content = Create("Frame", {
        Size = UDim2.new(1, -10, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Parent = NotifFrame,
    })
    AddPadding(Content, 6, 6, 6, 4)
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = Content,
    })

    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = Title:upper(),
        TextColor3 = Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Content,
    })

    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = Description,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = Content,
    })

    local ProgressBg = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Button,
        BorderSizePixel = 0,
        LayoutOrder = 10,
        Parent = Content,
    })
    local ProgressFill = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = ProgressBg,
    })

    -- Slide in
    NotifFrame.Position = UDim2.new(1, 50, 0, 0)
    Tween(NotifFrame, 0.35, { Position = UDim2.new(0, 0, 0, 0) })

    -- Countdown
    Tween(ProgressFill, Duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)

    task.delay(Duration, function()
        if NotifFrame and NotifFrame.Parent then
            local T = Tween(NotifFrame, 0.35, { Position = UDim2.new(1, 50, 0, 0) })
            T.Completed:Wait()
            NotifFrame:Destroy()
        end
    end)
end

-- =====================================================================
-- // [SECTION] Unload
-- =====================================================================
function Library:OnUnload(Callback)
    table.insert(Library.UnloadCallbacks, Callback)
end

function Library:Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true

    for _, Callback in ipairs(Library.UnloadCallbacks) do
        pcall(Callback)
    end

    for _, Conn in ipairs(Library.Connections) do
        if typeof(Conn) == "RBXScriptConnection" then
            pcall(function() Conn:Disconnect() end)
        end
    end

    if Library.ScreenGui then
        Library.ScreenGui:Destroy()
    end
end

-- =====================================================================
-- // [SECTION] Toggle / Checkbox base (with keypicker + colorpicker extensions)
-- =====================================================================
local ToggleMethods = {}
ToggleMethods.__index = ToggleMethods

function ToggleMethods:OnChanged(Fn)
    self.State:OnChanged(Fn)
    return self
end

function ToggleMethods:SetValue(Val)
    self.State:SetValue(Val)
    self:UpdateVisual(Val)
    return self
end

-- // Inline key picker attached to a toggle row (Pandora style)
function ToggleMethods:AddKeyPicker(Key, Config)
    Config = Config or {}
    local DefaultKey = Config.Default or "None"
    local Mode       = Config.Mode    or "Toggle" -- Toggle | Hold | Always

    local Picker = {
        Value    = Enum.KeyCode[DefaultKey] or Enum.KeyCode.Unknown,
        Mode     = Mode,
        Picking  = false,
        Active   = (Mode == "Always"),
    }

    local PickerBtn = Create("TextButton", {
        Size = UDim2.fromOffset(40, 16),
        BackgroundColor3 = Theme.Button,
        Text = Picker.Value == Enum.KeyCode.Unknown and "[None]" or ("[" .. Picker.Value.Name .. "]"),
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        AutoButtonColor = false,
        Parent = self.RightControls,
    })
    AddCorner(PickerBtn, 3)
    AddStroke(PickerBtn, Theme.Border, 1, Theme.BorderAlpha)

    local ModePopup
    local function CloseModePopup()
        if ModePopup then
            ModePopup:Destroy()
            ModePopup = nil
        end
    end

    local function SetActive(Active)
        Picker.Active = Active
        Library.ActiveKeybinds[self.Text or self.Key] = {
            Active = Active,
            Mode   = Picker.Mode,
        }
        UpdateKeybindList()

        if Active and Picker.Mode == "Toggle" then
            self.State:SetValue(not self.State.Value)
            self:UpdateVisual(self.State.Value)
        elseif Picker.Mode == "Hold" then
            self.State:SetValue(Active)
            self:UpdateVisual(Active)
        end
    end

    PickerBtn.MouseButton1Click:Connect(function()
        CloseActivePopup()
        Picker.Picking = true
        PickerBtn.Text = "[...]"
        PickerBtn.TextColor3 = Theme.Accent
    end)

    PickerBtn.MouseButton2Click:Connect(function()
        CloseActivePopup()
        ModePopup = Create("Frame", {
            Size = UDim2.fromOffset(72, 60),
            Position = UDim2.fromOffset(
                PickerBtn.AbsolutePosition.X - Library.OverlayFrame.AbsolutePosition.X,
                PickerBtn.AbsolutePosition.Y - Library.OverlayFrame.AbsolutePosition.Y + PickerBtn.AbsoluteSize.Y + 2
            ),
            BackgroundColor3 = Theme.GroupBoxBg,
            ZIndex = 10,
            Parent = Library.OverlayFrame,
        })
        AddCorner(ModePopup, 4)
        AddStroke(ModePopup, Theme.Border, 1, Theme.BorderAlpha)

        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ModePopup,
        })

        local Modes = { "Always", "Hold", "Toggle" }
        for _, M in ipairs(Modes) do
            local Selected = (Picker.Mode == M)
            local ModeBtn = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = Selected and Theme.FrameActive or Theme.GroupBoxBg,
                BackgroundTransparency = Selected and 0.2 or 1,
                Text = M,
                TextColor3 = Selected and Theme.Accent or Theme.TextDisabled,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 11,
                Parent = ModePopup,
            })

            ModeBtn.MouseEnter:Connect(function()
                if Picker.Mode ~= M then
                    Tween(ModeBtn, 0.1, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme.FrameActive })
                end
            end)
            ModeBtn.MouseLeave:Connect(function()
                if Picker.Mode ~= M then
                    Tween(ModeBtn, 0.1, { BackgroundTransparency = 1, BackgroundColor3 = Theme.GroupBoxBg })
                end
            end)

            ModeBtn.MouseButton1Click:Connect(function()
                Picker.Mode = M
                if M == "Always" then SetActive(true) else SetActive(false) end
                CloseActivePopup()
            end)
        end

        Library.OpenedPopup = { Close = CloseModePopup }
        Library.OverlayButton.Visible = true
    end)

    local InputBeganConn = UserInputService.InputBegan:Connect(function(Input, GPE)
        if Picker.Picking then
            Picker.Picking = false
            if Input.UserInputType == Enum.UserInputType.Keyboard then
                if Input.KeyCode == Enum.KeyCode.Escape then
                    Picker.Value = Enum.KeyCode.Unknown
                    PickerBtn.Text = "[None]"
                else
                    Picker.Value = Input.KeyCode
                    PickerBtn.Text = "[" .. Input.KeyCode.Name .. "]"
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Picker.Value = Enum.KeyCode.Unknown
                PickerBtn.Text = "[None]"
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                Picker.Value = Enum.KeyCode.Unknown
                PickerBtn.Text = "[None]"
            end
            PickerBtn.TextColor3 = Theme.TextDisabled
            CloseActivePopup()
            return
        end

        if GPE then return end
        if Picker.Value == Enum.KeyCode.Unknown then return end

        if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Picker.Value then
            if Picker.Mode == "Hold" then
                SetActive(true)
            elseif Picker.Mode == "Toggle" then
                SetActive(not Picker.Active)
            end
        end
    end)
    table.insert(Library.Connections, InputBeganConn)

    local InputEndedConn = UserInputService.InputEnded:Connect(function(Input)
        if Picker.Value == Enum.KeyCode.Unknown then return end
        if Picker.Mode == "Hold"
            and Input.UserInputType == Enum.UserInputType.Keyboard
            and Input.KeyCode == Picker.Value then
            SetActive(false)
        end
    end)
    table.insert(Library.Connections, InputEndedConn)

    Library.Options[Key] = Picker
    return self
end

-- // Inline color picker swatch attached to a toggle row
function ToggleMethods:AddColorPicker(Key, Config)
    Config = Config or {}
    local DefaultColor = Config.Default or Color3.fromRGB(255, 255, 255)
    local DefaultAlpha = Config.Alpha   or 1

    local ColorState = CreateElementState(Key, { Color = DefaultColor, Alpha = DefaultAlpha })
    Library.Options[Key] = ColorState

    local Swatch = Create("TextButton", {
        Size = UDim2.fromOffset(20, 12),
        BackgroundColor3 = DefaultColor,
        Text = "",
        AutoButtonColor = false,
        Parent = self.RightControls,
    })
    AddCorner(Swatch, 2)
    AddStroke(Swatch, Theme.Border, 1, Theme.BorderAlpha)

    local PickerFrame
    local function ClosePicker()
        if PickerFrame then PickerFrame:Destroy() end
        PickerFrame = nil
    end

    Swatch.MouseButton1Click:Connect(function()
        CloseActivePopup()

        local H, S, V = ColorState.Value.Color:ToHSV()
        local Alpha   = ColorState.Value.Alpha

        PickerFrame = Create("Frame", {
            Size = UDim2.fromOffset(200, 170),
            Position = UDim2.fromOffset(
                Swatch.AbsolutePosition.X - Library.OverlayFrame.AbsolutePosition.X - 205,
                Swatch.AbsolutePosition.Y - Library.OverlayFrame.AbsolutePosition.Y
            ),
            BackgroundColor3 = Theme.GroupBoxBg,
            ZIndex = 10,
            Parent = Library.OverlayFrame,
        })
        AddCorner(PickerFrame, 6)
        AddStroke(PickerFrame, Theme.Border, 1, Theme.BorderAlpha)

        -- Saturation/Value Box
        local SVBox = Create("ImageButton", {
            Size = UDim2.fromOffset(125, 105),
            Position = UDim2.fromOffset(10, 10),
            BackgroundColor3 = Color3.fromHSV(H, 1, 1),
            AutoButtonColor = false,
            ZIndex = 11,
            Parent = PickerFrame,
        })
        AddCorner(SVBox, 3)

        local WhiteGrad = Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 11,
            Parent = SVBox,
        })
        AddCorner(WhiteGrad, 3)
        local WG = AddGradient(WhiteGrad, Theme.White, Theme.White, 0)
        WG.Transparency = NumberSequence.new(0, 1)

        local BlackGrad = Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 12,
            Parent = SVBox,
        })
        AddCorner(BlackGrad, 3)
        local BG = AddGradient(BlackGrad, Theme.Black, Theme.Black, 90)
        BG.Transparency = NumberSequence.new(1, 0)

        local SVCursor = Create("Frame", {
            Size = UDim2.fromOffset(6, 6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(S, 1 - V),
            BackgroundColor3 = Theme.White,
            ZIndex = 13,
            Parent = SVBox,
        })
        AddCorner(SVCursor, 3)
        AddStroke(SVCursor, Theme.Black, 1, 0)

        -- Hue Slider (vertical)
        local HueBar = Create("ImageButton", {
            Size = UDim2.fromOffset(14, 105),
            Position = UDim2.fromOffset(143, 10),
            BackgroundColor3 = Theme.White,
            AutoButtonColor = false,
            ZIndex = 11,
            Parent = PickerFrame,
        })
        AddCorner(HueBar, 3)

        local HueColors = {}
        for i = 0, 6 do
            table.insert(HueColors, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
        end
        Create("UIGradient", {
            Color = ColorSequence.new(HueColors),
            Rotation = 90,
            Parent = HueBar,
        })

        local HueCursor = Create("Frame", {
            Size = UDim2.new(1, 4, 0, 4),
            Position = UDim2.new(-2, 0, H, -2),
            BackgroundColor3 = Theme.White,
            BorderSizePixel = 0,
            ZIndex = 12,
            Parent = HueBar,
        })
        AddCorner(HueCursor, 1)
        AddStroke(HueCursor, Theme.Black, 1, 0)

        -- Alpha Slider (horizontal)
        local AlphaBar = Create("ImageButton", {
            Size = UDim2.fromOffset(147, 12),
            Position = UDim2.fromOffset(10, 122),
            BackgroundColor3 = ColorState.Value.Color,
            AutoButtonColor = false,
            ZIndex = 11,
            Parent = PickerFrame,
        })
        AddCorner(AlphaBar, 3)
        Create("UIGradient", {
            Color = ColorSequence.new(Theme.White, Theme.Black),
            Parent = AlphaBar,
        })

        local AlphaCursor = Create("Frame", {
            Size = UDim2.fromOffset(4, 16),
            Position = UDim2.new(Alpha, -2, -2, 0),
            BackgroundColor3 = Theme.White,
            BorderSizePixel = 0,
            ZIndex = 12,
            Parent = AlphaBar,
        })
        AddCorner(AlphaCursor, 1)
        AddStroke(AlphaCursor, Theme.Black, 1, 0)

        -- Hex Input
        local HexInput = Create("TextBox", {
            Size = UDim2.fromOffset(60, 18),
            Position = UDim2.fromOffset(10, 142),
            BackgroundColor3 = Theme.Button,
            Text = "#" .. ColorState.Value.Color:ToHex():upper(),
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            ZIndex = 11,
            ClearTextOnFocus = false,
            Parent = PickerFrame,
        })
        AddCorner(HexInput, 3)
        AddStroke(HexInput, Theme.Border, 1, Theme.BorderAlpha)

        local function UpdateColor()
            local C = Color3.fromHSV(H, S, V)
            ColorState:SetValue({ Color = C, Alpha = Alpha })

            Swatch.BackgroundColor3   = C
            SVBox.BackgroundColor3    = Color3.fromHSV(H, 1, 1)
            SVCursor.Position         = UDim2.fromScale(S, 1 - V)
            HueCursor.Position        = UDim2.new(-2, 0, H, -2)
            AlphaBar.BackgroundColor3 = C
            AlphaCursor.Position      = UDim2.new(Alpha, -2, -2, 0)

            if not HexInput:IsFocused() then
                HexInput.Text = "#" .. C:ToHex():upper()
            end
        end

        local DraggingSV, DraggingHue, DraggingAlpha = false, false, false

        SVBox.InputBegan:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingSV = true end
        end)
        SVBox.InputEnded:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingSV = false end
        end)

        HueBar.InputBegan:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingHue = true end
        end)
        HueBar.InputEnded:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingHue = false end
        end)

        AlphaBar.InputBegan:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingAlpha = true end
        end)
        AlphaBar.InputEnded:Connect(function(I)
            if I.UserInputType == Enum.UserInputType.MouseButton1 then DraggingAlpha = false end
        end)

        local Conn = UserInputService.InputChanged:Connect(function(I)
            if I.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            if DraggingSV then
                local sz, p = SVBox.AbsoluteSize, SVBox.AbsolutePosition
                S = math.clamp((I.Position.X - p.X) / sz.X, 0, 1)
                V = 1 - math.clamp((I.Position.Y - p.Y) / sz.Y, 0, 1)
                UpdateColor()
            elseif DraggingHue then
                local sz, p = HueBar.AbsoluteSize, HueBar.AbsolutePosition
                H = math.clamp((I.Position.Y - p.Y) / sz.Y, 0, 1)
                UpdateColor()
            elseif DraggingAlpha then
                local sz, p = AlphaBar.AbsoluteSize, AlphaBar.AbsolutePosition
                Alpha = math.clamp((I.Position.X - p.X) / sz.X, 0, 1)
                UpdateColor()
            end
        end)
        table.insert(Library.Connections, Conn)

        HexInput.FocusLost:Connect(function()
            local Hex = HexInput.Text:gsub("#", "")
            local ok, NewColor = pcall(function() return Color3.fromHex(Hex) end)
            if ok then
                H, S, V = NewColor:ToHSV()
                UpdateColor()
            else
                HexInput.Text = "#" .. ColorState.Value.Color:ToHex():upper()
            end
        end)

        Library.OpenedPopup = { Close = ClosePicker }
        Library.OverlayButton.Visible = true
    end)

    return self
end

Library.ToggleMethods = ToggleMethods

-- =====================================================================
-- // [SECTION] Groupbox widget builders
-- =====================================================================
local GroupboxMethods = {}
GroupboxMethods.__index = GroupboxMethods

function GroupboxMethods:_AddRow(Height)
    local Row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, Height or 22),
        BackgroundTransparency = 1,
        Parent = self.Container,
    })

    local RightControls = Create("Frame", {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -100, 0, 0),
        BackgroundTransparency = 1,
        Parent = Row,
    })
    Create("UIListLayout", {
        FillDirection      = Enum.FillDirection.Horizontal,
        HorizontalAlignment= Enum.HorizontalAlignment.Right,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        SortOrder          = Enum.SortOrder.LayoutOrder,
        Padding            = UDim.new(0, 6),
        Parent = RightControls,
    })

    return Row, RightControls
end

-- // Checkbox (Toggle)
function GroupboxMethods:AddToggle(Key, Config)
    Config = Config or {}
    local Text    = Config.Text    or Key
    local Default = Config.Default or false

    local State = CreateElementState(Key, Default)
    Library.Toggles[Key] = State

    local Row, RightControls = self:_AddRow(20)

    -- 12x12 rounded square checkbox
    local CheckFrame = Create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = Default and Theme.Accent or Theme.Button,
        BorderSizePixel = 0,
        Parent = Row,
    })
    AddCorner(CheckFrame, 3)
    AddStroke(CheckFrame, Default and Theme.Accent or Theme.Border, 1, Default and 0 or Theme.BorderAlpha)

    local Mark = Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "✓",
        TextColor3 = Theme.White,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        Visible = Default,
        Parent = CheckFrame,
    })

    local Label = Create("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1,
        Text = Text,
        TextColor3 = Default and Theme.Text or Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Row,
    })

    local ToggleObj = setmetatable({
        Key           = Key,
        Text          = Text,
        Frame         = Row,
        RightControls = RightControls,
        State         = State,
    }, ToggleMethods)

    function ToggleObj:UpdateVisual(Val)
        Tween(CheckFrame, 0.15, { BackgroundColor3 = Val and Theme.Accent or Theme.Button })
        local Stroke = CheckFrame:FindFirstChildOfClass("UIStroke")
        if Stroke then
            Tween(Stroke, 0.15, {
                Color = Val and Theme.Accent or Theme.Border,
                Transparency = Val and 0 or Theme.BorderAlpha,
            })
        end
        Mark.Visible = Val
        Tween(Label, 0.15, { TextColor3 = Val and Theme.Text or Theme.TextDisabled })
    end

    local function ToggleVal()
        local New = not State.Value
        State:SetValue(New)
        ToggleObj:UpdateVisual(New)
    end

    local ClickBtn = Create("TextButton", {
        Size = UDim2.new(1, -100, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Parent = Row,
    })
    ClickBtn.MouseButton1Click:Connect(ToggleVal)

    return ToggleObj
end

function GroupboxMethods:AddCheckbox(Key, Config)
    return self:AddToggle(Key, Config)
end

-- // Draggable slider
function GroupboxMethods:AddSlider(Key, Config)
    Config = Config or {}
    local Text     = Config.Text     or Key
    local Min      = Config.Min      or 0
    local Max      = Config.Max      or 100
    local Default  = Config.Default  or Min
    local Rounding = Config.Rounding or 0
    local Suffix   = Config.Suffix   or ""

    local State = CreateElementState(Key, Default)
    Library.Options[Key] = State

    local Row = self:_AddRow(36)

    Create("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = Text,
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Row,
    })

    local function FormatVal(V)
        if Rounding == 0 then
            return tostring(math.floor(V)) .. Suffix
        end
        return string.format("%." .. Rounding .. "f", V) .. Suffix
    end

    local ValueLabel = Create("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 14),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = FormatVal(Default),
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Row,
    })

    local Track = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = Theme.Button,
        BorderSizePixel = 0,
        Parent = Row,
    })
    AddCorner(Track, 2)
    AddStroke(Track, Theme.Border, 1, Theme.BorderAlpha)

    local Pct = math.clamp((Default - Min) / (Max - Min), 0, 1)
    local Fill = Create("Frame", {
        Size = UDim2.fromScale(Pct, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = Track,
    })
    AddCorner(Fill, 2)

    local Thumb = Create("Frame", {
        Size = UDim2.fromOffset(8, 8),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(Pct, 0, 0.5, 0),
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = Track,
    })
    AddCorner(Thumb, 4)

    local Btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
        Parent = Row,
    })

    local Dragging = false
    local function ApplyPct(P)
        P = math.clamp(P, 0, 1)
        local Value = Min + (Max - Min) * P
        if Rounding == 0 then
            Value = math.floor(Value + 0.5)
        else
            local F = 10 ^ Rounding
            Value = math.floor(Value * F + 0.5) / F
        end
        Value = math.clamp(Value, Min, Max)

        local SnapPct = (Value - Min) / (Max - Min)
        Fill.Size       = UDim2.fromScale(SnapPct, 1)
        Thumb.Position  = UDim2.new(SnapPct, 0, 0.5, 0)
        ValueLabel.Text = FormatVal(Value)
        State:SetValue(Value)
    end

    Btn.InputBegan:Connect(function(I)
        if I.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            ApplyPct((I.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X)
        end
    end)
    Btn.InputEnded:Connect(function(I)
        if I.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = false
        end
    end)

    local Conn = UserInputService.InputChanged:Connect(function(I)
        if Dragging and I.UserInputType == Enum.UserInputType.MouseMovement then
            ApplyPct((I.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X)
        end
    end)
    table.insert(Library.Connections, Conn)

    return State
end

-- // Floating dropdown (anti-clipping; supports Multi + Searchable + "Player" specialtype)
function GroupboxMethods:AddDropdown(Key, Config)
    Config = Config or {}
    local Text         = Config.Text or Key
    local Values       = Config.Values or {}
    local Default      = Config.Default
    local Multi        = Config.Multi or false
    local Searchable   = Config.Searchable or false
    local SpecialType  = Config.SpecialType
    local ExcludeLocal = Config.ExcludeLocalPlayer or false
    local MaxVisible   = Config.MaxVisibleDropdownItems or 6

    if SpecialType == "Player" then
        Values = {}
        for _, Plr in ipairs(Players:GetPlayers()) do
            if ExcludeLocal and Plr == Players.LocalPlayer then continue end
            table.insert(Values, Plr.Name)
        end
    end

    local InitialVal
    if Multi then
        InitialVal = Default or {}
    else
        InitialVal = Default or Values[1] or ""
    end

    local State = CreateElementState(Key, InitialVal)
    Library.Options[Key] = State

    local Row = self:_AddRow(40)

    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = Text,
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Row,
    })

    local function GetDisplay()
        if Multi then
            local Sel = {}
            for K, V in pairs(State.Value) do
                if V then table.insert(Sel, tostring(K)) end
            end
            if #Sel == 0 then return "None" end
            return table.concat(Sel, ", ")
        end
        return tostring(State.Value)
    end

    local DropBtn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = Theme.Button,
        Text = "",
        AutoButtonColor = false,
        Parent = Row,
    })
    AddCorner(DropBtn, 3)
    AddStroke(DropBtn, Theme.Border, 1, Theme.BorderAlpha)

    local DisplayLabel = Create("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text = GetDisplay(),
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = DropBtn,
    })

    Create("TextLabel", {
        Size = UDim2.fromOffset(16, 22),
        Position = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        Parent = DropBtn,
    })

    local ListFrame, SearchBox
    local IsOpen = false

    local function CloseList()
        if ListFrame then ListFrame:Destroy(); ListFrame = nil end
        if SearchBox then SearchBox:Destroy(); SearchBox = nil end
        IsOpen = false
    end

    local function OpenList()
        CloseActivePopup()
        IsOpen = true

        local Current = Values
        if SpecialType == "Player" then
            Current = {}
            for _, Plr in ipairs(Players:GetPlayers()) do
                if ExcludeLocal and Plr == Players.LocalPlayer then continue end
                table.insert(Current, Plr.Name)
            end
        end

        local ItemHeight = 22
        local DropYOffset = 24

        if Searchable then
            SearchBox = Create("TextBox", {
                Size = UDim2.new(0, DropBtn.AbsoluteSize.X, 0, 22),
                Position = UDim2.fromOffset(
                    DropBtn.AbsolutePosition.X - Library.OverlayFrame.AbsolutePosition.X,
                    DropBtn.AbsolutePosition.Y - Library.OverlayFrame.AbsolutePosition.Y + 24
                ),
                BackgroundColor3 = Theme.Button,
                Text = "",
                PlaceholderText = "Search...",
                PlaceholderColor3 = Theme.TextDisabled,
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                ClearTextOnFocus = false,
                ZIndex = 10,
                Parent = Library.OverlayFrame,
            })
            AddCorner(SearchBox, 3)
            AddStroke(SearchBox, Theme.Border, 1, Theme.BorderAlpha)
            AddPadding(SearchBox, 0, 6, 0, 6)
            DropYOffset = 48
        end

        ListFrame = Create("ScrollingFrame", {
            Size = UDim2.new(0, DropBtn.AbsoluteSize.X, 0, math.min(#Current, MaxVisible) * ItemHeight),
            Position = UDim2.fromOffset(
                DropBtn.AbsolutePosition.X - Library.OverlayFrame.AbsolutePosition.X,
                DropBtn.AbsolutePosition.Y - Library.OverlayFrame.AbsolutePosition.Y + DropYOffset
            ),
            BackgroundColor3 = Theme.GroupBoxBg,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = Library.OverlayFrame,
        })
        AddCorner(ListFrame, 3)
        AddStroke(ListFrame, Theme.Border, 1, Theme.BorderAlpha)

        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ListFrame,
        })

        local function Populate(Filter)
            for _, Child in ipairs(ListFrame:GetChildren()) do
                if Child:IsA("TextButton") then Child:Destroy() end
            end

            local Filtered = {}
            for _, V in ipairs(Current) do
                if not Filter or Filter == "" or string.find(string.lower(V), string.lower(Filter), 1, true) then
                    table.insert(Filtered, V)
                end
            end

            for _, V in ipairs(Filtered) do
                local Selected = Multi and (State.Value[V] == true) or (State.Value == V)

                local Item = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, ItemHeight),
                    BackgroundColor3 = Selected and Theme.FrameActive or Theme.GroupBoxBg,
                    BackgroundTransparency = Selected and 0.2 or 1,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 11,
                    Parent = ListFrame,
                })

                Create("TextLabel", {
                    Size = UDim2.new(1, -16, 1, 0),
                    Position = UDim2.fromOffset(8, 0),
                    BackgroundTransparency = 1,
                    Text = V,
                    TextColor3 = Selected and Theme.Accent or Theme.Text,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 12,
                    Parent = Item,
                })

                Item.MouseEnter:Connect(function()
                    if not Selected then
                        Tween(Item, 0.1, { BackgroundColor3 = Theme.ButtonHover, BackgroundTransparency = 0.5 })
                    end
                end)
                Item.MouseLeave:Connect(function()
                    if not Selected then
                        Tween(Item, 0.1, { BackgroundColor3 = Theme.GroupBoxBg, BackgroundTransparency = 1 })
                    end
                end)

                Item.MouseButton1Click:Connect(function()
                    if Multi then
                        local C = State.Value
                        C[V] = not C[V]
                        State:SetValue(C)
                        DisplayLabel.Text = GetDisplay()
                        Populate(SearchBox and SearchBox.Text or "")
                    else
                        State:SetValue(V)
                        DisplayLabel.Text = GetDisplay()
                        CloseActivePopup()
                    end
                end)
            end

            ListFrame.CanvasSize = UDim2.fromOffset(0, #Filtered * ItemHeight)
            ListFrame.Size = UDim2.new(0, DropBtn.AbsoluteSize.X, 0, math.min(#Filtered, MaxVisible) * ItemHeight)
        end

        Populate("")

        if SearchBox then
            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                Populate(SearchBox.Text)
            end)
        end

        Library.OpenedPopup = { Close = CloseList }
        Library.OverlayButton.Visible = true
    end

    DropBtn.MouseButton1Click:Connect(function()
        if IsOpen then CloseActivePopup() else OpenList() end
    end)

    return State
end

-- // Flat button
function GroupboxMethods:AddButton(Config)
    Config = Config or {}
    local Text = Config.Text or "Button"
    local Func = Config.Func or function() end

    local Row = self:_AddRow(24)

    local Btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 1),
        BackgroundColor3 = Theme.Button,
        Text = Text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = Row,
    })
    AddCorner(Btn, 3)
    AddStroke(Btn, Theme.Border, 1, Theme.BorderAlpha)

    Btn.MouseEnter:Connect(function()
        Tween(Btn, 0.15, { BackgroundColor3 = Theme.ButtonHover })
        local S = Btn:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Accent, Transparency = 0.5 }) end
    end)
    Btn.MouseLeave:Connect(function()
        Tween(Btn, 0.15, { BackgroundColor3 = Theme.Button })
        local S = Btn:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Border, Transparency = Theme.BorderAlpha }) end
    end)

    Btn.MouseButton1Click:Connect(function()
        Tween(Btn, 0.05, { BackgroundColor3 = Theme.ButtonActive })
        task.delay(0.08, function()
            Tween(Btn, 0.15, { BackgroundColor3 = Theme.ButtonHover })
        end)
        pcall(Func)
    end)

    return { Frame = Row, Button = Btn }
end

-- // Text input
function GroupboxMethods:AddInput(Key, Config)
    Config = Config or {}
    local Text        = Config.Text or Key
    local Default     = Config.Default or ""
    local Placeholder = Config.Placeholder or ""
    local Callback    = Config.Callback

    local State = CreateElementState(Key, Default)
    Library.Options[Key] = State

    local Row = self:_AddRow(40)

    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = Text,
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Row,
    })

    local Input = Create("TextBox", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = Theme.Button,
        Text = Default,
        PlaceholderText = Placeholder,
        PlaceholderColor3 = Theme.TextDisabled,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        ClearTextOnFocus = false,
        Parent = Row,
    })
    AddCorner(Input, 3)
    AddStroke(Input, Theme.Border, 1, Theme.BorderAlpha)
    AddPadding(Input, 0, 6, 0, 6)

    Input.Focused:Connect(function()
        local S = Input:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Accent, Transparency = 0 }) end
    end)
    Input.FocusLost:Connect(function()
        local S = Input:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Border, Transparency = Theme.BorderAlpha }) end
        State:SetValue(Input.Text)
        if Callback then pcall(Callback, Input.Text) end
    end)

    return State
end

-- // Plain label
function GroupboxMethods:AddLabel(Text)
    local Row = self:_AddRow(16)
    local L = Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = Text or "",
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Row,
    })
    return {
        Frame = Row,
        SetText = function(_, T) L.Text = T end,
    }
end

-- // Divider line
function GroupboxMethods:AddDivider()
    local Row = self:_AddRow(8)
    local Line = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = Theme.BorderAlpha,
        BorderSizePixel = 0,
        Parent = Row,
    })
    return { Frame = Row, Line = Line }
end

Library.GroupboxMethods = GroupboxMethods

-- =====================================================================
-- // [SECTION] Subtab methods
-- =====================================================================
local SubtabMethods = {}
SubtabMethods.__index = SubtabMethods

local function MakeGroupbox(Parent, Name)
    -- Outer container — gives space for the floating title above the box
    local Outer = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = Parent,
    })

    -- Card body — offset down by 8px so the title floats above
    local Card = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 8),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.GroupBoxBg,
        Parent = Outer,
    })
    AddCorner(Card, 6)
    AddStroke(Card, Theme.Border, 1, Theme.BorderAlpha)

    -- Floating title text at (12, 0) per gui.cpp:94
    Create("TextLabel", {
        Size = UDim2.fromOffset(120, 14),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = Name or "",
        TextColor3 = Theme.White,
        TextTransparency = 0.5,  -- white @ 0.5 alpha
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Outer,
    })

    -- Inner content container — padding 12 sides, 13 top per gui.cpp:96-98
    local Container = Create("Frame", {
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.fromOffset(12, 21),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = Card,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),  -- item spacing 8x10 per gui.cpp:102
        Parent = Container,
    })

    -- Bottom spacer
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        LayoutOrder = 99999,
        Parent = Container,
    })

    return setmetatable({
        Frame     = Outer,
        Card      = Card,
        Container = Container,
        Name      = Name,
    }, GroupboxMethods)
end

function SubtabMethods:AddLeftGroupbox(Name)
    return MakeGroupbox(self.LeftColumn, Name)
end

function SubtabMethods:AddRightGroupbox(Name)
    return MakeGroupbox(self.RightColumn, Name)
end

Library.SubtabMethods = SubtabMethods

-- =====================================================================
-- // [SECTION] Tab methods (Neverlose sidebar tab with icon)
-- =====================================================================
local TabMethods = {}
TabMethods.__index = TabMethods

function TabMethods:AddSubtab(Name)
    -- Subtab "page" — holds two columns
    local SubtabPage = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = (#self.Subtabs == 0),
        Parent = self.SubtabPageHolder,
    })

    local LeftColumn = Create("ScrollingFrame", {
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 1,
        ScrollBarImageColor3 = Theme.Border,
        ScrollBarImageTransparency = Theme.BorderAlpha,
        BorderSizePixel = 0,
        Parent = SubtabPage,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 12),
        Parent = LeftColumn,
    })
    AddPadding(LeftColumn, 4, 2, 4, 2)

    local RightColumn = Create("ScrollingFrame", {
        Size = UDim2.new(0.5, -6, 1, 0),
        Position = UDim2.new(0.5, 6, 0, 0),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 1,
        ScrollBarImageColor3 = Theme.Border,
        ScrollBarImageTransparency = Theme.BorderAlpha,
        BorderSizePixel = 0,
        Parent = SubtabPage,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 12),
        Parent = RightColumn,
    })
    AddPadding(RightColumn, 4, 2, 4, 2)

    local SubtabObj = setmetatable({
        Name        = Name,
        Page        = SubtabPage,
        LeftColumn  = LeftColumn,
        RightColumn = RightColumn,
        Tab         = self,
    }, SubtabMethods)

    -- Subtab button (the segmented pill in the header bar)
    local SubtabBtn = Create("TextButton", {
        Size = UDim2.new(0, 0, 1, 0),  -- size set after all subtabs known
        BackgroundColor3 = Theme.FrameActive,
        BackgroundTransparency = (#self.Subtabs == 0) and 0.2 or 1,
        Text = "",
        AutoButtonColor = false,
        Parent = self.SubtabBar,
    })

    local SubtabCorner = AddCorner(SubtabBtn, 4)

    Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = Name,
        TextColor3 = (#self.Subtabs == 0) and Theme.Text or Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Parent = SubtabBtn,
    })

    SubtabObj.Button = SubtabBtn
    table.insert(self.Subtabs, SubtabObj)

    if #self.Subtabs == 1 then self.ActiveSubtab = SubtabObj end

    -- Resize all subtab buttons to equal slices of bar width
    local function ResizeSubtabs()
        local N = #self.Subtabs
        if N == 0 then return end
        for i, S in ipairs(self.Subtabs) do
            S.Button.Size = UDim2.new(1 / N, 0, 1, 0)
            S.Button.Position = UDim2.new((i - 1) / N, 0, 0, 0)
        end
    end
    ResizeSubtabs()

    SubtabBtn.MouseButton1Click:Connect(function()
        self:SelectSubtab(SubtabObj)
    end)

    SubtabBtn.MouseEnter:Connect(function()
        if self.ActiveSubtab ~= SubtabObj then
            Tween(SubtabBtn, 0.15, { BackgroundTransparency = 0.6 })
            local Lbl = SubtabBtn:FindFirstChildOfClass("TextLabel")
            if Lbl then Tween(Lbl, 0.15, { TextColor3 = Theme.Text }) end
        end
    end)
    SubtabBtn.MouseLeave:Connect(function()
        if self.ActiveSubtab ~= SubtabObj then
            Tween(SubtabBtn, 0.15, { BackgroundTransparency = 1 })
            local Lbl = SubtabBtn:FindFirstChildOfClass("TextLabel")
            if Lbl then Tween(Lbl, 0.15, { TextColor3 = Theme.TextDisabled }) end
        end
    end)

    return SubtabObj
end

function TabMethods:SelectSubtab(SubtabObj)
    if self.ActiveSubtab == SubtabObj then return end

    if self.ActiveSubtab then
        local Old = self.ActiveSubtab
        Old.Page.Visible = false
        Tween(Old.Button, 0.15, { BackgroundTransparency = 1 })
        local Lbl = Old.Button:FindFirstChildOfClass("TextLabel")
        if Lbl then Tween(Lbl, 0.15, { TextColor3 = Theme.TextDisabled }) end
    end

    self.ActiveSubtab = SubtabObj
    SubtabObj.Page.Visible = true
    Tween(SubtabObj.Button, 0.15, { BackgroundTransparency = 0.2 })
    local Lbl = SubtabObj.Button:FindFirstChildOfClass("TextLabel")
    if Lbl then Tween(Lbl, 0.15, { TextColor3 = Theme.Text }) end
end

-- // Convenience: skip subtab and add groupbox directly (auto-creates "Main" subtab)
function TabMethods:AddLeftGroupbox(Name)
    if #self.Subtabs == 0 then self:AddSubtab("Main") end
    return self.Subtabs[1]:AddLeftGroupbox(Name)
end

function TabMethods:AddRightGroupbox(Name)
    if #self.Subtabs == 0 then self:AddSubtab("Main") end
    return self.Subtabs[1]:AddRightGroupbox(Name)
end

Library.TabMethods = TabMethods

-- =====================================================================
-- // [SECTION] Window methods
-- =====================================================================
local WindowMethods = {}
WindowMethods.__index = WindowMethods

function WindowMethods:AddTabGroup(Name)
    -- Sidebar section title (e.g. "Aimbot", "Visuals", "Miscellaneous")
    local Container = self.SidebarTabList

    -- Spacer above (except for the first group)
    if #self.TabGroups > 0 then
        Create("Frame", {
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundTransparency = 1,
            LayoutOrder = #self.TabGroups * 100,
            Parent = Container,
        })
    end

    local TitleFrame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        LayoutOrder = #self.TabGroups * 100 + 1,
        Parent = Container,
    })
    AddPadding(TitleFrame, 0, 0, 0, 10)

    Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = Name,
        TextColor3 = Theme.White,
        TextTransparency = 0.5,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TitleFrame,
    })

    local Group = {
        Name      = Name,
        Window    = self,
        Container = Container,
        BaseOrder = #self.TabGroups * 100 + 2,
        TabCount  = 0,
    }

    function Group:AddTab(Config)
        return self.Window:_CreateTab(Config, self)
    end

    table.insert(self.TabGroups, Group)
    return Group
end

function WindowMethods:_CreateTab(Config, Group)
    Config = Config or {}
    local Name = Config.Name or "Tab"
    local Icon = Config.Icon

    local TabObj = setmetatable({
        Name           = Name,
        Icon           = Icon,
        Window         = self,
        Group          = Group,
        Subtabs        = {},
        ActiveSubtab   = nil,
    }, TabMethods)

    -- Per-tab subtab bar inside the shared SubtabBarContainer; only active tab's is visible
    local SubtabBar = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Button,
        Visible = (#self.Tabs == 0),
        Parent = self.SubtabBarContainer,
    })
    AddCorner(SubtabBar, 4)
    AddStroke(SubtabBar, Theme.Border, 1, Theme.BorderAlpha)
    TabObj.SubtabBar = SubtabBar

    -- Per-tab content area
    local TabContent = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = (#self.Tabs == 0),
        Parent = self.ContentBody,
    })
    TabObj.TabContent = TabContent

    -- Holder for the subtab pages
    local SubtabPageHolder = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = TabContent,
    })
    TabObj.SubtabPageHolder = SubtabPageHolder

    -- Sidebar tab button (Neverlose-style: icon left, label right, 30px tall)
    local Order = Group and (Group.BaseOrder + Group.TabCount) or (#self.Tabs)
    if Group then Group.TabCount = Group.TabCount + 1 end

    local TabBtn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.FrameActive,
        BackgroundTransparency = (#self.Tabs == 0) and 0.5 or 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Order,
        Parent = self.SidebarTabList,
    })
    AddCorner(TabBtn, 5)

    -- Icon (text glyph or rbxassetid image)
    if Icon then
        if IsImageIcon(Icon) then
            Create("ImageLabel", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, 10, 0.5, -8),
                BackgroundTransparency = 1,
                Image = Icon,
                ImageColor3 = Theme.Accent,
                Parent = TabBtn,
            })
        else
            Create("TextLabel", {
                Size = UDim2.fromOffset(20, 16),
                Position = UDim2.new(0, 10, 0.5, -8),
                BackgroundTransparency = 1,
                Text = Icon,
                TextColor3 = Theme.Accent,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = TabBtn,
            })
        end
    end

    local Label = Create("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.fromOffset(35, 0),
        BackgroundTransparency = 1,
        Text = Name,
        TextColor3 = (#self.Tabs == 0) and Theme.Text or Theme.TextDisabled,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabBtn,
    })

    TabObj.Button = TabBtn
    TabObj.Label  = Label

    table.insert(self.Tabs, TabObj)

    if #self.Tabs == 1 then self.ActiveTab = TabObj end

    TabBtn.MouseButton1Click:Connect(function() self:SelectTab(TabObj) end)

    TabBtn.MouseEnter:Connect(function()
        if self.ActiveTab ~= TabObj then
            Tween(TabBtn, 0.15, { BackgroundTransparency = 0.7 })
            Tween(Label, 0.15, { TextColor3 = Theme.Text })
        end
    end)
    TabBtn.MouseLeave:Connect(function()
        if self.ActiveTab ~= TabObj then
            Tween(TabBtn, 0.15, { BackgroundTransparency = 1 })
            Tween(Label, 0.15, { TextColor3 = Theme.TextDisabled })
        end
    end)

    return TabObj
end

-- // Public: add a tab outside of any group (rare; mostly use TabGroup:AddTab)
function WindowMethods:AddTab(Config)
    return self:_CreateTab(Config, nil)
end

function WindowMethods:SelectTab(TabObj)
    if self.ActiveTab == TabObj then return end

    if self.ActiveTab then
        local Old = self.ActiveTab
        Old.TabContent.Visible = false
        Old.SubtabBar.Visible  = false
        Tween(Old.Button, 0.15, { BackgroundTransparency = 1 })
        Tween(Old.Label,  0.15, { TextColor3 = Theme.TextDisabled })
    end

    self.ActiveTab = TabObj
    TabObj.TabContent.Visible = true
    TabObj.SubtabBar.Visible  = true
    Tween(TabObj.Button, 0.15, { BackgroundTransparency = 0.5 })
    Tween(TabObj.Label,  0.15, { TextColor3 = Theme.Text })
end

Library.WindowMethods = WindowMethods

-- =====================================================================
-- // [SECTION] CreateWindow — builds the entire Neverlose-style shell
-- =====================================================================
function Library:CreateWindow(Config)
    Config = Config or {}
    local Title         = Config.Title         or "NEVERLOSE"
    local Username      = Config.Username      or (Players.LocalPlayer and Players.LocalPlayer.Name) or "User"
    local Subscription  = Config.Subscription  or "Lifetime"
    local WindowSize    = Config.Size          or UDim2.fromOffset(690, 500)
    local Center        = Config.Center ~= false
    local AccentColor   = Config.AccentColor
    local ToggleKey     = Config.ToggleKey     or Enum.KeyCode.RightControl
    local AvatarId      = Config.AvatarId
    local OnSave        = Config.OnSave        or function() end
    local ShowFooter    = Config.ShowFooter ~= false

    Library.ToggleKey = ToggleKey

    if AccentColor then
        Theme.Accent = AccentColor
    end

    -- // ScreenGui setup
    local ScreenGui = Create("ScreenGui", {
        Name              = "NeverloseGui",
        ResetOnSpawn      = false,
        IgnoreGuiInset    = true,
        ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
        DisplayOrder      = 9999,
    })

    local parented = pcall(function() ScreenGui.Parent = CoreGui end)
    if not parented or not ScreenGui.Parent then
        ScreenGui.Parent = (Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui"))
                        or game:GetService("CoreGui")
    end
    Library.ScreenGui = ScreenGui

    -- // Overlay for popup management
    local OverlayFrame = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 99995,
        Parent = ScreenGui,
    })
    Library.OverlayFrame = OverlayFrame

    local OverlayButton = Create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        Visible = false,
        ZIndex = 1,
        Parent = OverlayFrame,
    })
    OverlayButton.MouseButton1Click:Connect(CloseActivePopup)
    Library.OverlayButton = OverlayButton

    -- // Notification holder (top right)
    NotificationHolder = Create("Frame", {
        Size = UDim2.fromOffset(270, 0),
        Position = UDim2.new(1, -280, 0, 50),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 99999,
        Parent = ScreenGui,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = NotificationHolder,
    })

    -- // Watermark (top right)
    local WatermarkFrame = Create("Frame", {
        Size = UDim2.fromOffset(140, 24),
        Position = UDim2.new(1, -150, 0, 10),
        BackgroundColor3 = Theme.GroupBoxBg,
        Parent = ScreenGui,
    })
    AddCorner(WatermarkFrame, 4)
    AddStroke(WatermarkFrame, Theme.Border, 1, Theme.BorderAlpha)

    local WatermarkAccent = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = WatermarkFrame,
    })
    AddCorner(WatermarkAccent, 2)

    Create("TextLabel", {
        Name = "WatermarkLabel",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = Library.WatermarkText,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = WatermarkFrame,
    })
    Library.WatermarkFrame = WatermarkFrame

    -- // Keybind list frame (draggable, hidden by default)
    local KeybindListFrame = Create("Frame", {
        Size = UDim2.fromOffset(160, 24),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0.02, 0, 0.4, 0),
        BackgroundColor3 = Theme.GroupBoxBg,
        Visible = false,
        Parent = ScreenGui,
    })
    AddCorner(KeybindListFrame, 4)
    AddStroke(KeybindListFrame, Theme.Border, 1, Theme.BorderAlpha)
    MakeDraggable(KeybindListFrame, KeybindListFrame)

    local KeybindAccent = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = KeybindListFrame,
    })
    AddCorner(KeybindAccent, 2)

    local KeybindHeader = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 1,
        Parent = KeybindListFrame,
    })
    Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "KEYBINDS",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Parent = KeybindHeader,
    })

    local KeybindContainer = Create("Frame", {
        Name = "Container",
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.fromOffset(8, 22),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = KeybindListFrame,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = KeybindContainer,
    })
    AddPadding(KeybindContainer, 0, 0, 8, 0)
    Library.KeybindListFrame = KeybindListFrame

    -- // FPS/ping/clock loop
    local FPS, FrameCount, LastTime = 60, 0, os.clock()
    local FPSConn = RunService.RenderStepped:Connect(function()
        FrameCount += 1
        local Now = os.clock()
        if Now - LastTime >= 1 then
            FPS = FrameCount
            FrameCount = 0
            LastTime = Now

            local Plr = Players.LocalPlayer
            local Ping = 0
            if Plr then
                local ok, p = pcall(function() return Plr:GetNetworkPing() end)
                if ok then Ping = math.floor(p * 1000) end
            end

            local Clock = os.date("%H:%M:%S")
            local base = Library.WatermarkText:split(" |")[1]
            Library:SetWatermark(string.format("%s | %d FPS | %d MS | %s", base, FPS, Ping, Clock))
        end
    end)
    table.insert(Library.Connections, FPSConn)

    -- // Main window
    local WindowPos
    if Center then
        WindowPos = UDim2.new(0.5, -math.floor(WindowSize.X.Offset / 2),
                              0.5, -math.floor(WindowSize.Y.Offset / 2))
    else
        WindowPos = UDim2.fromOffset(120, 120)
    end

    local MainFrame = Create("Frame", {
        Size = WindowSize,
        Position = WindowPos,
        BackgroundColor3 = Theme.FrameInactive,
        Parent = ScreenGui,
    })
    AddCorner(MainFrame, 6)
    AddStroke(MainFrame, Theme.Border, 1, Theme.BorderAlpha)
    Library.MainFrame = MainFrame

    -- =====================================================================
    -- // Sidebar (left, 150 wide)
    -- =====================================================================
    local Sidebar = Create("Frame", {
        Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = Theme.FrameInactive,
        BorderSizePixel = 0,
        Parent = MainFrame,
    })

    -- Logo: "NEVERLOSE" header with 1px offset shadow (accent color underneath, white on top)
    -- Mirrors main.cpp:196-197 (header position 170/2 horizontally centered at y=20)
    local LogoHolder = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })

    -- Accent shadow (offset +1px in X)
    Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(1, 0),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Accent,
        Font = Enum.Font.GothamBlack,
        TextSize = 22,
        Parent = LogoHolder,
    })

    -- White text on top
    Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 22,
        Parent = LogoHolder,
    })

    -- // Sidebar Tab list (scrolling)
    local SidebarTabList = Create("ScrollingFrame", {
        Size = UDim2.new(1, -10, 1, -120),
        Position = UDim2.fromOffset(5, 55),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = SidebarTabList,
    })

    -- // User bar at bottom of sidebar (avatar + username + subscription)
    -- Per main.cpp:203-208
    local UserBarSeparator = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 1, -50),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    local Avatar = Create("ImageLabel", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(0, 15, 1, -40),
        BackgroundColor3 = Theme.Button,
        Image = AvatarId or (Players.LocalPlayer
            and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", Players.LocalPlayer.UserId)
            or ""),
        Parent = Sidebar,
    })
    AddCorner(Avatar, 100)
    AddStroke(Avatar, Theme.Border, 1, Theme.BorderAlpha)

    Create("TextLabel", {
        Size = UDim2.new(1, -55, 0, 16),
        Position = UDim2.new(0, 50, 1, -40),
        BackgroundTransparency = 1,
        Text = Username,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Sidebar,
    })

    local TillLabel = Create("TextLabel", {
        Size = UDim2.new(0, 28, 0, 14),
        Position = UDim2.new(0, 50, 1, -22),
        BackgroundTransparency = 1,
        Text = "Till:",
        TextColor3 = Theme.TextDisabled,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    Create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 14),
        Position = UDim2.new(0, 78, 1, -22),
        BackgroundTransparency = 1,
        Text = Subscription,
        TextColor3 = Theme.Accent,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Sidebar,
    })

    -- =====================================================================
    -- // Right section (header + content body)
    -- =====================================================================
    local RightSection = Create("Frame", {
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.fromOffset(150, 0),
        BackgroundTransparency = 1,
        Parent = MainFrame,
    })

    -- // Header (top 55 px)
    local HeaderRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 55),
        BackgroundTransparency = 1,
        Parent = RightSection,
    })

    -- Save button at (40, 12) within RightSection per main.cpp:251 → (190, 20) absolute
    local SaveBtn = Create("TextButton", {
        Size = UDim2.fromOffset(100, 25),
        Position = UDim2.fromOffset(40, 15),
        BackgroundColor3 = Theme.Button,
        Text = "💾 Save",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = HeaderRow,
    })
    AddCorner(SaveBtn, 4)
    AddStroke(SaveBtn, Theme.Border, 1, Theme.BorderAlpha)

    SaveBtn.MouseEnter:Connect(function()
        Tween(SaveBtn, 0.15, { BackgroundColor3 = Theme.ButtonHover })
        local S = SaveBtn:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Accent, Transparency = 0.5 }) end
    end)
    SaveBtn.MouseLeave:Connect(function()
        Tween(SaveBtn, 0.15, { BackgroundColor3 = Theme.Button })
        local S = SaveBtn:FindFirstChildOfClass("UIStroke")
        if S then Tween(S, 0.15, { Color = Theme.Border, Transparency = Theme.BorderAlpha }) end
    end)
    SaveBtn.MouseButton1Click:Connect(function()
        Tween(SaveBtn, 0.05, { BackgroundColor3 = Theme.ButtonActive })
        task.delay(0.08, function()
            Tween(SaveBtn, 0.15, { BackgroundColor3 = Theme.ButtonHover })
        end)
        pcall(OnSave, Library)
    end)

    -- Subtab bar container at (150, 12) within RightSection per main.cpp:255 → (300, 20) absolute
    local SubtabBarContainer = Create("Frame", {
        Size = UDim2.fromOffset(240, 25),
        Position = UDim2.fromOffset(150, 15),
        BackgroundTransparency = 1,
        Parent = HeaderRow,
    })

    -- // Content body (below header, with some padding from edges)
    local ContentBody = Create("Frame", {
        Size = UDim2.new(1, -20, 1, -70 - (ShowFooter and 18 or 0)),
        Position = UDim2.fromOffset(10, 60),
        BackgroundTransparency = 1,
        Parent = RightSection,
    })

    -- =====================================================================
    -- // Footer
    -- =====================================================================
    if ShowFooter then
        local Footer = Create("Frame", {
            Size = UDim2.new(1, -20, 0, 18),
            Position = UDim2.new(0, 10, 1, -22),
            BackgroundTransparency = 1,
            Parent = RightSection,
        })

        Create("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = Config.Footer or "Neverlose.lua | Universal build",
            TextColor3 = Theme.TextDisabled,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Footer,
        })

        Create("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = ("[%s] to toggle"):format(ToggleKey.Name),
            TextColor3 = Theme.TextDisabled,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = Footer,
        })
    end

    -- // Drag the window from anywhere except the content/sidebar interactives
    -- We'll use the LogoHolder and HeaderRow as drag handles
    MakeDraggable(MainFrame, LogoHolder)
    MakeDraggable(MainFrame, HeaderRow)

    -- // Window object
    local WindowObj = setmetatable({
        MainFrame          = MainFrame,
        Sidebar            = Sidebar,
        SidebarTabList     = SidebarTabList,
        RightSection       = RightSection,
        HeaderRow          = HeaderRow,
        SubtabBarContainer = SubtabBarContainer,
        ContentBody        = ContentBody,
        SaveButton         = SaveBtn,
        Tabs               = {},
        TabGroups          = {},
        ActiveTab          = nil,
    }, WindowMethods)
    Library.Window = WindowObj

    -- // Toggle key (Right-Control by default)
    local BindConn = UserInputService.InputBegan:Connect(function(Input, GPE)
        if GPE then return end
        if Input.KeyCode == Library.ToggleKey then
            CloseActivePopup()
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
    table.insert(Library.Connections, BindConn)

    return WindowObj
end

return Library
