local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local RequestHit = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")

_G.IsBuying = false
_G.SelectWeapon = "Sword"

local MobNameOverrides = {
    ["Slime Warrior Hunter"] = "Slime",
}

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

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

game:GetService("RunService").Heartbeat:Connect(function()
    if LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if (v:IsA("BasePart") or v:IsA("Part")) then
                v.CanCollide = false
            end
        end
        AddVelocity()
    end
end)

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
    TweenService:Create(root, tweenInfo, {CFrame = target}):Play()
end

function AutoEquip(n)
    local c = LocalPlayer.Character if not c then return end
    local w = n or _G.SelectWeapon
    if c:FindFirstChild(w) or c:FindFirstChildOfClass("Tool") then return end
    local t = (LocalPlayer.Backpack:FindFirstChild(w)) or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
    if t then 
        local h = c:FindFirstChildOfClass("Humanoid") 
        if h then h:EquipTool(t) t.Parent = c end 
    end
end

function CheckBackPack(bx)
    local BackpackandCharacter = { game.Players.LocalPlayer.Backpack, game.Players.LocalPlayer.Character }
    for _, by in pairs(BackpackandCharacter) do
        for _, v in pairs(by:GetChildren()) do
            if type(bx) == "table" then
                if table.find(bx, v.Name) then return v end
            else
                if v.Name == bx then return v end
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

function CheckInventory(n, t, q)
    local p = game.Players.LocalPlayer
    local invBtn = p.PlayerGui:FindFirstChild("BasicStatsCurrencyAndButtonsUI") and p.PlayerGui.BasicStatsCurrencyAndButtonsUI.MainFrame.UIButtons.InventoryButtonFrame.InventoryButton
    if invBtn then 
        if invBtn.MouseButton1Click then firesignal(invBtn.MouseButton1Click) end 
        if invBtn.Activated then firesignal(invBtn.Activated) end 
    end
    
    local g = p.PlayerGui:FindFirstChild("InventoryPanelUI") and p.PlayerGui.InventoryPanelUI.MainFrame
    if not g then return q and 0 end
    
    repeat task.wait() until g.Visible
    local tb = g.Frame.Content.Holder.Tabs:FindFirstChild(t)
    local btn = tb and tb:FindFirstChild("ButtonOff")
    if btn then 
        if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end 
        if btn.Activated then firesignal(btn.Activated) end 
        repeat task.wait() until not btn.Visible 
    end
    
    for _, v in pairs(g.Frame.Content.Holder.StorageHolder.Storage:GetChildren()) do
        if string.find(v.Name, n) then
            local h = v:FindFirstChild("Slot") and v.Slot:FindFirstChild("Holder")
            return q and h and h:FindFirstChild("Quantity") and tonumber(h.Quantity.Text:match("%d+")) or h and h:FindFirstChild("ItemName") and h.ItemName.Text
        end
    end
    return q and 0
end

function BuySword(n, m)
    local d = LocalPlayer:FindFirstChild("Data")
    if not d or d.Money.Value < m then return false end
    
    local f = workspace:FindFirstChild("ServiceNPCs") or (workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("ServiceNPCs"))
    local npc = f and f:FindFirstChild(n)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if npc and npc:FindFirstChild("HumanoidRootPart") and hrp then
        local targetCFrame = npc.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        TP(targetCFrame)
        task.wait(0.5)
        
        local p = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if p then 
            fireproximityprompt(p, 1) 
        else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end
end

local function getSortedNPCs()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end

    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return {} end

    local list = {}
    for _, npc in pairs(folder:GetChildren()) do
        local hum = npc:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
            local p = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
            if p then
                local dist = (p.Position - hrp.Position).Magnitude
                if dist <= 300 then
                    table.insert(list, {npc = npc, dist = dist})
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)

    local sorted = {}
    for _, v in ipairs(list) do table.insert(sorted, v.npc) end
    return sorted
end

