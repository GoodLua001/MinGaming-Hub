local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

_G.AutoFarm = true
_G.FastAttack = true

local remoteHit = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
local remoteQuest = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAccept")
local remoteTeleport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TeleportToPortal")

local MobConfig = {
    {Min = 0, Max = 99, Mob = "Thief", Island = "Starter"},
    {Min = 100, Max = 249, Mob = "Thief Boss", Island = "Starter"},
    {Min = 250, Max = 499, Mob = "Monkey", Island = "Jungle"},
    {Min = 500, Max = 749, Mob = "Monkey Boss", Island = "Jungle"},
    {Min = 750, Max = 999, Mob = "Desert Bandit", Island = "Desert"},
    {Min = 1000, Max = 1499, Mob = "Desert Boss", Island = "Desert"},
    {Min = 1500, Max = 1999, Mob = "Frost Rogue", Island = "Snow"},
    {Min = 2000, Max = 2999, Mob = "Winter Warden", Island = "Snow"},
    {Min = 3000, Max = 99999, Mob = "Sorcerer Student", Island = "Shibuya"}
}

local function getCurrentFarm()
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then return nil end
    local lvl = dataFolder:WaitForChild("Level").Value
    
    for _, v in pairs(MobConfig) do
        if lvl >= v.Min and lvl <= v.Max then
            return v
        end
    end
    return MobConfig[#MobConfig]
end

local function getBestQuest()
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then return nil end
    local lvl = dataFolder:WaitForChild("Level").Value
    
    local bestQuest, bestLvl = nil, -1
    local questConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestConfig"))
    
    for k, v in pairs(questConfig.RepeatableQuests or {}) do
        if type(k) == "string" and k:find("QuestNPC") and v.recommendedLevel and lvl >= v.recommendedLevel and v.recommendedLevel > bestLvl then
            bestQuest = {QuestID = k, Title = v.title, Data = v}
            bestLvl = v.recommendedLevel
        end
    end
    return bestQuest
end

local function getTargetMob(targetMobName)
    local npcFolder = workspace:FindFirstChild("NPCs")
    if not npcFolder or not targetMobName then return nil end

    local bestTarget = nil
    local closestDist = math.huge
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or Vector3.new(0,0,0)
    
    local tName = targetMobName:lower()

    for _, v in pairs(npcFolder:GetChildren()) do
        local humanoid = v:FindFirstChild("Humanoid")
        local root = v:FindFirstChild("HumanoidRootPart")
        
        if humanoid and root and humanoid.Health > 0 then
            local cleanMobName = v.Name:lower():gsub("%[.-%]", ""):gsub("^%s*(.-)%s*$", "%1")
            
            if cleanMobName == tName or cleanMobName:find(tName, 1, true) then
                local dist = (root.Position - myPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    bestTarget = v
                end
            end
        end
    end
    
    return bestTarget
end

local lastTeleportTime = 0 

task.spawn(function()
    while task.wait(3) do
        if _G.AutoFarm then
            pcall(function()
                local farmData = getCurrentFarm()
                if farmData then
                    local target = getTargetMob(farmData.Mob)
                    
                    if not target and (tick() - lastTeleportTime) > 15 then
                        lastTeleportTime = tick()
                        remoteTeleport:FireServer(farmData.Island)
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(2) do
        if _G.AutoFarm then
            pcall(function()
                local best = getBestQuest()
                if best and best.QuestID then
                    remoteQuest:FireServer(best.QuestID)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if _G.AutoFarm then
            pcall(function()
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local root = char.HumanoidRootPart
                    local farmData = getCurrentFarm()
                    
                    if farmData then
                        local target = getTargetMob(farmData.Mob)
                        
                        if target then
                            local flyPos = target.HumanoidRootPart.CFrame * CFrame.new(0, 2, 0)
                            root.CFrame = CFrame.lookAt(flyPos.Position, target.HumanoidRootPart.Position)
                            root.Velocity = Vector3.new(0, 0, 0)
                        else
                            root.Velocity = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoFarm and _G.FastAttack then
            pcall(function()
                local char = player.Character
                if char then
                    local tool = char:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                    if tool then
                        if tool.Parent ~= char then tool.Parent = char end
                        tool:Activate()
                        remoteHit:FireServer()
                    end
                end
            end)
        end
    end
end)
