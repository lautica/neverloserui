-- // Neverlose (Luau Port)
-- Structure follows Seraph library pattern

local Players        = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local CoreGui        = cloneref(game:GetService("CoreGui"))

-- // Theme — Neverlose color palette
local Theme = {
    Background    = Color3.fromRGB(5, 10, 16),
    Sidebar       = Color3.fromRGB(8, 16, 28),
    Panel         = Color3.fromRGB(5, 9, 16),
    Border        = Color3.fromRGB(255, 255, 255),
    Element       = Color3.fromRGB(8, 9, 15),
    ElementHover  = Color3.fromRGB(13, 14, 20),
    ElementActive = Color3.fromRGB(11, 18, 35),
    Accent        = Color3.fromRGB(77, 125, 255),
    Text          = Color3.fromRGB(255, 255, 255),
    TextDim       = Color3.fromRGB(130, 133, 143),
}

-- // Global Library State
local Library = {
    Toggles         = {},
    Options         = {},
    Unloaded        = false,
    ScreenGui       = nil,
    Window          = nil,
    Connections     = {},
    UnloadCallbacks = {},
}

-- // Utility Helpers

local function Create(Class, Props, Children)
    local Inst = Instance.new(Class)
    for K, V in pairs(Props) do
        if K ~= "Parent" then Inst[K] = V end
    end
    if Children then
        for _, Child in ipairs(Children) do Child.Parent = Inst end
    end
    if Props.Parent then Inst.Parent = Props.Parent end
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
        Color            = Color or Theme.Border,
        Thickness        = Thickness or 1,
        Transparency     = Transparency or 0.95,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
        Parent           = Inst,
    })
end

local function AddPadding(Inst, Top, Right, Bottom, Left)
    return Create("UIPadding", {
        PaddingTop    = UDim.new(0, Top    or 0),
        PaddingRight  = UDim.new(0, Right  or 0),
        PaddingBottom = UDim.new(0, Bottom or 0),
        PaddingLeft   = UDim.new(0, Left   or 0),
        Parent        = Inst,
    })
end

local function MakeDraggable(Frame, Handle)
    local Dragging, DragInput, DragStart, StartPos = false, nil, nil, nil
    Handle.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging  = true
            DragStart = Input.Position
            StartPos  = Frame.Position
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
            end)
        end
    end)
    Handle.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement then DragInput = Input end
    end)
    table.insert(Library.Connections, UserInputService.InputChanged:Connect(function(Input)
        if Dragging and Input == DragInput then
            local Delta = Input.Position - DragStart
            Frame.Position = UDim2.new(
                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
            )
        end
    end))
end

-- // State System

local function CreateElementState(Key, Default)
    local State = { Value = Default, Callbacks = {} }
    function State:OnChanged(Fn)
        table.insert(State.Callbacks, Fn)
        task.spawn(Fn, State.Value)
        return self
    end
    function State:SetValue(NewVal)
        if State.Value == NewVal and typeof(NewVal) ~= "table" then return end
        State.Value = NewVal
        for _, Fn in ipairs(State.Callbacks) do task.spawn(Fn, NewVal) end
    end
    return State
end

-- // Groupbox Methods

local GroupboxMethods = {}
GroupboxMethods.__index = GroupboxMethods

function GroupboxMethods:_AddRow(Height)
    return Create("Frame", {
        Size                = UDim2.new(1, 0, 0, Height or 20),
        BackgroundTransparency = 1,
        Parent              = self.Container,
    })
end

