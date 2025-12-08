-- Full LocalScript: Loading overlay + fixed toggles + complete ESP/Aim UI
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

------------------------------------------------
-- Persistence helpers
------------------------------------------------
local ATTRIBUTE_KEY = "ControlPanelPosition"
local DEFAULT_POSITION = UDim2.new(0.05, 0, 0.7, 0)

local function parseSavedPosition(str)
    if type(str) ~= "string" then return nil end
    local a,b,c,d = str:match("([^,]+),([^,]+),([^,]+),([^,]+)")
    if not a then return nil end
    return UDim2.new(tonumber(a), tonumber(b), tonumber(c), tonumber(d))
end

local function formatSavedPosition(ud)
    if typeof(ud) ~= "UDim2" then return nil end
    return string.format("%f,%d,%f,%d", ud.X.Scale, ud.X.Offset, ud.Y.Scale, ud.Y.Offset)
end

local function loadSavedPosition()
    local attr = LocalPlayer:GetAttribute(ATTRIBUTE_KEY)
    local parsed = parseSavedPosition(attr)
    return parsed or DEFAULT_POSITION
end

local function savePosition(ud)
    local s = formatSavedPosition(ud)
    if s then LocalPlayer:SetAttribute(ATTRIBUTE_KEY, s) end
end

------------------------------------------------
-- Loading overlay (simple Rayfield-style)
------------------------------------------------
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "LoadingOverlay"
loadingGui.IgnoreGuiInset = true
loadingGui.ResetOnSpawn = false
loadingGui.Parent = PlayerGui

local loadFrame = Instance.new("Frame")
loadFrame.Size = UDim2.new(0, 260, 0, 120)
loadFrame.Position = UDim2.new(0.5, -130, 0.5, -60)
loadFrame.BackgroundColor3 = Color3.fromRGB(25,25,30)
loadFrame.BorderSizePixel = 0
loadFrame.Parent = loadingGui
local loadCorner = Instance.new("UICorner"); loadCorner.CornerRadius = UDim.new(0,12); loadCorner.Parent = loadFrame

local loadTitle = Instance.new("TextLabel")
loadTitle.Size = UDim2.new(1,0,0,40)
loadTitle.Position = UDim2.new(0,0,0,10)
loadTitle.BackgroundTransparency = 1
loadTitle.Text = "Loading ESP UI..."
loadTitle.TextColor3 = Color3.fromRGB(255,255,255)
loadTitle.Font = Enum.Font.GothamBold
loadTitle.TextScaled = true
loadTitle.Parent = loadFrame

local spinner = Instance.new("Frame")
spinner.Size = UDim2.new(0,40,0,40)
spinner.Position = UDim2.new(0.5,-20,0.7,-20)
spinner.BackgroundTransparency = 1
spinner.Parent = loadFrame
local spinnerStroke = Instance.new("UIStroke"); spinnerStroke.Thickness = 4; spinnerStroke.Color = Color3.fromRGB(0,200,255); spinnerStroke.Parent = spinner

local spinnerConn
local function startSpinner()
    local angle = 0
    spinnerConn = RunService.RenderStepped:Connect(function(dt)
        angle = angle + 180 * dt
        spinner.Rotation = angle % 360
    end)
end
local function stopSpinner()
    if spinnerConn then spinnerConn:Disconnect(); spinnerConn = nil end
end

local function ShowLoading()
    loadingGui.Enabled = true
    startSpinner()
end

local function HideLoading(callback)
    stopSpinner()
    TweenService:Create(loadFrame, TweenInfo.new(0.45), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadTitle, TweenInfo.new(0.45), {TextTransparency = 1}):Play()
    TweenService:Create(spinnerStroke, TweenInfo.new(0.45), {Transparency = 1}):Play()
    task.wait(0.55)
    loadingGui.Enabled = false
    if callback then callback() end
end

