local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local RequestHit = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

_G.SelectWeapon = "Sword"
_G.OrbitAngle = 0

local function CheckInventory(n, t, q)
    local g = LocalPlayer.PlayerGui:FindFirstChild("InventoryPanelUI") and LocalPlayer.PlayerGui.InventoryPanelUI:FindFirstChild("MainFrame")
    if not g then return q and 0 or nil end
    pcall(function()
        local invBtn = LocalPlayer.PlayerGui.BasicStatsCurrencyAndButtonsUI.MainFrame.UIButtons.InventoryButtonFrame.InventoryButton
        if invBtn.MouseButton1Click then firesignal(invBtn.MouseButton1Click) end
        if invBtn.Activated then firesignal(invBtn.Activated) end
    end)
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
            if q and h and h:FindFirstChild("Quantity") then
                return tonumber(h.Quantity.Text:match("%d+")) or 0
            elseif not q and h and h:FindFirstChild("ItemName") then
                return h.ItemName.Text
            end
        end
    end
    return q and 0 or nil
end

local function Check(n)
    local b, c = LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character
    return (b and b:FindFirstChild(n)) or (c and c:FindFirstChild(n)) ~= nil
end

local function GetBestWeapon()
    for _, w in ipairs({"Gryphon", "Dark Blade", "Katana ", "Katana", "Sword"}) do
        if Check(w) then return w end
    end
    return "Sword"
end

local function AutoEquip()
    _G.SelectWeapon = GetBestWeapon()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if c and h then
        local cw = c:FindFirstChildOfClass("Tool")
        if cw and cw.Name == _G.SelectWeapon then return end
        h:UnequipTools()
        local t = LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(_G.SelectWeapon)
        if t then h:EquipTool(t) end
    end
end

local function TP(pos)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local target = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
    if not root:FindFirstChild("3TOC") then
        local b = Instance.new("BodyVelocity", root)
        b.Name, b.MaxForce, b.Velocity = "3TOC", Vector3.new(9e9, 9e9, 9e9), Vector3.zero
    end
    local dist = (root.Position - target.Position).Magnitude
    if dist < 3 then
        root.CFrame = target
        return
    end
    TweenService:Create(root, TweenInfo.new(dist / 180, Enum.EasingStyle.Linear), {CFrame = target}):Play()
end

local function getBestQuest()
    local mod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("QuestConfig")
    if not mod then return nil end
    local req = require(mod)
    local lvl = LocalPlayer.Data.Level.Value
    local bq, bl = nil, -math.huge
    for n, d in pairs(req.RepeatableQuests or {}) do
        if type(n) == "string" and n:find("QuestNPC") and d.recommendedLevel and d.requirements and d.requirements[1] then
            if lvl >= d.recommendedLevel and d.recommendedLevel > bl then
                bl = d.recommendedLevel
                bq = {quest = n, namequest = d.title, npc = d.requirements[1].npcType}
            end
        end
    end
    return bq
end

