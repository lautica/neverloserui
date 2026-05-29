-- ZyrexLib_Final.lua
-- Standalone Roblox/Luau UI library inspired by the supplied Zyrex Dear ImGui source.
-- Returns ZyrexLib. Designed for loadstring(game:HttpGet(...))().

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local ZyrexLib = {
    Version = "1.2.3-final-luau",
    Flags = {},
    Options = {},
    Windows = {},
    Connections = {},
    Keybinds = {},
    Unloaded = false,
}

local Tokens = {
    WindowW = 760,
    WindowH = 554,
    HeaderH = 48,
    Pad = 16,
    ItemSpacing = 16,
    ChildPad = 14,
    CellPadX = 4,
    CellPadY = 2,
    FramePadX = 12,
    FramePadY = 12,
    FontSize = 14,
    HeaderFontSize = 16,
    CodeFontSize = 14,
    WindowRounding = 7,
    ChildRounding = 5,
    FrameRounding = 4,
    PopupRounding = 3,
    Border = 1,
    Scrollbar = 6,
    Anim = .165,
    FastAnim = .105,
    SlowAnim = .24,
}
ZyrexLib.Tokens = Tokens

local Theme = {
    WindowBg = Color3.fromRGB(10, 7, 8),
    TitleBg = Color3.fromRGB(18, 15, 17),
    ChildBg = Color3.fromRGB(18, 15, 17),
    ChildBgAlpha = Color3.fromRGB(18, 15, 17),
    PopupBg = Color3.fromRGB(18, 15, 17),
    Text = Color3.fromRGB(218, 218, 218),
    TextDisabled = Color3.fromRGB(85, 85, 85),
    TextDim = Color3.fromRGB(65, 60, 62),
    CheckMark = Color3.fromRGB(218, 218, 218),
    Border = Color3.fromRGB(34, 28, 30),
    BorderSoft = Color3.fromRGB(25, 21, 23),
    Separator = Color3.fromRGB(34, 28, 30),
    Accent = Color3.fromRGB(87, 190, 234),
    AccentHovered = Color3.fromRGB(0, 122, 200),
    AccentActive = Color3.fromRGB(0, 122, 200),
    FrameBg = Color3.fromRGB(26, 22, 23),
    FrameBgHovered = Color3.fromRGB(34, 30, 31),
    FrameBgActive = Color3.fromRGB(21, 18, 19),
    Shadow = Color3.fromRGB(0, 0, 0),
    Tab = Color3.fromRGB(14, 12, 13),
    TabHovered = Color3.fromRGB(26, 22, 23),
    TabActive = Color3.fromRGB(21, 18, 19),
    White = Color3.fromRGB(255, 255, 255),
    Black = Color3.fromRGB(0, 0, 0),
}
ZyrexLib.Theme = Theme

local IconGlyphs = {
    running = "↗", code = "</>", eye = "◉", misc = "⌘", palette = "✿", settings = "⚙",
    target = "✥", click = "◉", clock = "◷", crime = "◇", cursor = "➤", evil = "☠",
    globe = "◎", knife = "⌁", location = "◆", objects = "▦", pulse = "∿", verified = "✓", wrench = "⚙",
    clear = "×", open = "▣", save = "▤", play = "▶",
}

ZyrexLib.Assets = {
    IconIds = {}, -- optional: set ZyrexLib.Assets.IconIds.target = "rbxassetid://..."
    FontFace = nil,
    HeaderFontFace = nil,
    CodeFontFace = nil,
}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(ZyrexLib.Connections, c)
    return c
end

local function create(className, props, children)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = obj
        end
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

local function corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
        Parent = parent,
    })
end

local function padding(parent, l, t, r, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function list(parent, pad, direction)
    return create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, pad or 0),
        Parent = parent,
    })
end

local function tween(obj, duration, props, easing)
    local t = TweenService:Create(obj, TweenInfo.new(duration or Tokens.Anim, easing or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function round(x)
    return math.floor(x + .5)
end

local function colorAlpha(color, alpha)
    return color, 1 - alpha
end

local function setFont(label, kind)
    if kind == "code" and ZyrexLib.Assets.CodeFontFace then
        label.FontFace = ZyrexLib.Assets.CodeFontFace
    elseif kind == "header" and ZyrexLib.Assets.HeaderFontFace then
        label.FontFace = ZyrexLib.Assets.HeaderFontFace
    elseif ZyrexLib.Assets.FontFace then
        label.FontFace = ZyrexLib.Assets.FontFace
    else
        label.Font = (kind == "code") and Enum.Font.Code or Enum.Font.SourceSansSemibold
    end
end

local function textLabel(props, kind)
    local obj = create("TextLabel", props)
    setFont(obj, kind)
    return obj
end

local function textButton(props, kind)
    local obj = create("TextButton", props)
    setFont(obj, kind)
    obj.AutoButtonColor = false
    return obj
end

local function measure(text, size, font)
    local ok, res = pcall(function()
        return TextService:GetTextSize(tostring(text), size or Tokens.FontSize, font or Enum.Font.SourceSansSemibold, Vector2.new(10000, 10000))
    end)
    if ok then return res end
    return Vector2.new(#tostring(text) * 7, size or Tokens.FontSize)
end

local function addSoftShadow(parent, radius)
    local shadow = create("Frame", {
        Name = "Shadow",
        Size = UDim2.new(1, 18, 1, 18),
        Position = UDim2.fromOffset(-9, -4),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = .78,
        BorderSizePixel = 0,
        ZIndex = math.max(0, parent.ZIndex - 1),
        Parent = parent.Parent,
    })
    corner(shadow, radius or 9)
    shadow.Parent = parent
    shadow.Size = UDim2.new(1, 16, 1, 16)
    shadow.Position = UDim2.fromOffset(-8, -3)
    return shadow
end

local function icon(parent, key, size, color, z)
    size = size or 14
    local img = ZyrexLib.Assets.IconIds[key]
    if img then
        return create("ImageLabel", {
            Size = UDim2.fromOffset(size, size),
            BackgroundTransparency = 1,
            Image = img,
            ImageColor3 = color or Theme.Text,
            ZIndex = z or parent.ZIndex + 1,
            Parent = parent,
        })
    end
    local txt = textLabel({
        Size = UDim2.fromOffset(size + 4, size),
        BackgroundTransparency = 1,
        Text = IconGlyphs[key] or key or "•",
        TextColor3 = color or Theme.Text,
        TextSize = math.max(10, size - 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = z or parent.ZIndex + 1,
        Parent = parent,
    })
    return txt
end

local function drawCheckMark(parent, z)
    local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or parent.ZIndex + 3, Parent = parent })
    local a = create("Frame", {
        Size = UDim2.fromOffset(2, 6),
        AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromOffset(5, 8),
        Rotation = -42,
        BackgroundColor3 = Theme.CheckMark,
        BorderSizePixel = 0,
        ZIndex = holder.ZIndex + 1,
        Parent = holder,
    })
    corner(a, 1)
    local b = create("Frame", {
        Size = UDim2.fromOffset(2, 10),
        AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromOffset(9, 7),
        Rotation = 43,
        BackgroundColor3 = Theme.CheckMark,
        BorderSizePixel = 0,
        ZIndex = holder.ZIndex + 1,
        Parent = holder,
    })
    corner(b, 1)
    return holder
end

local function state(key, default, callback)
    local s = { Value = default, Callbacks = {} }
    if callback then table.insert(s.Callbacks, callback) end
    function s:Set(v, silent)
        self.Value = v
        ZyrexLib.Flags[key] = v
        if not silent then
            for _, cb in ipairs(self.Callbacks) do
                task.spawn(cb, v)
            end
        end
    end
    function s:Get()
        return self.Value
    end
    function s:OnChanged(cb)
        table.insert(self.Callbacks, cb)
        task.spawn(cb, self.Value)
        return self
    end
    ZyrexLib.Options[key] = s
    ZyrexLib.Flags[key] = default
    return s
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos, dragInput
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)
    connect(handle.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function updateScale(root, scaleObj, refW, refH)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scale = math.min(1, math.min((vp.X - 40) / refW, (vp.Y - 40) / refH))
    scaleObj.Scale = scale
end

local function makeHoverFrame(btn, idleColor, hoverColor, activeColor, strokeObj)
    connect(btn.MouseEnter, function()
        tween(btn, Tokens.FastAnim, { BackgroundColor3 = hoverColor or Theme.FrameBgHovered })
        if strokeObj then tween(strokeObj, Tokens.FastAnim, { Color = Theme.Border }) end
    end)
    connect(btn.MouseLeave, function()
        tween(btn, Tokens.FastAnim, { BackgroundColor3 = idleColor or Theme.FrameBg })
    end)
    connect(btn.MouseButton1Down, function()
        tween(btn, .06, { BackgroundColor3 = activeColor or Theme.FrameBgActive })
    end)
    connect(btn.MouseButton1Up, function()
        tween(btn, Tokens.FastAnim, { BackgroundColor3 = hoverColor or Theme.FrameBgHovered })
    end)
end

local Groupbox = {}
Groupbox.__index = Groupbox

function Groupbox:_row(height)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 22),
        BackgroundTransparency = 1,
        ZIndex = self.ZIndex + 1,
        Parent = self.Container,
    })
    return row