------------------------------------------------
-- InitESPUI: full UI + ESP/Aim logic
------------------------------------------------
local function InitESPUI()
    -- State
    local aimLockEnabled = false
    local espEnabled = false
    local namesEnabled = false
    local healthEnabled = false
    local aimSpeed = 0.45

    -- ESP registry
    local ESPRegistry = {} -- [player] = { highlight, tracer, nameLabel, healthBar, healthFill }

    -- ScreenGuis
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ModernControlUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui

    local tracerGui = Instance.new("ScreenGui")
    tracerGui.Name = "TracerLayer"
    tracerGui.ResetOnSpawn = false
    tracerGui.IgnoreGuiInset = true
    tracerGui.Parent = PlayerGui

    -- Tween helper
    local function tween(instance, props, time, style, dir)
        style = style or Enum.EasingStyle.Quint
        dir = dir or Enum.EasingDirection.Out
        local info = TweenInfo.new(time or 0.25, style, dir)
        local t = TweenService:Create(instance, info, props)
        t:Play()
        return t
    end

    -- Panel (create early so other UI elements can reference it)
    local savedPosition = loadSavedPosition()
    local panel = Instance.new("Frame")
    panel.Name = "ControlPanel"
    panel.Size = UDim2.new(0, 300, 0, 200)
    panel.Position = savedPosition
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    panel.BackgroundTransparency = 0.18
    panel.BorderSizePixel = 0
    panel.Parent = screenGui
    panel.Active = true

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Aim • ESP Controls"
    title.TextColor3 = Color3.fromRGB(235, 235, 240)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    -- Hamburger toggle button (parented to screenGui so it's always visible)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "MenuToggle"
    toggleBtn.Size = UDim2.new(0, 44, 0, 44)
    toggleBtn.Position = UDim2.new(1, -54, 0, 10)
    toggleBtn.AnchorPoint = Vector2.new(0, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    toggleBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    toggleBtn.Text = "≡"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 20
    toggleBtn.Parent = screenGui

    local toggleCorner = Instance.new("UICorner"); toggleCorner.CornerRadius = UDim.new(0, 10); toggleCorner.Parent = toggleBtn
    local toggleStroke = Instance.new("UIStroke"); toggleStroke.Color = Color3.fromRGB(90,90,100); toggleStroke.Thickness = 1; toggleStroke.Parent = toggleBtn

    -- Menu toggle behavior (start closed off-screen)
    panel.Position = UDim2.new(savedPosition.X.Scale, savedPosition.X.Offset, 1.2, 0)
    panel.BackgroundTransparency = 1
    local menuOpen = false
    toggleBtn.MouseButton1Click:Connect(function()
        menuOpen = not menuOpen
        if menuOpen then
            tween(panel, {Position = savedPosition, BackgroundTransparency = 0.18}, 0.35)
        else
            tween(panel, {Position = UDim2.new(savedPosition.X.Scale, savedPosition.X.Offset, 1.2, 0), BackgroundTransparency = 1}, 0.35)
        end
    end)

    -- Toggle factory with callback (visual + logic sync)
    local function makeToggle(name, labelText, posX, posY, initialState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 140, 0, 40)
        container.Position = UDim2.new(0, posX, 0, posY)
        container.BackgroundTransparency = 1
        container.Parent = panel

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 100, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230,230,235)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 40, 0, 24)
        btn.Position = UDim2.new(1, -40, 0.5, -12)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,55)
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = container

        local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, 12); btnCorner.Parent = btn
        local inner = Instance.new("Frame")
        inner.Size = UDim2.new(0.5, -4, 1, -4)
        inner.Position = UDim2.new(0, 2, 0, 2)
        inner.BackgroundColor3 = Color3.fromRGB(200,200,200)
        inner.Parent = btn
        local innerCorner = Instance.new("UICorner"); innerCorner.CornerRadius = UDim.new(1, 0); innerCorner.Parent = inner
        local glow = Instance.new("UIStroke"); glow.Thickness = 2; glow.Color = Color3.fromRGB(0,200,160); glow.Transparency = 1; glow.Parent = inner

        local state = initialState or false
        local function updateVisual()
            if state then
                tween(btn, {BackgroundColor3 = Color3.fromRGB(10,160,120)}, 0.22)
                tween(inner, {Position = UDim2.new(0.5,2,0,2)}, 0.18)
                tween(glow, {Transparency = 0}, 0.28)
            else
                tween(btn, {BackgroundColor3 = Color3.fromRGB(50,50,55)}, 0.22)
                tween(inner, {Position = UDim2.new(0,2,0,2)}, 0.18)
                tween(glow, {Transparency = 1}, 0.28)
            end
        end

        btn.MouseButton1Click:Connect(function()
            state = not state
            updateVisual()
            if callback then callback(state) end
        end)

        updateVisual()
        return { setState = function(s) state = s; updateVisual() end, getState = function() return state end }
    end

    -- Create toggles with callbacks that update logic
    local aimToggle = makeToggle("AimToggle", "Aim-Lock", 12, 44, false, function(state) aimLockEnabled = state end)
    local espToggle = makeToggle("ESPToggle", "ESP", 152, 44, false, function(state)
        espEnabled = state
        for _, pack in pairs(ESPRegistry) do
            if pack.highlight then pack.highlight.Enabled = espEnabled end
            if pack.tracer then pack.tracer.Visible = espEnabled end
            if pack.nameLabel then pack.nameLabel.Visible = espEnabled and namesEnabled end
            if pack.healthBar then pack.healthBar.Visible = espEnabled and healthEnabled end
        end
    end)
    local namesToggle = makeToggle("NamesToggle", "Names", 12, 92, false, function(state)
        namesEnabled = state
        for _, pack in pairs(ESPRegistry) do
            if pack.nameLabel then pack.nameLabel.Visible = espEnabled and namesEnabled end
        end
    end)
    local healthToggle = makeToggle("HealthToggle", "Health", 152, 92, false, function(state)
        healthEnabled = state
        for _, pack in pairs(ESPRegistry) do
            if pack.healthBar then pack.healthBar.Visible = espEnabled and healthEnabled end
        end
    end)

    -- Slider (Aim Speed)
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(0, 260, 0, 18)
    sliderBg.Position = UDim2.new(0, 18, 0, 150)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40,40,45)
    sliderBg.Parent = panel
    local sliderCorner = Instance.new("UICorner"); sliderCorner.CornerRadius = UDim.new(0, 10); sliderCorner.Parent = sliderBg

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new(aimSpeed, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0,200,160)
    sliderFill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 10); fillCorner.Parent = sliderFill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(aimSpeed, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner"); knobCorner.CornerRadius = UDim.new(1, 0); knobCorner.Parent = knob
    local knobGlow = Instance.new("UIStroke"); knobGlow.Thickness = 2; knobGlow.Color = Color3.fromRGB(0,200,160); knobGlow.Transparency = 0.4; knobGlow.Parent = knob

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size = UDim2.new(0, 260, 0, 18)
    sliderLabel.Position = UDim2.new(0, 18, 0, 172)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.TextColor3 = Color3.fromRGB(230,230,235)
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.TextSize = 14
    sliderLabel.Text = string.format("Aim Speed: %.2f", aimSpeed)
    sliderLabel.Parent = panel

    do
        local sliding = false
        local function setFromX(x)
            local absPos = sliderBg.AbsolutePosition.X
            local absSize = sliderBg.AbsoluteSize.X
            local t = math.clamp((x - absPos) / absSize, 0.05, 1.0)
            sliderFill.Size = UDim2.new(t, 0, 1, 0)
            knob.Position = UDim2.new(t, 0, 0.5, 0)
            aimSpeed = math.clamp(t, 0.05, 1.0)
            sliderLabel.Text = string.format("Aim Speed: %.2f", aimSpeed)
            tween(knobGlow, {Transparency = 0}, 0.12)
        end
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                setFromX(input.Position.X)
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        sliding = false
                        tween(knobGlow, {Transparency = 0.4}, 0.25)
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setFromX(input.Position.X)
            end
        end)
    end

    -- Dragging panel with saved position
    do
        local dragging = false
        local dragStart, startPos
        panel.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = panel.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        savedPosition = panel.Position
                        savePosition(savedPosition)
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                panel.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- ESP creation functions (use closures to access espEnabled/namesEnabled/healthEnabled)
    local function getOrCreateHighlight(player)
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        local existing = player.Character:FindFirstChild("ESPHighlight")
        if existing then return existing end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillColor = Color3.fromRGB(255, 60, 120)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0
        highlight.Enabled = espEnabled
        highlight.Parent = player.Character
        ESPRegistry[player] = ESPRegistry[player] or {}
        ESPRegistry[player].highlight = highlight
        return highlight
    end

    local function getOrCreateTracer(player)
        local pack = ESPRegistry[player]
        if pack and pack.tracer and pack.tracer.Parent then return pack.tracer end
        local line = Instance.new("Frame")
        line.Name = "Tracer"
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BackgroundColor3 = Color3.fromRGB(255, 120, 180)
        line.BorderSizePixel = 0
        line.Visible = espEnabled
        line.Size = UDim2.new(0, 2, 0, 2)
        line.Parent = tracerGui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(255, 120, 180)
        stroke.Transparency = 0.4
        stroke.Parent = line
        ESPRegistry[player] = ESPRegistry[player] or {}
        ESPRegistry[player].tracer = line
        return line
    end

    local function getOrCreateName(player)
        local pack = ESPRegistry[player]
        if pack and pack.nameLabel and pack.nameLabel.Parent then return pack.nameLabel end
        local label = Instance.new("TextLabel")
        label.Name = "NameLabel"
        label.Size = UDim2.new(0, 140, 0, 20)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.Font = Enum.Font.GothamSemibold
        label.TextScaled = true
        label.Text = player.Name
        label.Visible = espEnabled and namesEnabled
        label.Parent = tracerGui
        ESPRegistry[player] = ESPRegistry[player] or {}
        ESPRegistry[player].nameLabel = label
        return label
    end

    local function getOrCreateHealthBar(player)
        local pack = ESPRegistry[player]
        if pack and pack.healthBar and pack.healthBar.Parent then return pack.healthBar end
        local bar = Instance.new("Frame")
        bar.Name = "HealthBar"
        bar.Size = UDim2.new(0, 70, 0, 8)
        bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        bar.BorderSizePixel = 0
        bar.Visible = espEnabled and healthEnabled
        bar.Parent = tracerGui
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = bar
        local cornerFill = Instance.new("UICorner"); cornerFill.CornerRadius = UDim.new(0, 6); cornerFill.Parent = fill
        ESPRegistry[player] = ESPRegistry[player] or {}
        ESPRegistry[player].healthBar = bar
        ESPRegistry[player].healthFill = fill
        return bar
    end

    local function updateTracerLine(lineFrame, targetScreenPos)
        local screenSize = Camera.ViewportSize
        local startPos = Vector2.new(screenSize.X/2, screenSize.Y)
        local endPos = Vector2.new(targetScreenPos.X, targetScreenPos.Y)
        local delta = endPos - startPos
        local length = delta.Magnitude
        local angle = math.atan2(delta.Y, delta.X)
        local mid = (startPos + endPos)/2
        lineFrame.Position = UDim2.fromOffset(mid.X, mid.Y)
        lineFrame.Size = UDim2.fromOffset(length, 3)
        lineFrame.Rotation = math.deg(angle)
    end

    -- ESP lifecycle
    local function ensureESPFor(player)
        local function apply()
            if player.Character then
                getOrCreateHighlight(player)
                getOrCreateTracer(player)
                getOrCreateName(player)
                getOrCreateHealthBar(player)
            end
        end
        apply()
        player.CharacterAdded:Connect(function()
            task.wait(0.12)
            apply()
        end)
    end

    local function cleanupESPFor(player)
        local pack = ESPRegistry[player]
        if not pack then return end
        for _, obj in pairs(pack) do
            if typeof(obj) == "Instance" and obj.Parent then obj:Destroy() end
        end
        ESPRegistry[player] = nil
    end

    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then ensureESPFor(p) end end
    Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then ensureESPFor(p) end end)
    Players.PlayerRemoving:Connect(function(p) cleanupESPFor(p) end)

    -- Main loop
    RunService.RenderStepped:Connect(function()
        -- Aim lock
        if aimLockEnabled then
            local target = GetClosestPlayer and GetClosestPlayer() or nil
            -- fallback: inline GetClosestPlayer if not defined in outer scope
            if not target then
                local closest, bestDist = nil, math.huge
                local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local head = player.Character:FindFirstChild("Head")
                        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                        if head and humanoid and humanoid.Health > 0 then
                            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                            if onScreen then
                                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                                if dist < bestDist then
                                    bestDist = dist
                                    closest = player
                                end
                            end
                        end
                    end
                end
                target = closest
            end

            if target and target.Character then
                local head = target.Character:FindFirstChild("Head")
                local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
                if head and humanoid and humanoid.Health > 0 then
                    local desired = CFrame.new(Camera.CFrame.Position, head.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(desired, aimSpeed)
                end
            end
        end

        -- ESP updates
        if espEnabled then
            for player, pack in pairs(ESPRegistry) do
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if head and humanoid and humanoid.Health > 0 then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if pack.highlight then pack.highlight.Enabled = true end
                    if pack.tracer then
                        pack.tracer.Visible = onScreen
                        if onScreen then updateTracerLine(pack.tracer, screenPos) end
                    end
                    if pack.nameLabel then
                        pack.nameLabel.Visible = namesEnabled and onScreen
                        if onScreen then pack.nameLabel.Position = UDim2.fromOffset(screenPos.X - 70, screenPos.Y - 44) end
                    end
                    if pack.healthBar and pack.healthFill then
                        pack.healthBar.Visible = healthEnabled and onScreen
                        if onScreen then
                            local max = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
                            local ratio = math.clamp(humanoid.Health / max, 0, 1)
                            pack.healthFill.Size = UDim2.new(ratio, 0, 1, 0)
                            local r = math.floor(255 * (1 - ratio))
                            local g = math.floor(255 * ratio)
                            pack.healthFill.BackgroundColor3 = Color3.fromRGB(r, g, 0)
                            pack.healthBar.Position = UDim2.fromOffset(screenPos.X - 35, screenPos.Y - 28)
                        end
                    end
                else
                    if pack.highlight then pack.highlight.Enabled = false end
                    if pack.tracer then pack.tracer.Visible = false end
                    if pack.nameLabel then pack.nameLabel.Visible = false end
                    if pack.healthBar then pack.healthBar.Visible = false end
                end
            end
        else
            for _, pack in pairs(ESPRegistry) do
                if pack.highlight then pack.highlight.Enabled = false end
                if pack.tracer then pack.tracer.Visible = false end
                if pack.nameLabel then pack.nameLabel.Visible = false end
                if pack.healthBar then pack.healthBar.Visible = false end
            end
        end
    end)
end

------------------------------------------------
-- FLOW: show loading, then initialize UI
------------------------------------------------
ShowLoading()
task.delay(2, function()
    HideLoading(function()
        InitESPUI()
    end)
end)
