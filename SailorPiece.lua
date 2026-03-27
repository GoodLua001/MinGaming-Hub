local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

local RequestHit = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

_G.SelectWeapon = "Sword"

function GetDistance(a, b)
    local function pos(t)
        if typeof(t) == "Vector3" then return t end
        if typeof(t) == "CFrame" then return t.Position end
        if typeof(t) == "Instance" then
            if t:IsA("BasePart") then return t.Position end
            local hrp = t:FindFirstChild("HumanoidRootPart")
            return hrp and hrp.Position or (pcall(t.GetPivot, t) and t:GetPivot().Position)
        end
    end
    local p1 = pos(a)
    local p2 = pos(b) or pos(LocalPlayer.Character)
    return (p1 and p2) and (p1 - p2).Magnitude or math.huge
end

function AddVelocity()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and not root:FindFirstChild("3TOC") then
        local body = Instance.new("BodyVelocity")
        body.Name = "3TOC"
        body.Parent = root
        body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        body.Velocity = Vector3.new(0, 0, 0)
    end
end

function TP(pos)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local target = typeof(pos) == "CFrame" and pos or CFrame.new(pos.X, pos.Y, pos.Z)
    local distance = (root.Position - target.Position).Magnitude
    
    if distance < 3 then
        AddVelocity()
        root.CFrame = target
        return
    end
    
    local time = distance / 180
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    AddVelocity()
    TweenService:Create(root, tweenInfo, {CFrame = target}):Play()
end

function AutoEquip()
    local char = LocalPlayer.Character
    if char then
        local currentWeapon = char:FindFirstChild(_G.SelectWeapon) or char:FindFirstChildOfClass("Tool")
        if currentWeapon then return end 
        
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            local tool = backpack:FindFirstChild(_G.SelectWeapon) or backpack:FindFirstChildOfClass("Tool")
            if tool then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:EquipTool(tool)
                    if tool.Parent ~= char then
                        tool.Parent = char
                    end
                end
            end
        end
    end
end

local function getBestQuest()
    local modulePath = ReplicatedStorage:WaitForChild("Modules", 5) and ReplicatedStorage.Modules:FindFirstChild("QuestConfig")
    if not modulePath then return nil end
    local module = require(modulePath)
    local playerLvl = LocalPlayer.Data.Level.Value
    local bestQuest, bestLevel = nil, -math.huge
    for name, data in pairs(module.RepeatableQuests or {}) do
        if type(name) == "string" and name:find("QuestNPC") then
            if data.recommendedLevel and data.requirements and data.requirements[1] then
                local reqLvl = data.recommendedLevel
                if playerLvl >= reqLvl and reqLvl > bestLevel then
                    bestLevel = reqLvl
                    bestQuest = {quest = name, namequest = data.title, npc = data.requirements[1].npcType}
                end
            end
        end
    end
    return bestQuest
end

local function getCurrentMobs(mobName)
    local currentMobs = {}
    if not Workspace:FindFirstChild("NPCs") then return currentMobs end
    for _, npc in ipairs(Workspace.NPCs:GetChildren()) do
        if (npc.Name:match("^"..mobName.."%d+$") or npc.Name == mobName) and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 and npc:FindFirstChild("HumanoidRootPart") then
            table.insert(currentMobs, npc)
        end
    end
    return currentMobs
end

task.spawn(function()
    while task.wait() do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        pcall(function()
            if not hrp or not hum then return end
            local Best_Quest = getBestQuest()
            if not Best_Quest then 
                hum.AutoRotate = true 
                hum.PlatformStand = false
                return 
            end
            
            local playerGui = LocalPlayer:WaitForChild("PlayerGui")
            
            if playerGui.QuestUI.Quest.Visible and playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text == Best_Quest.namequest then
                local allMobs = getCurrentMobs(Best_Quest.npc)
                
                local MobInstance = nil
                local closestDist = math.huge
                
                for _, m in ipairs(allMobs) do
                    local dist = GetDistance(m:GetPivot().Position, hrp.Position)
                    if dist < closestDist then
                        closestDist = dist
                        MobInstance = m
                    end
                end

                if MobInstance then
                    hum.AutoRotate = false 
                    hum.PlatformStand = true 
                    
                    local mHrp = MobInstance:FindFirstChild("HumanoidRootPart")
                    
                    if mHrp then
                        mHrp.Anchored = true 
                        
                        local orbitAngle = 0 
                        
                        repeat task.wait()
                            if not MobInstance.Parent or MobInstance.Humanoid.Health <= 0 then break end
                            
                            AutoEquip()
                            
                            local pos = mHrp.Position
                            orbitAngle = orbitAngle + math.rad(5) 
                            local radius = 5 
                            local flyPos = pos + Vector3.new(math.cos(orbitAngle) * radius, 35, math.sin(orbitAngle) * radius)
                            
                            local targetCFrame = CFrame.lookAt(flyPos, pos)
                            
                            TP(targetCFrame)
                        until MobInstance.Humanoid.Health <= 0 or not playerGui.QuestUI.Quest.Visible or playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= Best_Quest.namequest
                        
                        if mHrp then mHrp.Anchored = false end
                    end
                else
                    hum.AutoRotate = true
                    hum.PlatformStand = false
                    local npc = Workspace.ServiceNPCs:FindFirstChild(Best_Quest.quest)
                    if npc then TP(npc:GetPivot() * CFrame.new(0, 0, 3)) end
                end
            elseif playerGui.QuestUI.Quest.Visible then
                hum.AutoRotate = true
                hum.PlatformStand = false
                ReplicatedStorage.RemoteEvents.QuestAbandon:FireServer("repeatable")
            else
                hum.AutoRotate = true
                hum.PlatformStand = false
                local npc = Workspace.ServiceNPCs:FindFirstChild(Best_Quest.quest)
                if npc then
                    local targetPos = npc:GetPivot() * CFrame.new(0, 0, 3)
                    TP(targetPos)
                    if GetDistance(targetPos.Position) <= 10 then
                        ReplicatedStorage.RemoteEvents.QuestAccept:FireServer(Best_Quest.quest)
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local statPointsValue = LocalPlayer.Data:FindFirstChild("StatPoints")
            if not statPointsValue then return end
            
            local statPoints = statPointsValue.Value
            
            if statPoints > 0 then
                local remote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")
                
                if statPoints >= 2 then
                    local pointsToAdd = math.floor(statPoints / 2)
                    local remainder = statPoints % 2
                    remote:FireServer("Defense", pointsToAdd)
                    remote:FireServer("Sword", pointsToAdd + remainder)
                else
                    remote:FireServer("Sword", 1)
                end
            end
        end)
    end
end)

local function getNearestTarget()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local npcFolder = Workspace:FindFirstChild("NPCs")
    if not npcFolder then return end
    local closest, closestDist
    for _, npc in pairs(npcFolder:GetChildren()) do
        local primary = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
        local humanoid = npc:FindFirstChild("Humanoid")
        if primary and humanoid and humanoid.Health > 0 then
            local dist = (primary.Position - hrp.Position).Magnitude
            if not closestDist or dist < closestDist then
                closestDist = dist
                closest = primary
            end
        end
    end
    return closest
end

task.spawn(function()
    while task.wait(0.1) do
        local target = getNearestTarget()
        if target then
            pcall(function()
                RequestHit:FireServer(target.Position)
            end)
        end
    end
end)