end

function Groupbox:AddSeparator(text)
    local row = self:_row(20)
    local line = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, .5, 0),
        BackgroundColor3 = Theme.Separator,
        BackgroundTransparency = .18,
        BorderSizePixel = 0,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local label = textLabel({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.ChildBg,
        BorderSizePixel = 0,
        Text = text or "Section",
        TextColor3 = Theme.TextDisabled,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 2,
        Parent = row,
    })
    padding(label, 0, 0, 8, 0)
    return { Frame = row, Label = label, Line = line }
end

function Groupbox:AddLabel(text)
    local row = self:_row(20)
    local l = textLabel({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local obj = { Frame = row, Label = l }
    function obj:SetText(v) l.Text = tostring(v) end
    return obj
end

function Groupbox:AddToggle(key, cfg)
    cfg = cfg or {}
    local text = cfg.Text or key
    local default = cfg.Default == true
    local s = state(key, default, cfg.Callback)
    local row = self:_row(24)

    local box = textButton({
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(0, 0, .5, -8),
        BackgroundColor3 = default and Theme.Accent or Theme.FrameBg,
        Text = "",
        ZIndex = row.ZIndex + 2,
        Parent = row,
    })
    corner(box, 4)
    local st = stroke(box, default and Theme.AccentHovered or Theme.Border, 1, default and .15 or .18)
    local check = drawCheckMark(box, box.ZIndex + 2)
    check.Visible = default
    for _, seg in ipairs(check:GetChildren()) do
        if seg:IsA("Frame") then
            seg.BackgroundTransparency = default and 0 or 1
        end
    end

    local label = textLabel({
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.fromOffset(26, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local hit = textButton({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = row.ZIndex + 5, Parent = row })

    local obj = { State = s, Frame = row, Type = "Toggle" }
    function obj:SetValue(v, silent)
        v = v == true
        s:Set(v, silent)
        tween(box, Tokens.FastAnim, { BackgroundColor3 = v and Theme.Accent or Theme.FrameBg })
        tween(st, Tokens.FastAnim, { Color = v and Theme.AccentHovered or Theme.Border, Transparency = v and .1 or .18 })
        check.Visible = true
        for _, seg in ipairs(check:GetChildren()) do
            if seg:IsA("Frame") then
                tween(seg, Tokens.FastAnim, { BackgroundTransparency = v and 0 or 1 })
            end
        end
        task.delay(Tokens.FastAnim, function()
            if check and check.Parent and not s.Value then check.Visible = false end
        end)
        return self
    end
    function obj:Get() return s.Value end
    function obj:OnChanged(cb) s:OnChanged(cb); return self end
    function obj:AddKeyPicker(k, c) return self.Parent:AddKeybind(k, c, self.Frame) end
    function obj:AddColorPicker(k, c) return self.Parent:AddColorPicker(k, c, self.Frame) end
    obj.Parent = self

    connect(hit.MouseButton1Click, function() obj:SetValue(not s.Value) end)
    connect(hit.MouseEnter, function() tween(box, Tokens.FastAnim, { BackgroundColor3 = s.Value and Theme.AccentHovered or Theme.FrameBgHovered }) end)
    connect(hit.MouseLeave, function() tween(box, Tokens.FastAnim, { BackgroundColor3 = s.Value and Theme.Accent or Theme.FrameBg }) end)
    return obj
end

function Groupbox:AddCheckbox(key, cfg)
    return self:AddToggle(key, cfg)
end

function Groupbox:AddHeaderToggle(key, cfg)
    cfg = cfg or {}
    local text = cfg.Text or key
    local default = cfg.Default == true
    local s = state(key, default, cfg.Callback)
    local row = self:_row(24)

    local label = textLabel({
        Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = Tokens.HeaderFontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    }, "header")

    local track = textButton({
        Size = UDim2.fromOffset(34, 18),
        AnchorPoint = Vector2.new(1, .5),
        Position = UDim2.new(1, 0, .5, 0),
        BackgroundColor3 = default and Theme.Accent:Lerp(Theme.White, .08) or Theme.FrameBg,
        Text = "",
        ZIndex = row.ZIndex + 2,
        Parent = row,
    })
    corner(track, 9)
    local st = stroke(track, default and Theme.AccentHovered or Theme.Border, 1, default and .2 or .12)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(.5, .5),
        Position = default and UDim2.new(1, -9, .5, 0) or UDim2.new(0, 9, .5, 0),
        BackgroundColor3 = default and Theme.White or Theme.TextDisabled,
        BorderSizePixel = 0,
        ZIndex = track.ZIndex + 2,
        Parent = track,
    })
    corner(knob, 6)

    local hit = textButton({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = row.ZIndex + 5, Parent = row })
    local obj = { State = s, Frame = row, Type = "HeaderToggle" }
    function obj:SetValue(v, silent)
        v = v == true
        s:Set(v, silent)
        tween(track, Tokens.Anim, { BackgroundColor3 = v and Theme.Accent or Theme.FrameBg })
        tween(st, Tokens.Anim, { Color = v and Theme.AccentHovered or Theme.Border, Transparency = v and .16 or .12 })
        tween(knob, Tokens.Anim, { Position = v and UDim2.new(1, -9, .5, 0) or UDim2.new(0, 9, .5, 0), BackgroundColor3 = v and Theme.White or Theme.TextDisabled })
        return self
    end
    function obj:Get() return s.Value end
    function obj:OnChanged(cb) s:OnChanged(cb); return self end
    connect(hit.MouseButton1Click, function() obj:SetValue(not s.Value) end)
    connect(hit.MouseEnter, function()
        if not s.Value then tween(track, Tokens.FastAnim, { BackgroundColor3 = Theme.FrameBgHovered }) end
    end)
    connect(hit.MouseLeave, function()
        if not s.Value then tween(track, Tokens.FastAnim, { BackgroundColor3 = Theme.FrameBg }) end
    end)
    return obj
end

function Groupbox:AddButton(cfg)
    cfg = cfg or {}
    local text = cfg.Text or "Button"
    local row = self:_row(32)
    local btn = textButton({
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.fromOffset(0, 2),
        BackgroundColor3 = Theme.FrameBg,
        Text = "",
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    corner(btn, Tokens.FrameRounding)
    local st = stroke(btn, Theme.Border, 1, .08)
    if cfg.Icon then
        local ic = icon(btn, cfg.Icon, 14, Theme.TextDisabled, btn.ZIndex + 1)
        ic.Position = UDim2.fromOffset(12, 7)
    end
    textLabel({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = btn.ZIndex + 1,
        Parent = btn,
    })
    makeHoverFrame(btn, Theme.FrameBg, Theme.FrameBgHovered, Theme.FrameBgActive, st)
    connect(btn.MouseButton1Click, function()
        if cfg.Callback or cfg.Func then task.spawn(cfg.Callback or cfg.Func) end
    end)
    return btn
end

function Groupbox:AddInput(key, cfg)
    cfg = cfg or {}
    local s = state(key, cfg.Default or "", cfg.Callback)
    local row = self:_row(42)
    textLabel({
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = cfg.Text or key,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local box = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 19),
        BackgroundColor3 = Theme.FrameBg,
        Text = tostring(cfg.Default or ""),
        PlaceholderText = cfg.Placeholder or "",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    setFont(box)
    corner(box, Tokens.FrameRounding)
    local st = stroke(box, Theme.Border, 1, .12)
    padding(box, 8, 0, 8, 0)
    connect(box.Focused, function() tween(st, Tokens.FastAnim, { Color = Theme.Accent, Transparency = .25 }) end)
    connect(box.FocusLost, function()
        tween(st, Tokens.FastAnim, { Color = Theme.Border, Transparency = .12 })
        s:Set(box.Text)
    end)
    return s
end

function Groupbox:AddSlider(key, cfg)
    cfg = cfg or {}
    local minv = cfg.Min or 0
    local maxv = cfg.Max or 100
    local default = cfg.Default or minv
    local rounding = cfg.Rounding or 0
    local suffix = cfg.Suffix or ""
    local s = state(key, default, cfg.Callback)
    local row = self:_row(38)

    local label = textLabel({
        Size = UDim2.new(.7, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = cfg.Text or key,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local valueLabel = textLabel({
        Size = UDim2.new(.3, 0, 0, 18),
        Position = UDim2.new(.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextDisabled,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local bar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.fromOffset(0, 25),
        BackgroundColor3 = Theme.FrameBg,
        BorderSizePixel = 0,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    corner(bar, 3)
    stroke(bar, Theme.Border, 1, .2)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = bar.ZIndex + 1, Parent = bar })
    corner(fill, 3)
    local thumb = create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.new(0, 0, .5, 0),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        ZIndex = bar.ZIndex + 3,
        Parent = bar,
    })
    corner(thumb, 7)
    stroke(thumb, Theme.Border, 1, .2)
    local hit = textButton({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 17), BackgroundTransparency = 1, Text = "", ZIndex = row.ZIndex + 5, Parent = row })

    local function format(v)
        if rounding == 0 then
            return tostring(math.floor(v + .5)) .. suffix
        end
        return string.format("%." .. tostring(rounding) .. "f", v) .. suffix
    end
    local function setByPercent(p, silent)
        p = clamp(p, 0, 1)
        local v = minv + (maxv - minv) * p
        if rounding == 0 then v = math.floor(v + .5) else local f = 10 ^ rounding; v = math.floor(v * f + .5) / f end
        v = clamp(v, minv, maxv)
        local sp = (v - minv) / (maxv - minv)
        fill.Size = UDim2.fromScale(sp, 1)
        thumb.Position = UDim2.new(sp, 0, .5, 0)
        valueLabel.Text = format(v)
        s:Set(v, silent)
    end
    setByPercent((default - minv) / (maxv - minv), true)

    local dragging = false
    local function updateFrom(input)
        local p = (input.Position.X - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X)
        setByPercent(p)
    end
    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFrom(input)
            tween(thumb, Tokens.FastAnim, { Size = UDim2.fromOffset(14, 14) })
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFrom(input)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            tween(thumb, Tokens.FastAnim, { Size = UDim2.fromOffset(12, 12) })
        end
    end)
    local obj = s
    function obj:SetValue(v, silent) setByPercent((v - minv) / (maxv - minv), silent); return self end
    return obj
end

function Groupbox:AddDropdown(key, cfg)
    cfg = cfg or {}
    local values = cfg.Values or cfg.Items or {}
    local default = cfg.Default or values[1] or ""
    local s = state(key, default, cfg.Callback)
    local row = self:_row(42)
    local label = textLabel({
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = cfg.Text or key,
        TextColor3 = Theme.Text,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    local combo = textButton({
        Size = UDim2.new(.58, 0, 0, 24),
        Position = UDim2.new(.42, 0, 0, 18),
        BackgroundColor3 = Theme.FrameBg,
        Text = "",
        ZIndex = row.ZIndex + 2,
        Parent = row,
    })
    corner(combo, Tokens.FrameRounding)
    stroke(combo, Theme.Border, 1, .12)
    local display = textLabel({
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Theme.TextDisabled,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = combo.ZIndex + 1,
        Parent = combo,
    })
    local arrow = textLabel({
        Size = UDim2.fromOffset(20, 24),
        Position = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = Theme.TextDisabled,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = combo.ZIndex + 1,
        Parent = combo,
    })

    local popup
    local function close()
        if popup then popup:Destroy(); popup = nil end
        if self.Window then self.Window:_hideOverlay() end
    end
    local function open()
        if popup then close(); return end
        if self.Window then self.Window:_showOverlay(close) end
        local root = self.Window and self.Window.OverlayRoot or self.Container
        local abs = combo.AbsolutePosition - root.AbsolutePosition
        local h = math.min(#values, cfg.MaxVisible or 6) * 24
        popup = create("Frame", {
            Size = UDim2.fromOffset(combo.AbsoluteSize.X, h),
            Position = UDim2.fromOffset(abs.X, abs.Y + combo.AbsoluteSize.Y + 4),
            BackgroundColor3 = Theme.PopupBg,
            ZIndex = 900,
            Parent = root,
        })
        corner(popup, Tokens.PopupRounding)
        stroke(popup, Theme.Border, 1, .08)
        local clip = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.fromOffset(0, #values * 24),
            ZIndex = popup.ZIndex + 1,
            Parent = popup,
        })
        list(clip, 0)
        for _, v in ipairs(values) do
            local item = textButton({
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = (s.Value == v) and Theme.FrameBgActive or Theme.PopupBg,
                BackgroundTransparency = (s.Value == v) and 0 or 1,
                Text = "",
                ZIndex = clip.ZIndex + 1,
                Parent = clip,
            })
            textLabel({
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text = tostring(v),
                TextColor3 = (s.Value == v) and Theme.Text or Theme.TextDisabled,
                TextSize = Tokens.FontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = item.ZIndex + 1,
                Parent = item,
            })
            connect(item.MouseEnter, function() if s.Value ~= v then tween(item, Tokens.FastAnim, { BackgroundTransparency = 0, BackgroundColor3 = Theme.FrameBgHovered }) end end)
            connect(item.MouseLeave, function() if s.Value ~= v then tween(item, Tokens.FastAnim, { BackgroundTransparency = 1, BackgroundColor3 = Theme.PopupBg }) end end)
            connect(item.MouseButton1Click, function()
                s:Set(v)
                display.Text = tostring(v)
                close()
            end)
        end
    end
    connect(combo.MouseButton1Click, open)
    local obj = s
    function obj:SetValue(v, silent) s:Set(v, silent); display.Text = tostring(v); return self end
    function obj:SetValues(newValues) values = newValues or {}; return self end
    return obj
end

function Groupbox:AddKeybind(key, cfg, attachRow)
    cfg = cfg or {}
    local default = cfg.Default or Enum.KeyCode.Unknown
    if typeof(default) == "string" then default = Enum.KeyCode[default] or Enum.KeyCode.Unknown end
    local s = state(key, default, cfg.Callback)
    local row = attachRow or self:_row(30)
    if not attachRow then
        textLabel({ Size = UDim2.new(.5, 0, 1, 0), BackgroundTransparency = 1, Text = cfg.Text or key, TextColor3 = Theme.Text, TextSize = Tokens.FontSize, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = row.ZIndex + 1, Parent = row })
    end
    local btn = textButton({
        Size = UDim2.fromOffset(74, 24),
        AnchorPoint = Vector2.new(1, .5),
        Position = UDim2.new(1, 0, .5, 0),
        BackgroundColor3 = Theme.FrameBg,
        Text = "",
        ZIndex = row.ZIndex + 6,
        Parent = row,
    })
    corner(btn, Tokens.FrameRounding)
    stroke(btn, Theme.Border, 1, .12)
    local label = textLabel({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = default == Enum.KeyCode.Unknown and "Unbinded" or default.Name, TextColor3 = Theme.TextDisabled, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = btn.ZIndex + 1, Parent = btn })
    local capturing = false
    local function setKey(k)
        s:Set(k)
        label.Text = k == Enum.KeyCode.Unknown and "Unbinded" or k.Name
    end
    connect(btn.MouseButton1Click, function()
        capturing = true
        label.Text = "..."
        tween(btn, Tokens.FastAnim, { BackgroundColor3 = Theme.FrameBgActive })
    end)
    connect(UserInputService.InputBegan, function(input, gpe)
        if capturing then
            capturing = false
            tween(btn, Tokens.FastAnim, { BackgroundColor3 = Theme.FrameBg })
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                    setKey(Enum.KeyCode.Unknown)
                else
                    setKey(input.KeyCode)
                end
            else
                setKey(Enum.KeyCode.Unknown)
            end
            return
        end
        if gpe or s.Value == Enum.KeyCode.Unknown then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == s.Value then
            if cfg.Mode == "Hold" then ZyrexLib.Keybinds[key] = true else ZyrexLib.Keybinds[key] = not ZyrexLib.Keybinds[key] end
            if cfg.OnPressed then task.spawn(cfg.OnPressed, ZyrexLib.Keybinds[key]) end
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if cfg.Mode == "Hold" and s.Value ~= Enum.KeyCode.Unknown and input.KeyCode == s.Value then
            ZyrexLib.Keybinds[key] = false
            if cfg.OnPressed then task.spawn(cfg.OnPressed, false) end
        end
    end)
    return s
end

function Groupbox:AddColorPicker(key, cfg, attachRow)
    cfg = cfg or {}
    local default = cfg.Default or Color3.fromRGB(255, 255, 255)
    local alpha = cfg.Alpha or 1
    local s = state(key, { Color = default, Alpha = alpha }, cfg.Callback)
    local row = attachRow or self:_row(28)
    if not attachRow then
        textLabel({ Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = cfg.Text or key, TextColor3 = Theme.Text, TextSize = Tokens.FontSize, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = row.ZIndex + 1, Parent = row })
    end
    local swatch = textButton({
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(1, .5),
        Position = UDim2.new(1, 0, .5, 0),
        BackgroundColor3 = default,
        Text = "",
        ZIndex = row.ZIndex + 6,
        Parent = row,
    })
    corner(swatch, 7)
    stroke(swatch, Theme.Border, 1, .15)

    local popup
    local H, S, V = default:ToHSV()
    local function close()
        if popup then popup:Destroy(); popup = nil end
        if self.Window then self.Window:_hideOverlay() end
    end
    local function update(color, a)
        swatch.BackgroundColor3 = color
        s:Set({ Color = color, Alpha = a or alpha })
    end
    local function open()
        if popup then close(); return end
        if self.Window then self.Window:_showOverlay(close) end
        local root = self.Window and self.Window.OverlayRoot or self.Container
        local abs = swatch.AbsolutePosition - root.AbsolutePosition
        popup = create("Frame", {
            Size = UDim2.fromOffset(216, 176),
            Position = UDim2.fromOffset(abs.X - 202, abs.Y + 18),
            BackgroundColor3 = Theme.PopupBg,
            ZIndex = 900,
            Parent = root,
        })
        corner(popup, Tokens.PopupRounding)
        stroke(popup, Theme.Border, 1, .08)
        padding(popup, 12, 12, 12, 12)
        local title = textLabel({ Size = UDim2.new(1, -72, 0, 18), BackgroundTransparency = 1, Text = cfg.Text or key, TextColor3 = Theme.Text, TextSize = Tokens.FontSize, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = popup.ZIndex + 1, Parent = popup })
        local hex = textLabel({ Size = UDim2.fromOffset(72, 18), Position = UDim2.new(1, -72, 0, 0), BackgroundTransparency = 1, Text = "#" .. s.Value.Color:ToHex():lower(), TextColor3 = Theme.TextDisabled, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = popup.ZIndex + 1, Parent = popup })
        local sv = textButton({ Size = UDim2.fromOffset(150, 88), Position = UDim2.fromOffset(0, 28), BackgroundColor3 = Color3.fromHSV(H, 1, 1), Text = "", ZIndex = popup.ZIndex + 1, Parent = popup })
        corner(sv, Tokens.FrameRounding)
        local white = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.White, BackgroundTransparency = 0, ZIndex = sv.ZIndex + 1, Parent = sv })
        corner(white, Tokens.FrameRounding)
        create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 0, Parent = white })
        local black = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Black, BackgroundTransparency = 0, ZIndex = sv.ZIndex + 2, Parent = sv })
        corner(black, Tokens.FrameRounding)
        create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Rotation = 90, Parent = black })
        local cursor = create("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(S, 1 - V), BackgroundColor3 = Theme.White, ZIndex = sv.ZIndex + 4, Parent = sv })
        corner(cursor, 4); stroke(cursor, Theme.Black, 1, .1)
        local hue = textButton({ Size = UDim2.fromOffset(16, 88), Position = UDim2.fromOffset(162, 28), BackgroundColor3 = Theme.White, Text = "", ZIndex = popup.ZIndex + 1, Parent = popup })
        corner(hue, Tokens.FrameRounding)
        local pts = {}
        for i = 0, 6 do table.insert(pts, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
        create("UIGradient", { Color = ColorSequence.new(pts), Rotation = 90, Parent = hue })
        local hCursor = create("Frame", { Size = UDim2.new(1, 4, 0, 4), Position = UDim2.new(0, -2, H, -2), BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = hue.ZIndex + 2, Parent = hue })
        corner(hCursor, 2); stroke(hCursor, Theme.Black, 1, .2)
        local alphaBar = textButton({ Size = UDim2.fromOffset(178, 14), Position = UDim2.fromOffset(0, 128), BackgroundColor3 = s.Value.Color, Text = "", ZIndex = popup.ZIndex + 1, Parent = popup })
        corner(alphaBar, Tokens.FrameRounding)
        create("UIGradient", { Transparency = NumberSequence.new(0, .75), Rotation = 0, Parent = alphaBar })
        local aCursor = create("Frame", { Size = UDim2.fromOffset(4, 18), Position = UDim2.new(alpha, -2, 0, -2), BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = alphaBar.ZIndex + 2, Parent = alphaBar })
        corner(aCursor, 2); stroke(aCursor, Theme.Black, 1, .2)
        local draggingSV, draggingHue, draggingAlpha = false, false, false
        local function refresh()
            local c = Color3.fromHSV(H, S, V)
            sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
            cursor.Position = UDim2.fromScale(S, 1 - V)
            hCursor.Position = UDim2.new(0, -2, H, -2)
            alphaBar.BackgroundColor3 = c
            aCursor.Position = UDim2.new(alpha, -2, 0, -2)
            hex.Text = "#" .. c:ToHex():lower()
            update(c, alpha)
        end
        local function handle(input)
            if draggingSV then
                local p = sv.AbsolutePosition; local sz = sv.AbsoluteSize
                S = clamp((input.Position.X - p.X) / sz.X, 0, 1)
                V = 1 - clamp((input.Position.Y - p.Y) / sz.Y, 0, 1)
                refresh()
            elseif draggingHue then
                local p = hue.AbsolutePosition; local sz = hue.AbsoluteSize
                H = clamp((input.Position.Y - p.Y) / sz.Y, 0, 1)
                refresh()
            elseif draggingAlpha then
                local p = alphaBar.AbsolutePosition; local sz = alphaBar.AbsoluteSize
                alpha = clamp((input.Position.X - p.X) / sz.X, 0, 1)
                refresh()
            end
        end
        connect(sv.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true; handle(i) end end)
        connect(hue.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true; handle(i) end end)
        connect(alphaBar.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingAlpha = true; handle(i) end end)
        connect(UserInputService.InputChanged, function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then handle(i) end end)
        connect(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false; draggingHue = false; draggingAlpha = false end end)
    end
    connect(swatch.MouseButton1Click, open)
    return s
end

function Groupbox:AddColorEdit(key, cfg)
    return self:AddColorPicker(key, cfg)
end

function Groupbox:AddCodeBox(key, cfg)
    cfg = cfg or {}
    local s = state(key, cfg.Default or "", cfg.Callback)
    local h = cfg.Height or 260
    local row = self:_row(h)
    local box = create("TextBox", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.WindowBg,
        BackgroundTransparency = .08,
        ClearTextOnFocus = false,
        MultiLine = true,
        Text = cfg.Default or "",
        TextColor3 = Theme.Text,
        TextSize = Tokens.CodeFontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = row.ZIndex + 1,
        Parent = row,
    })
    setFont(box, "code")
    corner(box, Tokens.ChildRounding)
    stroke(box, Theme.Border, 1, .12)
    padding(box, 10, 8, 10, 8)
    connect(box.FocusLost, function() s:Set(box.Text) end)
    return s
end

local SubTab = {}
SubTab.__index = SubTab

function SubTab:_makeColumn(side)
    local width = UDim2.new(.5, -8, 1, 0)
    local pos = side == "Right" and UDim2.new(.5, 8, 0, 0) or UDim2.fromOffset(0, 0)
    local col = create("ScrollingFrame", {
        Name = side .. "Column",
        Size = width,
        Position = pos,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = Tokens.Scrollbar,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = .15,
        ZIndex = self.Frame.ZIndex + 1,
        Parent = self.Page,
    })
    list(col, Tokens.ItemSpacing)
    return col
end

function SubTab:_addGroupbox(name, side, height)
    local parent = side == "Right" and self.RightColumn or self.LeftColumn
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 0),
        AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.ChildBg,
        BackgroundTransparency = .4,
        BorderSizePixel = 0,
        ZIndex = parent.ZIndex + 1,
        Parent = parent,
    })
    corner(outer, Tokens.ChildRounding)
    stroke(outer, Theme.Border, 1, .12)
    local container = create("Frame", {
        Name = "Container",
        Size = UDim2.new(1, -Tokens.ChildPad * 2, 0, 0),
        Position = UDim2.fromOffset(Tokens.ChildPad, Tokens.ChildPad),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = outer.ZIndex + 1,
        Parent = outer,
    })
    list(container, 6)
    local gb = setmetatable({ Frame = outer, Container = container, Name = name, Side = side, Window = self.Window, ZIndex = container.ZIndex }, Groupbox)
    return gb
