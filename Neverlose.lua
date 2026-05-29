--[[
    ZyrexLib - Luau ImGui-style UI library
    Recreated from the provided C++ ImGui Zyrex menu design.

    Usage:
    local ZyrexLib = loadstring(game:HttpGet("https://your-raw-url/ZyrexLib.lua"))()
    local Window = ZyrexLib:CreateWindow({ Title = "Zyrex", Size = UDim2.fromOffset(760, 554) })
]]

local ZyrexLib = {}
ZyrexLib.__index = ZyrexLib

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local CoreGui = (typeof(cloneref) == "function" and cloneref(game:GetService("CoreGui"))) or game:GetService("CoreGui")

--// Theme based on C++ ImGui style colors
local Theme = {
    WindowBg = Color3.fromRGB(10, 7, 8),
    TitleBg = Color3.fromRGB(18, 15, 17),
    ChildBg = Color3.fromRGB(18, 15, 17),
    ChildBg2 = Color3.fromRGB(14, 12, 13),
    PopupBg = Color3.fromRGB(18, 15, 17),
    Border = Color3.fromRGB(34, 28, 30),
    BorderSoft = Color3.fromRGB(48, 40, 43),
    Text = Color3.fromRGB(218, 218, 218),
    TextDisabled = Color3.fromRGB(85, 85, 85),
    Frame = Color3.fromRGB(26, 22, 23),
    FrameHover = Color3.fromRGB(34, 30, 31),
    FrameActive = Color3.fromRGB(21, 18, 19),
    Tab = Color3.fromRGB(14, 12, 13),
    TabHover = Color3.fromRGB(26, 22, 23),
    TabActive = Color3.fromRGB(21, 18, 19),
    Accent = Color3.fromRGB(87, 190, 234),
    AccentHover = Color3.fromRGB(0, 122, 200),
    AccentActive = Color3.fromRGB(0, 122, 200),
    White = Color3.fromRGB(255, 255, 255),
    Black = Color3.fromRGB(0, 0, 0),
}

ZyrexLib.Theme = Theme
ZyrexLib.Toggles = {}
ZyrexLib.Options = {}
ZyrexLib.Windows = {}
ZyrexLib.Connections = {}
ZyrexLib.OpenDropdown = nil
ZyrexLib.KeyListening = nil

--// Helpers
local function Create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function Corner(parent, radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
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

local function Padding(parent, l, t, r, b)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function List(parent, direction, padding)
    return Create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding or 8),
        Parent = parent,
    })
end