-- Toggle / Checkbox
function GroupboxMethods:AddToggle(Key, Config)
    Config = Config or {}
    local Label   = Config.Text or Key
    local Default = Config.Default or false

    local State = CreateElementState(Key, Default)
    Library.Toggles[Key] = State

    local Row = self:_AddRow(20)

    local CheckFrame = Create("Frame", {
        Size             = UDim2.fromOffset(12, 12),
        Position         = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = Default and Theme.Accent or Theme.Element,
        Parent           = Row,
    })
    AddCorner(CheckFrame, 2)
    local CheckStroke = AddStroke(CheckFrame, Theme.Border, 1, Default and 0.5 or 0.87)

    local Mark = Create("TextLabel", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = "✓",
        TextColor3         = Theme.Text,
        Font               = Enum.Font.ArialBold,
        TextSize           = 10,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
        Visible            = Default,
        Parent             = CheckFrame,
    })

    local TextLabel = Create("TextLabel", {
        Size               = UDim2.new(1, -18, 1, 0),
        Position           = UDim2.fromOffset(18, 0),
        BackgroundTransparency = 1,
        Text               = Label,
        TextColor3         = Default and Theme.Text or Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
        Parent             = Row,
    })

    local ToggleObj = { Key = Key, State = State }

    function ToggleObj:UpdateVisual(Val)
        Tween(CheckFrame, 0.12, { BackgroundColor3 = Val and Theme.Accent or Theme.Element })
        CheckStroke.Transparency = Val and 0.5 or 0.87
        Mark.Visible    = Val
        TextLabel.TextColor3 = Val and Theme.Text or Theme.TextDim
    end

    function ToggleObj:OnChanged(Fn) self.State:OnChanged(Fn); return self end
    function ToggleObj:SetValue(Val) self.State:SetValue(Val); self:UpdateVisual(Val); return self end

    local Btn = Create("TextButton", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = Row,
    })
    Btn.MouseButton1Click:Connect(function()
        local NewVal = not State.Value
        State:SetValue(NewVal)
        ToggleObj:UpdateVisual(NewVal)
    end)

    return ToggleObj
end

function GroupboxMethods:AddCheckbox(Key, Config)
    return self:AddToggle(Key, Config)
end

