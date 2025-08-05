-- Serviços Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Variáveis globais
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local aiming = false
local showMenu = false
local recoilOffset = Vector2.new(0, 0)

-- Configurações
local config = {
    espEnabled = true,
    aimbotEnabled = true,
    teamCheck = true,
    fov = 100,
    smoothness = 0.5,
    recoilControl = true,
    aimKey = Enum.UserInputType.MouseButton1,
    toggleMenuKey = Enum.KeyCode.RightShift
}

-- Drawing: FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Radius = config.fov
fovCircle.Filled = false
fovCircle.Transparency = 0.4
fovCircle.Visible = true

-- Estruturas para ESP
local skeletons = {}
local healthBars = {}
local healthTexts = {}
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

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Color = Color3.fromRGB(255, 0, 0)
    line.Visible = false
    return line
end

local function createSkeleton(player)
    skeletons[player] = {}
    for _ = 1, #bodyParts do
        table.insert(skeletons[player], createLine())
    end
    if not healthBars[player] then
        local bar = Drawing.new("Line")
        bar.Thickness = 4
        bar.Color = Color3.fromRGB(0, 255, 0)
        bar.Visible = false
        healthBars[player] = bar
    end
    if not healthTexts[player] then
        local txt = Drawing.new("Text")
        txt.Size = 14
        txt.Color = Color3.fromRGB(255,255,255)
        txt.Outline = true
        txt.Center = true
        txt.Visible = false
        healthTexts[player] = txt
    end
end

local function removeSkeleton(player)
    if skeletons[player] then
        for _, line in ipairs(skeletons[player]) do
            line:Remove()
        end
        skeletons[player] = nil
    end
    if healthBars[player] then
        healthBars[player]:Remove()
        healthBars[player] = nil
    end
    if healthTexts[player] then
        healthTexts[player]:Remove()
        healthTexts[player] = nil
    end
end

local function updateSkeleton(player)
    local char = player.Character
    if not char then return end

    if not skeletons[player] then
        createSkeleton(player)
    end

    local lines = skeletons[player]
    local visible = config.espEnabled
        and player.Team ~= localPlayer.Team
        and char:FindFirstChild("Humanoid")
        and char.Humanoid.Health > 0

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

    local humanoid = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    if humanoid and head and healthBars[player] and healthTexts[player] then
        local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local headPos, onScreen = camera:WorldToViewportPoint(head.Position)
        if visible and onScreen then
            local barLength = 40
            local startPos = Vector2.new(headPos.X - barLength/2, headPos.Y - 30)
            local endPos = Vector2.new(startPos.X + barLength * health, startPos.Y)
            healthBars[player].From = startPos
            healthBars[player].To = endPos
            healthBars[player].Color = Color3.fromRGB(255 * (1-health), 255 * health, 0)
            healthBars[player].Visible = true

            healthTexts[player].Text = string.format("%d / %d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
            healthTexts[player].Position = Vector2.new(headPos.X, startPos.Y - 12)
            healthTexts[player].Visible = true
        else
            healthBars[player].Visible = false
            healthTexts[player].Visible = false
        end
    elseif healthBars[player] and healthTexts[player] then
        healthBars[player].Visible = false
        healthTexts[player].Visible = false
    end
end

-- Aimbot: Seleção do alvo mais próximo
local function getClosestTarget()
    local closest, shortestDist = nil, config.fov
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer
            and player.Character
            and player.Character:FindFirstChild("Head")
            and player.Character:FindFirstChild("Humanoid")
        then
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

-- Aimbot: Função de mira (recoil 100% compensado)
local function aimAt(target)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end

    local screenPos = camera:WorldToViewportPoint(head.Position)
    local mousePos = UserInputService:GetMouseLocation()
    local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos

    -- Compensação total do recoil (tiros sempre retos)
    if config.recoilControl then
        delta = delta - recoilOffset
    end

    local move = delta * config.smoothness
    mousemoverel(move.X, move.Y)

    -- Zera o recoil após cada tiro
    if config.recoilControl then
        recoilOffset = Vector2.new(0, 0)
    end
end

-- Menu Drawing
local menuOptions = {
    {name = "Aimbot", key = "aimbotEnabled"},
    {name = "ESP", key = "espEnabled"},
    {name = "Team Check", key = "teamCheck"},
    {name = "Recoil Control", key = "recoilControl"},
}
local menuDrawings = {}
local menuBaseY, menuSpacing = 100, 25

local function updateMenu()
    for i, opt in ipairs(menuOptions) do
        if not menuDrawings[i] then
            menuDrawings[i] = Drawing.new("Text")
            menuDrawings[i].Size = 18
            menuDrawings[i].Outline = true
        end
        menuDrawings[i].Visible = showMenu
        menuDrawings[i].Position = Vector2.new(50, menuBaseY + (i-1)*menuSpacing)
        menuDrawings[i].Color = config[opt.key] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        menuDrawings[i].Text = string.format("[%d] %s: %s", i, opt.name, config[opt.key] and "ON" or "OFF")
    end
end

local function toggleOption(index)
    local opt = menuOptions[index]
    if opt and config[opt.key] ~= nil then
        config[opt.key] = not config[opt.key]
    end
end

-- Eventos de Input
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == config.toggleMenuKey then
        showMenu = not showMenu
        updateMenu()
    end

    -- Atalhos para alternar opções do menu (teclas 1-4)
    if showMenu and input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Four.Value then
        local idx = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
        toggleOption(idx)
        updateMenu()
    end

    if input.UserInputType == config.aimKey then
        aiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == config.aimKey then
        aiming = false
        recoilOffset = Vector2.new(0, 0)
    end
end)

-- Gerenciamento de jogadores
local characterCleanupConnections = {}

local function setupCharacterCleanup(player)
    -- Remove conexões antigas
    if characterCleanupConnections[player] then
        characterCleanupConnections[player]:Disconnect()
        characterCleanupConnections[player] = nil
    end

    -- Conecta cleanup para o personagem atual
    if player.Character then
        removeSkeleton(player)
        characterCleanupConnections[player] = player.CharacterRemoving:Connect(function()
            removeSkeleton(player)
        end)
    end

    -- Sempre conecta para futuros personagens
    player.CharacterAdded:Connect(function()
        removeSkeleton(player) -- Remove qualquer desenho antigo antes de criar novo
        createSkeleton(player)
        -- Remove conexão antiga e conecta nova
        if characterCleanupConnections[player] then
            characterCleanupConnections[player]:Disconnect()
        end
        characterCleanupConnections[player] = player.CharacterRemoving:Connect(function()
            removeSkeleton(player)
        end)
    end)
end

Players.PlayerAdded:Connect(setupCharacterCleanup)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createSkeleton(player)
        setupCharacterCleanup(player)
    end
end

Players.PlayerRemoving:Connect(function(player)
    removeSkeleton(player)
    if characterCleanupConnections[player] then
        characterCleanupConnections[player]:Disconnect()
        characterCleanupConnections[player] = nil
    end
end)

-- Loop principal
RunService.RenderStepped:Connect(function()
    if not localPlayer or not camera then return end

    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = config.fov
    fovCircle.Visible = config.aimbotEnabled

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            updateSkeleton(player)
        end
    end

    if aiming and config.aimbotEnabled then
        local target = getClosestTarget()
        if target then
            aimAt(target)
        end
    end

    updateMenu()
end)