local function Tween(inst, time, props)
    local tw = TweenService:Create(inst, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function AddConnection(conn)
    table.insert(ZyrexLib.Connections, conn)
    return conn
end

local function MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

local function State(default, callback)
    local obj = { Value = default, Callback = callback, Changed = {} }
    function obj:SetValue(value)
        if self.Value == value then return end
        self.Value = value
        if self.Callback then task.spawn(self.Callback, value) end
        for _, fn in ipairs(self.Changed) do task.spawn(fn, value) end
    end
    function obj:OnChanged(fn)
        table.insert(self.Changed, fn)
        task.spawn(fn, self.Value)
        return self
    end
    return obj
end

local function Text(parent, txt, size, bold, color)
    return Create("TextLabel", {
        BackgroundTransparency = 1,
        Text = txt or "",
        TextColor3 = color or Theme.Text,
        Font = bold and Enum.Font.GothamSemibold or Enum.Font.Gotham,
        TextSize = size or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = parent,
    })
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods
local TabMethods = {}
TabMethods.__index = TabMethods
local PageMethods = {}
PageMethods.__index = PageMethods
local GroupboxMethods = {}
GroupboxMethods.__index = GroupboxMethods

function ZyrexLib:Unload()
    for _, c in ipairs(self.Connections) do
        if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
    end
    for _, win in ipairs(self.Windows) do
        if win.Gui then win.Gui:Destroy() end
    end
    table.clear(self.Windows)
    table.clear(self.Connections)
end

function ZyrexLib:SetThemeColor(name, color)
    if Theme[name] and typeof(color) == "Color3" then
        Theme[name] = color
    end
end

function ZyrexLib:CreateWindow(config)
    config = config or {}
    local title = config.Title or "Zyrex"
    local size = config.Size or UDim2.fromOffset(760, 554)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local gui = Create("ScreenGui", {
        Name = config.Name or "ZyrexLib",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    local root = Create("Frame", {
        Size = size,
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        BackgroundTransparency = 1,
        Parent = gui,
    })

    local shadow = Create("ImageLabel", {
        Size = UDim2.new(1, 36, 1, 36),
        Position = UDim2.fromOffset(-18, -18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5554236805",
        ImageColor3 = Theme.Black,
        ImageTransparency = 0.35,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(23, 23, 277, 277),
        Parent = root,
    })

    local main = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.WindowBg,
        ClipsDescendants = true,
        Parent = root,
    })
    Corner(main, 7)
    Stroke(main, Theme.Border, 1)

    local header = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.TitleBg,
        BorderSizePixel = 0,
        Parent = main,
    })
    Corner(header, 7)

    local headerMask = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 9),
        Position = UDim2.new(0, 0, 1, -9),
        BackgroundColor3 = Theme.TitleBg,
        BorderSizePixel = 0,
        Parent = header,
    })

    local headerLine = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = header,
    })

    local titleLabel = Text(header, title, 16, true, Theme.Text)
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.fromOffset(16, 0)

    local close = Create("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -40, 0.5, -14),
        BackgroundColor3 = Theme.Frame,
        Text = "×",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        AutoButtonColor = false,
        Parent = header,
    })
    Corner(close, 4)
    Stroke(close, Theme.Border)
    close.MouseEnter:Connect(function() Tween(close, .12, { BackgroundColor3 = Theme.FrameHover, TextColor3 = Theme.Accent }) end)
    close.MouseLeave:Connect(function() Tween(close, .12, { BackgroundColor3 = Theme.Frame, TextColor3 = Theme.Text }) end)
    close.MouseButton1Click:Connect(function() gui.Enabled = false end)

    local content = Create("Frame", {
        Size = UDim2.new(1, 0, 1, -48),
        Position = UDim2.fromOffset(0, 48),
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        Parent = main,
    })
    Padding(content, 16, 16, 16, 16)

    local topbar = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        Parent = content,
    })

    local topList = List(topbar, Enum.FillDirection.Horizontal, 8)
    topList.VerticalAlignment = Enum.VerticalAlignment.Center

    local body = Create("Frame", {
        Size = UDim2.new(1, 0, 1, -58),
        Position = UDim2.fromOffset(0, 58),
        BackgroundTransparency = 1,
        Parent = content,
    })

    local win = setmetatable({
        Gui = gui,
        Root = root,
        Main = main,
        Header = header,
        Topbar = topbar,
        Body = body,
        Title = title,
        Tabs = {},
        ActiveTab = nil,
        ToggleKey = toggleKey,
    }, WindowMethods)

    table.insert(ZyrexLib.Windows, win)
    MakeDraggable(root, header)

    AddConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == toggleKey then
            gui.Enabled = not gui.Enabled
        end
    end))

    return win
end

function WindowMethods:SetVisible(v)
    self.Gui.Enabled = v
end

function WindowMethods:AddTab(name, icon)
    local index = #self.Tabs + 1
    local tab = setmetatable({
        Window = self,
        Name = name,
        Icon = icon or "•",
        SubTabs = {},
        ActivePage = nil,
        Pages = {},
    }, TabMethods)

    local btn = Create("TextButton", {
        Size = UDim2.fromOffset(name == "Settings" and 42 or 118, 34),
        BackgroundColor3 = index == 1 and Theme.TabActive or Theme.Tab,
        Text = "",
        AutoButtonColor = false,
        Parent = self.Topbar,
    })
    Corner(btn, 4)
    Stroke(btn, index == 1 and Theme.BorderSoft or Theme.Border, 1)

    local iconLabel = Text(btn, icon or "•", 15, true, index == 1 and Theme.Accent or Theme.TextDisabled)
    iconLabel.Size = UDim2.fromOffset(26, 34)
    iconLabel.Position = UDim2.fromOffset(10, 0)
    iconLabel.TextXAlignment = Enum.TextXAlignment.Center

    local label = Text(btn, name == "Settings" and "" or name, 13, true, index == 1 and Theme.Text or Theme.TextDisabled)
    label.Size = UDim2.new(1, -38, 1, 0)
    label.Position = UDim2.fromOffset(36, 0)

    tab.Button = btn
    tab.ButtonLabel = label
    tab.ButtonIcon = iconLabel

    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            Tween(btn, .12, { BackgroundColor3 = Theme.TabHover })
            Tween(label, .12, { TextColor3 = Theme.Text })
            Tween(iconLabel, .12, { TextColor3 = Theme.Accent })
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            Tween(btn, .12, { BackgroundColor3 = Theme.Tab })
            Tween(label, .12, { TextColor3 = Theme.TextDisabled })
            Tween(iconLabel, .12, { TextColor3 = Theme.TextDisabled })
        end
    end)

    table.insert(self.Tabs, tab)
    if index == 1 then
        self.ActiveTab = tab
        task.defer(function() self:SelectTab(tab) end)
    end
    return tab