-- Slider
function GroupboxMethods:AddSlider(Key, Config)
    Config = Config or {}
    local Text     = Config.Text or Key
    local Min      = Config.Min or 0
    local Max      = Config.Max or 100
    local Default  = Config.Default or Min
    local Rounding = Config.Rounding or 0
    local Suffix   = Config.Suffix or ""

    local State = CreateElementState(Key, Default)
    Library.Options[Key] = State

    local Row = self:_AddRow(36)

    -- Header row
    local Header = Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Parent             = Row,
    })
    Create("TextLabel", {
        Size               = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = Text,
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = Header,
    })
    local function FormatVal(V)
        if Rounding == 0 then return tostring(math.floor(V)) .. Suffix end
        return string.format("%." .. Rounding .. "f", V) .. Suffix
    end
    local ValLabel = Create("TextLabel", {
        Size               = UDim2.new(0.3, 0, 1, 0),
        Position           = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text               = FormatVal(Default),
        TextColor3         = Theme.Accent,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Right,
        Parent             = Header,
    })

    -- Track
    local Track = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 4),
        Position         = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = Theme.Element,
        Parent           = Row,
    })
    AddCorner(Track, 2)
    AddStroke(Track, Theme.Border, 1, 0.9)

    local FillPct = math.clamp((Default - Min) / (Max - Min), 0, 1)
    local Fill = Create("Frame", {
        Size             = UDim2.fromScale(FillPct, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Parent           = Track,
    })
    AddCorner(Fill, 2)

    local Thumb = Create("Frame", {
        Size             = UDim2.fromOffset(8, 8),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(FillPct, 0, 0.5, 0),
        BackgroundColor3 = Theme.Text,
        ZIndex           = 5,
        Parent           = Track,
    })
    AddCorner(Thumb, 4)

    -- Invisible drag target
    local SliderBtn = Create("TextButton", {
        Size               = UDim2.new(1, 0, 0, 14),
        Position           = UDim2.new(0, 0, 0, 14),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 6,
        Parent             = Row,
    })

    local Dragging = false
    local function Update(Pct)
        Pct = math.clamp(Pct, 0, 1)
        local Value = Min + (Max - Min) * Pct
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
        ValLabel.Text   = FormatVal(Value)
        State:SetValue(Value)
    end

    SliderBtn.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            Update((Input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X)
        end
    end)
    SliderBtn.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
    end)
    table.insert(Library.Connections, UserInputService.InputChanged:Connect(function(Input)
        if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
            Update((Input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X)
        end
    end))

    return State
end

-- Dropdown
function GroupboxMethods:AddDropdown(Key, Config)
    Config = Config or {}
    local Text    = Config.Text or Key
    local Values  = Config.Values or {}
    local Default = Config.Default or (Values[1] or "")
    local Multi   = Config.Multi or false

    local State = CreateElementState(Key, Multi and (Config.Default or {}) or Default)
    Library.Options[Key] = State

    local Row = self:_AddRow(38)

    Create("TextLabel", {
        Size               = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text               = Text,
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = Row,
    })

    local DropBtn = Create("TextButton", {
        Size             = UDim2.new(1, 0, 0, 20),
        Position         = UDim2.new(0, 0, 0, 16),
        BackgroundColor3 = Theme.Element,
        Text             = "",
        AutoButtonColor  = false,
        Parent           = Row,
    })
    AddCorner(DropBtn, 3)
    AddStroke(DropBtn, Theme.Border, 1, 0.87)

    local function GetDisplay()
        if Multi then
            local Sel = {}
            for K, V in pairs(State.Value) do if V then table.insert(Sel, tostring(K)) end end
            return #Sel == 0 and "None" or table.concat(Sel, ", ")
        end
        return tostring(State.Value)
    end

    local DisplayLabel = Create("TextLabel", {
        Size               = UDim2.new(1, -24, 1, 0),
        Position           = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text               = GetDisplay(),
        TextColor3         = Theme.Text,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
        Parent             = DropBtn,
    })
    Create("TextLabel", {
        Size               = UDim2.fromOffset(16, 20),
        Position           = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Text               = "▾",
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 10,
        Parent             = DropBtn,
    })

    local Expanded  = false
    local ListFrame = nil

    local function CloseList()
        if ListFrame then ListFrame:Destroy(); ListFrame = nil end
        Expanded = false
    end

    DropBtn.MouseButton1Click:Connect(function()
        if Expanded then CloseList(); return end
        Expanded = true

        ListFrame = Create("Frame", {
            Size             = UDim2.new(1, 0, 0, #Values * 20),
            Position         = UDim2.new(0, 0, 1, 2),
            BackgroundColor3 = Theme.Panel,
            ZIndex           = 10,
            Parent           = DropBtn,
        })
        AddCorner(ListFrame, 3)
        AddStroke(ListFrame, Theme.Border, 1, 0.87)
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = ListFrame })

        local function Populate()
            for _, Child in ipairs(ListFrame:GetChildren()) do
                if Child:IsA("TextButton") then Child:Destroy() end
            end
            for _, V in ipairs(Values) do
                local IsSelected = Multi and (State.Value[V] == true) or (State.Value == V)
                local ItemBtn = Create("TextButton", {
                    Size               = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3   = IsSelected and Theme.ElementActive or Theme.Panel,
                    BackgroundTransparency = IsSelected and 0 or 1,
                    Text               = "",
                    AutoButtonColor    = false,
                    ZIndex             = 11,
                    Parent             = ListFrame,
                })
                Create("TextLabel", {
                    Size               = UDim2.new(1, -8, 1, 0),
                    Position           = UDim2.fromOffset(8, 0),
                    BackgroundTransparency = 1,
                    Text               = V,
                    TextColor3         = IsSelected and Theme.Accent or Theme.Text,
                    Font               = Enum.Font.SourceSans,
                    TextSize           = 12,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    ZIndex             = 12,
                    Parent             = ItemBtn,
                })
                ItemBtn.MouseEnter:Connect(function()
                    if not IsSelected then Tween(ItemBtn, 0.1, { BackgroundColor3 = Theme.ElementHover, BackgroundTransparency = 0.5 }) end
                end)
                ItemBtn.MouseLeave:Connect(function()
                    if not IsSelected then Tween(ItemBtn, 0.1, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1 }) end
                end)
                ItemBtn.MouseButton1Click:Connect(function()
                    if Multi then
                        local Curr = State.Value
                        Curr[V] = not Curr[V]
                        State:SetValue(Curr)
                        DisplayLabel.Text = GetDisplay()
                        Populate()
                    else
                        State:SetValue(V)
                        DisplayLabel.Text = V
                        CloseList()
                    end
                end)
            end
        end
        Populate()
    end)

    return State
end

-- Button
function GroupboxMethods:AddButton(Config)
    Config = Config or {}
    local Text = Config.Text or "Button"
    local Func = Config.Func or function() end

    local Row = self:_AddRow(24)

    local Btn = Create("TextButton", {
        Size             = UDim2.new(1, 0, 0, 20),
        Position         = UDim2.fromOffset(0, 2),
        BackgroundColor3 = Theme.Element,
        Text             = Text,
        TextColor3       = Theme.Text,
        Font             = Enum.Font.SourceSansBold,
        TextSize         = 12,
        AutoButtonColor  = false,
        Parent           = Row,
    })
    AddCorner(Btn, 3)
    local BtnStroke = AddStroke(Btn, Theme.Border, 1, 0.87)

    Btn.MouseEnter:Connect(function()
        Tween(Btn, 0.12, { BackgroundColor3 = Theme.ElementHover })
        Tween(BtnStroke, 0.12, { Transparency = 0.3, Color = Theme.Accent })
    end)
    Btn.MouseLeave:Connect(function()
        Tween(Btn, 0.12, { BackgroundColor3 = Theme.Element })
        Tween(BtnStroke, 0.12, { Transparency = 0.87, Color = Theme.Border })
    end)
    Btn.MouseButton1Click:Connect(function()
        Tween(Btn, 0.05, { BackgroundColor3 = Theme.ElementActive })
        task.delay(0.1, function() Tween(Btn, 0.12, { BackgroundColor3 = Theme.Element }) end)
        pcall(Func)
    end)
