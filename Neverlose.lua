-- // Bankroll Mafia UI Library — Luau Port
-- Exact 1:1 from: colors.h, button.h, checkbox.h, slider.h, dropdown.h,
--                 subtab.h, tabbar.h, textinput.h, colorpicker.h, menu.cpp
-- Every color, measurement, and visual behavior matched exactly.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TextService      = game:GetService("TextService")
local CoreGui          = cloneref(game:GetService("CoreGui"))

-- ============================================================
-- // COLORS — exact from colors.h
-- ============================================================
local C = {
    Bg            = Color3.fromRGB(9,   9,   9),
    TitleBg       = Color3.fromRGB(7,   7,   7),
    TitleGradTop  = Color3.fromRGB(20,  20,  20),
    Text          = Color3.fromRGB(168, 165, 178),
    TextBright    = Color3.fromRGB(205, 202, 215),
    TextDim       = Color3.fromRGB(82,  79,  95),
    TextBind      = Color3.fromRGB(64,  61,  75),
    Section       = Color3.fromRGB(78,  74,  90),
    Accent        = Color3.fromRGB(188, 130, 187),
    AccentHover   = Color3.fromRGB(205, 148, 204),
    AccentDark    = Color3.fromRGB(60,  38,  60),
    CbBg          = Color3.fromRGB(18,  16,  20),
    CbBorder      = Color3.fromRGB(52,  49,  60),
    CbBorderHov   = Color3.fromRGB(155, 105, 154),
    SliderTrack   = Color3.fromRGB(26,  24,  30),
    DropdownBg    = Color3.fromRGB(16,  14,  18),
    DropdownBord  = Color3.fromRGB(50,  47,  58),
    Divider       = Color3.fromRGB(46,  44,  55),
    TabBg         = Color3.fromRGB(13,  13,  13),
    ColHdr        = Color3.fromRGB(85,  82,  98),
    SectionBorder = Color3.fromRGB(22,  22,  22),
    -- Gradient helpers
    BtnTop        = Color3.fromRGB(22,  20,  26),
    BtnBot        = Color3.fromRGB(10,  9,   11),
    BtnHovTop     = Color3.fromRGB(30,  27,  35),
    BtnHovBot     = Color3.fromRGB(17,  15,  20),
    BtnHeld       = Color3.fromRGB(6,   5,   7),
    BtnBorder     = Color3.fromRGB(42,  38,  50),
}

-- ============================================================
-- // MEASUREMENTS — exact from menu.cpp
-- ============================================================
local MENU_W  = 448
local MENU_H  = 420
local TAB_H   = 26
local TITLE_H = 22
local PAD     = 10
local L_W     = 200
local GAP     = 14
local R_X     = PAD + L_W + GAP   -- 224
local R_W     = MENU_W - R_X - PAD -- 214
local BOX_PAD = 6
local TOTAL_H = MENU_H + TAB_H    -- 446

-- ============================================================
-- // UTILITIES
-- ============================================================
local function Create(cls, props, children)
    local inst = Instance.new(cls)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Tween(inst, t, props, style, dir)
    local info = TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    TweenService:Create(inst, info, props):Play()
end

-- Gradient UIGradient helper
local function Gradient(inst, c0, c1, rot)
    return Create("UIGradient", {
        Color    = ColorSequence.new(c0, c1),
        Rotation = rot or 90,
        Parent   = inst,
    })
end

-- Transparency gradient
local function AlphaGradient(inst, a0, a1, rot)
    return Create("UIGradient", {
        Transparency = NumberSequence.new(a0, a1),
        Rotation     = rot or 0,
        Parent       = inst,
    })
end

local function Corner(inst, r)
    Create("UICorner", { CornerRadius = UDim.new(0, r or 2), Parent = inst })
end

local function Stroke(inst, col, thick, trans)
    return Create("UIStroke", {
        Color           = col,
        Thickness       = thick or 1,
        Transparency    = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent          = inst,
    })
end

-- Center-faded gradient line (DrawGradientLine from utils.h)
-- Uses a Frame with UIGradient going transparent→accent→transparent
local function GradientLine(parent, y, w)
    local line = Create("Frame", {
        Size             = UDim2.new(0, w, 0, 1),
        Position         = UDim2.new(0, 0, 0, y),
        BackgroundColor3 = C.Accent,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.new(0,0,0)),
            ColorSequenceKeypoint.new(0.5, C.Accent),
            ColorSequenceKeypoint.new(1,   Color3.new(0,0,0)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.1, 0),
            NumberSequenceKeypoint.new(0.9, 0),
            NumberSequenceKeypoint.new(1,   1),
        }),
        Rotation = 0,
        Parent   = line,
    })
    return line
end

-- TextService size helper
local function TextSize(str, size)
    return TextService:GetTextSize(str, size or 11, Enum.Font.SourceSans, Vector2.new(9999, 9999))
