local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local systems=script.Parent:WaitForChild("GameSystems")
local Economy=require(systems.GameEconomy)
local Safety=require(systems.LairSafety)
local Loot=require(systems.LairLoot)
local Monster=require(systems.LairMonster)
local Expedition=require(systems.LairExpedition)
local Traps=require(systems.LairTraps)
local Servants=require(systems.LairServants)
local RelicEscape=require(systems.RelicEscape)
local scene=workspace:WaitForChild("SafeBaseScene"):WaitForChild("TreasureLair")
local keeper=Monster.new(scene,function(player)Loot.ClearCarried(player)end)
local servants
local function geometryChanged()
    keeper:GeometryChanged()
    -- Traps/vaults initialize before Loot and the servants are activated.
    if servants then servants:GeometryChanged() end
end
local traps=Traps.new(scene,geometryChanged,keeper)
local escape=RelicEscape.new(scene,traps,keeper,Loot.GetRelicCarrier)
local vaults=scene.VaultDoors:GetChildren()
local vaultTweens={}
local function resetVaults()
    for _,vault in ipairs(vaults) do
        local animations=vaultTweens[vault]
        if animations then for _,animation in ipairs(animations) do animation:Cancel() end end
        vaultTweens[vault]=nil
        local door=vault.Door
        door.CFrame=door:GetAttribute("ClosedCFrame")
        door.CanCollide=true;door:SetAttribute("Open",false);door.Unlock.Enabled=true
        vault.Signal.Color=vault.Signal:GetAttribute("RestColor")
    end
    geometryChanged()
end
local function openVault(player,vault)
    local door=vault.Door
    local root=Safety.Root(player)
    if door:GetAttribute("Open") or not door.Unlock.Enabled or not root or not Economy.IsReady(player)
        or (root.Position-door.Position).Magnitude>door.Unlock.MaxActivationDistance then return false end
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character};ray.RespectCanCollide=true
    local hit=workspace:Raycast(root.Position,door.Position-root.Position,ray)
    if hit and hit.Instance~=door then return false end
    if not Economy.TryUseKey(player) then
        ReplicatedStorage.GameRemotes.Notify:FireClient(player,"Нужен ключ · купить на базе за "..Economy.KeyPrice,Color3.fromRGB(255,193,100))
        return false
    end
    -- No yield between the shared door check, key debit and opening: one key per expedition door.
    door:SetAttribute("Open",true);door.Unlock.Enabled=false;door.CanCollide=false
    local opening=TweenService:Create(door,TweenInfo.new(.8,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{CFrame=door:GetAttribute("OpenCFrame")})
    local warning=TweenService:Create(vault.Signal,TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,3,true),{Color=Color3.fromRGB(255,93,50)})
    vaultTweens[vault]={opening,warning};opening:Play();warning:Play()
    geometryChanged()
    keeper:OnTheft(player,vault:GetAttribute("Suspicion"),root.Position)
    ReplicatedStorage.GameRemotes.Notify:FireClient(player,"Замок открыт. Хозяин насторожился!",Color3.fromRGB(255,193,100))
    return true
end
for _,vault in ipairs(vaults) do vault.Door.Unlock.Triggered:Connect(function(player)openVault(player,vault)end) end
resetVaults()
Loot.Start(scene,function(player,risk,position) keeper:OnTheft(player,risk,position) end,
    function(player,position) escape:Start(player,position) end)
servants=Servants.new(scene,keeper,Loot.Slow)
traps.servantRoots={}
for _,actor in servants.actors do table.insert(traps.servantRoots,actor.root) end
keeper:Reset()
keeper:Start()

local hatch=scene.Routes.UndergroundTunnel.Hatch
local hatchTween
hatch.OpenHatch.Triggered:Connect(function(player)
    local root=Safety.Root(player)
    if hatch:GetAttribute("Open") or not root or (root.Position-hatch.Position).Magnitude>hatch.OpenHatch.MaxActivationDistance then return end
    hatch:SetAttribute("Open",true)
    hatch.OpenHatch.Enabled=false
    hatch.CanCollide=false
    local closed=hatch:GetAttribute("ClosedCFrame")
    local hinge=closed*CFrame.new(-hatch.Size.X/2,0,0)
    local opened=hinge*CFrame.Angles(0,0,-math.pi/2)*CFrame.new(hatch.Size.X/2,0,0)
    hatchTween=game:GetService("TweenService"):Create(hatch,TweenInfo.new(.6),{CFrame=opened})
    hatchTween:Play()
end)

local expedition=Expedition.new(scene,function()
    escape:Reset()
    traps:Reset()
    resetVaults()
    Loot.Reset()
    servants:Reset()
    keeper:Reset()
    if hatchTween then hatchTween:Cancel();hatchTween=nil end
    hatch.CFrame=hatch:GetAttribute("ClosedCFrame")
    hatch:SetAttribute("Open",false)
    hatch.CanCollide=true
    hatch.OpenHatch.Enabled=true
    for _,player in Players:GetPlayers() do
        local root=Safety.Root(player)
        if root and Safety.InBase(scene,root.Position) then
            ReplicatedStorage.GameRemotes.Notify:FireClient(player,"Сокровища обновлены",Color3.fromRGB(115,245,178))
        end
    end
end)

local function playerAdded(player)
    player.CharacterRemoving:Connect(function()
        -- Resetting a character cannot turn unbanked loot into a free delivery.
        Economy.LoseUndelivered(player)
        Loot.ClearCarried(player)
    end)
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)Loot.RemovePlayer(player)end)
ReplicatedStorage.GameRemotes.TreasureAction.OnServerEvent:Connect(function(player,action,value)
    if action=="Drop" then Loot.Drop(player,value)
    elseif action=="Walk" then Loot.SetWalking(player,value) end
    if action=="Sprint" then Loot.Sprint(player)
    elseif action=="FireCannon" then Loot.FireCannon(player,value,keeper) end
end)
for _,p in ipairs(Players:GetPlayers()) do playerAdded(p) end

while scene.Parent do
    task.wait(0.2)
    local players=Players:GetPlayers()
    for _,player in ipairs(players) do
        local root=Safety.Root(player)
        if root and Safety.InBase(scene,root.Position) and Economy.GetUndeliveredValue(player)>0 then
            local value,count=Economy.Deliver(player)
            if count>0 then
                Loot.ClearCarried(player)
                ReplicatedStorage.GameRemotes.Notify:FireClient(player,
                    string.format("Сдано +%d · Баланс %d монет\nКлючи и улучшение рюкзака — на базе.",value,player:GetAttribute("Coins")),Color3.fromRGB(115,245,178),5)
            end
        end
    end
    Loot.Step(players,os.clock(),keeper)
    servants:Step(players,os.clock())
    expedition:Step(players,os.clock())
    escape:Step(players,os.clock())
    traps:Step(players,os.clock())
end