end

-- Input
function GroupboxMethods:AddInput(Key, Config)
    Config = Config or {}
    local Text        = Config.Text or Key
    local Default     = Config.Default or ""
    local Placeholder = Config.Placeholder or ""
    local Callback    = Config.Callback

    local State = CreateElementState(Key, Default)
    Library.Options[Key] = State

    local Row = self:_AddRow(38)

    Create("TextLabel", {
        Size               = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text               = Text,
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = Row,
    })

    local InputBox = Create("TextBox", {
        Size             = UDim2.new(1, 0, 0, 20),
        Position         = UDim2.new(0, 0, 0, 16),
        BackgroundColor3 = Theme.Element,
        Text             = Default,
        PlaceholderText  = Placeholder,
        PlaceholderColor3 = Color3.fromRGB(70, 75, 90),
        TextColor3       = Theme.Text,
        Font             = Enum.Font.SourceSans,
        TextSize         = 12,
        ClearTextOnFocus = false,
        Parent           = Row,
    })
    AddCorner(InputBox, 3)
    local InputStroke = AddStroke(InputBox, Theme.Border, 1, 0.87)
    AddPadding(InputBox, 0, 6, 0, 6)

    InputBox.Focused:Connect(function()
        Tween(InputStroke, 0.12, { Transparency = 0.3, Color = Theme.Accent })
    end)
    InputBox.FocusLost:Connect(function()
        Tween(InputStroke, 0.12, { Transparency = 0.87, Color = Theme.Border })
        State:SetValue(InputBox.Text)
        if Callback then pcall(Callback, InputBox.Text) end
    end)

    return State
end

-- Label
function GroupboxMethods:AddLabel(Text)
    local Row = self:_AddRow(14)
    local L = Create("TextLabel", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = Text or "",
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = Row,
    })
    return { SetText = function(_, T) L.Text = T end }
end

-- Divider
function GroupboxMethods:AddDivider()
    local Row = self:_AddRow(8)
    Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 1),
        Position           = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3   = Theme.Border,
        BackgroundTransparency = 0.9,
        BorderSizePixel    = 0,
        Parent             = Row,
    })
end

-- // Shared Groupbox Builder

local function BuildGroupbox(Name, Column)
    local BoxFrame = Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 0),
        AutomaticSize      = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent             = Column,
    })

    local Card = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel,
        Parent           = BoxFrame,
    })
    AddCorner(Card, 4)
    AddStroke(Card, Theme.Border, 1, 0.95)

    -- Title cutout — background matches sidebar/content bg to visually "cut" the border
    local TitleBg = Create("Frame", {
        Size          = UDim2.new(0, 0, 0, 14),
        Position      = UDim2.fromOffset(10, -8),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent        = Card,
    })
    AddPadding(TitleBg, 0, 4, 0, 4)

    Create("TextLabel", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = Name,
        TextColor3         = Theme.Text,
        TextTransparency   = 0.5,
        Font               = Enum.Font.SourceSans,
        TextSize           = 12,
        TextXAlignment     = Enum.TextXAlignment.Center,
        Parent             = TitleBg,
    })

    local Container = Create("Frame", {
        Size               = UDim2.new(1, -16, 0, 0),
        Position           = UDim2.fromOffset(8, 10),
        AutomaticSize      = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent             = Card,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 8),
        Parent    = Container,
    })
    -- Bottom spacer
    Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 6),
        BackgroundTransparency = 1,
        LayoutOrder        = 99999,
        Parent             = Container,
    })

    return setmetatable({ Card = Card, Container = Container, Name = Name }, GroupboxMethods)
end

-- // Shared Column Builder

