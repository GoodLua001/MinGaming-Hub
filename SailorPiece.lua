_G.Config = {
    AutoFarm = true,
    BringMobs = true,
    AutoStats = true,
    FarmHeight = 6,
    BringDistance = 4,
    TeleportSpeed = 200
}

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
    
    local time = distance / _G.Config.TeleportSpeed
    if time < 0.05 then time = 0.05 end
    
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    
    AddVelocity()
    local tween = TweenService:Create(root, tweenInfo, {CFrame = target})
    tween:Play()
    return tween
end

local function getBestQuest()
    local modulePath = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 5) and game:GetService("ReplicatedStorage").Modules:FindFirstChild("QuestConfig")
    if not modulePath then return nil end
    local module = require(modulePath)
    local playerLvl = game.Players.LocalPlayer.Data.Level.Value

    local bestQuest = nil
    local bestLevel = -math.huge

    for name, data in pairs(module.RepeatableQuests or {}) do
        if type(name) == "string" and name:find("QuestNPC") then
            if data.recommendedLevel and data.requirements and data.requirements[1] then
                local reqLvl = data.recommendedLevel
                local mobName = data.requirements[1].npcType

                if playerLvl >= reqLvl and reqLvl > bestLevel then
                    bestLevel = reqLvl
                    bestQuest = {
                        quest = name,
                        namequest = data.title,
                        npc = mobName,
                        level = reqLvl
                    }
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
    local currentFarmTween = nil
    
    while task.wait() do
        if not _G.Config.AutoFarm then 
            if currentFarmTween then currentFarmTween:Cancel() currentFarmTween = nil end
            local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root and root:FindFirstChild("3TOC") then root["3TOC"]:Destroy() end
            continue 
        end
        
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local Best_Quest = getBestQuest()
            if not Best_Quest then return end
            
            local Quest = Best_Quest.quest
            local MobTitleQuest = Best_Quest.namequest
            local MobNameFolder = Best_Quest.npc

            local playerGui = player:WaitForChild("PlayerGui")
            local Quest_Gui = playerGui.QuestUI.Quest.Visible
            local Quest_Text = playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text

            if Quest_Gui then
                if Quest_Text == MobTitleQuest then
                    
                    if _G.Config.BringMobs then
                        local mobs = getCurrentMobs(MobNameFolder)
                        
                        if #mobs > 0 then
                            _G.CentralFarmPoint = _G.CentralFarmPoint or mobs[1]:GetPivot().Position
                            local flyPos = _G.CentralFarmPoint + Vector3.new(0, _G.Config.FarmHeight, 0)
                            
                            TP(CFrame.lookAt(flyPos, _G.CentralFarmPoint))
                            
                            repeat task.wait()
                                if not _G.Config.BringMobs or not _G.Config.AutoFarm then break end
                                mobs = getCurrentMobs(MobNameFolder)
                                hrp.CFrame = CFrame.lookAt(flyPos, _G.CentralFarmPoint)

                                for i, mob in ipairs(mobs) do
                                    pcall(function()
                                        local angle = (i / #mobs) * math.pi * 2
                                        local x = math.cos(angle) * _G.Config.BringDistance
                                        local z = math.sin(angle) * _G.Config.BringDistance
                                        
                                        mob.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(x, -(_G.Config.FarmHeight - 1), z)
                                        mob.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                                    end)
                                end
                                game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                            until #mobs == 0 or not playerGui.QuestUI.Quest.Visible or playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= MobTitleQuest
                        else
                            _G.CentralFarmPoint = nil
                        end
                    else
                        local MobInstance = nil
                        local allMobs = getCurrentMobs(MobNameFolder)
                        
                        local closestDist = math.huge
                        for _, m in ipairs(allMobs) do
                            local dist = GetDistance(m:GetPivot().Position, hrp.Position)
                            if dist < closestDist then
                                closestDist = dist
                                MobInstance = m
                            end
                        end

                        if MobInstance then
                            repeat task.wait()
                                if _G.Config.BringMobs or not _G.Config.AutoFarm then break end
                                if not MobInstance.Parent or MobInstance.Humanoid.Health <= 0 then break end
                                
                                local pivot = MobInstance:GetPivot()
                                local pos = pivot.Position
                                local flyPos = pos + Vector3.new(0, _G.Config.FarmHeight, 0)
                                local targetCFrame = CFrame.lookAt(flyPos, pos)
                                
                                TP(targetCFrame)
                                game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                            until MobInstance.Humanoid.Health <= 0 or not playerGui.QuestUI.Quest.Visible or playerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= MobTitleQuest
                        else
                            local npc = workspace.ServiceNPCs:FindFirstChild(Quest)
                            if npc then 
                                TP(npc:GetPivot() * CFrame.new(0, 0, 3))
                            end
                        end
                    end
                else
                    game:GetService("ReplicatedStorage").RemoteEvents.QuestAbandon:FireServer("repeatable")
                    _G.CentralFarmPoint = nil
                end
            else
                _G.CentralFarmPoint = nil
                local npc = workspace.ServiceNPCs:FindFirstChild(Quest)
                if npc then
                    local targetPos = npc:GetPivot() * CFrame.new(0, 0, 3)
                    if GetDistance(targetPos.Position) > 10 then
                        TP(targetPos)
                    else
                        game:GetService("ReplicatedStorage").RemoteEvents.QuestAccept:FireServer(Quest)
                    end
                end
            end
        end)
    end
end)

spawn(function()
    while task.wait(1) do
        if not _G.Config.AutoStats then continue end
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
