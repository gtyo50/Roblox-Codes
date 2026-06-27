local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

Players.CharacterAutoLoads = false

local remotes = ReplicatedStorage:FindFirstChild("RPGRemotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "RPGRemotes"
    remotes.Parent = ReplicatedStorage
end

local STAT_NAMES = {
    "Health",
    "Mana",
    "Strength",
    "Magic",
    "Defense",
    "Speed",
    "Crit",
    "Regeneration",
    "FireResistance",
    "ExperienceGain",
    "Stealth",
}

local DEFAULT_STATS = {
    Health = 100,
    Mana = 50,
    Strength = 10,
    Magic = 10,
    Defense = 10,
    Speed = 10,
    Crit = 5,
    Regeneration = 0,
    FireResistance = 0,
    ExperienceGain = 0,
    Stealth = 0,
}

local WALK_SPEED = 12.5
local SPRINT_SPEED = 26
local SPRINT_SPEED_BLEND_TIME = 0.28

local RACE_BODY_COLORS = {
    Dragon = Color3.fromRGB(184, 38, 28),
    Dwarf = Color3.fromRGB(214, 118, 36),
    Human = Color3.fromRGB(226, 194, 148),
    Spirit = Color3.fromRGB(245, 245, 245),
    Elf = Color3.fromRGB(167, 214, 153),
}

local RACE_TEXT_COLORS = {
    Dragon = Color3.fromRGB(255, 108, 88),
    Dwarf = Color3.fromRGB(255, 169, 82),
    Human = Color3.fromRGB(244, 211, 124),
    Spirit = Color3.fromRGB(255, 255, 255),
    Elf = Color3.fromRGB(179, 255, 170),
}

local spawnLoadedCharacter = remotes:FindFirstChild("SpawnLoadedCharacter")
if spawnLoadedCharacter and not spawnLoadedCharacter:IsA("RemoteFunction") then
    spawnLoadedCharacter:Destroy()
    spawnLoadedCharacter = nil
end

if not spawnLoadedCharacter then
    spawnLoadedCharacter = Instance.new("RemoteFunction")
    spawnLoadedCharacter.Name = "SpawnLoadedCharacter"
    spawnLoadedCharacter.Parent = remotes
end

local setSprintState = remotes:FindFirstChild("SetSprintState")
local sprintTweens = {}
local sprintTweenTokens = {}
if setSprintState and not setSprintState:IsA("RemoteEvent") then
    setSprintState:Destroy()
    setSprintState = nil
end

if not setSprintState then
    setSprintState = Instance.new("RemoteEvent")
    setSprintState.Name = "SetSprintState"
    setSprintState.Parent = remotes
end

local function ensureWorldSpawn()
    local spawnPart = Workspace:FindFirstChild("RPGWorldSpawn")
    if spawnPart and spawnPart:IsA("BasePart") then
        return spawnPart
    end

    if spawnPart then
        spawnPart:Destroy()
    end

    local baseplate = Workspace:FindFirstChild("Baseplate")
    local spawnPosition = Vector3.new(0, 4, 0)
    if baseplate and baseplate:IsA("BasePart") then
        spawnPosition = baseplate.Position + Vector3.new(0, (baseplate.Size.Y / 2) + 4, 0)
    end

    spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "RPGWorldSpawn"
    spawnPart.Anchored = true
    spawnPart.CanCollide = false
    spawnPart.CanTouch = false
    spawnPart.CanQuery = false
    spawnPart.Enabled = false
    spawnPart.Neutral = true
    spawnPart.Transparency = 1
    spawnPart.Size = Vector3.new(8, 1, 8)
    spawnPart.Position = spawnPosition
    spawnPart.Parent = Workspace

    return spawnPart
end

local function getPlayerStat(player, statName)
    return tonumber(player:GetAttribute(statName)) or tonumber(player:GetAttribute("RPGStat" .. statName)) or DEFAULT_STATS[statName] or 0
end

local function getLoadedStats(player)
    local stats = {}
    for _, statName in ipairs(STAT_NAMES) do
        stats[statName] = getPlayerStat(player, statName)
    end
    return stats
end

local function setStatFolder(parent, stats)
    local folder = parent:FindFirstChild("RPGStats")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RPGStats"
        folder.Parent = parent
    end

    for _, statName in ipairs(STAT_NAMES) do
        local valueObject = folder:FindFirstChild(statName)
        if not valueObject then
            valueObject = Instance.new("NumberValue")
            valueObject.Name = statName
            valueObject.Parent = folder
        end

        valueObject.Value = stats[statName]
    end

    return folder
end

local function calculateWalkSpeed(_speedStat)
    return WALK_SPEED
end

local function calculateSprintSpeed(_speedStat)
    return SPRINT_SPEED
end

local function getRaceBodyColor(raceName)
    return RACE_BODY_COLORS[tostring(raceName or "")] or RACE_BODY_COLORS.Human
end

local function getRaceTextColor(raceName)
    return RACE_TEXT_COLORS[tostring(raceName or "")] or RACE_TEXT_COLORS.Human
end

local function applyRaceColor(character, raceName)
    local color = getRaceBodyColor(raceName)
    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if not bodyColors then
        bodyColors = Instance.new("BodyColors")
        bodyColors.Name = "Body Colors"
        bodyColors.Parent = character
    end

    bodyColors.HeadColor3 = color
    bodyColors.LeftArmColor3 = color
    bodyColors.RightArmColor3 = color
    bodyColors.LeftLegColor3 = color
    bodyColors.RightLegColor3 = color
    bodyColors.TorsoColor3 = color

    for _, partName in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            part.Color = color
        end
    end
end

local function makeNameText(parent, name, text, position, color, textSize, font)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = UDim2.new(1, 0, 0, textSize + 4)
    label.Font = font
    label.Text = text
    label.TextColor3 = color
    label.TextSize = textSize
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.25
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function applyNameplate(character, characterName, className, level, raceName)
    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then
        return
    end

    local oldNameplate = head:FindFirstChild("RPGNameplate")
    if oldNameplate then
        oldNameplate:Destroy()
    end

    local nameplate = Instance.new("BillboardGui")
    nameplate.Name = "RPGNameplate"
    nameplate.Adornee = head
    nameplate.AlwaysOnTop = true
    nameplate.MaxDistance = 120
    nameplate.Size = UDim2.fromOffset(190, 74)
    nameplate.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
    nameplate.Parent = head

    local frame = Instance.new("Frame")
    frame.Name = "TextFrame"
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1, 1)
    frame.Parent = nameplate

    local raceColor = getRaceTextColor(raceName)
    makeNameText(frame, "NameLabel", tostring(characterName or "Adventurer"), UDim2.fromOffset(0, 0), raceColor, 18, Enum.Font.GothamBold)
    makeNameText(frame, "ClassLabel", tostring(className or "Class"), UDim2.fromOffset(0, 24), Color3.fromRGB(232, 230, 218), 14, Enum.Font.GothamSemibold)
    makeNameText(frame, "LevelLabel", "Level " .. tostring(level or 1), UDim2.fromOffset(0, 44), Color3.fromRGB(203, 196, 174), 13, Enum.Font.Gotham)
