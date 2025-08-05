-- Serviços e variáveis
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local aiming = false
local showMenu = false
local recoilOffset = Vector2.new(0, 0)

-- Configurações do Aimbot
local config = {
    espEnabled = true,
    aimbotEnabled = true,
    teamCheck = true,
    fov = 100,
    smoothness = 0.5, -- Aumentar para deixar o aimbot mais agressivo
    recoilControl = true,
    aimKey = Enum.UserInputType.MouseButton1, -- Alterar o botao de acao do aimbot
    toggleMenuKey = Enum.KeyCode.RightShift -- Alterar a tecla para abrir/fechar o menu (Sem menu ainda, mas pode ser implementado futuramente)
}

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Radius = config.fov
fovCircle.Filled = false
fovCircle.Transparency = 0.4
fovCircle.Visible = true

local skeletons = {}

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Color = Color3.fromRGB(255, 0, 0)
    line.Visible = false
    return line
end

local bodyParts = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
}

local function createSkeleton(player)
    skeletons[player] = {}
    for _, _ in pairs(bodyParts) do
        table.insert(skeletons[player], createLine())
    end
end

local function updateSkeleton(player)
    local char = player.Character
    if not char then return end

    if not skeletons[player] then
        createSkeleton(player)
    end

    local lines = skeletons[player]
    local visible = config.espEnabled and player.Team ~= localPlayer.Team and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0

    for i, pair in ipairs(bodyParts) do
        local p1 = char:FindFirstChild(pair[1])
        local p2 = char:FindFirstChild(pair[2])
        if p1 and p2 then
            local pos1, vis1 = camera:WorldToViewportPoint(p1.Position)
            local pos2, vis2 = camera:WorldToViewportPoint(p2.Position)

            lines[i].From = Vector2.new(pos1.X, pos1.Y)
            lines[i].To = Vector2.new(pos2.X, pos2.Y)
            lines[i].Visible = visible and vis1 and vis2
        else
            lines[i].Visible = false
        end
    end
end

-- Configuracão do Aimbot 
local function getClosestTarget()
    local closest = nil
    local shortestDist = config.fov

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("Humanoid") then
            if config.teamCheck and player.Team == localPlayer.Team then continue end

            if player.Character.Humanoid.Health <= 0 then continue end

            local head = player.Character.Head
            local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
            if not onScreen then continue end

            local mousePos = UserInputService:GetMouseLocation()
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

            if dist < shortestDist then
                shortestDist = dist
                closest = player
            end
        end
    end

    return closest
end

local function aimAt(target)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end

    local screenPos = camera:WorldToViewportPoint(head.Position)
    local mousePos = UserInputService:GetMouseLocation()
    local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos

    if config.recoilControl then
        delta = delta - (recoilOffset * 0.5)
    end

    local move = delta * config.smoothness
    mousemoverel(move.X, move.Y)

    if config.recoilControl then
        recoilOffset = recoilOffset + (move * 0.2)
    end
end

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == config.aimKey then
        aiming = false
        recoilOffset = Vector2.new(0, 0)
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == config.toggleMenuKey then
        showMenu = not showMenu
        print("Menu " .. (showMenu and "ON" or "OFF"))
    end

    if input.UserInputType == config.aimKey then
        aiming = true
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if skeletons[player] then
        for _, line in ipairs(skeletons[player]) do
            line:Remove()
        end
        skeletons[player] = nil
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        createSkeleton(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createSkeleton(player)
    end
end

RunService.RenderStepped:Connect(function()
    if not localPlayer or not camera then return end

    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = config.fov
    fovCircle.Visible = config.aimbotEnabled

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updateSkeleton(player)
        end
    end

    if aiming and config.aimbotEnabled then
        local target = getClosestTarget()
        if target then
            aimAt(target)
        end
    end
end)