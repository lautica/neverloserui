--[[
    ZyrexLib_OneToOne.lua
    Standalone Luau UI library recreated from Zyrex C++ Dear ImGui menu.
    Usage:
        local ZyrexLib = loadstring(game:HttpGet("RAW_URL"))()
        local Window = ZyrexLib:CreateWindow({Title="Zyrex"})
        local Combat = Window:AddTab("Combat", "target")
        local Legit = Combat:AddSubTab("Legit", "verified")
        local Main = Legit:AddLeftGroupbox("Legit")
        Main:AddToggle("Enabled", {Default=false, Callback=function(v) print(v) end})
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local ZyrexLib = {
    Version = "1.2.3-luau",
    Windows = {},
    Flags = {},
    Options = {},
    Connections = {},
    Unloaded = false,
}

local Theme = {
    WindowBg = Color3.fromRGB(10, 7, 8),
    TitleBg = Color3.fromRGB(18, 15, 17),
    ChildBg = Color3.fromRGB(18, 15, 17),
    ChildBg2 = Color3.fromRGB(16, 13, 15),
    PopupBg = Color3.fromRGB(18, 15, 17),
    FrameBg = Color3.fromRGB(26, 22, 23),
    FrameBgHovered = Color3.fromRGB(34, 30, 31),
    FrameBgActive = Color3.fromRGB(21, 18, 19),
    Border = Color3.fromRGB(34, 28, 30),
    Text = Color3.fromRGB(218, 218, 218),
    TextDisabled = Color3.fromRGB(85, 85, 85),
    Accent = Color3.fromRGB(87, 190, 234),
    AccentHovered = Color3.fromRGB(0, 122, 200),
    AccentActive = Color3.fromRGB(0, 122, 200),
    White = Color3.fromRGB(255,255,255),
    Black = Color3.fromRGB(0,0,0),
}
ZyrexLib.Theme = Theme

local IconMap = {
    target = "✥", verified = "✓", click = "◉", cursor = "➤", clock = "◷",
    eye = "◉", globe = "◎", location = "◆", objects = "▦", pulse = "∿",
    palette = "✿", crime = "♢", knife = "⌁", wrench = "⚙", running = "↗",
    evil = "☠", misc = "⌘", code = "</>", settings = "⚙", clear = "×", open = "▣",
    save = "▤", play = "▶"
}

local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function floor(v) return math.floor(v + 0.5) end

local function Create(class, props, children)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do
        if k ~= "Parent" then obj[k] = v end
    end
    if children then
        for _, child in ipairs(children) do child.Parent = obj end
    end
    if props and props.Parent then obj.Parent = props.Parent end
    return obj
end

local function Corner(parent, r)
    return Create("UICorner", {CornerRadius = UDim.new(0, r or 4), Parent = parent})
end

local function Stroke(parent, color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Padding(parent, l,t,r,b)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0,l or 0), PaddingTop = UDim.new(0,t or 0),
        PaddingRight = UDim.new(0,r or 0), PaddingBottom = UDim.new(0,b or 0), Parent = parent
    })
end

