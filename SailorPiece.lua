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
    if not game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"):FindFirstChild("3TOC") then
        local body = Instance.new("BodyVelocity")
        body.Name = "3TOC"
        body.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
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
    local time = distance / 180
    
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    AddVelocity()
    TweenService:Create(root, tweenInfo, {CFrame = target}):Play()
end

local function getBestQuest()
    local module = require(game:GetService("ReplicatedStorage").Modules:WaitForChild("QuestConfig"))
    local lvl = game.Players.LocalPlayer.Data.Level.Value

    local bestQuest = nil
    local bestLevel = -math.huge

    for name, data in pairs(module.RepeatableQuests or {}) do
        if type(name) == "string" and name:find("QuestNPC") then
            if data.recommendedLevel and data.requirements and data.requirements[1] then
                local reqLvl = data.recommendedLevel
                local mobName = data.requirements[1].npcType

                if lvl >= reqLvl and reqLvl > bestLevel then
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

_G.AutoStats = true
task.spawn(function()
    local player = game:GetService("Players").LocalPlayer
    local allocateRemote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")

    while task.wait(0.5) do
        if _G.AutoStats then
            pcall(function()
                local data = player.Data
                local unspentPoints = data.StatPoints.Value
                
                if unspentPoints > 0 then
                    local currentMelee = data.Melee.Value
                    local currentDefense = data.Defense.Value
                    
                    local statToUpgrade = nil
                    local pointsToAdd = 0
                    
                    if currentMelee < 11500 then
                        statToUpgrade = "Melee"
                        pointsToAdd = math.min(unspentPoints, 11500 - currentMelee)
                    elseif currentDefense < 11500 then
                        statToUpgrade = "Defense"
                        pointsToAdd = math.min(unspentPoints, 11500 - currentDefense)
                    else
                        statToUpgrade = "Sword"
                        pointsToAdd = unspentPoints
                    end
                    
                    if statToUpgrade and pointsToAdd > 0 then
                        local args = {
                            statToUpgrade,
                            pointsToAdd
                        }
                        allocateRemote:FireServer(unpack(args))
                    end
                end
            end)
        end
    end
end)

spawn(function()
    while task.wait() do
        pcall(function()
            local Best_Quest = getBestQuest()
            local Quest, Mob, NPC, Level = Best_Quest.quest, Best_Quest.namequest, Best_Quest.npc, Best_Quest.level
            if not Quest or not Mob then return end

            local player = game:GetService("Players").LocalPlayer
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            local Quest_Gui = player.PlayerGui.QuestUI.Quest.Visible
            local Quest_Text = player.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text

            if Quest_Gui then
                if Quest_Text == Mob then
                    local MobFolder = nil
                    for _, npc in ipairs(workspace.NPCs:GetChildren()) do
                        if npc.Name:match("^"..NPC.."%d+$") or npc.Name == NPC then
                            MobFolder = npc
                            break
                        end
                    end

                    if MobFolder and hrp then
                        local pivot = MobFolder:GetPivot()
                        local pos = pivot.Position

                        if MobFolder then
                            repeat task.wait()
                                hrp.CFrame = CFrame.lookAt(hrp.Position, pos)
                                TP(pivot * CFrame.new(0, 6, 0))
                                game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                            until not MobFolder or MobFolder.Humanoid.Health <= 0 or not player.PlayerGui.QuestUI.Quest.Visible or player.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= Mob
                        end
                    else
                        local npc = workspace.ServiceNPCs:FindFirstChild(Quest)
                        if npc then TP(npc:GetPivot() * CFrame.new(0, 0, 3)) end
                    end
                else
                    game:GetService("ReplicatedStorage").RemoteEvents.QuestAbandon:FireServer("repeatable")
                end
            else
                local npc = workspace.ServiceNPCs:FindFirstChild(Quest)
                if npc then
                    if GetDistance(npc:GetPivot().Position) > 5 then
                        TP(npc:GetPivot() * CFrame.new(0, 0, 3))
                    else
                        game:GetService("ReplicatedStorage").RemoteEvents.QuestAccept:FireServer(Quest)
                    end
                end
            end
        end)
    end
end)