end

function SubTab:AddLeftGroupbox(name, height) return self:_addGroupbox(name, "Left", height) end
function SubTab:AddRightGroupbox(name, height) return self:_addGroupbox(name, "Right", height) end
function SubTab:AddGroupbox(name, height) return self:AddLeftGroupbox(name, height) end

local Tab = {}
Tab.__index = Tab

function Tab:AddSubTab(name, iconKey)
    local idx = #self.SubTabs + 1
    local page = create("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = idx == 1,
        ZIndex = self.ContentFrame.ZIndex + 1,
        Parent = self.ContentFrame,
    })
    local sub = setmetatable({ Name = name, IconKey = iconKey, Index = idx, Tab = self, Window = self.Window, Frame = page, Page = page }, SubTab)
    sub.LeftColumn = sub:_makeColumn("Left")
    sub.RightColumn = sub:_makeColumn("Right")

    local btn = textButton({
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = idx == 1 and Theme.TabActive or Theme.WindowBg,
        BackgroundTransparency = idx == 1 and 0 or 1,
        Text = "",
        ZIndex = self.Sidebar.ZIndex + 1,
        Parent = self.Sidebar,
    })
    corner(btn, Tokens.FrameRounding)
    local st = stroke(btn, Theme.Border, 1, idx == 1 and .2 or 1)
    local ic = icon(btn, iconKey, 15, idx == 1 and Theme.Text or Theme.TextDisabled, btn.ZIndex + 1)
    ic.Position = UDim2.fromOffset(12, 11)
    local lbl = textLabel({
        Size = UDim2.new(1, -42, 1, 0),
        Position = UDim2.fromOffset(38, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = idx == 1 and Theme.Text or Theme.TextDisabled,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = btn.ZIndex + 1,
        Parent = btn,
    })
    sub.Button = btn; sub.Label = lbl; sub.Icon = ic; sub.Stroke = st
    table.insert(self.SubTabs, sub)
    if idx == 1 then self.SelectedSubTab = sub end
    connect(btn.MouseButton1Click, function() self:SelectSubTab(sub) end)
    connect(btn.MouseEnter, function()
        if self.SelectedSubTab ~= sub then
            tween(btn, Tokens.FastAnim, { BackgroundTransparency = 0, BackgroundColor3 = Theme.TabHovered })
            tween(lbl, Tokens.FastAnim, { TextColor3 = Theme.Text })
            if ic:IsA("ImageLabel") then tween(ic, Tokens.FastAnim, { ImageColor3 = Theme.Text }) else tween(ic, Tokens.FastAnim, { TextColor3 = Theme.Text }) end
        end
    end)
    connect(btn.MouseLeave, function()
        if self.SelectedSubTab ~= sub then
            tween(btn, Tokens.FastAnim, { BackgroundTransparency = 1, BackgroundColor3 = Theme.WindowBg })
            tween(lbl, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled })
            if ic:IsA("ImageLabel") then tween(ic, Tokens.FastAnim, { ImageColor3 = Theme.TextDisabled }) else tween(ic, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled }) end
        end
    end)
    return sub