end

local function applyRPGStatsToCharacter(player, character, humanoid)
    local stats = getLoadedStats(player)
    local characterName = player:GetAttribute("RPGCharacterName")
    local raceName = player:GetAttribute("RPGCharacterRace")
    local className = player:GetAttribute("RPGCharacterClass")
    local level = player:GetAttribute("RPGCharacterLevel") or player:GetAttribute("Level") or 1
    local money = player:GetAttribute("RPGCharacterMoney") or player:GetAttribute("Money") or 0

    character:SetAttribute("CharacterName", characterName)
    character:SetAttribute("Race", raceName)
    character:SetAttribute("Class", className)
    character:SetAttribute("Level", level)
    character:SetAttribute("Money", money)
    character:SetAttribute("RPGCharacterName", characterName)
    character:SetAttribute("RPGCharacterRace", raceName)
    character:SetAttribute("RPGCharacterClass", className)
    character:SetAttribute("RPGCharacterLevel", level)
    character:SetAttribute("RPGCharacterMoney", money)

    for _, statName in ipairs(STAT_NAMES) do
        character:SetAttribute(statName, stats[statName])
        character:SetAttribute("RPGStat" .. statName, stats[statName])
    end

    setStatFolder(player, stats)
    setStatFolder(character, stats)
    applyRaceColor(character, raceName)
    applyNameplate(character, characterName, className, level, raceName)

    if humanoid then
        if characterName then
            humanoid.DisplayName = characterName
        end

        local walkSpeed = calculateWalkSpeed(stats.Speed)
        local sprintSpeed = calculateSprintSpeed(stats.Speed)

        humanoid.MaxHealth = math.max(1, stats.Health)
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = walkSpeed
        humanoid:SetAttribute("RPGBaseWalkSpeed", walkSpeed)
        humanoid:SetAttribute("RPGSprintWalkSpeed", sprintSpeed)
        humanoid:SetAttribute("RPGIsSprinting", false)
        character:SetAttribute("RPGBaseWalkSpeed", walkSpeed)
        character:SetAttribute("RPGSprintWalkSpeed", sprintSpeed)
        character:SetAttribute("RPGIsSprinting", false)
    end