local function BuyWeapon(eqName, bpName, cost, gems, npcName)
    if Check(bpName) or Check(eqName) then return false end
    local d = LocalPlayer:FindFirstChild("Data")
    if not d or d.Money.Value < cost or (d:FindFirstChild("Gems") and d.Gems.Value < gems) then return false end
    local f = Workspace:FindFirstChild("ServiceNPCs") or (Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("ServiceNPCs"))
    local npc = f and f:FindFirstChild(npcName)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if npc and npc:FindFirstChild("HumanoidRootPart") and hrp then
        TP(npc.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
        local p = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if p then fireproximityprompt(p, 1) else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
        task.wait(1.5)
        if Check(bpName) or Check(eqName) then
            pcall(function()
                ReplicatedStorage.Remotes.EquipWeapon:FireServer("UnEquip", _G.SelectWeapon)
                task.wait(0.3)
                ReplicatedStorage.Remotes.EquipWeapon:FireServer("Equip", eqName)
            end)
        end
        return true
    end
    return false
end

local function FarmLogic()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local bq = getBestQuest()
    if not bq then hum.AutoRotate, hum.PlatformStand = true, false return end
    
    local gui = LocalPlayer:WaitForChild("PlayerGui")
    if gui.QuestUI.Quest.Visible and gui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text == bq.namequest then
        local mobs, target, dist = {}, nil, math.huge
        local f = Workspace:FindFirstChild("NPCs")
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if (m.Name:match("^"..bq.npc.."%d+$") or m.Name == bq.npc) and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 and m:FindFirstChild("HumanoidRootPart") then
                    local d = (m:GetPivot().Position - hrp.Position).Magnitude
                    if d < dist then dist, target = d, m end
                end
            end
        end
        
        if target then
            hum.AutoRotate, hum.PlatformStand = false, true
            local mHrp = target:FindFirstChild("HumanoidRootPart")
            if mHrp then
                mHrp.Anchored = true
                AutoEquip()
                _G.OrbitAngle = _G.OrbitAngle + math.rad(5)
                TP(CFrame.lookAt(mHrp.Position + Vector3.new(math.cos(_G.OrbitAngle) * 5, 35, math.sin(_G.OrbitAngle) * 5), mHrp.Position))
            end
        else
            hum.AutoRotate, hum.PlatformStand = true, false
            local npc = Workspace:FindFirstChild("ServiceNPCs") or (Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("ServiceNPCs"))
            if npc and npc:FindFirstChild(bq.quest) then TP(npc[bq.quest]:GetPivot() * CFrame.new(0, 0, 3)) end
        end
    elseif gui.QuestUI.Quest.Visible then
        hum.AutoRotate, hum.PlatformStand = true, false
        ReplicatedStorage.RemoteEvents.QuestAbandon:FireServer("repeatable")
    else
        hum.AutoRotate, hum.PlatformStand = true, false
        local npc = Workspace:FindFirstChild("ServiceNPCs") or (Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("ServiceNPCs"))
        if npc and npc:FindFirstChild(bq.quest) then
            local pos = npc[bq.quest]:GetPivot() * CFrame.new(0, 0, 3)
            TP(pos)
            if (hrp.Position - pos.Position).Magnitude <= 10 then
                ReplicatedStorage.RemoteEvents.QuestAccept:FireServer(bq.quest)
            end
        end
    end
end

local lastStat, lastAtk = 0, 0
local function StatsLogic()
    if tick() - lastStat < 1 then return end
    lastStat = tick()
    local sp = LocalPlayer.Data:FindFirstChild("StatPoints")
    if sp and sp.Value > 0 then
        local rm = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")
        if sp.Value >= 2 then
            rm:FireServer("Defense", math.floor(sp.Value / 2))
            rm:FireServer("Sword", math.floor(sp.Value / 2) + (sp.Value % 2))
        else
            rm:FireServer("Sword", 1)
        end
    end
end

local function AttackLogic()
    if tick() - lastAtk < 0.1 then return end
    lastAtk = tick()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local f = Workspace:FindFirstChild("NPCs")
    if not hrp or not f then return end
    local closest, dist = nil, math.huge
    for _, n in pairs(f:GetChildren()) do
        local p = n.PrimaryPart or n:FindFirstChild("HumanoidRootPart") or n:FindFirstChild("Head")
        local h = n:FindFirstChild("Humanoid")
        if p and h and h.Health > 0 then
            local d = (p.Position - hrp.Position).Magnitude
            if d < dist then dist, closest = d, p end
        end
    end
    if closest then RequestHit:FireServer(closest.Position) end
end

task.spawn(function()
    while task.wait() do
        pcall(function()
            if BuyWeapon("Gryphon", "Gryphon", 650000, 650, "GryphonBuyerNPC") or 
               BuyWeapon("Dark Blade", "Dark Blade", 250000, 150, "DarkBladeNPC") or 
               BuyWeapon("Katana ", "Katana", 2500, 0, "Katana") then
            else
                FarmLogic()
                AttackLogic()
            end
            StatsLogic()
        end)
    end
end)