end

function WindowMethods:SelectTab(tab)
    if self.ActiveTab and self.ActiveTab ~= tab then
        local old = self.ActiveTab
        if old.Container then old.Container.Visible = false end
        Tween(old.Button, .12, { BackgroundColor3 = Theme.Tab })
        Tween(old.ButtonLabel, .12, { TextColor3 = Theme.TextDisabled })
        Tween(old.ButtonIcon, .12, { TextColor3 = Theme.TextDisabled })
    end
    self.ActiveTab = tab
    if not tab.Container then tab:_BuildContainer() end
    tab.Container.Visible = true
    Tween(tab.Button, .12, { BackgroundColor3 = Theme.TabActive })
    Tween(tab.ButtonLabel, .12, { TextColor3 = Theme.Text })
    Tween(tab.ButtonIcon, .12, { TextColor3 = Theme.Accent })
end

function TabMethods:_BuildContainer()
    local container = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.Window.Body,
    })
    self.Container = container

    local sidebarWidth = (#self.SubTabs > 0) and 180 or 0
    if sidebarWidth > 0 then
        local sidebar = Create("Frame", {
            Size = UDim2.new(0, sidebarWidth, 1, 0),
            BackgroundColor3 = Theme.ChildBg,
            Parent = container,
        })
        Corner(sidebar, 5)
        Stroke(sidebar, Theme.Border)
        Padding(sidebar, 10, 10, 10, 10)
        List(sidebar, Enum.FillDirection.Vertical, 5)
        self.Sidebar = sidebar
    end

    local pageHolder = Create("Frame", {
        Size = UDim2.new(1, -sidebarWidth - (sidebarWidth > 0 and 12 or 0), 1, 0),
        Position = UDim2.fromOffset(sidebarWidth > 0 and sidebarWidth + 12 or 0, 0),
        BackgroundTransparency = 1,
        Parent = container,
    })
    self.PageHolder = pageHolder

    if #self.SubTabs == 0 then
        local page = self:_CreatePage(self.Name, nil)
        page.Frame.Visible = true
        self.ActivePage = page
    else
        for i, st in ipairs(self.SubTabs) do
            st:_MountButton(i)
        end
        self:SelectPage(self.SubTabs[1])
    end
end

function TabMethods:_CreatePage(name, icon)
    local page = setmetatable({ Tab = self, Name = name, Icon = icon, Groupboxes = {} }, PageMethods)
    local frame = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.PageHolder,
    })
    page.Frame = frame

    local left = Create("ScrollingFrame", {
        Size = UDim2.new(0.5, -8, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.BorderSoft,
        Parent = frame,
    })
    Padding(left, 0, 0, 4, 0)
    List(left, Enum.FillDirection.Vertical, 12)

    local right = Create("ScrollingFrame", {
        Size = UDim2.new(0.5, -8, 1, 0),
        Position = UDim2.new(0.5, 8, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.BorderSoft,
        Parent = frame,
    })
    Padding(right, 4, 0, 0, 0)
    List(right, Enum.FillDirection.Vertical, 12)

    page.Left = left
    page.Right = right
    table.insert(self.Pages, page)
    return page
end

function TabMethods:AddSubTab(name, icon)
    local page = self:_CreatePage(name, icon or "•")
    table.insert(self.SubTabs, page)
    if self.Container and self.Sidebar then page:_MountButton(#self.SubTabs) end
    return page
end

function TabMethods:GetPage()
    if #self.Pages == 0 then
        if not self.Container then self:_BuildContainer() end
    end
    return self.Pages[1]
end

function TabMethods:SelectPage(page)
    if self.ActivePage and self.ActivePage ~= page then
        self.ActivePage.Frame.Visible = false
        if self.ActivePage.Button then
            Tween(self.ActivePage.Button, .12, { BackgroundColor3 = Theme.ChildBg })
            Tween(self.ActivePage.ButtonLabel, .12, { TextColor3 = Theme.TextDisabled })
            Tween(self.ActivePage.ButtonIcon, .12, { TextColor3 = Theme.TextDisabled })
        end
    end
    self.ActivePage = page
    page.Frame.Visible = true
    if page.Button then
        Tween(page.Button, .12, { BackgroundColor3 = Theme.Frame })
        Tween(page.ButtonLabel, .12, { TextColor3 = Theme.Text })
        Tween(page.ButtonIcon, .12, { TextColor3 = Theme.Accent })
    end
end

function PageMethods:_MountButton(order)
    if not self.Tab.Sidebar or self.Button then return end
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = order,
        BackgroundColor3 = order == 1 and Theme.Frame or Theme.ChildBg,
        Text = "",
        AutoButtonColor = false,
        Parent = self.Tab.Sidebar,
    })
    Corner(btn, 4)
    Stroke(btn, Theme.Border)

    local icon = Text(btn, self.Icon or "•", 15, true, order == 1 and Theme.Accent or Theme.TextDisabled)
    icon.Size = UDim2.fromOffset(30, 40)
    icon.Position = UDim2.fromOffset(8, 0)
    icon.TextXAlignment = Enum.TextXAlignment.Center

    local label = Text(btn, self.Name, 13, true, order == 1 and Theme.Text or Theme.TextDisabled)
    label.Size = UDim2.new(1, -46, 1, 0)
    label.Position = UDim2.fromOffset(42, 0)

    self.Button = btn
    self.ButtonLabel = label
    self.ButtonIcon = icon
    btn.MouseButton1Click:Connect(function() self.Tab:SelectPage(self) end)
end

function PageMethods:AddGroupbox(name, side)
    local parent = (side == "Right") and self.Right or self.Left
    local box = setmetatable({ Page = self, Name = name }, GroupboxMethods)

    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.ChildBg,
        Parent = parent,
    })
    Corner(frame, 5)
    Stroke(frame, Theme.Border)

    local top = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.ChildBg2,
        BorderSizePixel = 0,
        Parent = frame,
    })
    Corner(top, 5)
    local topMask = Create("Frame", { Size = UDim2.new(1,0,0,8), Position = UDim2.new(0,0,1,-8), BackgroundColor3 = Theme.ChildBg2, BorderSizePixel = 0, Parent = top })
    local heading = Text(top, name or "Groupbox", 14, true, Theme.Text)
    heading.Size = UDim2.new(1, -24, 1, 0)
    heading.Position = UDim2.fromOffset(14, 0)

    local container = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = frame,
    })
    Padding(container, 14, 12, 14, 14)
    List(container, Enum.FillDirection.Vertical, 10)

    box.Frame = frame
    box.Container = container
    table.insert(self.Groupboxes, box)
    return box