local function List(parent, pad, dir)
    return Create("UIListLayout", {
        Padding = UDim.new(0, pad or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = dir or Enum.FillDirection.Vertical,
        Parent = parent
    })
end

local function Tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(ZyrexLib.Connections, c)
    return c
end

local function TextBounds(text, size, font)
    local ok, res = pcall(function()
        return TextService:GetTextSize(tostring(text), size, font or Enum.Font.SourceSansSemibold, Vector2.new(9999, 9999))
    end)
    return ok and res or Vector2.new(60, size)
end

local function MakeDraggable(frame, handle)
    local dragging, dragStart, startPos, dragInput
    Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Connect(handle.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function NewState(key, default, callback)
    local state = {Value = default, Callbacks = {}}
    if callback then table.insert(state.Callbacks, callback) end
    function state:Set(v)
        self.Value = v
        ZyrexLib.Flags[key] = v
        for _,cb in ipairs(self.Callbacks) do task.spawn(cb, v) end
    end
    function state:Get() return self.Value end
    function state:OnChanged(cb)
        table.insert(self.Callbacks, cb)
        task.spawn(cb, self.Value)
        return self
    end
    ZyrexLib.Options[key] = state
    ZyrexLib.Flags[key] = default
    return state
end

local function SectionText(parent, text)
    local row = Create("Frame", {Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, Parent = parent})
    local label = Create("TextLabel", {
        Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.ChildBg, BorderSizePixel = 0,
        Text = text, TextColor3 = Theme.TextDisabled, Font = Enum.Font.SourceSansSemibold,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = parent.ZIndex + 2, Parent = row
    })
    Padding(label, 0,0,8,0)
    Create("Frame", {Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,.5,0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = parent.ZIndex + 1, Parent = row})
    return row
end

local GroupboxMethods = {}
GroupboxMethods.__index = GroupboxMethods

function GroupboxMethods:_Row(h)
    local row = Create("Frame", {Size = UDim2.new(1,0,0,h or 24), BackgroundTransparency = 1, Parent = self.Container})
    return row
end

function GroupboxMethods:AddSeparator(text)
    return SectionText(self.Container, text or "Section")
end

function GroupboxMethods:AddLabel(text)
    local row = self:_Row(20)
    local l = Create("TextLabel", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text=text or "", TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    return {SetText=function(_,v) l.Text=v end, Frame=row}
end

function GroupboxMethods:AddToggle(key, cfg)
    cfg = cfg or {}
    local text = cfg.Text or key
    local default = cfg.Default or false
    local state = NewState(key, default, cfg.Callback)
    local row = self:_Row(24)
    local box = Create("TextButton", {Size=UDim2.fromOffset(16,16), Position=UDim2.new(0,0,.5,-8), BackgroundColor3=default and Theme.Accent or Theme.FrameBg, AutoButtonColor=false, Text="", Parent=row})
    Corner(box, 3); Stroke(box, Theme.Border)
    local check = Create("TextLabel", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="✓", TextColor3=Theme.White, Font=Enum.Font.SourceSansBold, TextSize=12, Visible=default, Parent=box})
    local label = Create("TextLabel", {Size=UDim2.new(1,-24,1,0), Position=UDim2.fromOffset(24,0), BackgroundTransparency=1, Text=text, TextColor3=default and Theme.Text or Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local click = Create("TextButton", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="", AutoButtonColor=false, Parent=row})
    local obj = {State=state, Frame=row}
    local function render(v)
        Tween(box,.12,{BackgroundColor3=v and Theme.Accent or Theme.FrameBg})
        check.Visible = v
    end
    function obj:SetValue(v) state:Set(v); render(v); return self end
    function obj:Get() return state:Get() end
    function obj:OnChanged(cb) state:OnChanged(cb); return self end
    function obj:AddColorPicker(k, c) return self end -- compatibility no-op on toggle row
    function obj:AddKeyPicker(k, c) return self end
    click.MouseButton1Click:Connect(function() obj:SetValue(not state.Value) end)
    box.MouseButton1Click:Connect(function() obj:SetValue(not state.Value) end)
    return obj
end

function GroupboxMethods:AddCheckbox(key,cfg) return self:AddToggle(key,cfg) end

function GroupboxMethods:AddHeaderToggle(key, cfg)
    cfg = cfg or {}
    local text = cfg.Text or key
    local state = NewState(key, cfg.Default or false, cfg.Callback)
    self.Title.Text = text
    local toggle = Create("TextButton", {Size=UDim2.fromOffset(40,20), Position=UDim2.new(1,-44,0,10), BackgroundColor3=state.Value and Theme.AccentHovered or Theme.FrameBg, Text="", AutoButtonColor=false, Parent=self.Card})
    Corner(toggle, 10); Stroke(toggle, Theme.Border)
    local knob = Create("Frame", {Size=UDim2.fromOffset(14,14), Position=state.Value and UDim2.new(1,-17,.5,-7) or UDim2.new(0,3,.5,-7), BackgroundColor3=Theme.Text, BorderSizePixel=0, Parent=toggle})
    Corner(knob, 7)
    local obj = {State=state, Frame=toggle}
    local function render(v)
        Tween(toggle,.12,{BackgroundColor3=v and Theme.AccentHovered or Theme.FrameBg})
        Tween(knob,.12,{Position=v and UDim2.new(1,-17,.5,-7) or UDim2.new(0,3,.5,-7)})
    end
    function obj:SetValue(v) state:Set(v); render(v); return self end
    function obj:Get() return state:Get() end
    function obj:OnChanged(cb) state:OnChanged(cb); return self end
    toggle.MouseButton1Click:Connect(function() obj:SetValue(not state.Value) end)
    return obj
end

function GroupboxMethods:AddSlider(key, cfg)
    cfg = cfg or {}
    local min, max = cfg.Min or 0, cfg.Max or 100
    local default = cfg.Default or min
    local rounding = cfg.Rounding or 0
    local suffix = cfg.Suffix or ""
    local state = NewState(key, default, cfg.Callback)
    local row = self:_Row(42)
    local label = Create("TextLabel", {Size=UDim2.new(.65,0,0,18), BackgroundTransparency=1, Text=cfg.Text or key, TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local val = Create("TextLabel", {Size=UDim2.new(.35,0,0,18), Position=UDim2.new(.65,0,0,0), BackgroundTransparency=1, TextColor3=Theme.TextDisabled, Font=Enum.Font.SourceSansSemibold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right, Parent=row})
    local bar = Create("Frame", {Size=UDim2.new(1,0,0,7), Position=UDim2.new(0,0,0,25), BackgroundColor3=Theme.FrameBg, BorderSizePixel=0, Parent=row})
    Corner(bar, 4)
    local fill = Create("Frame", {Size=UDim2.fromScale(0,1), BackgroundColor3=Theme.Accent, BorderSizePixel=0, Parent=bar})
    Corner(fill, 4)
    local knob = Create("Frame", {Size=UDim2.fromOffset(14,14), AnchorPoint=Vector2.new(.5,.5), Position=UDim2.new(0,0,.5,0), BackgroundColor3=Theme.Text, BorderSizePixel=0, Parent=bar})
    Corner(knob, 7); Stroke(knob, rgb(120,120,120), 1, .2)
    local btn = Create("TextButton", {Size=UDim2.new(1,0,0,22), Position=UDim2.new(0,0,0,18), BackgroundTransparency=1, Text="", AutoButtonColor=false, Parent=row})
    local dragging = false
    local function fmt(v)
        if rounding == 0 then return tostring(math.floor(v))..suffix end
        return string.format("%."..rounding.."f", v)..suffix
    end
    local function setFromPercent(p)
        p = clamp(p,0,1)
        local value = min + (max-min)*p
        if rounding == 0 then value = floor(value) else local f=10^rounding; value=math.floor(value*f+.5)/f end
        local sp = (value-min)/(max-min)
        fill.Size = UDim2.fromScale(sp,1)
        knob.Position = UDim2.new(sp,0,.5,0)
        val.Text = fmt(value)
        state:Set(value)
    end
    function state:SetValue(v) setFromPercent((v-min)/(max-min)) end
    setFromPercent((default-min)/(max-min))
    btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; setFromPercent((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X) end end)
    btn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    Connect(UserInputService.InputChanged,function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then setFromPercent((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X) end end)
    return state
end

function GroupboxMethods:AddButton(textOrCfg, fn)
    local cfg = type(textOrCfg)=="table" and textOrCfg or {Text=textOrCfg, Func=fn}
    local row = self:_Row(34)
    local btn = Create("TextButton", {Size=UDim2.new(1,0,0,30), BackgroundColor3=Theme.FrameBg, Text=cfg.Text or "Button", TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, AutoButtonColor=false, Parent=row})
    Corner(btn,4); Stroke(btn, Theme.Border)
    btn.MouseEnter:Connect(function() Tween(btn,.12,{BackgroundColor3=Theme.FrameBgHovered}) end)
    btn.MouseLeave:Connect(function() Tween(btn,.12,{BackgroundColor3=Theme.FrameBg}) end)
    btn.MouseButton1Click:Connect(function() if cfg.Func then task.spawn(cfg.Func) elseif cfg.Callback then task.spawn(cfg.Callback) end end)
    return btn
end

function GroupboxMethods:AddDropdown(key, cfg)
    cfg = cfg or {}
    local values = cfg.Values or {}
    local default = cfg.Default or values[1] or ""
    local state = NewState(key, default, cfg.Callback)
    local row = self:_Row(46)
    Create("TextLabel", {Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=cfg.Text or key, TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local btn = Create("TextButton", {Size=UDim2.new(1,0,0,24), Position=UDim2.new(0,0,0,20), BackgroundColor3=Theme.FrameBg, Text="", AutoButtonColor=false, Parent=row})
    Corner(btn,4); Stroke(btn,Theme.Border)
    local label = Create("TextLabel", {Size=UDim2.new(1,-28,1,0), Position=UDim2.fromOffset(8,0), BackgroundTransparency=1, Text=tostring(default), TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=btn})
    Create("TextLabel", {Size=UDim2.fromOffset(20,24), Position=UDim2.new(1,-24,0,0), BackgroundTransparency=1, Text="▼", TextColor3=Theme.TextDisabled, Font=Enum.Font.SourceSansBold, TextSize=9, Parent=btn})
    local popup
    local function close() if popup then popup:Destroy(); popup=nil end end
    btn.MouseButton1Click:Connect(function()
        if popup then close(); return end
        popup = Create("Frame", {Size=UDim2.fromOffset(btn.AbsoluteSize.X, math.min(#values,6)*24), Position=UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y+btn.AbsoluteSize.Y+2), BackgroundColor3=Theme.PopupBg, ZIndex=999, Parent=self.Window.Gui})
        Corner(popup,4); Stroke(popup,Theme.Border); List(popup,0)
        for _,v in ipairs(values) do
            local item=Create("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundColor3=(v==state.Value and Theme.FrameBgHovered or Theme.PopupBg),Text=tostring(v),TextColor3=Theme.Text,Font=Enum.Font.SourceSansSemibold,TextSize=13,AutoButtonColor=false,ZIndex=1000,Parent=popup})
            item.MouseButton1Click:Connect(function() state:Set(v); label.Text=tostring(v); close() end)
        end
    end)
    return state
end

function GroupboxMethods:AddColorPicker(key, cfg)
    cfg = cfg or {}
    local default = cfg.Default or Color3.fromRGB(255,255,255)
    local state = NewState(key, default, cfg.Callback)
    local row = self:_Row(26)
    Create("TextLabel", {Size=UDim2.new(1,-30,1,0), BackgroundTransparency=1, Text=cfg.Text or key, TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local swatch = Create("TextButton", {Size=UDim2.fromOffset(16,16), Position=UDim2.new(1,-18,.5,-8), BackgroundColor3=default, Text="", AutoButtonColor=false, Parent=row})
    Corner(swatch,8); Stroke(swatch,Theme.Border)
    local palette = cfg.Palette or {Color3.fromRGB(0,0,255),Color3.fromRGB(90,90,255),Color3.fromRGB(0,255,0),Color3.fromRGB(255,65,65),Theme.Accent,Color3.fromRGB(255,255,255)}
    local popup
    local function close() if popup then popup:Destroy(); popup=nil end end
    swatch.MouseButton1Click:Connect(function()
        if popup then close(); return end
        popup = Create("Frame", {Size=UDim2.fromOffset(126,54), Position=UDim2.fromOffset(swatch.AbsolutePosition.X-110, swatch.AbsolutePosition.Y+20), BackgroundColor3=Theme.PopupBg, ZIndex=999, Parent=self.Window.Gui})
        Corner(popup,4); Stroke(popup,Theme.Border); Padding(popup,6,6,6,6)
        local grid = Create("UIGridLayout", {CellSize=UDim2.fromOffset(16,16), CellPadding=UDim2.fromOffset(4,4), SortOrder=Enum.SortOrder.LayoutOrder, Parent=popup})
        for _,c in ipairs(palette) do
            local b=Create("TextButton",{BackgroundColor3=c,Text="",AutoButtonColor=false,ZIndex=1000,Parent=popup})
            Corner(b,8); Stroke(b,Theme.Border)
            b.MouseButton1Click:Connect(function() state:Set(c); swatch.BackgroundColor3=c; close() end)
        end
    end)
    return state
end

function GroupboxMethods:AddKeybind(key,cfg)
    cfg = cfg or {}
    local default = cfg.Default or Enum.KeyCode.Insert
    if typeof(default)=="string" then default = Enum.KeyCode[default] or Enum.KeyCode.Unknown end
    local state = NewState(key, default, cfg.Callback)
    local row = self:_Row(28)
    Create("TextLabel", {Size=UDim2.new(1,-88,1,0), BackgroundTransparency=1, Text=cfg.Text or key, TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local btn = Create("TextButton", {Size=UDim2.fromOffset(78,22), Position=UDim2.new(1,-78,.5,-11), BackgroundColor3=Theme.FrameBg, Text="["..default.Name.."]", TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=12, AutoButtonColor=false, Parent=row})
    Corner(btn,4); Stroke(btn,Theme.Border)
    local picking=false
    btn.MouseButton1Click:Connect(function() picking=true; btn.Text="[...]" end)
    Connect(UserInputService.InputBegan,function(input,gpe)
        if picking then
            picking=false
            if input.UserInputType == Enum.UserInputType.Keyboard then state:Set(input.KeyCode); btn.Text="["..input.KeyCode.Name.."]" end
            return
        end
        if not gpe and input.KeyCode == state.Value and cfg.Callback then task.spawn(cfg.Callback, input.KeyCode) end
    end)
    return state
end

function GroupboxMethods:AddInput(key,cfg)
    cfg = cfg or {}
    local state = NewState(key, cfg.Default or "", cfg.Callback)
    local row = self:_Row(46)
    Create("TextLabel", {Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=cfg.Text or key, TextColor3=Theme.Text, Font=Enum.Font.SourceSansSemibold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = Create("TextBox", {Size=UDim2.new(1,0,0,24), Position=UDim2.fromOffset(0,20), BackgroundColor3=Theme.FrameBg, Text=cfg.Default or "", PlaceholderText=cfg.Placeholder or "", TextColor3=Theme.Text, PlaceholderColor3=Theme.TextDisabled, Font=Enum.Font.SourceSansSemibold, TextSize=13, ClearTextOnFocus=false, Parent=row})
    Corner(box,4); Stroke(box,Theme.Border); Padding(box,8,0,8,0)
    box.FocusLost:Connect(function() state:Set(box.Text) end)
    return state
end

function GroupboxMethods:AddCodeBox(key,cfg)
    cfg = cfg or {}
    local row = self:_Row(cfg.Height or 260)
    local box = Create("TextBox", {Size=UDim2.fromScale(1,1), BackgroundColor3=Theme.WindowBg, Text=cfg.Default or "-- Lua editor", TextColor3=Theme.Text, ClearTextOnFocus=false, MultiLine=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Font=Enum.Font.Code, TextSize=13, Parent=row})
    Corner(box,4); Stroke(box,Theme.Border); Padding(box,10,8,10,8)
    local state = NewState(key, box.Text, cfg.Callback)
    box.FocusLost:Connect(function() state:Set(box.Text) end)
    state.Box = box
    return state
end

local SubTabMethods = {}
SubTabMethods.__index = SubTabMethods
function SubTabMethods:_AddGroupbox(name, side, height)
    local parent = side == "Left" and self.LeftColumn or self.RightColumn
    local card = Create("Frame", {Size=UDim2.new(1,0,0,height or 0), AutomaticSize=height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, BackgroundColor3=Theme.ChildBg, Parent=parent})
    Corner(card,5); Stroke(card,Theme.Border,1,.25)
    local title = Create("TextLabel", {Size=UDim2.new(1,-28,0,24), Position=UDim2.fromOffset(14,10), BackgroundTransparency=1, Text=name or "Group", TextColor3=Theme.Text, Font=Enum.Font.SourceSansBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=card})
    local container = Create("Frame", {Size=UDim2.new(1,-28,0,0), Position=UDim2.fromOffset(14,42), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=card})
    List(container,6)
    local gb=setmetatable({Card=card,Container=container,Title=title,Window=self.Window}, GroupboxMethods)
    return gb
end
function SubTabMethods:AddLeftGroupbox(name,height) return self:_AddGroupbox(name,"Left",height) end
function SubTabMethods:AddRightGroupbox(name,height) return self:_AddGroupbox(name,"Right",height) end
function SubTabMethods:AddFullGroupbox(name,height)
    local gb = self:_AddGroupbox(name,"Left",height)
    gb.Card.Size = UDim2.new(2, 16, 0, height or 0)
    return gb
end

local TabMethods = {}
TabMethods.__index = TabMethods
function TabMethods:AddSubTab(name, icon)
    local index = #self.SubTabs + 1
    local frame = Create("Frame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=index==1, Parent=self.PageFrame})
    local left = Create("ScrollingFrame", {Size=UDim2.new(.5,-8,1,0), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.fromOffset(0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3, ScrollBarImageColor3=Theme.Border, Parent=frame})
    Padding(left,0,0,0,0); List(left,14)
    local right = Create("ScrollingFrame", {Size=UDim2.new(.5,-8,1,0), Position=UDim2.new(.5,8,0,0), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.fromOffset(0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3, ScrollBarImageColor3=Theme.Border, Parent=frame})
    Padding(right,0,0,0,0); List(right,14)
    local btn = Create("TextButton", {Size=UDim2.new(1,0,0,38), BackgroundColor3=index==1 and Theme.FrameBg or Theme.ChildBg, Text="", AutoButtonColor=false, Parent=self.Sidebar})
    Corner(btn,4); Stroke(btn, index==1 and Theme.Border or Theme.ChildBg, 1, index==1 and .15 or 1)
    Create("TextLabel", {Size=UDim2.fromOffset(30,38), BackgroundTransparency=1, Text=IconMap[icon or ""] or tostring(icon or ""), TextColor3=index==1 and Theme.Text or Theme.TextDisabled, Font=Enum.Font.SourceSansBold, TextSize=15, Parent=btn})
    local lbl=Create("TextLabel", {Size=UDim2.new(1,-38,1,0), Position=UDim2.fromOffset(38,0), BackgroundTransparency=1, Text=name, TextColor3=index==1 and Theme.Text or Theme.TextDisabled, Font=Enum.Font.SourceSansBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=btn})
    local st=setmetatable({Name=name,Frame=frame,Button=btn,Label=lbl,LeftColumn=left,RightColumn=right,Window=self.Window},SubTabMethods)
    table.insert(self.SubTabs,st)
    if index==1 then self.ActiveSubTab=st end
    btn.MouseButton1Click:Connect(function() self:SelectSubTab(st) end)
    return st
end
function TabMethods:SelectSubTab(st)
    for _,s in ipairs(self.SubTabs) do
        s.Frame.Visible = s==st
        Tween(s.Button,.12,{BackgroundColor3=s==st and Theme.FrameBg or Theme.ChildBg})
        s.Label.TextColor3 = s==st and Theme.Text or Theme.TextDisabled
    end
    self.ActiveSubTab = st
end
function TabMethods:AddLeftGroupbox(name,height)
    if not self.ActiveSubTab then return self:AddSubTab("Main"):AddLeftGroupbox(name,height) end
    return self.ActiveSubTab:AddLeftGroupbox(name,height)
end
function TabMethods:AddRightGroupbox(name,height)
    if not self.ActiveSubTab then return self:AddSubTab("Main"):AddRightGroupbox(name,height) end
    return self.ActiveSubTab:AddRightGroupbox(name,height)
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods
function WindowMethods:SelectTab(tab)
    for _,t in ipairs(self.Tabs) do
        t.Content.Visible = t==tab
        Tween(t.Button,.12,{BackgroundColor3=t==tab and Theme.FrameBg or Theme.WindowBg})
        t.Label.TextColor3 = t==tab and Theme.Text or Theme.TextDisabled
    end
    self.ActiveTab = tab
end
function WindowMethods:AddTab(name, icon)
    local index = #self.Tabs + 1
    local content = Create("Frame", {Size=UDim2.new(1,0,1,-54), Position=UDim2.fromOffset(0,54), BackgroundTransparency=1, Visible=index==1, Parent=self.Content})
    local sidebar = Create("Frame", {Size=UDim2.fromOffset(180, content.AbsoluteSize.Y), Position=UDim2.fromOffset(0,0), BackgroundTransparency=1, Parent=content})
    Padding(sidebar,0,0,10,0); List(sidebar,8)
    local page = Create("Frame", {Size=UDim2.new(1,-176,1,0), Position=UDim2.fromOffset(176,0), BackgroundTransparency=1, Parent=content})
    local btn = Create("TextButton", {Size=UDim2.fromOffset(index==1 and 96 or 40, 40), BackgroundColor3=index==1 and Theme.FrameBg or Theme.WindowBg, Text="", AutoButtonColor=false, Parent=self.TabBar})
    Corner(btn,4); Stroke(btn, Theme.Border,1,index==1 and .15 or .75)
    local il = Create("TextLabel", {Size=UDim2.fromOffset(34,40), BackgroundTransparency=1, Text=IconMap[icon or ""] or tostring(icon or ""), TextColor3=index==1 and Theme.Text or Theme.TextDisabled, Font=Enum.Font.SourceSansBold, TextSize=16, Parent=btn})
    local lbl = Create("TextLabel", {Size=UDim2.new(1,-38,1,0), Position=UDim2.fromOffset(38,0), BackgroundTransparency=1, Text=name, TextColor3=index==1 and Theme.Text or Theme.TextDisabled, Font=Enum.Font.SourceSansBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Visible=index==1, Parent=btn})
    local tab=setmetatable({Name=name,Content=content,Button=btn,Label=lbl,Icon=il,Sidebar=sidebar,PageFrame=page,SubTabs={},Window=self},TabMethods)
    table.insert(self.Tabs,tab)
    if index==1 then self.ActiveTab=tab end
    btn.MouseButton1Click:Connect(function()
        for _,t in ipairs(self.Tabs) do t.Label.Visible=false; t.Button.Size=UDim2.fromOffset(40,40) end
        btn.Size=UDim2.fromOffset(math.max(96, TextBounds(name,13,Enum.Font.SourceSansBold).X+48),40); lbl.Visible=true
        self:SelectTab(tab)
    end)
    return tab
end
function WindowMethods:SetVisible(v) self.Gui.Enabled = v end
function WindowMethods:Destroy() self.Gui:Destroy() end

function ZyrexLib:CreateWindow(cfg)
    cfg = cfg or {}
    local size = cfg.Size or UDim2.fromOffset(760,554)
    local title = cfg.Title or "Zyrex"
    local gui = Create("ScreenGui", {Name="ZyrexUILibrary", ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    local main = Create("Frame", {Size=size, Position=cfg.Position or UDim2.new(.5,-size.X.Offset/2,.5,-size.Y.Offset/2), BackgroundColor3=Theme.WindowBg, BorderSizePixel=0, Parent=gui})
    Corner(main,7)
    local header = Create("Frame", {Size=UDim2.new(1,0,0,46), BackgroundColor3=Theme.TitleBg, BorderSizePixel=0, Parent=main})
    Corner(header,7)
    Create("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=Theme.Border, BorderSizePixel=0, Parent=header})
    Create("TextLabel", {Size=UDim2.new(1,-70,1,0), Position=UDim2.fromOffset(16,0), BackgroundTransparency=1, Text=title, TextColor3=Theme.Text, Font=Enum.Font.SourceSansBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=header})
    local close = Create("TextButton", {Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-36,.5,-12), BackgroundTransparency=1, Text="×", TextColor3=Theme.Text, Font=Enum.Font.SourceSans, TextSize=22, AutoButtonColor=false, Parent=header})
    close.MouseButton1Click:Connect(function() gui.Enabled=false end)
    local content = Create("Frame", {Size=UDim2.new(1,-32,1,-78), Position=UDim2.fromOffset(16,62), BackgroundTransparency=1, Parent=main})
    local tabbar = Create("Frame", {Size=UDim2.new(1,0,0,40), BackgroundTransparency=1, Parent=content})
    List(tabbar,16,Enum.FillDirection.Horizontal)
    local window=setmetatable({Gui=gui,Main=main,Header=header,Content=content,TabBar=tabbar,Tabs={},Theme=Theme},WindowMethods)
    MakeDraggable(main, header)
    if cfg.ToggleKey ~= false then
        local key = cfg.ToggleKey or Enum.KeyCode.RightShift
        Connect(UserInputService.InputBegan, function(input,gpe)
            if not gpe and input.KeyCode == key then gui.Enabled = not gui.Enabled end
        end)
    end
    table.insert(self.Windows,window)
    return window
end

function ZyrexLib:Unload()
    for _,c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    for _,w in ipairs(self.Windows) do pcall(function() w.Gui:Destroy() end) end
    self.Unloaded = true
end

function ZyrexLib:CreateDemo()
    local Window = self:CreateWindow({Title="Zyrex", Size=UDim2.fromOffset(760,554), ToggleKey=Enum.KeyCode.RightShift})
    local Combat=Window:AddTab("Combat","target")
    local Legit=Combat:AddSubTab("Legit","verified")
    Combat:AddSubTab("Silent","click"); Combat:AddSubTab("Aimbot","cursor"); Combat:AddSubTab("Trigger","clock")
    local Visuals=Window:AddTab("Visuals","eye")
    local World=Visuals:AddSubTab("World","globe"); Visuals:AddSubTab("Local","location"); Visuals:AddSubTab("ESP","objects"); Visuals:AddSubTab("Visualizers","pulse")
    local Skin=Window:AddTab("Skin Changer","palette"); Skin:AddSubTab("Skins","crime"); Skin:AddSubTab("Knives","knife"); Skin:AddSubTab("Custom","wrench")
    local Movement=Window:AddTab("Movement","running"); Movement:AddSubTab("Legit","verified"); Movement:AddSubTab("Rage","evil")
    local Misc=Window:AddTab("Misc","misc"); local MiscMain=Misc:AddSubTab("Main","misc")
    local Lua=Window:AddTab("Lua","code"); local LuaMain=Lua:AddSubTab("Editor","code")
    local Settings=Window:AddTab("Settings","settings"); local SetMain=Settings:AddSubTab("Theme","settings")

    local L1=Legit:AddLeftGroupbox("Legit",248)
    L1:AddHeaderToggle("legit_enabled",{Text="Legit",Default=true})
    L1:AddToggle("predict_aim",{Text="Predict aim",Default=true})
    L1:AddToggle("auto_group",{Text="Auto group"})
    L1:AddToggle("visible_check",{Text="Visible check",Default=true})
    L1:AddToggle("flash_check",{Text="Flash check"})
    L1:AddToggle("scope_check",{Text="Scope check"})
    L1:AddToggle("humanized_smooth",{Text="Humanized smooth"})
    L1:AddToggle("hit_chance",{Text="Hit chance"})
    local L2=Legit:AddLeftGroupbox("",116)
    L2.Title.Visible=false
    L2.Container.Position=UDim2.fromOffset(14,14)
    L2:AddSlider("humanized_smoothness",{Text="Humanized Smoothness",Min=0,Max=100,Default=30,Suffix="%"})
    L2:AddSlider("hit_chance_slider",{Text="Hit chance",Min=0,Max=100,Default=70,Suffix="%"})
    local R1=Legit:AddRightGroupbox("Draw FOV",374)
    R1:AddHeaderToggle("draw_fov",{Text="Draw FOV"})
    R1:AddSeparator("Render")
    R1:AddToggle("draw_circle_outlines",{Text="Draw circle outlines"})
    R1:AddToggle("draw_circle_filled",{Text="Draw circle filled"})
    R1:AddToggle("draw_center_tracer",{Text="Draw center tracer"})
    R1:AddToggle("draw_recoil_circle",{Text="Draw recoil circle"})
    R1:AddSeparator("Colors")
    R1:AddColorPicker("circle_outlines_color",{Text="Circle outlines",Default=Color3.fromRGB(0,0,255)})
    R1:AddColorPicker("circle_filled_color",{Text="Circle filled",Default=Color3.fromRGB(90,90,255)})
    R1:AddColorPicker("center_tracer_color",{Text="Center tracer",Default=Color3.fromRGB(0,255,0)})
    R1:AddColorPicker("recoil_circle_color",{Text="Recoil circle",Default=Color3.fromRGB(255,65,65)})
    R1:AddSeparator("Configs")
    R1:AddSlider("line_thickness",{Text="Line thichness",Min=.5,Max=3,Default=1,Rounding=1,Suffix="px"})

    local VO=World:AddLeftGroupbox("others",210)
    VO:AddSeparator("Combo")
    VO:AddDropdown("main_target",{Text="Main target",Values={"Header","Body","Limbs"},Default="Header"})
    VO:AddDropdown("aim_mode",{Text="Aim mode",Values={"Legit","Rage","Bot"},Default="Legit"})
    VO:AddSeparator("Keybind")
    VO:AddKeybind("visual_keybind",{Text="Keybind",Default=Enum.KeyCode.Insert})

    local LU=LuaMain:AddLeftGroupbox("path",44)
    LU.Title.Visible=false; LU.Container.Position=UDim2.fromOffset(14,10)
    LU:AddLabel("Please select a script")
    local Editor=LuaMain:AddLeftGroupbox("editor-frame",310)
    Editor.Title.Visible=false; Editor.Container.Position=UDim2.fromOffset(14,14)
    Editor:AddCodeBox("lua_editor",{Height=274,Default="-- select a script from Explorer\nprint('Zyrex')"})
    local Controls=LuaMain:AddLeftGroupbox("editor-controls",58)
    Controls.Title.Visible=false; Controls.Container.Position=UDim2.fromOffset(14,14)
    Controls:AddButton({Text="Clear",Func=function() end})
    local Explorer=LuaMain:AddRightGroupbox("Explorer",420)
    Explorer:AddSeparator("Explorer")
    Explorer:AddButton({Text="radar_hack.lua"}); Explorer:AddButton({Text="spectator_list.lua"}); Explorer:AddButton({Text="auto_jump.lua"}); Explorer:AddButton({Text="anti_aim.lua"}); Explorer:AddButton({Text="anti_troll.lua"})

    local TG=SetMain:AddLeftGroupbox("Theme",430)
    for _,name in ipairs({"Accent","Accent hovered","Accent active","Text","Text disabled","Button","Button hovered","Button active","Frame","Frame hovered","Frame active","Title","Border","Window","Child","Popup"}) do
        TG:AddColorPicker("theme_"..name:gsub("%s+","_"):lower(),{Text=name,Default=Theme.Accent})
    end
    MiscMain:AddLeftGroupbox("Misc",100):AddLabel("Empty page, matching C++ placeholder.")
    return Window
end

return ZyrexLib