end

function Tab:SelectSubTab(sub)
    if self.SelectedSubTab == sub then return end
    if self.SelectedSubTab then
        local old = self.SelectedSubTab
        old.Frame.Visible = false
        tween(old.Button, Tokens.FastAnim, { BackgroundTransparency = 1, BackgroundColor3 = Theme.WindowBg })
        tween(old.Label, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled })
        tween(old.Stroke, Tokens.FastAnim, { Transparency = 1 })
        if old.Icon:IsA("ImageLabel") then tween(old.Icon, Tokens.FastAnim, { ImageColor3 = Theme.TextDisabled }) else tween(old.Icon, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled }) end
    end
    self.SelectedSubTab = sub
    sub.Frame.Visible = true
    tween(sub.Button, Tokens.FastAnim, { BackgroundTransparency = 0, BackgroundColor3 = Theme.TabActive })
    tween(sub.Label, Tokens.FastAnim, { TextColor3 = Theme.Text })
    tween(sub.Stroke, Tokens.FastAnim, { Transparency = .2 })
    if sub.Icon:IsA("ImageLabel") then tween(sub.Icon, Tokens.FastAnim, { ImageColor3 = Theme.Text }) else tween(sub.Icon, Tokens.FastAnim, { TextColor3 = Theme.Text }) end