end

function PageMethods:AddLeftGroupbox(name) return self:AddGroupbox(name, "Left") end
function PageMethods:AddRightGroupbox(name) return self:AddGroupbox(name, "Right") end

function GroupboxMethods:_Row(height)
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 24),
        BackgroundTransparency = 1,
        Parent = self.Container,
    })
    return row
end

function GroupboxMethods:AddSeparator(text)
    local row = self:_Row(20)
    local line = Create("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Parent = row })
    if text then
        local label = Text(row, "  " .. text .. "  ", 12, true, Theme.Accent)
        label.Size = UDim2.fromOffset(TextService:GetTextSize(text, 12, Enum.Font.GothamSemibold, Vector2.new(999, 20)).X + 20, 20)
        label.BackgroundColor3 = Theme.ChildBg
        label.BackgroundTransparency = 0
        label.Position = UDim2.fromOffset(0, 0)
    end
end

function GroupboxMethods:AddLabel(text)
    local row = self:_Row(20)
    local lbl = Text(row, text, 13, false, Theme.TextDisabled)
    lbl.Size = UDim2.fromScale(1, 1)
    return { SetText = function(_, v) lbl.Text = v end, Label = lbl }
end

function GroupboxMethods:AddButton(config)
    config = config or {}
    local row = self:_Row(34)
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Frame,
        Text = config.Text or "Button",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = row,
    })
    Corner(btn, 4)
    Stroke(btn, Theme.Border)
    btn.MouseEnter:Connect(function() Tween(btn, .12, { BackgroundColor3 = Theme.FrameHover }) end)
    btn.MouseLeave:Connect(function() Tween(btn, .12, { BackgroundColor3 = Theme.Frame }) end)
    btn.MouseButton1Click:Connect(function()
        Tween(btn, .06, { BackgroundColor3 = Theme.FrameActive })
        task.delay(.08, function() if btn.Parent then Tween(btn, .12, { BackgroundColor3 = Theme.Frame }) end end)
        if config.Callback then task.spawn(config.Callback) end
    end)
    return btn
end