end

local function placeCharacterAtSpawn(player, character)
    local spawnPart = ensureWorldSpawn()
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)

    applyRPGStatsToCharacter(player, character, humanoid)

    if rootPart then
        character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
    end
end

local function setPlayerSprintState(player, shouldSprint)
    if not player:GetAttribute("RPGCharacterLoaded") then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    local walkSpeed = tonumber(humanoid:GetAttribute("RPGBaseWalkSpeed")) or WALK_SPEED
    local sprintSpeed = tonumber(humanoid:GetAttribute("RPGSprintWalkSpeed")) or SPRINT_SPEED
    local isSprinting = shouldSprint == true
    local targetSpeed = isSprinting and sprintSpeed or walkSpeed

    if sprintTweens[player] then
        sprintTweens[player]:Cancel()
        sprintTweens[player] = nil
    end

    sprintTweenTokens[player] = (sprintTweenTokens[player] or 0) + 1
    local token = sprintTweenTokens[player]

    humanoid:SetAttribute("RPGIsSprinting", isSprinting)
    character:SetAttribute("RPGIsSprinting", isSprinting)

    local tween = TweenService:Create(
        humanoid,
        TweenInfo.new(SPRINT_SPEED_BLEND_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { WalkSpeed = targetSpeed }
    )
    sprintTweens[player] = tween
    tween:Play()

    task.delay(SPRINT_SPEED_BLEND_TIME + 0.05, function()
        if sprintTweenTokens[player] ~= token then
            return
        end

        if humanoid.Parent and humanoid.Health > 0 then
            humanoid.WalkSpeed = targetSpeed
        end

        if sprintTweens[player] == tween then
            sprintTweens[player] = nil
        end
    end)
end

local function removeMenuCharacter(player, character)
    if player:GetAttribute("RPGCharacterLoaded") then
        return
    end

    task.defer(function()
        if character and character.Parent then
            character:Destroy()
        end
    end)
end

local function setupPlayer(player)
    if player:GetAttribute("RPGCharacterLoaded") == nil then
        player:SetAttribute("RPGCharacterLoaded", false)
    end

    player.CharacterAdded:Connect(function(character)
        if player:GetAttribute("RPGCharacterLoaded") then
            placeCharacterAtSpawn(player, character)
        else
            removeMenuCharacter(player, character)
        end
    end)

    if player.Character then
        removeMenuCharacter(player, player.Character)
    end
end

setSprintState.OnServerEvent:Connect(function(player, shouldSprint)
    setPlayerSprintState(player, shouldSprint)
end)

spawnLoadedCharacter.OnServerInvoke = function(player)
    if not player:GetAttribute("RPGCharacterLoaded") then
        return { Success = false, Message = "Choose and load a character first." }
    end

    local characterName = player:GetAttribute("RPGCharacterName")
    if not characterName then
        return { Success = false, Message = "Loaded character data is missing." }
    end

    player:LoadCharacter()

    local character = player.Character or player.CharacterAdded:Wait()
    placeCharacterAtSpawn(player, character)

    print(string.format("RPGSpawnController: Spawned %s for %s.", tostring(characterName), player.Name))

    return {
        Success = true,
        Message = "Spawned " .. tostring(characterName) .. ".",
    }
end

ensureWorldSpawn()
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
    if sprintTweens[player] then
        sprintTweens[player]:Cancel()
        sprintTweens[player] = nil
    end
    sprintTweenTokens[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
