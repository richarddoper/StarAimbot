local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    if ok then
        WindUI = result
    else 
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end
end

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- // State Management
local States = {
    AimLock = false, TeamCheck = false, VisibleCheck = false, AimSpeed = 0.45, TargetPart = "Head",
    ShowFOV = false, FOVRadius = 150, FOVColor = Color3.fromRGB(255, 255, 255),
    ESP = false, Names = false, Tracers = false,
    ESPColor = Color3.fromRGB(255, 60, 120),
    TracerColor = Color3.fromRGB(0, 255, 0),
    WalkSpeed = 16, JumpPower = 50, FlyEnabled = false, FlySpeed = 50
}

local ESPRegistry = {}
local Tracers = {} 

------------------------------------------------
-- // CORE FUNCTIONS
------------------------------------------------

local function isVisible(part, character)
    local origin = Camera.CFrame.Position
    local destination = part.Position
    local direction = (destination - origin).Unit * (destination - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil 
end

local function createTracer(player)
    if player == LocalPlayer then return end
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Color = States.TracerColor
    line.Transparency = 1
    line.Visible = false
    Tracers[player] = line
end

local function setupESP(player)
    if player == LocalPlayer then return end
    local function onCharacter(char)
        if not char then return end
        local head = char:WaitForChild("Head", 10)
        local highlight = Instance.new("Highlight", char)
        highlight.FillColor = States.ESPColor
        local billboard = Instance.new("BillboardGui", CoreGui)
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 150, 0, 40)
        billboard.AlwaysOnTop = true
        local label = Instance.new("TextLabel", billboard)
        label.Size, label.BackgroundTransparency, label.TextColor3 = UDim2.new(1, 0, 1, 0), 1, Color3.new(1, 1, 1)
        label.Font, label.TextSize = Enum.Font.GothamBold, 13
        ESPRegistry[player] = { highlight = highlight, billboard = billboard, label = label }
    end
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then onCharacter(player.Character) end
end

------------------------------------------------
-- // INTERFACE CONSTRUCTION
------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "StarAimbot Revamped",
    Author = "GuyBoi",
    Folder = "staraimbot_v2",
    IconSize = 22,
    OpenButton = { Enabled = true, Draggable = true }
})

-- Standalone Tabs
local AimTab = Window:Tab({ Title = "Aim", Icon = "target" })
AimTab:Toggle({ Title = "Aim Lock", Callback = function(v) States.AimLock = v end })
AimTab:Toggle({ Title = "Visible Check", Callback = function(v) States.VisibleCheck = v end })
AimTab:Toggle({ Title = "Show FOV Circle", Callback = function(v) States.ShowFOV = v end })
AimTab:Toggle({ Title = "Team Check", Callback = function(v) States.TeamCheck = v end })

local AimSettingsTab = Window:Tab({ Title = "Aim Settings", Icon = "settings-2" })
AimSettingsTab:Slider({ Title = "Smoothing", Step = 0.01, Value = { Min = 0.05, Max = 1, Default = 0.45 }, Callback = function(v) States.AimSpeed = v end })
AimSettingsTab:Slider({ Title = "FOV Radius", Step = 1, Value = { Min = 10, Max = 800, Default = 150 }, Callback = function(v) States.FOVRadius = v end })
AimSettingsTab:Colorpicker({ Title = "Adjustment Radius Color", Default = States.FOVColor, Callback = function(color) States.FOVColor = color end })

local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisualsTab:Toggle({ Title = "Enable ESP", Callback = function(v) States.ESP = v end })
VisualsTab:Toggle({ Title = "Show Names", Callback = function(v) States.Names = v end })
VisualsTab:Toggle({ Title = "Show Tracers", Callback = function(v) States.Tracers = v end })

local VisualsSettingsTab = Window:Tab({ Title = "Visuals Settings", Icon = "palette" })
VisualsSettingsTab:Colorpicker({ Title = "ESP Color", Default = States.ESPColor, Callback = function(color) States.ESPColor = color end })
VisualsSettingsTab:Colorpicker({ Title = "Tracer Color", Default = States.TracerColor, Callback = function(color) States.TracerColor = color end })

-- Others Section (Player & Misc)
local OthersSection = Window:Section({ Title = "Others" })