end

local Window = {}
Window.__index = Window

function Window:_showOverlay(callback)
    if self.OverlayButton then
        self.OverlayButton.Visible = true
        self.OverlayCallback = callback
    end
end
function Window:_hideOverlay()
    if self.OverlayButton then self.OverlayButton.Visible = false end
    self.OverlayCallback = nil
end

function Window:AddTab(name, iconKey)
    local idx = #self.Tabs + 1
    local tab = setmetatable({ Name = name, IconKey = iconKey, Index = idx, Window = self, SubTabs = {} }, Tab)
    local content = create("Frame", {
        Name = name .. "Content",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = idx == 1,
        ZIndex = self.PageFrame.ZIndex + 1,
        Parent = self.PageFrame,
    })
    tab.ContentFrame = content
    local sidebar = create("ScrollingFrame", {
        Name = name .. "Sidebar",
        Size = UDim2.fromOffset(180, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = idx == 1,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = self.SidebarHost.ZIndex + 1,
        Parent = self.SidebarHost,
    })
    list(sidebar, Tokens.FrameRounding)
    tab.Sidebar = sidebar

    local expanded = idx == 1 or name == "Combat"
    local labelText = name == "Settings" and "##Settings" or name
    local btnW = (idx == 1) and 95 or 40
    if name == "Settings" then btnW = 40 end
    local btn = textButton({
        Size = UDim2.fromOffset(btnW, 34),
        BackgroundColor3 = idx == 1 and Theme.TabActive or Theme.Tab,
        BackgroundTransparency = 0,
        Text = "",
        ZIndex = self.MenuBar.ZIndex + 1,
        Parent = self.MenuBar,
    })
    corner(btn, Tokens.FrameRounding)
    local st = stroke(btn, Theme.Border, 1, idx == 1 and .12 or .65)
    local ic = icon(btn, iconKey, 15, idx == 1 and Theme.Text or Theme.TextDisabled, btn.ZIndex + 1)
    ic.Position = UDim2.fromOffset(12, 10)
    local lbl = textLabel({
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.fromOffset(34, 0),
        BackgroundTransparency = 1,
        Text = labelText == "##Settings" and "" or labelText,
        TextColor3 = idx == 1 and Theme.Text or Theme.TextDisabled,
        TextSize = Tokens.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = btn.ZIndex + 1,
        Parent = btn,
    })
    tab.Button = btn; tab.ButtonLabel = lbl; tab.ButtonIcon = ic; tab.ButtonStroke = st
    table.insert(self.Tabs, tab)
    if idx == 1 then self.ActiveTab = tab end
    connect(btn.MouseButton1Click, function() self:SelectTab(tab) end)
    connect(btn.MouseEnter, function()
        if self.ActiveTab ~= tab then
            tween(btn, Tokens.FastAnim, { BackgroundColor3 = Theme.TabHovered })
            tween(lbl, Tokens.FastAnim, { TextColor3 = Theme.Text })
            if ic:IsA("ImageLabel") then tween(ic, Tokens.FastAnim, { ImageColor3 = Theme.Text }) else tween(ic, Tokens.FastAnim, { TextColor3 = Theme.Text }) end
        end
    end)
    connect(btn.MouseLeave, function()
        if self.ActiveTab ~= tab then
            tween(btn, Tokens.FastAnim, { BackgroundColor3 = Theme.Tab })
            tween(lbl, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled })
            if ic:IsA("ImageLabel") then tween(ic, Tokens.FastAnim, { ImageColor3 = Theme.TextDisabled }) else tween(ic, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled }) end
        end
    end)
    return tab