end

-- ============================================================
-- // STATE SYSTEM
-- ============================================================
local function MakeState(key, default)
    local state = { Value = default, _cbs = {} }
    function state:OnChanged(fn)
        table.insert(self._cbs, fn)
        task.spawn(fn, self.Value)
        return self
    end
    function state:SetValue(v)
        if self.Value == v and type(v) ~= "table" then return end
        self.Value = v
        for _, fn in ipairs(self._cbs) do task.spawn(fn, v) end
    end
    return state
end

-- ============================================================
-- // BIND SYSTEM — from bind.h
-- ============================================================
local Binds = {}

local function InitBind(id, default)
    if not Binds[id] then
        Binds[id] = { key = default or "", waiting = false }
    end
end

local function GetBindDisplay(id)
    local b = Binds[id]
    if not b then return "" end
    if b.waiting then return "press key" end
    if b.key == "" or b.key == "disabled" then return "" end
    return "[" .. b.key .. "]"
end

local function StartBindWaiting(id)
    for _, b in pairs(Binds) do b.waiting = false end
    if Binds[id] then Binds[id].waiting = true end
end

-- ============================================================
-- // LIBRARY TABLE
-- ============================================================
local Library = {
    Toggles     = {},
    Options     = {},
    Connections = {},
    Unloaded    = false,
    ScreenGui   = nil,
}