local PlayerTab = OthersSection:Tab({ Title = "Player", Icon = "user" })
PlayerTab:Slider({ Title = "WalkSpeed", Step = 1, Value = { Min = 16, Max = 300, Default = 16 }, Callback = function(v) States.WalkSpeed = v end })
PlayerTab:Slider({ Title = "JumpPower", Step = 1, Value = { Min = 50, Max = 500, Default = 50 }, Callback = function(v) States.JumpPower = v end })
PlayerTab:Toggle({ Title = "Enable Fly", Callback = function(v) States.FlyEnabled = v end })

local MiscTab = OthersSection:Tab({ Title = "Misc", Icon = "box" })
local ConfigManager = Window.ConfigManager
local ConfigName = "default"

MiscTab:Input({ Title = "Config Name", Callback = function(v) ConfigName = v end })
MiscTab:Button({ Title = "Save Settings", Callback = function()
    Window.CurrentConfig = ConfigManager:Config(ConfigName)
    Window.CurrentConfig:Save()
    WindUI:Notify({Title = "Success", Content = "Config Saved"})
end })
MiscTab:Button({ Title = "Load Settings", Callback = function()
    Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
    Window.CurrentConfig:Load()
    WindUI:Notify({Title = "Success", Content = "Config Loaded"})
end })
MiscTab:Button({ Title = "Server Hop", Callback = function()
    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")).data
    for _, s in pairs(servers) do if s.playing < s.maxPlayers and s.id ~= game.JobId then TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id) end end
end })
MiscTab:Button({ Title = "Rejoin Server", Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })

------------------------------------------------
-- // FOV CIRCLE SYSTEM
------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "StarAimbot_Overlay"
ScreenGui.IgnoreGuiInset = true

local FOVFrame = Instance.new("Frame", ScreenGui)
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Visible = false

local UIStroke = Instance.new("UIStroke", FOVFrame)
UIStroke.Thickness = 2
UIStroke.Transparency = 0.4
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local UICorner = Instance.new("UICorner", FOVFrame)
UICorner.CornerRadius = UDim.new(1, 0)

------------------------------------------------
-- // RENDER LOOP
------------------------------------------------
local flyBody = Instance.new("BodyVelocity")
flyBody.MaxForce = Vector3.new(1, 1, 1) * math.huge

RunService.RenderStepped:Connect(function()
    local viewportSize = Camera.ViewportSize
    local screenCenter = viewportSize / 2
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    -- FOV
    FOVFrame.Visible = States.ShowFOV
    if States.ShowFOV then
        FOVFrame.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
        FOVFrame.Size = UDim2.fromOffset(States.FOVRadius * 2, States.FOVRadius * 2)
        UIStroke.Color = States.FOVColor
    end

    -- Character
    if hum then hum.WalkSpeed = States.WalkSpeed hum.JumpPower = States.JumpPower end
    if States.FlyEnabled and root then
        flyBody.Parent = root
        flyBody.Velocity = Camera.CFrame.LookVector * States.FlySpeed
    else flyBody.Parent = nil end

    -- Aim Assist Logic
    if States.AimLock then
        local target, minDistance = nil, States.FOVRadius
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(States.TargetPart) then
                if States.TeamCheck and p.Team == LocalPlayer.Team then continue end
                local targetPart = p.Character[States.TargetPart]
                if States.VisibleCheck and not isVisible(targetPart, p.Character) then continue end
                
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local magnitude = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if magnitude < minDistance then minDistance, target = magnitude, p end
                end
            end
        end
        if target then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Character[States.TargetPart].Position), States.AimSpeed)
        end
    end

    -- Visuals Rendering
    for player, line in pairs(Tracers) do
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and States.Tracers then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                line.Visible, line.From, line.To, line.Color = true, Vector2.new(viewportSize.X / 2, viewportSize.Y), Vector2.new(pos.X, pos.Y), States.TracerColor
            else line.Visible = false end
        else line.Visible = false end
    end

    for player, obj in pairs(ESPRegistry) do
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            obj.highlight.Enabled, obj.highlight.FillColor = States.ESP, States.ESPColor
            obj.billboard.Enabled, obj.label.Text = (States.ESP and States.Names), player.Name
        else obj.highlight.Enabled, obj.billboard.Enabled = false, false end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do createTracer(p) setupESP(p) end
Players.PlayerAdded:Connect(function(p) createTracer(p) setupESP(p) end)

WindUI:Notify({ Title = "staraimbot", Content = "Full Logic Restored", Icon = "check" })