end

function Window:SelectTab(tab)
    if self.ActiveTab == tab then return end
    if self.ActiveTab then
        local old = self.ActiveTab
        old.ContentFrame.Visible = false
        old.Sidebar.Visible = false
        tween(old.Button, Tokens.FastAnim, { BackgroundColor3 = Theme.Tab })
        tween(old.ButtonLabel, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled })
        tween(old.ButtonStroke, Tokens.FastAnim, { Transparency = .65 })
        if old.ButtonIcon:IsA("ImageLabel") then tween(old.ButtonIcon, Tokens.FastAnim, { ImageColor3 = Theme.TextDisabled }) else tween(old.ButtonIcon, Tokens.FastAnim, { TextColor3 = Theme.TextDisabled }) end
    end
    self.ActiveTab = tab
    tab.ContentFrame.Visible = true
    tab.Sidebar.Visible = true
    tween(tab.Button, Tokens.FastAnim, { BackgroundColor3 = Theme.TabActive })
    tween(tab.ButtonLabel, Tokens.FastAnim, { TextColor3 = Theme.Text })
    tween(tab.ButtonStroke, Tokens.FastAnim, { Transparency = .12 })
    if tab.ButtonIcon:IsA("ImageLabel") then tween(tab.ButtonIcon, Tokens.FastAnim, { ImageColor3 = Theme.Text }) else tween(tab.ButtonIcon, Tokens.FastAnim, { TextColor3 = Theme.Text }) end