function GroupboxMethods:AddToggle(key, config)
    config = config or {}
    local default = config.Default or false
    local row = self:_Row(26)
    local st = State(default, config.Callback)
    ZyrexLib.Toggles[key] = st

    local box = Create("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundColor3 = default and Theme.Accent or Theme.Frame,
        Parent = row,
    })
    Corner(box, 4)
    Stroke(box, default and Theme.AccentHover or Theme.Border)

    local check = Text(box, "✓", 13, true, Theme.White)
    check.Size = UDim2.fromScale(1, 1)
    check.TextXAlignment = Enum.TextXAlignment.Center
    check.Visible = default

    local label = Text(row, config.Text or key, 13, false, default and Theme.Text or Theme.TextDisabled)
    label.Size = UDim2.new(1, -28, 1, 0)
    label.Position = UDim2.fromOffset(28, 0)

    local hit = Create("TextButton", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", Parent = row })
    local obj = { State = st, Frame = row }
    function obj:SetValue(v)
        st:SetValue(v)
        Tween(box, .12, { BackgroundColor3 = v and Theme.Accent or Theme.Frame })
        local stroke = box:FindFirstChildOfClass("UIStroke")
        if stroke then Tween(stroke, .12, { Color = v and Theme.AccentHover or Theme.Border }) end
        check.Visible = v
        label.TextColor3 = v and Theme.Text or Theme.TextDisabled
    end
    function obj:OnChanged(fn) st:OnChanged(fn); return obj end
    hit.MouseButton1Click:Connect(function() obj:SetValue(not st.Value) end)
    return obj
end
GroupboxMethods.AddCheckbox = GroupboxMethods.AddToggle

function GroupboxMethods:AddSlider(key, config)
    config = config or {}
    local min = config.Min or 0
    local max = config.Max or 100
    local default = config.Default or min
    local suffix = config.Suffix or ""
    local rounding = config.Rounding or 0
    local st = State(default, config.Callback)
    ZyrexLib.Options[key] = st

    local row = self:_Row(52)
    local label = Text(row, config.Text or key, 13, false, Theme.TextDisabled)
    label.Size = UDim2.new(.65, 0, 0, 18)

    local value = Text(row, tostring(default) .. suffix, 12, true, Theme.Accent)
    value.Size = UDim2.new(.35, 0, 0, 18)
    value.Position = UDim2.new(.65, 0, 0, 0)
    value.TextXAlignment = Enum.TextXAlignment.Right

    local track = Create("Frame", { Size = UDim2.new(1,0,0,8), Position = UDim2.fromOffset(0,30), BackgroundColor3 = Theme.Frame, Parent = row })
    Corner(track, 6)
    Stroke(track, Theme.Border)
    local fill = Create("Frame", { Size = UDim2.fromScale((default-min)/(max-min),1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track })
    Corner(fill, 6)
    local knob = Create("Frame", { Size = UDim2.fromOffset(14,14), AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new((default-min)/(max-min),0,.5,0), BackgroundColor3 = Theme.Text, Parent = track })
    Corner(knob, 8)
    Stroke(knob, Theme.Border)

    local button = Create("TextButton", { Size = UDim2.new(1,0,0,24), Position = UDim2.fromOffset(0,22), BackgroundTransparency = 1, Text = "", Parent = row })
    local dragging = false
    local function fmt(v)
        if rounding == 0 then return tostring(math.floor(v + .5)) .. suffix end
        return string.format("%." .. tostring(rounding) .. "f", v) .. suffix
    end
    local function setPercent(p)
        p = math.clamp(p, 0, 1)
        local v = min + (max - min) * p
        if rounding == 0 then v = math.floor(v + .5) else local f = 10 ^ rounding; v = math.floor(v * f + .5) / f end
        local sp = (v - min) / (max - min)
        fill.Size = UDim2.fromScale(sp, 1)
        knob.Position = UDim2.new(sp, 0, .5, 0)
        value.Text = fmt(v)
        st:SetValue(v)
    end
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setPercent((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
        end
    end)
    button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setPercent((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
        end
    end))
    return st
end

function GroupboxMethods:AddDropdown(key, config)
    config = config or {}
    local values = config.Values or {}
    local default = config.Default or values[1] or "None"
    local st = State(default, config.Callback)
    ZyrexLib.Options[key] = st
    local row = self:_Row(58)
    local label = Text(row, config.Text or key, 13, false, Theme.TextDisabled)
    label.Size = UDim2.new(1,0,0,18)
    local btn = Create("TextButton", { Size = UDim2.new(1,0,0,30), Position = UDim2.fromOffset(0,24), BackgroundColor3 = Theme.Frame, Text = "", AutoButtonColor = false, Parent = row })
    Corner(btn, 4)
    Stroke(btn, Theme.Border)
    local display = Text(btn, tostring(default), 13, false, Theme.Text)
    display.Size = UDim2.new(1,-38,1,0)
    display.Position = UDim2.fromOffset(12,0)
    local arrow = Text(btn, "▼", 11, true, Theme.TextDisabled)
    arrow.Size = UDim2.fromOffset(28, 30)
    arrow.Position = UDim2.new(1,-32,0,0)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local popup
    local function close()
        if popup then popup:Destroy(); popup = nil end
        if ZyrexLib.OpenDropdown == close then ZyrexLib.OpenDropdown = nil end
    end
    btn.MouseButton1Click:Connect(function()
        if popup then close(); return end
        if ZyrexLib.OpenDropdown then ZyrexLib.OpenDropdown() end
        ZyrexLib.OpenDropdown = close
        popup = Create("Frame", {
            Size = UDim2.fromOffset(btn.AbsoluteSize.X, math.min(#values, config.MaxVisible or 6) * 28 + 8),
            Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4),
            BackgroundColor3 = Theme.PopupBg,
            ZIndex = 1000,
            Parent = self.Page.Tab.Window.Gui,
        })
        Corner(popup, 4)
        Stroke(popup, Theme.Border)
        Padding(popup, 4, 4, 4, 4)
        List(popup, Enum.FillDirection.Vertical, 2)
        for _, item in ipairs(values) do
            local opt = Create("TextButton", { Size = UDim2.new(1,0,0,26), BackgroundColor3 = item == st.Value and Theme.FrameHover or Theme.PopupBg, Text = tostring(item), TextColor3 = item == st.Value and Theme.Accent or Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, AutoButtonColor = false, ZIndex = 1001, Parent = popup })
            Corner(opt, 3)
            opt.MouseButton1Click:Connect(function()
                st:SetValue(item)
                display.Text = tostring(item)
                close()
            end)
        end
    end)
    return st
end

function GroupboxMethods:AddKeybind(key, config)
    config = config or {}
    local default = config.Default or Enum.KeyCode.Unknown
    if typeof(default) == "string" then default = Enum.KeyCode[default] or Enum.KeyCode.Unknown end
    local st = State(default, config.Callback)
    ZyrexLib.Options[key] = st
    local row = self:_Row(34)
    local label = Text(row, config.Text or key, 13, false, Theme.TextDisabled)
    label.Size = UDim2.new(1,-112,1,0)
    local btn = Create("TextButton", { Size = UDim2.fromOffset(104,28), Position = UDim2.new(1,-104,.5,-14), BackgroundColor3 = Theme.Frame, Text = default == Enum.KeyCode.Unknown and "None" or default.Name, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, Parent = row })
    Corner(btn, 4); Stroke(btn, Theme.Border)
    btn.MouseButton1Click:Connect(function()
        ZyrexLib.KeyListening = { State = st, Button = btn }
        btn.Text = "..."
        btn.TextColor3 = Theme.Accent
    end)
    return st
end

AddConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if ZyrexLib.KeyListening then
        local info = ZyrexLib.KeyListening
        ZyrexLib.KeyListening = nil
        local key = input.KeyCode
        if key == Enum.KeyCode.Escape then key = Enum.KeyCode.Unknown end
        info.State:SetValue(key)
        info.Button.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
        info.Button.TextColor3 = Theme.Text
        return
    end
end))

function GroupboxMethods:AddColorPicker(key, config)
    config = config or {}
    local default = config.Default or Theme.Accent
    local st = State(default, config.Callback)
    ZyrexLib.Options[key] = st
    local row = self:_Row(34)
    local label = Text(row, config.Text or key, 13, false, Theme.TextDisabled)
    label.Size = UDim2.new(1,-52,1,0)
    local swatch = Create("TextButton", { Size = UDim2.fromOffset(42,22), Position = UDim2.new(1,-42,.5,-11), BackgroundColor3 = default, Text = "", AutoButtonColor = false, Parent = row })
    Corner(swatch, 4); Stroke(swatch, Theme.Border)
    local colors = { Theme.Accent, Color3.fromRGB(255,90,90), Color3.fromRGB(120,255,150), Color3.fromRGB(255,220,90), Color3.fromRGB(180,120,255), Color3.fromRGB(255,255,255) }
    local popup
    local function close() if popup then popup:Destroy(); popup = nil end end
    swatch.MouseButton1Click:Connect(function()
        if popup then close(); return end
        popup = Create("Frame", { Size = UDim2.fromOffset(156, 60), Position = UDim2.fromOffset(swatch.AbsolutePosition.X - 114, swatch.AbsolutePosition.Y + 26), BackgroundColor3 = Theme.PopupBg, ZIndex = 1000, Parent = self.Page.Tab.Window.Gui })
        Corner(popup, 4); Stroke(popup, Theme.Border); Padding(popup, 8,8,8,8)
        local grid = Create("UIGridLayout", { CellSize = UDim2.fromOffset(20,20), CellPadding = UDim2.fromOffset(5,5), Parent = popup })
        for _, col in ipairs(colors) do
            local c = Create("TextButton", { BackgroundColor3 = col, Text = "", AutoButtonColor = false, ZIndex = 1001, Parent = popup })
            Corner(c, 3); Stroke(c, Theme.Border)
            c.MouseButton1Click:Connect(function()
                st:SetValue(col)
                swatch.BackgroundColor3 = col
                close()
            end)
        end
    end)
    return st
end

function GroupboxMethods:AddInput(key, config)
    config = config or {}
    local st = State(config.Default or "", config.Callback)
    ZyrexLib.Options[key] = st
    local row = self:_Row(58)
    local label = Text(row, config.Text or key, 13, false, Theme.TextDisabled)
    label.Size = UDim2.new(1,0,0,18)
    local input = Create("TextBox", { Size = UDim2.new(1,0,0,30), Position = UDim2.fromOffset(0,24), BackgroundColor3 = Theme.Frame, Text = config.Default or "", PlaceholderText = config.Placeholder or "", PlaceholderColor3 = Theme.TextDisabled, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, Parent = row })
    Corner(input, 4); Stroke(input, Theme.Border); Padding(input, 8,0,8,0)
    input.FocusLost:Connect(function() st:SetValue(input.Text) end)
    return st
end

function GroupboxMethods:AddCodeBox(key, config)
    config = config or {}
    local st = State(config.Default or "", config.Callback)
    ZyrexLib.Options[key] = st
    local row = self:_Row(config.Height or 270)
    local box = Create("TextBox", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Theme.FrameActive, Text = config.Default or "-- Lua editor", TextColor3 = Theme.Text, Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ClearTextOnFocus = false, MultiLine = true, Parent = row })
    Corner(box, 4); Stroke(box, Theme.Border); Padding(box, 10,10,10,10)
    box.FocusLost:Connect(function() st:SetValue(box.Text) end)
    return st
end

--// One-call demo that recreates the provided C++ menu layout
function ZyrexLib:CreateDemo()
    local Window = self:CreateWindow({ Title = "Zyrex", Size = UDim2.fromOffset(760, 554), ToggleKey = Enum.KeyCode.RightShift })

    local Combat = Window:AddTab("Combat", "◎")
    local Legit = Combat:AddSubTab("Legit", "✓")
    Combat:AddSubTab("Silent", "◉"):AddLeftGroupbox("Silent"):AddLabel("Empty in the C++ file")
    Combat:AddSubTab("Aimbot", "⌖"):AddLeftGroupbox("Aimbot"):AddLabel("Empty in the C++ file")
    Combat:AddSubTab("Trigger", "◷"):AddLeftGroupbox("Trigger"):AddLabel("Empty in the C++ file")

    local legitMain = Legit:AddLeftGroupbox("Legit")
    legitMain:AddToggle("legit_enabled", { Text = "Legit", Default = false })
    legitMain:AddCheckbox("predict_aim", { Text = "Predict aim" })
    legitMain:AddCheckbox("auto_group", { Text = "Auto group" })
    legitMain:AddCheckbox("visible_check", { Text = "Visible check" })
    legitMain:AddCheckbox("flash_check", { Text = "Flash check" })
    legitMain:AddCheckbox("scope_check", { Text = "Scope check" })
    legitMain:AddCheckbox("humanized_smooth", { Text = "Humanized smooth" })
    legitMain:AddCheckbox("hit_chance", { Text = "Hit chance" })

    local legitSliders = Legit:AddLeftGroupbox("Tuning")
    legitSliders:AddSlider("humanized_smoothness", { Text = "Humanized Smoothness", Min = 0, Max = 100, Default = 30, Suffix = "%" })
    legitSliders:AddSlider("hit_chance_slider", { Text = "Hit chance", Min = 0, Max = 100, Default = 70, Suffix = "%" })

    local fov = Legit:AddRightGroupbox("Draw FOV")
    fov:AddToggle("draw_fov", { Text = "Draw FOV" })
    fov:AddSeparator("Render")
    fov:AddCheckbox("draw_circle_outlines", { Text = "Draw circle outlines" })
    fov:AddCheckbox("draw_circle_filled", { Text = "Draw circle filled" })
    fov:AddCheckbox("draw_center_tracer", { Text = "Draw center tracer" })
    fov:AddCheckbox("draw_recoil_circle", { Text = "Draw recoil circle" })
    fov:AddSeparator("Colors")
    fov:AddColorPicker("circle_outlines_color", { Text = "Circle outlines", Default = Color3.fromRGB(0, 0, 255) })
    fov:AddColorPicker("circle_filled_color", { Text = "Circle filled", Default = Color3.fromRGB(0, 0, 255) })
    fov:AddColorPicker("center_tracer_color", { Text = "Center tracer", Default = Color3.fromRGB(0, 255, 0) })
    fov:AddColorPicker("recoil_circle_color", { Text = "Recoil circle", Default = Color3.fromRGB(255, 0, 0) })
    fov:AddSeparator("Configs")
    fov:AddSlider("line_thickness", { Text = "Line thickness", Min = 0.5, Max = 3, Default = 1, Rounding = 1, Suffix = "px" })

    local Visuals = Window:AddTab("Visuals", "◌")
    local World = Visuals:AddSubTab("World", "◎")
    Visuals:AddSubTab("Local", "⌖"):AddLeftGroupbox("Local"):AddLabel("Empty in the C++ file")
    Visuals:AddSubTab("ESP", "▦"):AddLeftGroupbox("ESP"):AddLabel("Empty in the C++ file")
    Visuals:AddSubTab("Visualizers", "≋"):AddLeftGroupbox("Visualizers"):AddLabel("Empty in the C++ file")
    local other = World:AddLeftGroupbox("Combo")
    other:AddDropdown("main_target", { Text = "Main target", Values = { "Header", "Body", "Limbs" }, Default = "Header" })
    other:AddDropdown("aim_mode", { Text = "Aim mode", Values = { "Legit", "Rage", "Bot" }, Default = "Legit" })
    other:AddSeparator("Keybind")
    other:AddKeybind("visual_keybind", { Text = "Keybind", Default = "Insert" })

    local Skins = Window:AddTab("Skin Changer", "◈")
    Skins:AddSubTab("Skins", "♢"):AddLeftGroupbox("Skins"):AddLabel("Empty in the C++ file")
    Skins:AddSubTab("Knives", "†"):AddLeftGroupbox("Knives"):AddLabel("Empty in the C++ file")
    Skins:AddSubTab("Custom", "⚒"):AddLeftGroupbox("Custom"):AddLabel("Empty in the C++ file")

    local Movement = Window:AddTab("Movement", "↟")
    Movement:AddSubTab("Legit", "✓"):AddLeftGroupbox("Legit"):AddLabel("Empty in the C++ file")
    Movement:AddSubTab("Rage", "☠"):AddLeftGroupbox("Rage"):AddLabel("Empty in the C++ file")

    local Misc = Window:AddTab("Misc", "✦")
    Misc:GetPage():AddLeftGroupbox("Misc"):AddLabel("Empty in the C++ file")

    local Lua = Window:AddTab("Lua", "</>")
    local luaPage = Lua:GetPage()
    local editor = luaPage:AddLeftGroupbox("Editor")
    editor:AddLabel("Please select a script")
    editor:AddCodeBox("script_editor", { Height = 290, Default = "-- Zyrex Lua editor\nprint('hello world')" })
    editor:AddButton({ Text = "Clear", Callback = function() end })
    editor:AddButton({ Text = "Open", Callback = function() end })
    editor:AddButton({ Text = "Save", Callback = function() end })
    editor:AddButton({ Text = "Execute", Callback = function() end })
    local explorer = luaPage:AddRightGroupbox("Explorer")
    explorer:AddButton({ Text = "radar_hack.lua" })
    explorer:AddButton({ Text = "spectator_list.lua" })
    explorer:AddButton({ Text = "auto_jump.lua" })
    explorer:AddButton({ Text = "anti_aim.lua" })
    explorer:AddButton({ Text = "anti_troll.lua" })

    local Settings = Window:AddTab("Settings", "⚙")
    local theme = Settings:GetPage():AddLeftGroupbox("Theme")
    theme:AddColorPicker("theme_accent", { Text = "Accent", Default = Theme.Accent })
    theme:AddColorPicker("theme_text", { Text = "Text", Default = Theme.Text })
    theme:AddColorPicker("theme_button", { Text = "Button", Default = Theme.Frame })
    theme:AddColorPicker("theme_frame", { Text = "Frame", Default = Theme.Frame })
    theme:AddColorPicker("theme_title", { Text = "Title", Default = Theme.TitleBg })
    theme:AddColorPicker("theme_border", { Text = "Border", Default = Theme.Border })
    theme:AddColorPicker("theme_window", { Text = "Window", Default = Theme.WindowBg })
    theme:AddColorPicker("theme_child", { Text = "Child", Default = Theme.ChildBg })
    theme:AddColorPicker("theme_popup", { Text = "Popup", Default = Theme.PopupBg })

    Window:SelectTab(Combat)
    return Window
end

return ZyrexLib