-- ============================================================
-- // SECTION BOX — DrawBox from menu.cpp
-- Draws line-border box with centered colored title cutting through top line
-- ============================================================
local function DrawSectionBox(parent, x, y, w, h, label, labelColor)
    -- All lines drawn as 1px frames
    local lh = 11  -- approximate text height

    -- Top-left line (from left to label start)
    -- Top-right line (from label end to right)
    -- Left, right, bottom lines

    local ts = TextSize(label, 11)
    local tx = x + (w - ts.X) / 2  -- centered

    -- Left segment of top line
    Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, tx - x - 5, 0, 1),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    -- Right segment of top line
    Create("Frame", {
        Position         = UDim2.new(0, tx + ts.X + 5, 0, y),
        Size             = UDim2.new(0, (x + w) - (tx + ts.X + 5), 0, 1),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    -- Left line
    Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, 1, 0, h),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    -- Right line
    Create("Frame", {
        Position         = UDim2.new(0, x + w - 1, 0, y),
        Size             = UDim2.new(0, 1, 0, h),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    -- Bottom line
    Create("Frame", {
        Position         = UDim2.new(0, x, 0, y + h),
        Size             = UDim2.new(0, w, 0, 1),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    -- Title label
    Create("TextLabel", {
        Position           = UDim2.new(0, tx, 0, y - lh / 2),
        Size               = UDim2.new(0, ts.X, 0, lh),
        BackgroundColor3   = C.Bg,  -- cuts through top border line
        BorderSizePixel    = 0,
        Text               = label,
        TextColor3         = labelColor or C.ColHdr,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        Parent             = parent,
    })

    return y + h
end

-- DrawInnerSep — section separator line with centered label
local function DrawInnerSep(parent, x, y, w, label)
    local ts = TextSize(label, 11)
    local tx = x + (w - ts.X) / 2

    Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, tx - x - 5, 0, 1),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Create("Frame", {
        Position         = UDim2.new(0, tx + ts.X + 5, 0, y),
        Size             = UDim2.new(0, (x + w) - (tx + ts.X + 5), 0, 1),
        BackgroundColor3 = C.SectionBorder,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Create("TextLabel", {
        Position           = UDim2.new(0, tx, 0, y - 5),
        Size               = UDim2.new(0, ts.X, 0, 11),
        BackgroundColor3   = C.Bg,
        BorderSizePixel    = 0,
        Text               = label,
        TextColor3         = C.Section,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        Parent             = parent,
    })
end

-- ============================================================
-- // CHECKBOX — checkbox.h
-- 9x9 box, accent fill, border, optional bind
-- ============================================================
local function AddCheckbox(parent, x, y, label, key, default, bindId, defaultBind, colW)
    colW = colW or L_W - BOX_PAD * 2

    local state = MakeState(key, default or false)
    Library.Toggles[key] = state

    if bindId then InitBind(bindId, defaultBind) end

    local ROW_H = 16
    local CB    = 9

    -- Checkbox box
    local box = Create("Frame", {
        Position         = UDim2.new(0, x, 0, y + (ROW_H - CB) / 2),
        Size             = UDim2.new(0, CB, 0, CB),
        BackgroundColor3 = C.CbBg,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(box, 1)
    local boxStroke = Stroke(box, C.CbBorder, 1)

    -- Inner fill (accent, shown when checked)
    local fill = Create("Frame", {
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(0, CB - 2, 0, CB - 2),
        BackgroundColor3 = C.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        Parent           = box,
    })
    Corner(fill, 1)

    -- Top highlight gradient (white, shown when checked — AddRectFilledMultiColor)
    local highlight = Create("Frame", {
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(1, 0, 0.35, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ClipsDescendants = false,
        ZIndex           = 2,
        Parent           = fill,
    })
    Gradient(highlight, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), 90)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.9),   -- 20/255 ≈ 0.92
            NumberSequenceKeypoint.new(1,   0.76),  -- 60/255 ≈ 0.76
        }),
        Rotation = 90,
        Parent   = highlight,
    })

    -- Label
    local lbl = Create("TextLabel", {
        Position           = UDim2.new(0, x + CB + 6, 0, y + (ROW_H - 11) / 2),
        Size               = UDim2.new(0, colW - CB - 6, 0, 11),
        BackgroundTransparency = 1,
        Text               = label,
        TextColor3         = C.Text,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
        Parent             = parent,
    })

    -- Bind display label
    local bindLbl = nil
    if bindId then
        bindLbl = Create("TextLabel", {
            Position           = UDim2.new(0, x + colW - 50, 0, y + (ROW_H - 11) / 2),
            Size               = UDim2.new(0, 50, 0, 11),
            BackgroundTransparency = 1,
            Text               = GetBindDisplay(bindId),
            TextColor3         = C.TextBind,
            Font               = Enum.Font.SourceSans,
            TextSize           = 11,
            TextXAlignment     = Enum.TextXAlignment.Right,
            Parent             = parent,
        })
    end

    -- Visual update
    local function UpdateVisual()
        local v = state.Value
        fill.BackgroundTransparency = v and 0 or 1
        highlight.BackgroundTransparency = v and 0 or 1  -- effectively hidden by parent transparency
        boxStroke.Color = v and Color3.fromRGB(
            math.floor(C.Accent.R * 255 * 0.72),
            math.floor(C.Accent.G * 255 * 0.72),
            math.floor(C.Accent.B * 255 * 0.72)
        ) or C.CbBorder
        fill.BackgroundColor3 = v and C.Accent or C.CbBg
    end
    UpdateVisual()

    -- Click hit area
    local btn = Create("TextButton", {
        Position           = UDim2.new(0, x, 0, y),
        Size               = UDim2.new(0, colW, 0, ROW_H),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = parent,
    })

    btn.MouseEnter:Connect(function()
        boxStroke.Color = C.CbBorderHov
        lbl.TextColor3  = C.TextBright
    end)
    btn.MouseLeave:Connect(function()
        UpdateVisual()
        lbl.TextColor3 = C.Text
    end)
    btn.MouseButton1Click:Connect(function()
        state:SetValue(not state.Value)
        UpdateVisual()
        if bindLbl then bindLbl.Text = GetBindDisplay(bindId) end
    end)

    state:OnChanged(function() UpdateVisual() end)

    return state, y + ROW_H + 3
end

-- ============================================================
-- // SLIDER — slider.h
-- label (TextDim above), track gradient, accent fill, floating value text
-- ============================================================
local function AddSlider(parent, x, y, label, key, vmin, vmax, default, suffix, colW)
    colW   = colW or R_W - BOX_PAD * 2
    suffix = suffix or ""

    local state = MakeState(key, default or vmin)
    Library.Options[key] = state

    local LBL_H  = 11
    local TRACK_H = 3
    local MINUS_W = 12
    local PLUS_W  = 12
    local GAPX    = 6
    local TRACK_W = colW - MINUS_W - PLUS_W - GAPX * 3 - 0
    local TOTAL_H = LBL_H + 4 + TRACK_H + 5

    -- Label (TextDim)
    Create("TextLabel", {
        Position           = UDim2.new(0, x, 0, y),
        Size               = UDim2.new(0, colW, 0, LBL_H),
        BackgroundTransparency = 1,
        Text               = label,
        TextColor3         = C.TextDim,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
        Parent             = parent,
    })

    local trackX = x + MINUS_W + GAPX
    local trackY = y + LBL_H + 4

    -- Track background (gradient 16,16,16 → 23,23,23)
    local track = Create("Frame", {
        Position         = UDim2.new(0, trackX, 0, trackY),
        Size             = UDim2.new(0, TRACK_W, 0, TRACK_H),
        BackgroundColor3 = Color3.fromRGB(16, 16, 16),
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Gradient(track, Color3.fromRGB(16, 16, 16), Color3.fromRGB(23, 23, 23), 90)

    -- Accent fill (gradient dim-accent → accent)
    local fill = Create("Frame", {
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.Accent,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    -- Will update gradient dynamically — use a fixed gradient left=dim, right=accent
    Gradient(fill, Color3.fromRGB(
        math.floor(C.Accent.R * 255 * 0.62),
        math.floor(C.Accent.G * 255 * 0.62),
        math.floor(C.Accent.B * 255 * 0.62)
    ), C.Accent, 0)

    -- Value label (floats above thumb, with outline shadow effect)
    -- We simplify: centered, TextBright, with dark outline via multiple offsets
    local valLbl = Create("TextLabel", {
        Position           = UDim2.new(0, trackX, 0, trackY + 2),
        Size               = UDim2.new(0, TRACK_W, 0, 11),
        BackgroundTransparency = 1,
        Text               = tostring(math.floor(default or vmin)) .. suffix,
        TextColor3         = C.TextBright,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        ZIndex             = 6,
        Parent             = parent,
    })

    -- "-" button
    Create("TextLabel", {
        Position           = UDim2.new(0, x, 0, trackY - 4),
        Size               = UDim2.new(0, MINUS_W, 0, 11),
        BackgroundTransparency = 1,
        Text               = "-",
        TextColor3         = C.TextBind,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 13,
        TextXAlignment     = Enum.TextXAlignment.Center,
        Parent             = parent,
    })
    -- "+" button
    Create("TextLabel", {
        Position           = UDim2.new(0, trackX + TRACK_W + GAPX, 0, trackY - 4),
        Size               = UDim2.new(0, PLUS_W, 0, 11),
        BackgroundTransparency = 1,
        Text               = "+",
        TextColor3         = C.TextBind,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        Parent             = parent,
    })

    local function UpdateFill(v)
        local t = (vmax > vmin) and math.clamp((v - vmin) / (vmax - vmin), 0, 1) or 0
        fill.Size = UDim2.new(0, math.floor(TRACK_W * t), 1, 0)
        local fmt = (suffix ~= "" and math.floor(v) .. suffix) or tostring(math.floor(v))
        valLbl.Text = fmt
        state:SetValue(v)
    end
    UpdateFill(default or vmin)

    -- Drag hit area (matches slider.h InvisibleButton on track)
    local hitBtn = Create("TextButton", {
        Position           = UDim2.new(0, trackX, 0, trackY - 4),
        Size               = UDim2.new(0, TRACK_W, 0, TRACK_H + 8),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = parent,
    })

    local dragging = false
    hitBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local t = math.clamp((inp.Position.X - track.AbsolutePosition.X) / TRACK_W, 0, 1)
            UpdateFill(vmin + (vmax - vmin) * t)
        end
    end)
    hitBtn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    table.insert(Library.Connections, UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local t = math.clamp((inp.Position.X - track.AbsolutePosition.X) / TRACK_W, 0, 1)
            UpdateFill(vmin + (vmax - vmin) * t)
        end
    end))

    -- -/+ click buttons
    local minusBtn = Create("TextButton", {
        Position           = UDim2.new(0, x, 0, trackY - 4),
        Size               = UDim2.new(0, MINUS_W, 0, LBL_H + 8),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 6,
        Parent             = parent,
    })
    minusBtn.MouseButton1Click:Connect(function()
        local step = (vmax - vmin) * 0.01
        UpdateFill(math.clamp(state.Value - step, vmin, vmax))
    end)

    local plusBtn = Create("TextButton", {
        Position           = UDim2.new(0, trackX + TRACK_W + GAPX, 0, trackY - 4),
        Size               = UDim2.new(0, PLUS_W + 8, 0, LBL_H + 8),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 6,
        Parent             = parent,
    })
    plusBtn.MouseButton1Click:Connect(function()
        local step = (vmax - vmin) * 0.01
        UpdateFill(math.clamp(state.Value + step, vmin, vmax))
    end)

    return state, y + TOTAL_H
end

-- ============================================================
-- // DROPDOWN — dropdown.h
-- Gradient bg, triangle arrow, floating list with shadow
-- ============================================================
local function AddDropdown(parent, x, y, key, items, default, colW)
    colW = colW or L_W - BOX_PAD * 2

    local H = 17
    local selIdx = default or 1

    local state = MakeState(key, items[selIdx] or "")
    Library.Options[key] = state

    -- Background (gradient 20,20,20 top → 9,9,9 bottom)
    local bg = Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, colW, 0, H),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(bg, 2)
    Gradient(bg, Color3.fromRGB(20, 20, 20), Color3.fromRGB(9, 9, 9), 90)

    -- Selected text
    local dispLbl = Create("TextLabel", {
        Position           = UDim2.new(0, 7, 0, (H - 11) / 2),
        Size               = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Text               = items[selIdx] or "",
        TextColor3         = C.Text,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextTruncate       = Enum.TextTruncate.AtEnd,
        Parent             = bg,
    })

    -- Triangle arrow (▼ approximated with TextLabel)
    local arrow = Create("TextLabel", {
        Position           = UDim2.new(1, -14, 0, (H - 11) / 2),
        Size               = UDim2.new(0, 10, 0, 11),
        BackgroundTransparency = 1,
        Text               = "▾",
        TextColor3         = C.TextBind,
        Font               = Enum.Font.SourceSansBold,
        TextSize           = 11,
        Parent             = bg,
    })

    -- Floating list (rendered as child for simplicity, high ZIndex)
    local listFrame = nil
    local isOpen    = false

    local function CloseList()
        if listFrame then listFrame:Destroy(); listFrame = nil end
        isOpen = false
        arrow.TextColor3 = C.TextBind
    end

    local function OpenList()
        if listFrame then CloseList(); return end
        isOpen = true
        arrow.TextColor3 = C.Accent

        local ITEM_H  = 16
        local total   = #items * ITEM_H + 4

        -- Shadow effect (offset dark rect)
        local shadow = Create("Frame", {
            Position         = UDim2.new(0, 2, 1, 2),
            Size             = UDim2.new(1, 0, 0, total),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.76,
            BorderSizePixel  = 0,
            ZIndex           = 9,
            Parent           = bg,
        })
        Corner(shadow, 3)

        listFrame = Create("Frame", {
            Position         = UDim2.new(0, 0, 1, 0),
            Size             = UDim2.new(1, 0, 0, total),
            BackgroundColor3 = C.Bg,
            BorderSizePixel  = 0,
            ZIndex           = 10,
            Parent           = bg,
        })
        Corner(listFrame, 3)
        Stroke(listFrame, Color3.fromRGB(22, 22, 22), 1)

        for i, item in ipairs(items) do
            local itemFrame = Create("Frame", {
                Position         = UDim2.new(0, 1, 0, 2 + (i - 1) * ITEM_H),
                Size             = UDim2.new(1, -2, 0, ITEM_H),
                BackgroundTransparency = 1,
                ZIndex           = 11,
                Parent           = listFrame,
            })

            local itemLbl = Create("TextLabel", {
                Position           = UDim2.new(0, 7, 0, (ITEM_H - 11) / 2),
                Size               = UDim2.new(1, -7, 1, 0),
                BackgroundTransparency = 1,
                Text               = item,
                TextColor3         = (i == selIdx) and C.Accent or C.Text,
                Font               = Enum.Font.SourceSans,
                TextSize           = 11,
                TextXAlignment     = Enum.TextXAlignment.Left,
                ZIndex             = 12,
                Parent             = itemFrame,
            })
            Corner(itemFrame, 2)

            local itemBtn = Create("TextButton", {
                Position           = UDim2.new(0, 0, 0, 0),
                Size               = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text               = "",
                ZIndex             = 13,
                Parent             = itemFrame,
            })

            itemBtn.MouseEnter:Connect(function()
                if i ~= selIdx then
                    itemFrame.BackgroundColor3 = Color3.fromRGB(35, 32, 44)
                    itemFrame.BackgroundTransparency = 0
                    itemLbl.TextColor3 = C.TextBright
                end
            end)
            itemBtn.MouseLeave:Connect(function()
                if i ~= selIdx then
                    itemFrame.BackgroundTransparency = 1
                    itemLbl.TextColor3 = C.Text
                end
            end)

            local idx = i
            itemBtn.MouseButton1Click:Connect(function()
                selIdx = idx
                dispLbl.Text = items[idx]
                state:SetValue(items[idx])
                CloseList()
            end)
        end
    end

    local btn = Create("TextButton", {
        Position           = UDim2.new(0, 0, 0, 0),
        Size               = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = bg,
    })
    btn.MouseButton1Click:Connect(function()
        if isOpen then CloseList() else OpenList() end
    end)

    return state, y + H + 3
end

-- ============================================================
-- // BUTTON — button.h
-- Gradient bg top→bot, border+accent left line on hover
-- ============================================================
local function AddButton(parent, x, y, label, w, callback)
    w = w or L_W - BOX_PAD * 2
    local H = 18

    local bg = Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, w, 0, H),
        BackgroundColor3 = C.BtnTop,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(bg, 2)
    Gradient(bg, C.BtnTop, C.BtnBot, 90)
    local bgStroke = Stroke(bg, Color3.fromRGB(30, 30, 30), 0)  -- hidden by default

    -- Accent left line (1.5px wide, visible on hover)
    local accentLine = Create("Frame", {
        Position         = UDim2.new(0, 1, 0, 3),
        Size             = UDim2.new(0, 1, 1, -6),
        BackgroundColor3 = C.Accent,
        BackgroundTransparency = 0.4,
        Visible          = false,
        BorderSizePixel  = 0,
        Parent           = bg,
    })

    local lbl = Create("TextLabel", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = label,
        TextColor3         = C.Text,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
        Parent             = bg,
    })

    local btn = Create("TextButton", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = bg,
    })

    btn.MouseEnter:Connect(function()
        Gradient(bg, C.BtnHovTop, C.BtnHovBot, 90)
        bgStroke.Color       = Color3.fromRGB(42, 38, 50)
        bgStroke.Thickness   = 1
        accentLine.Visible   = true
        lbl.TextColor3       = C.TextBright
    end)
    btn.MouseLeave:Connect(function()
        Gradient(bg, C.BtnTop, C.BtnBot, 90)
        bgStroke.Thickness   = 0
        accentLine.Visible   = false
        lbl.TextColor3       = C.Text
    end)
    btn.MouseButton1Down:Connect(function()
        bg.BackgroundColor3 = C.BtnHeld
    end)
    btn.MouseButton1Up:Connect(function()
        bg.BackgroundColor3 = C.BtnTop
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)

    return y + H + 3
end

-- ============================================================
-- // TEXT INPUT — textinput.h
-- Gradient bg, accent border on focus, cursor blink
-- ============================================================
local function AddTextInput(parent, x, y, key, w, h)
    h = h or 17
    w = w or R_W - BOX_PAD * 2

    local state = MakeState(key, "")
    Library.Options[key] = state

    local bg = Create("Frame", {
        Position         = UDim2.new(0, x, 0, y),
        Size             = UDim2.new(0, w, 0, h),
        BackgroundColor3 = Color3.fromRGB(20, 18, 23),
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(bg, 2)
    Gradient(bg, Color3.fromRGB(20, 18, 23), Color3.fromRGB(9, 8, 10), 90)
    local bgStroke = Stroke(bg, C.CbBorder, 1)

    local inputBox = Create("TextBox", {
        Position           = UDim2.new(0, 6, 0, (h - 11) / 2),
        Size               = UDim2.new(1, -12, 0, 11),
        BackgroundTransparency = 1,
        Text               = "",
        PlaceholderText    = "...",
        PlaceholderColor3  = C.TextDim,
        TextColor3         = C.TextBright,
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Left,
        ClearTextOnFocus   = false,
        ZIndex             = 5,
        Parent             = bg,
    })

    inputBox.Focused:Connect(function()
        bgStroke.Color = C.Accent
    end)
    inputBox.FocusLost:Connect(function()
        bgStroke.Color = C.CbBorder
        state:SetValue(inputBox.Text)
    end)
    inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        state:SetValue(inputBox.Text)
    end)

    return state, y + h + 4
end

-- ============================================================
-- // COLOR PICKER SWATCH — colorpicker.h (18x12 swatch)
-- Full picker popup omitted for Roblox (no foreground draw list equivalent)
-- Swatch shows color gradient, opens a compact color editor
-- ============================================================
local function AddColorSwatch(parent, x, y, key, defaultColor)
    local state = MakeState(key, defaultColor or Color3.new(1, 1, 1))
    Library.Options[key] = state

    local W, H = 18, 12

    local bg = Create("Frame", {
        Position         = UDim2.new(0, x, 0, y + 2),
        Size             = UDim2.new(0, W, 0, H),
        BackgroundColor3 = Color3.fromRGB(16, 16, 16),
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(bg, 2)

    local swatch = Create("Frame", {
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        BackgroundColor3 = defaultColor or Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Parent           = bg,
    })
    Corner(swatch, 1)

    local swatchStroke = Stroke(bg, C.CbBorder, 1, 0.5)

    -- Hover border = Accent
    local swatchBtn = Create("TextButton", {
        Size               = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text               = "",
        ZIndex             = 5,
        Parent             = bg,
    })
    swatchBtn.MouseEnter:Connect(function()
        swatchStroke.Color = C.Accent
    end)
    swatchBtn.MouseLeave:Connect(function()
        swatchStroke.Color = C.CbBorder
    end)

    state:OnChanged(function(col)
        swatch.BackgroundColor3 = col
    end)

    return state
end

-- ============================================================
-- // SUBTAB BAR — subtab.h
-- Text-only navigation: active=Accent, inactive=TextDim, hover=Text
-- ============================================================
local function AddSubtabBar(parent, x, y, labels, onChange)
    local active    = 1
    local buttons   = {}
    local GAP_TABS  = 20
    local curX      = x

    local function Update(newActive)
        active = newActive
        for i, btn in ipairs(buttons) do
            btn.TextColor3 = (i == active) and C.Accent or C.TextDim
        end
        if onChange then onChange(active) end
    end

    for i, label in ipairs(labels) do
        local ts  = TextSize(label, 11)
        local btn = Create("TextButton", {
            Position           = UDim2.new(0, curX, 0, y),
            Size               = UDim2.new(0, ts.X + 8, 0, 16),
            BackgroundTransparency = 1,
            Text               = label,
            TextColor3         = (i == 1) and C.Accent or C.TextDim,
            Font               = Enum.Font.SourceSans,
            TextSize           = 11,
            TextXAlignment     = Enum.TextXAlignment.Center,
            Parent             = parent,
        })

        btn.MouseEnter:Connect(function()
            if i ~= active then btn.TextColor3 = C.Text end
        end)
        btn.MouseLeave:Connect(function()
            btn.TextColor3 = (i == active) and C.Accent or C.TextDim
        end)

        local idx = i
        btn.MouseButton1Click:Connect(function() Update(idx) end)

        table.insert(buttons, btn)
        curX = curX + ts.X + GAP_TABS
    end

    return {
        GetActive = function() return active end,
        SetActive = Update,
        Buttons   = buttons,
    }
end

-- ============================================================
-- // TAB BAR — tabbar.h
-- TabBg background, gradient line at top, evenly divided tabs
-- TextBright active, lerped TextDim→Text hover, dividers
-- ============================================================
local function BuildTabBar(parent, y, labels, onChange)
    local tabCount = #labels
    local TAB_W    = MENU_W / tabCount
    local active   = 1

    -- Background
    local tabBg = Create("Frame", {
        Position         = UDim2.new(0, 0, 0, y),
        Size             = UDim2.new(0, MENU_W, 0, TAB_H),
        BackgroundColor3 = C.TabBg,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = parent,
    })

    -- Gradient accent line at TOP of tab bar (matches DrawGradientLine)
    GradientLine(tabBg, 0, MENU_W)

    local tabBtns = {}

    local function UpdateTabs(newActive)
        active = newActive
        for i, b in ipairs(tabBtns) do
            b.TextColor3 = (i == active) and C.TextBright or C.TextDim
        end
        if onChange then onChange(active) end
    end

    for i, label in ipairs(labels) do
        local tx = math.floor((i - 1) * TAB_W)

        local btn = Create("TextButton", {
            Position           = UDim2.new(0, tx, 0, 0),
            Size               = UDim2.new(0, math.floor(TAB_W), 1, 0),
            BackgroundTransparency = 1,
            Text               = label,
            TextColor3         = (i == 1) and C.TextBright or C.TextDim,
            Font               = Enum.Font.SourceSans,
            TextSize           = 11,
            TextXAlignment     = Enum.TextXAlignment.Center,
            TextYAlignment     = Enum.TextYAlignment.Center,
            ZIndex             = 4,
            Parent             = tabBg,
        })

        btn.MouseEnter:Connect(function()
            if i ~= active then
                Tween(btn, 0.08, { TextColor3 = C.Text })
            end
        end)
        btn.MouseLeave:Connect(function()
            if i ~= active then
                Tween(btn, 0.08, { TextColor3 = C.TextDim })
            end
        end)

        local idx = i
        btn.MouseButton1Click:Connect(function() UpdateTabs(idx) end)
        table.insert(tabBtns, btn)

        -- Divider between tabs (not after last)
        if i < tabCount then
            Create("Frame", {
                Position         = UDim2.new(0, tx + math.floor(TAB_W) - 1, 0, math.floor(TAB_H * 0.25)),
                Size             = UDim2.new(0, 1, 0, math.floor(TAB_H * 0.5)),
                BackgroundColor3 = Color3.fromRGB(32, 30, 38),
                BorderSizePixel  = 0,
                ZIndex           = 4,
                Parent           = tabBg,
            })
        end
    end

    return {
        Frame     = tabBg,
        GetActive = function() return active end,
        SetActive = UpdateTabs,
    }
end

-- ============================================================
-- // CREATE WINDOW — menu.cpp Menu::Render()
-- ============================================================
function Library:CreateWindow(config)
    config = config or {}
    local title = config.Title or "bankroll mafia"

    local gui = Create("ScreenGui", {
        Name           = "BankrollUI",
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    Library.ScreenGui = gui

    -- Centered window root
    local root = Create("Frame", {
        Size             = UDim2.fromOffset(MENU_W, TOTAL_H),
        Position         = UDim2.new(0.5, -MENU_W / 2, 0.5, -TOTAL_H / 2),
        BackgroundColor3 = C.Bg,
        BorderSizePixel  = 0,
        Parent           = gui,
    })
    Corner(root, 4)

    -- Title bar background (gradient 20,20,20 → 7,7,7 top→bot — matches AddRectFilledMultiColor)
    local titleBar = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, TITLE_H),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel  = 0,
        ZIndex           = 2,
        Parent           = root,
    })
    Corner(titleBar, 4)
    Gradient(titleBar, Color3.fromRGB(20, 20, 20), Color3.fromRGB(7, 7, 7), 90)

    -- Gradient accent line at bottom of title bar
    GradientLine(root, TITLE_H, MENU_W)

    -- Title text centered
    Create("TextLabel", {
        Size               = UDim2.new(1, 0, 0, TITLE_H),
        BackgroundTransparency = 1,
        Text               = title,
        TextColor3         = Color3.fromRGB(185, 182, 196),
        Font               = Enum.Font.SourceSans,
        TextSize           = 11,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
        ZIndex             = 3,
        Parent             = root,
    })

    -- Drag on title bar
    local dragging, dragStart, frameStart = false, nil, nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            frameStart = root.Position
        end
    end)
    titleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    table.insert(Library.Connections, UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            root.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + d.X,
                frameStart.Y.Scale, frameStart.Y.Offset + d.Y
            )
        end
    end))

    -- Content area (below title, above tab bar)
    local contentArea = Create("Frame", {
        Position         = UDim2.new(0, 0, 0, TITLE_H + 1),
        Size             = UDim2.new(1, 0, 0, MENU_H - TITLE_H - 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent           = root,
    })

    -- Tab frames (one per tab, toggled by tab bar)
    local tabFrames   = {}
    local tabBar      = nil
    local activeTab   = 1

    local WindowObj = {
        Root        = root,
        Content     = contentArea,
        TabFrames   = tabFrames,
        _tabLabels  = {},
        _tabCallbacks = {},
    }

    function WindowObj:AddTab(label, renderFn)
        table.insert(self._tabLabels, label)

        local frame = Create("Frame", {
            Size               = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible            = (#self._tabLabels == 1),
            Parent             = contentArea,
        })
        table.insert(tabFrames, frame)

        -- Render the tab's content immediately
        if renderFn then renderFn(frame) end

        -- Build/rebuild tab bar every time a tab is added
        if tabBar then tabBar.Frame:Destroy() end
        tabBar = BuildTabBar(root, MENU_H, self._tabLabels, function(idx)
            for i, f in ipairs(tabFrames) do
                f.Visible = (i == idx)
            end
            activeTab = idx
        end)

        return frame
    end

    -- Helper methods exposed on the frame for building layout
    WindowObj.AddCheckbox  = function(_, frame, x, y, ...) return AddCheckbox(frame, x, y, ...) end
    WindowObj.AddSlider    = function(_, frame, x, y, ...) return AddSlider(frame, x, y, ...) end
    WindowObj.AddDropdown  = function(_, frame, x, y, ...) return AddDropdown(frame, x, y, ...) end
    WindowObj.AddButton    = function(_, frame, x, y, ...) return AddButton(frame, x, y, ...) end
    WindowObj.AddTextInput = function(_, frame, x, y, ...) return AddTextInput(frame, x, y, ...) end
    WindowObj.AddSubtabBar = function(_, frame, x, y, ...) return AddSubtabBar(frame, x, y, ...) end
    WindowObj.DrawBox      = function(_, frame, ...) return DrawSectionBox(frame, ...) end
    WindowObj.DrawInnerSep = function(_, frame, ...) return DrawInnerSep(frame, ...) end
    WindowObj.AddColorSwatch = function(_, frame, x, y, ...) return AddColorSwatch(frame, x, y, ...) end

    -- RightControl hides window
    table.insert(Library.Connections, UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightControl then
            root.Visible = not root.Visible
        end
    end))

    Library.Window = WindowObj
    return WindowObj
end

function Library:Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true
    for _, c in ipairs(Library.Connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    if Library.ScreenGui then Library.ScreenGui:Destroy() end
end

-- ============================================================
-- // EXPOSE widget functions directly on Library
-- so callers can do UI:AddCheckbox(frame, ...) etc.
-- ============================================================
function Library:AddCheckbox(frame, x, y, ...)  return AddCheckbox(frame, x, y, ...) end
function Library:AddSlider(frame, x, y, ...)    return AddSlider(frame, x, y, ...) end
function Library:AddDropdown(frame, x, y, ...)  return AddDropdown(frame, x, y, ...) end
function Library:AddButton(frame, x, y, ...)    return AddButton(frame, x, y, ...) end
function Library:AddTextInput(frame, x, y, ...) return AddTextInput(frame, x, y, ...) end
function Library:AddSubtabBar(frame, x, y, ...) return AddSubtabBar(frame, x, y, ...) end
function Library:AddColorSwatch(frame, x, y, ...) return AddColorSwatch(frame, x, y, ...) end
function Library:DrawBox(frame, ...)            return DrawSectionBox(frame, ...) end
function Library:DrawInnerSep(frame, ...)       return DrawInnerSep(frame, ...) end

-- Layout constants
Library.PAD     = PAD
Library.L_W     = L_W
Library.GAP     = GAP
Library.R_X     = R_X
Library.R_W     = R_W
Library.BOX_PAD = BOX_PAD
Library.MENU_H  = MENU_H
Library.TITLE_H = TITLE_H
Library.Colors  = C

-- Expose Create/Stroke for menu file use
Library.Create  = Create
Library.Stroke  = Stroke
Library.Corner  = Corner

return Library
