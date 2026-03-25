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
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        if not char.HumanoidRootPart:FindFirstChild("3TOC") then
            local body = Instance.new("BodyVelocity")
            body.Name = "3TOC"
            body.Parent = char.HumanoidRootPart
            body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            body.Velocity = Vector3.new(0, 0, 0)
        end
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

spawn(function()
    while task.wait() do
        pcall(function()
            local Best_Quest = getBestQuest()
            if not Best_Quest then return end
            
            local Quest, Mob, NPC, Level = Best_Quest.quest, Best_Quest.namequest, Best_Quest.npc, Best_Quest.level
            if not Quest or not Mob then return end

            local player = game:GetService("Players").LocalPlayer
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local QuestUI = player.PlayerGui:FindFirstChild("QuestUI")
            if not QuestUI then return end
            
            local Quest_Gui = QuestUI.Quest.Visible
            local Quest_Text = QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text

            if Quest_Gui then
                if Quest_Text == Mob then
                    local MobFolder = nil
                    
                    for _, npc in ipairs(workspace.NPCs:GetChildren()) do
                        if npc.Name:match("^"..NPC.."%d+$") and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
                            MobFolder = npc
                            break
                        end
                    end
                    
                    if not MobFolder then
                        for _, npc in ipairs(workspace.NPCs:GetChildren()) do
                            if npc.Name:find(NPC) and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
                                MobFolder = npc
                                break
                            end
                        end
                    end

                    if MobFolder then
                        local hrp_mob = MobFolder:FindFirstChild("HumanoidRootPart")
                        if hrp_mob then
                            if GetDistance(hrp.Position, hrp_mob.Position) > 15 then
                                TP(hrp_mob.CFrame * CFrame.new(0, 2, 0))
                                task.wait(0.2)
                            else
                                repeat task.wait()
                                    if not MobFolder or not MobFolder.Parent or MobFolder.Humanoid.Health <= 0 then break end
                                    local mRoot = MobFolder:FindFirstChild("HumanoidRootPart")
                                    if mRoot then
                                        hrp.CFrame = CFrame.lookAt((mRoot.CFrame * CFrame.new(0, 2, 0)).Position, mRoot.Position)
                                    end
                                    
                                    local tool = char:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                                    if tool then 
                                        if tool.Parent ~= char then tool.Parent = char end
                                        tool:Activate() 
                                    end
                                    game:GetService("ReplicatedStorage").CombatSystem.Remotes.RequestHit:FireServer()
                                until not MobFolder or not MobFolder.Parent or MobFolder.Humanoid.Health <= 0 or not QuestUI.Quest.Visible or QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text ~= Mob
                            end
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