function flv()
    if _G.IsBuying then return end

    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local q = getBestQuest()
    if not q then hum.AutoRotate, hum.PlatformStand = true, false return end
    
    local gui = LocalPlayer.PlayerGui
    local questUI = gui:FindFirstChild("QuestUI")
    if not questUI then return end
    
    local titleElement = questUI.Quest.Holder.Content.QuestInfo.QuestTitle:FindFirstChild("QuestTitle")
    local title = titleElement and titleElement.Text or ""
    
    if questUI.Visible and title == q.namequest then
        local targetMobName = MobNameOverrides[q.npc] or q.npc 
        
        local mobs = getCurrentMobs(targetMobName)
        local target, dist = nil, math.huge
        for _, m in ipairs(mobs) do
            local d = GetDistance(m:GetPivot().Position, hrp.Position)
            if d < dist then dist, target = d, m end
        end
        
        if target then
            hum.AutoRotate, hum.PlatformStand = false, true
            local mhrp = target:FindFirstChild("HumanoidRootPart")
            if mhrp then
                mhrp.Anchored = true
                local a = 0
                repeat task.wait()
                    if not target.Parent or target.Humanoid.Health <= 0 or _G.IsBuying then break end
                    AutoEquip()
                    a += math.rad(5)
                    local p = mhrp.Position
                    TP(CFrame.lookAt(p + Vector3.new(math.cos(a)*5, 30, math.sin(a)*5), p))
                until target.Humanoid.Health <= 0 or not questUI.Visible or title ~= q.namequest or _G.IsBuying
                mhrp.Anchored = false
            end
        else
            hum.AutoRotate, hum.PlatformStand = true, false
            local npc = Workspace.ServiceNPCs:FindFirstChild(q.quest)
            if npc then TP(npc:GetPivot() * CFrame.new(0,0,3)) end
        end
    elseif questUI.Visible then
        hum.AutoRotate, hum.PlatformStand = true, false
        ReplicatedStorage.RemoteEvents.QuestAbandon:FireServer("repeatable")
    else
        hum.AutoRotate, hum.PlatformStand = true, false
        ReplicatedStorage.RemoteEvents.QuestAccept:FireServer(q.quest)
    end
end

task.spawn(function()
    while task.wait(0.05) do
        pcall(function()
            flv() 
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
                
                local defensePoints = math.floor(statPoints / 4)
                local swordPoints = statPoints - defensePoints
                
                if defensePoints > 0 then
                    remote:FireServer("Defense", defensePoints)
                end
                if swordPoints > 0 then
                    remote:FireServer("Sword", swordPoints)
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        local npcs = getSortedNPCs()
        for _, npc in ipairs(npcs) do
            local hitPos = npc:FindFirstChild("Head") and npc.Head.Position or npc:FindFirstChild("HumanoidRootPart") and npc.HumanoidRootPart.Position
            if hitPos then
                pcall(function()
                    RequestHit:FireServer(hitPos)
                    task.wait(0.05)
                end)
            end
        end
    end
end)

local AutoBuySwordsList = {
    {ItemName = "Katana",    NPCName = "Katana",           Price = 2500},
    {ItemName = "DarkBlade", NPCName = "DarkBladeBuyer",   Price = 250000},
    {ItemName = "Gryphon",  NPCName = "GryphonBuyerNPC",  Price = 600000}
}

task.spawn(function()
    while task.wait(0.5) do 
        pcall(function()
            local playerData = LocalPlayer:FindFirstChild("Data")
            if playerData and playerData:FindFirstChild("Money") then
                local currentMoney = playerData.Money.Value
                for _, sword in ipairs(AutoBuySwordsList) do
                    if currentMoney >= sword.Price and not CheckInventory(sword.ItemName, "SwordTab", false) then
                        
                        _G.IsBuying = true 
                        task.wait(1) 
                        
                        BuySword(sword.NPCName, sword.Price)
                        task.wait(2) 
                        
                        _G.IsBuying = false 
                        break 
                        
                    end
                end
            end
        end)
    end
end)