local function BuildColumns(Parent)
    local LeftColumn = Create("ScrollingFrame", {
        Size                 = UDim2.new(0.5, -4, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize           = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ScrollBarThickness   = 1,
        ScrollBarImageColor3 = Theme.Border,
        BorderSizePixel      = 0,
        Parent               = Parent,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = LeftColumn })
    AddPadding(LeftColumn, 8, 2, 8, 2)

    local RightColumn = Create("ScrollingFrame", {
        Size                 = UDim2.new(0.5, -4, 1, 0),
        Position             = UDim2.new(0.5, 4, 0, 0),
        BackgroundTransparency = 1,
        CanvasSize           = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ScrollBarThickness   = 1,
        ScrollBarImageColor3 = Theme.Border,
        BorderSizePixel      = 0,
        Parent               = Parent,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = RightColumn })
    AddPadding(RightColumn, 8, 2, 8, 2)

    return LeftColumn, RightColumn
end

-- // Subtab Methods

local SubtabMethods = {}
SubtabMethods.__index = SubtabMethods

function SubtabMethods:AddLeftGroupbox(Name)
    return BuildGroupbox(Name, self.LeftColumn)
end

function SubtabMethods:AddRightGroupbox(Name)
    return BuildGroupbox(Name, self.RightColumn)
end

-- // SubtabBar Methods

local SubtabBarMethods = {}
SubtabBarMethods.__index = SubtabBarMethods

function SubtabBarMethods:GetSubtab(Index)
    return self.Subtabs[Index]
end

function SubtabBarMethods:SelectSubtab(Index)
    if self.ActiveIndex == Index then return end
    self.ActiveIndex = Index

    for i, SubtabObj in ipairs(self.Subtabs) do
        SubtabObj.Frame.Visible = (i == Index)
        local Btn   = self.Buttons[i]
        local Label = Btn:FindFirstChildOfClass("TextLabel")
        local Active = (i == Index)
        Tween(Btn, 0.12, {
            BackgroundColor3       = Active and Theme.ElementActive or Theme.Element,
            BackgroundTransparency = Active and 0 or 1,
        })
        if Label then Label.TextColor3 = Active and Theme.Accent or Theme.TextDim end
    end
end

-- // Tab Methods

local TabMethods = {}
TabMethods.__index = TabMethods

-- Segmented subtab control — equivalent to c_gui::subtab
-- Returns a SubtabBarObj; call :GetSubtab(i) to add groupboxes to a specific subtab
function TabMethods:AddSubtabBar(Names)
    -- Hide direct columns — subtab bar takes over content layout
    self.LeftColumn.Visible  = false
    self.RightColumn.Visible = false

    -- Segment bar frame (sits inside the pre-allocated SubtabBarHolder)
    local BtnWidth = 80
    local BarFrame = Create("Frame", {
        Size             = UDim2.fromOffset(#Names * BtnWidth, 22),
        BackgroundColor3 = Theme.Element,
        Parent           = self.SubtabBarHolder,
    })
    AddCorner(BarFrame, 3)
    AddStroke(BarFrame, Theme.Border, 1, 0.87)

    -- Subtab content lives in ColumnsArea (full height since bar holder is separate)
    local SubtabBarObj = setmetatable({
        BarFrame    = BarFrame,
        Subtabs     = {},
        Buttons     = {},
        ActiveIndex = 1,
    }, SubtabBarMethods)

    for i, Name in ipairs(Names) do
        local IsFirst = (i == 1)
        local IsLast  = (i == #Names)

        local Btn = Create("TextButton", {
            Size               = UDim2.fromOffset(BtnWidth, 22),
            Position           = UDim2.fromOffset((i - 1) * BtnWidth, 0),
            BackgroundColor3   = IsFirst and Theme.ElementActive or Theme.Element,
            BackgroundTransparency = IsFirst and 0 or 1,
            Text               = "",
            AutoButtonColor    = false,
            ZIndex             = 3,
            Parent             = BarFrame,
        })
        -- Round only the relevant corners per position (matching subtab flags in Neverlose)
        if IsFirst or IsLast then AddCorner(Btn, 3) end

        Create("TextLabel", {
            Size               = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text               = Name,
            TextColor3         = IsFirst and Theme.Accent or Theme.TextDim,
            Font               = Enum.Font.SourceSans,
            TextSize           = 12,
            ZIndex             = 4,
            Parent             = Btn,
        })

        -- Divider between segments
        if not IsLast then
            Create("Frame", {
                Size               = UDim2.new(0, 1, 0.5, 0),
                Position           = UDim2.new(0, BtnWidth - 1, 0.25, 0),
                BackgroundColor3   = Theme.Border,
                BackgroundTransparency = 0.6,
                BorderSizePixel    = 0,
                ZIndex             = 3,
                Parent             = BarFrame,
            })
        end

        -- Each subtab gets its own content frame + columns
        local ContentFrame = Create("Frame", {
            Size               = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible            = IsFirst,
            Parent             = self.ColumnsArea,
        })
        local LeftCol, RightCol = BuildColumns(ContentFrame)

        local SubtabObj = setmetatable({
            Frame       = ContentFrame,
            LeftColumn  = LeftCol,
            RightColumn = RightCol,
        }, SubtabMethods)

        table.insert(SubtabBarObj.Subtabs, SubtabObj)
        table.insert(SubtabBarObj.Buttons, Btn)

        local idx = i
        Btn.MouseButton1Click:Connect(function()
            SubtabBarObj:SelectSubtab(idx)
        end)
        Btn.MouseEnter:Connect(function()
            if SubtabBarObj.ActiveIndex ~= idx then
                Tween(Btn, 0.1, { BackgroundColor3 = Theme.ElementHover, BackgroundTransparency = 0.5 })
            end
        end)
        Btn.MouseLeave:Connect(function()
            if SubtabBarObj.ActiveIndex ~= idx then
                Tween(Btn, 0.1, { BackgroundColor3 = Theme.Element, BackgroundTransparency = 1 })
            end
        end)
    end

    return SubtabBarObj
end

-- Direct groupbox — used when no subtab bar on this tab
function TabMethods:AddLeftGroupbox(Name)
    return BuildGroupbox(Name, self.LeftColumn)
end

function TabMethods:AddRightGroupbox(Name)
    return BuildGroupbox(Name, self.RightColumn)
end

-- // Window Methods

local WindowMethods = {}
WindowMethods.__index = WindowMethods

-- Category separator label in sidebar — equivalent to c_gui::group_title
function WindowMethods:AddSidebarLabel(Name)
    local F = Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Parent             = self.TabListFrame,
    })
    AddPadding(F, 0, 0, 0, 4)
    Create("TextLabel", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = Name,
        TextColor3         = Theme.TextDim,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = F,
    })
