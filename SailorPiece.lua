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
_G.AutoFarm = true

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

task.spawn(function()
    while task.wait() do
        if _G.AutoFarm then
            pcall(function()
                local player = game.Players.LocalPlayer
                local char = player.Character
                if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end

                local tool = char:FindFirstChildOfClass("Tool")
                if not tool then
                    for _, v in pairs(player.Backpack:GetChildren()) do
                        if v:IsA("Tool") then
                            char.Humanoid:EquipTool(v)
                            break
                        end
                    end
                end

                local bestQuest = getBestQuest()
                local targetMob = bestQuest and bestQuest.npc or nil
                local target = nil
                local dist = math.huge

                local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs") or workspace

                for _, v in pairs(enemiesFolder:GetChildren()) do
                    if v:IsA("Model") and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 and v.Name ~= player.Name then
                        if not targetMob or string.find(v.Name, targetMob) then
                            local d = GetDistance(char, v)
                            if d < dist then
                                dist = d
                                target = v
                            end
                        end
                    end
                end

                if target then
                    TP(target.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0))
                    if tool then
                        tool:Activate()
                    end
                end
            end)
        end
    end
end)
