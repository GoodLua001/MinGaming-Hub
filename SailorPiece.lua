local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
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
    local p2 = pos(b) or pos(game.Players.LocalPlayer.Character)
    return (p1 and p2) and (p1 - p2).Magnitude or math.huge
end

function AddVelocity()
    local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and not root:FindFirstChild("3TOC") then
        local body = Instance.new("BodyVelocity")
        body.Name = "3TOC"
        body.Parent = root
        body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        body.Velocity = Vector3.new(0, 0, 0)
    end
end

local TweenService = game:GetService("TweenService")

function TP(pos)
    local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
    local player = game.Players.LocalPlayer
    local char = player.Character
    if char then
        local currentWeapon = char:FindFirstChild(_G.SelectWeapon) or char:FindFirstChildOfClass("Tool")
        if currentWeapon then return end 
        
        local backpack = player:FindFirstChild("Backpack")
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
    local modulePath = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 5) and game:GetService("ReplicatedStorage").Modules:FindFirstChild("QuestConfig")
    if not modulePath then return nil end
    local module = require(modulePath)
    local playerLvl = game.Players.LocalPlayer.Data.Level.Value
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
    if not workspace:FindFirstChild("NPCs") then return currentMobs end
    for _, npc in ipairs(workspace.NPCs:GetChildren()) do
        if (npc.Name:match("^"..mobName.."%d+$") or npc.Name == mobName) and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 and npc:FindFirstChild("HumanoidRootPart") then
            table.insert(currentMobs, npc)
        end
    end
    return currentMobs
end

spawn(function()
    while task.wait() do
        local player = game:GetService("Players").LocalPlayer
        local char = player.Character
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
            
            local playerGui = player:WaitForChild("PlayerGui")
            
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
                            local flyPos = pos + Vector3.new(math.cos(orbitAngle) * radius, 10, math.sin(orbitAngle) * radius)
                            
                            local targetCFrame = CFrame.lookAt(flyPos, pos)
                            
                            TP(targetCFrame)
                            game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                        until MobInstance.Humanoid.Health <= 0 or not playerGui.QuestUI.Quest.Visible or playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= Best_Quest.namequest
                        
                        if mHrp then mHrp.Anchored = false end
                    end
                else
                    hum.AutoRotate = true
                    hum.PlatformStand = false
                    local npc = workspace.ServiceNPCs:FindFirstChild(Best_Quest.quest)
                    if npc then TP(npc:GetPivot() * CFrame.new(0, 0, 3)) end
                end
            elseif playerGui.QuestUI.Quest.Visible then
                hum.AutoRotate = true
                hum.PlatformStand = false
                game:GetService("ReplicatedStorage").RemoteEvents.QuestAbandon:FireServer("repeatable")
            else
                hum.AutoRotate = true
                hum.PlatformStand = false
                local npc = workspace.ServiceNPCs:FindFirstChild(Best_Quest.quest)
                if npc then
                    local targetPos = npc:GetPivot() * CFrame.new(0, 0, 3)
                    TP(targetPos)
                    if GetDistance(targetPos.Position) <= 10 then
                        game:GetService("ReplicatedStorage").RemoteEvents.QuestAccept:FireServer(Best_Quest.quest)
                    end
                end
            end
        end)
    end
end)

spawn(function()
    while task.wait(1) do
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local statPointsValue = player.Data:FindFirstChild("StatPoints")
            if not statPointsValue then return end
            
            local statPoints = statPointsValue.Value
            
            if statPoints > 0 then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")
                
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

spawn(function()
    local abilityRemote = game:GetService("ReplicatedStorage"):WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
    while task.wait(0.5) do
        pcall(function()
            local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui and playerGui:FindFirstChild("QuestUI") and playerGui.QuestUI.Quest.Visible then
                abilityRemote:FireServer(1)
                task.wait(0.1)
                abilityRemote:FireServer(2)
            end
        end)
    end
end)