end

function WindowMethods:AddSidebarSpacer(Height)
    Create("Frame", {
        Size               = UDim2.new(1, 0, 0, Height or 6),
        BackgroundTransparency = 1,
        Parent             = self.TabListFrame,
    })
end

-- Tab — equivalent to c_gui::tab (icon + label sidebar button)
-- Usage: Window:AddTab("TabName") or Window:AddTab("⊕", "TabName")
function WindowMethods:AddTab(Icon, Name)
    if Name == nil then Name, Icon = Icon, nil end

    local TabObj = setmetatable({ Name = Name, Icon = Icon, Window = self }, TabMethods)

    -- Full tab content frame
    local TabContent = Create("Frame", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible            = (#self.Tabs == 0),
        Parent             = self.ContentArea,
    })

    -- Subtab bar holder (28px, empty until AddSubtabBar is called)
    local SubtabBarHolder = Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent             = TabContent,
    })

    -- Columns area (height accounts for SubtabBarHolder even when empty)
    local ColumnsArea = Create("Frame", {
        Size               = UDim2.new(1, 0, 1, -28),
        Position           = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent             = TabContent,
    })

    -- Default direct columns (used when no subtab bar)
    local LeftColumn, RightColumn = BuildColumns(ColumnsArea)

    TabObj.Frame           = TabContent
    TabObj.SubtabBarHolder = SubtabBarHolder
    TabObj.ColumnsArea     = ColumnsArea
    TabObj.LeftColumn      = LeftColumn
    TabObj.RightColumn     = RightColumn

    -- Sidebar button
    local IsFirst = (#self.Tabs == 0)
    local TabBtn = Create("TextButton", {
        Size               = UDim2.new(1, 0, 0, 30),
        BackgroundColor3   = IsFirst and Theme.ElementActive or Theme.Sidebar,
        BackgroundTransparency = IsFirst and 0 or 1,
        Text               = "",
        AutoButtonColor    = false,
        Parent             = self.TabListFrame,
    })
    AddCorner(TabBtn, 3)

    -- Active left-edge indicator (3px bar)
    local Indicator = Create("Frame", {
        Size             = UDim2.new(0, 3, 0.6, 0),
        Position         = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = Theme.Accent,
        Visible          = IsFirst,
        BorderSizePixel  = 0,
        Parent           = TabBtn,
    })
    AddCorner(Indicator, 1)

    if Icon then
        Create("TextLabel", {
            Size               = UDim2.fromOffset(22, 30),
            Position           = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Text               = Icon,
            TextColor3         = Theme.Accent,
            Font               = Enum.Font.SourceSans,
            TextSize           = 14,
            TextXAlignment     = Enum.TextXAlignment.Left,
            Parent             = TabBtn,
        })
    end

    local LabelOffset = Icon and 36 or 10
    local Label = Create("TextLabel", {
        Size               = UDim2.new(1, -LabelOffset - 6, 1, 0),
        Position           = UDim2.fromOffset(LabelOffset, 0),
        BackgroundTransparency = 1,
        Text               = Name,
        TextColor3         = IsFirst and Theme.Text or Theme.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = TabBtn,
    })

    TabObj.Button    = TabBtn
    TabObj.Indicator = Indicator
    TabObj.Label     = Label

    table.insert(self.Tabs, TabObj)

    TabBtn.MouseButton1Click:Connect(function() self:SelectTab(TabObj) end)
    TabBtn.MouseEnter:Connect(function()
        if self.ActiveTab ~= TabObj then
            Tween(TabBtn, 0.12, { BackgroundTransparency = 0.7, BackgroundColor3 = Theme.ElementHover })
            Tween(Label, 0.12, { TextColor3 = Theme.Text })
        end
    end)
    TabBtn.MouseLeave:Connect(function()
        if self.ActiveTab ~= TabObj then
            Tween(TabBtn, 0.12, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Sidebar })
            Tween(Label, 0.12, { TextColor3 = Theme.TextDim })
        end
    end)

    if #self.Tabs == 1 then self.ActiveTab = TabObj end
    return TabObj