end

function Window:SetVisible(v)
    self.Visible = v == true
    self.ScreenGui.Enabled = self.Visible
end
function Window:Toggle()
    self:SetVisible(not self.Visible)
end
function Window:Unload()
    if self.ScreenGui then self.ScreenGui:Destroy() end
end

function ZyrexLib:CreateWindow(cfg)
    cfg = cfg or {}
    local w = cfg.Size and cfg.Size.X.Offset or Tokens.WindowW
    local h = cfg.Size and cfg.Size.Y.Offset or Tokens.WindowH
    local title = cfg.Title or "Zyrex"
    local screen = create("ScreenGui", {
        Name = cfg.Name or "ZyrexGui",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = cfg.DisplayOrder or 9999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local ok = pcall(function() screen.Parent = CoreGui end)
    if not ok or not screen.Parent then
        screen.Parent = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui") or CoreGui
    end

    local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
    local scale = create("UIScale", { Scale = 1, Parent = root })
    local main = create("Frame", {
        Size = UDim2.fromOffset(w, h),
        AnchorPoint = Vector2.new(.5, .5),
        Position = cfg.Position or UDim2.fromScale(.5, .5),
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 10,
        Parent = root,
    })
    corner(main, Tokens.WindowRounding)
    stroke(main, Theme.Border, 1, .25)
    local shadowA = create("Frame", { Size = UDim2.new(1, 18, 1, 18), Position = UDim2.fromOffset(-9, -3), BackgroundColor3 = Theme.Black, BackgroundTransparency = .86, BorderSizePixel = 0, ZIndex = main.ZIndex - 2, Parent = main })
    corner(shadowA, Tokens.WindowRounding + 4)

    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, Tokens.HeaderH),
        BackgroundColor3 = Theme.TitleBg,
        BorderSizePixel = 0,
        ZIndex = main.ZIndex + 1,
        Parent = main,
    })
    corner(header, Tokens.WindowRounding)
    create("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8), BackgroundColor3 = Theme.TitleBg, BorderSizePixel = 0, ZIndex = header.ZIndex + 1, Parent = header })
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Border, BackgroundTransparency = .35, BorderSizePixel = 0, ZIndex = header.ZIndex + 2, Parent = header })
    local titleLabel = textLabel({
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(Tokens.Pad, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = Tokens.HeaderFontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = header.ZIndex + 3,
        Parent = header,
    }, "header")
    local close = textButton({
        Size = UDim2.fromOffset(22, 22),
        AnchorPoint = Vector2.new(1, .5),
        Position = UDim2.new(1, -Tokens.Pad, .5, 0),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Text,
        TextSize = 22,
        ZIndex = header.ZIndex + 4,
        Parent = header,
    })

    local content = create("Frame", {
        Size = UDim2.new(1, 0, 1, -Tokens.HeaderH),
        Position = UDim2.fromOffset(0, Tokens.HeaderH),
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = main.ZIndex + 1,
        Parent = main,
    })
    corner(content, Tokens.WindowRounding)
    create("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0, ZIndex = content.ZIndex + 1, Parent = content })

    local menuBar = create("Frame", {
        Size = UDim2.new(1, -Tokens.Pad * 2, 0, 34),
        Position = UDim2.fromOffset(Tokens.Pad, Tokens.Pad),
        BackgroundTransparency = 1,
        ZIndex = content.ZIndex + 2,
        Parent = content,
    })
    list(menuBar, 16, Enum.FillDirection.Horizontal)

    local sidebarHost = create("Frame", {
        Size = UDim2.fromOffset(180, h - Tokens.HeaderH - 34 - Tokens.Pad * 2),
        Position = UDim2.fromOffset(0, Tokens.Pad + 34 + Tokens.Pad),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = content.ZIndex + 2,
        Parent = content,
    })
    padding(sidebarHost, Tokens.Pad, 0, Tokens.Pad, 0)

    local pageFrame = create("Frame", {
        Size = UDim2.new(1, -180 + Tokens.Pad, 1, -(34 + Tokens.Pad * 2)),
        Position = UDim2.fromOffset(180 - Tokens.Pad, Tokens.Pad + 34 + Tokens.Pad),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = content.ZIndex + 2,
        Parent = content,
    })
    padding(pageFrame, Tokens.Pad, 0, Tokens.Pad, Tokens.Pad)

    local overlayRoot = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 850,
        Parent = main,
    })
    local overlayBtn = textButton({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Visible = false, ZIndex = 851, Parent = overlayRoot })

    local win = setmetatable({
        ScreenGui = screen,
        Root = root,
        Scale = scale,
        Main = main,
        Header = header,
        Content = content,
        MenuBar = menuBar,
        SidebarHost = sidebarHost,
        PageFrame = pageFrame,
        OverlayRoot = overlayRoot,
        OverlayButton = overlayBtn,
        OverlayCallback = nil,
        Tabs = {},
        ActiveTab = nil,
        Visible = true,
    }, Window)

    connect(close.MouseButton1Click, function() win:SetVisible(false) end)
    connect(overlayBtn.MouseButton1Click, function()
        if win.OverlayCallback then win.OverlayCallback() end
        win:_hideOverlay()
    end)
    makeDraggable(main, header)
    connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleKey then
            win:Toggle()
        end
    end)
    updateScale(root, scale, w, h)
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function() updateScale(root, scale, w, h) end)
    connect(RunService.RenderStepped, function() if cfg.AutoScale ~= false then updateScale(root, scale, w, h) end end)

    table.insert(self.Windows, win)
    return win