end

function WindowMethods:SelectTab(TabObj)
    if self.ActiveTab == TabObj then return end
    if self.ActiveTab then
        local Old = self.ActiveTab
        Old.Frame.Visible    = false
        Old.Indicator.Visible = false
        Tween(Old.Button, 0.12, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Sidebar })
        Tween(Old.Label, 0.12, { TextColor3 = Theme.TextDim })
    end
    self.ActiveTab = TabObj
    TabObj.Frame.Visible    = true
    TabObj.Indicator.Visible = true
    Tween(TabObj.Button, 0.12, { BackgroundTransparency = 0, BackgroundColor3 = Theme.ElementActive })
    Tween(TabObj.Label, 0.12, { TextColor3 = Theme.Text })
end

-- // Unload

function Library:OnUnload(Callback)
    table.insert(Library.UnloadCallbacks, Callback)
end

function Library:Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true
    for _, Callback in ipairs(Library.UnloadCallbacks) do pcall(Callback) end
    for _, Conn in ipairs(Library.Connections) do
        if typeof(Conn) == "RBXScriptConnection" then Conn:Disconnect() end
    end
    if Library.ScreenGui then Library.ScreenGui:Destroy() end
end

-- // Create Window

function Library:CreateWindow(Config)
    Config = Config or {}
    local Title       = Config.Title or "NEVERLOSE"
    local Size        = Config.Size or UDim2.fromOffset(690, 500)
    local Center      = Config.Center ~= false
    local UserName    = Config.UserName or "User"
    local UserSub     = Config.UserSubtitle or ""

    local ScreenGui = Create("ScreenGui", {
        Name            = "NeverloseGui",
        ResetOnSpawn    = false,
        IgnoreGuiInset  = true,
        ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    Library.ScreenGui = ScreenGui

    local WinPos = Center
        and UDim2.new(0.5, -Size.X.Offset / 2, 0.5, -Size.Y.Offset / 2)
        or  UDim2.fromOffset(120, 120)

    -- Main frame — transparent background matching ImGuiWindowFlags_NoBackground
    local MainFrame = Create("Frame", {
        Size               = Size,
        Position           = WinPos,
        BackgroundTransparency = 1,
        Parent             = ScreenGui,
    })
    MakeDraggable(MainFrame, MainFrame)
    Library.MainFrame = MainFrame

    -- // Sidebar (170px wide)

    local SidebarFrame = Create("Frame", {
        Size             = UDim2.new(0, 170, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel  = 0,
        Parent           = MainFrame,
    })
    AddCorner(SidebarFrame, 5)
    AddStroke(SidebarFrame, Theme.Border, 1, 0.95)

    -- Vertical separator on the right edge of sidebar
    Create("Frame", {
        Size               = UDim2.new(0, 1, 1, 0),
        Position           = UDim2.new(1, -1, 0, 0),
        BackgroundColor3   = Theme.Border,
        BackgroundTransparency = 0.87,
        BorderSizePixel    = 0,
        Parent             = SidebarFrame,
    })

    -- Title — shadow drawn first (accent color, +1px offset), then white on top
    -- Equivalent to the two draw->AddText calls in main.cpp for the "NEVERLOSE" header
    Create("TextLabel", {
        Size               = UDim2.new(1, 0, 0, 60),
        Position           = UDim2.fromOffset(1, 1),
        BackgroundTransparency = 1,
        Text               = Title,
        TextColor3         = Theme.Accent,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 20,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
        ZIndex             = 0,
        Parent             = SidebarFrame,
    })
    Create("TextLabel", {
        Size               = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        Text               = Title,
        TextColor3         = Theme.Text,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 20,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
        Parent             = SidebarFrame,
    })

    -- Scrolling tab list
    local TabListFrame = Create("ScrollingFrame", {
        Size                 = UDim2.new(1, -10, 1, -120),
        Position             = UDim2.fromOffset(5, 65),
        BackgroundTransparency = 1,
        CanvasSize           = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ScrollBarThickness   = 0,
        BorderSizePixel      = 0,
        Parent               = SidebarFrame,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 3),
        Parent    = TabListFrame,
    })

    -- User info section at bottom of sidebar
    -- Equivalent to the avatar + username + "Till: Lifetime" section in main.cpp
    local UserFrame = Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 50),
        Position           = UDim2.new(0, 0, 1, -50),
        BackgroundTransparency = 1,
        Parent             = SidebarFrame,
    })

    Create("Frame", {
        Size               = UDim2.new(1, 0, 0, 1),
        BackgroundColor3   = Theme.Border,
        BackgroundTransparency = 0.5,
        BorderSizePixel    = 0,
        Parent             = UserFrame,
    })

    local AvatarFrame = Create("Frame", {
        Size             = UDim2.fromOffset(30, 30),
        Position         = UDim2.fromOffset(15, 10),
        BackgroundColor3 = Theme.ElementActive,
        Parent           = UserFrame,
    })
    AddCorner(AvatarFrame, 15)
    AddStroke(AvatarFrame, Theme.Accent, 1, 0.5)

    Create("TextLabel", {
        Size               = UDim2.fromOffset(110, 16),
        Position           = UDim2.fromOffset(50, 8),
        BackgroundTransparency = 1,
        Text               = UserName,
        TextColor3         = Theme.Text,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = UserFrame,
    })

    if UserSub ~= "" then
        local SubParts = string.split(UserSub, ":")
        local SubLabel = Create("TextLabel", {
            Size               = UDim2.fromOffset(110, 14),
            Position           = UDim2.fromOffset(50, 26),
            BackgroundTransparency = 1,
            Text               = SubParts[1] and (SubParts[1] .. ":") or UserSub,
            TextColor3         = Theme.TextDim,
            Font               = Enum.Font.SourceSans,
            TextSize           = 11,
            TextXAlignment     = Enum.TextXAlignment.Left,
            Parent             = UserFrame,
        })
        if SubParts[2] then
            local SubLabelW = 50 + 6 + #(SubParts[1] .. ":") * 6
            Create("TextLabel", {
                Size               = UDim2.fromOffset(80, 14),
                Position           = UDim2.fromOffset(SubLabelW, 26),
                BackgroundTransparency = 1,
                Text               = SubParts[2]:match("^%s*(.-)%s*$"),
                TextColor3         = Theme.Accent,
                Font               = Enum.Font.SourceSans,
                TextSize           = 11,
                TextXAlignment     = Enum.TextXAlignment.Left,
                Parent             = UserFrame,
            })
        end
    end

    -- // Content area (right of sidebar, with small gap)

    local ContentArea = Create("Frame", {
        Size               = UDim2.new(1, -175, 1, 0),
        Position           = UDim2.fromOffset(175, 0),
        BackgroundTransparency = 1,
        Parent             = MainFrame,
    })

    -- RightControl toggles window visibility
    table.insert(Library.Connections, UserInputService.InputBegan:Connect(function(Input, GPE)
        if GPE then return end
        if Input.KeyCode == Enum.KeyCode.RightControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end))

    local WindowObj = setmetatable({
        MainFrame    = MainFrame,
        TabListFrame = TabListFrame,
        ContentArea  = ContentArea,
        Tabs         = {},
        ActiveTab    = nil,
    }, WindowMethods)

    Library.Window = WindowObj
    return WindowObj
end

return Library