end

function ZyrexLib:Unload()
    self.Unloaded = true
    for _, w in ipairs(self.Windows) do pcall(function() w:Unload() end) end
    for _, c in ipairs(self.Connections) do if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end end
end

function ZyrexLib:SetAssetIds(ids)
    for k, v in pairs(ids or {}) do self.Assets.IconIds[k] = v end
end

function ZyrexLib:CreateDemo()
    local window = self:CreateWindow({ Title = "Zyrex", Size = UDim2.fromOffset(760, 554), ToggleKey = Enum.KeyCode.RightShift })

    local combat = window:AddTab("Combat", "target")
    local legit = combat:AddSubTab("Legit", "verified")
    combat:AddSubTab("Silent", "evil")
    combat:AddSubTab("Aimbot", "cursor")
    combat:AddSubTab("Trigger", "clock")

    local main = legit:AddLeftGroupbox("1", 248)
    main:AddHeaderToggle("legit_enabled", { Text = "Legit", Default = true })
    main:AddToggle("predict_aim", { Text = "Predict aim", Default = true })
    main:AddToggle("auto_group", { Text = "Auto group" })
    main:AddToggle("visible_check", { Text = "Visible check", Default = true })
    main:AddToggle("flash_check", { Text = "Flash check" })
    main:AddToggle("scope_check", { Text = "Scope check" })
    main:AddToggle("humanized_smooth", { Text = "Humanized smooth" })
    main:AddToggle("hit_chance_toggle", { Text = "Hit chance" })

    local sliders = legit:AddLeftGroupbox("2", 112)
    sliders:AddSlider("humanized_smoothness", { Text = "Humanized Smoothness", Min = 0, Max = 100, Default = 30, Suffix = "%" })
    sliders:AddSlider("hit_chance", { Text = "Hit chance", Min = 0, Max = 100, Default = 70, Suffix = "%" })

    local right = legit:AddRightGroupbox("3")
    right:AddHeaderToggle("draw_fov", { Text = "Draw FOV" })
    right:AddSeparator("Render")
    right:AddToggle("draw_circle_outlines", { Text = "Draw circle outlines" })
    right:AddToggle("draw_circle_filled", { Text = "Draw circle filled" })
    right:AddToggle("draw_center_tracer", { Text = "Draw center tracer" })
    right:AddToggle("draw_recoil_circle", { Text = "Draw recoil circle" })
    right:AddSeparator("Colors")
    right:AddColorPicker("circle_outlines", { Text = "Circle outlines", Default = Color3.fromRGB(0, 0, 255), Alpha = 1 })
    right:AddColorPicker("circle_filled", { Text = "Circle filled", Default = Color3.fromRGB(80, 80, 255), Alpha = .5 })
    right:AddColorPicker("center_tracer", { Text = "Center tracer", Default = Color3.fromRGB(0, 255, 0), Alpha = 1 })
    right:AddColorPicker("recoil_circle", { Text = "Recoil circle", Default = Color3.fromRGB(255, 50, 50), Alpha = .75 })
    right:AddSeparator("Configs")
    right:AddSlider("line_thickness", { Text = "Line thichness", Min = .5, Max = 3, Default = 1, Rounding = 1, Suffix = "px" })

    local visuals = window:AddTab("Visuals", "eye")
    local world = visuals:AddSubTab("Others", "objects")
    local other = world:AddLeftGroupbox("others")
    other:AddSeparator("Combo")
    other:AddDropdown("main_target", { Text = "Main target", Values = { "Header", "Body", "Limbs" }, Default = "Header" })
    other:AddDropdown("aim_mode", { Text = "Aim mode", Values = { "Legit", "Rage", "Bot" }, Default = "Legit" })
    other:AddSeparator("Keybind")
    other:AddKeybind("keybind", { Text = "Keybind", Default = Enum.KeyCode.Insert })

    window:AddTab("Movement", "running")
    window:AddTab("Misc", "misc")
    window:AddTab("Players", "globe")

    local lua = window:AddTab("Lua", "code")
    local scripts = lua:AddSubTab("Editor", "code")
    local editorLeft = scripts:AddLeftGroupbox("left-frame")
    editorLeft:AddLabel("Please select a script")
    editorLeft:AddCodeBox("lua_editor", { Height = 296, Default = "-- Zyrex Lua editor\nprint('hello')" })
    local controls = scripts:AddLeftGroupbox("editor-controls", 46)
    controls:AddButton({ Text = "Clear", Icon = "clear" })
    controls:AddButton({ Text = "Open", Icon = "open" })
    controls:AddButton({ Text = "Save", Icon = "save" })
    controls:AddButton({ Text = "Execute", Icon = "play" })
    local explorer = scripts:AddRightGroupbox("Explorer")
    explorer:AddSeparator("Explorer")
    explorer:AddLabel("example.lua")
    explorer:AddLabel("utility.lua")
    explorer:AddLabel("ragebot.lua")

    local settings = window:AddTab("Settings", "settings")
    local themeTab = settings:AddSubTab("Theme", "palette")
    local themeBox = themeTab:AddLeftGroupbox("Theme")
    themeBox:AddColorPicker("accent", { Text = "Accent", Default = Theme.Accent })
    themeBox:AddColorPicker("accent_hovered", { Text = "Accent hovered", Default = Theme.AccentHovered })
    themeBox:AddColorPicker("accent_active", { Text = "Accent active", Default = Theme.AccentActive })
    themeBox:AddColorPicker("text", { Text = "Text", Default = Theme.Text })
    themeBox:AddColorPicker("text_disabled", { Text = "Text disabled", Default = Theme.TextDisabled })
    themeBox:AddColorPicker("button", { Text = "Button", Default = Theme.FrameBg })
    themeBox:AddColorPicker("button_hovered", { Text = "Button hovered", Default = Theme.FrameBgHovered })
    themeBox:AddColorPicker("button_active", { Text = "Button active", Default = Theme.FrameBgActive })
    themeBox:AddButton({ Text = "Unload", Callback = function() self:Unload() end })

    return window
end

return ZyrexLib
