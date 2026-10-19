local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(script.Parent.GameSystems.GameEconomy)
local Progress = require(script.Parent.GameSystems.PlayerProgress)
local Safety = require(script.Parent.GameSystems.LairSafety)
local Config = require(script.Parent.GameSystems.LairConfig)
local remotes = ReplicatedStorage.GameRemotes
local terminal = workspace.SafeBaseScene.SafeBase.ShopTerminal.TerminalBody
local shopPrompt = terminal.ShopPrompt
local shopPurchases = {}

local function initPlayer(player)
    if player:GetAttribute("ProgressLoaded")~=nil then return end
    player:SetAttribute("ProgressLoaded",false)
    player:SetAttribute("Coins", 0)
    player:SetAttribute("MaxInventory", Economy.BaseCapacity)
    player:SetAttribute("BackpackLevel", 0)
    player:SetAttribute("Keys", 0)
    player:SetAttribute("SprintUnlocked",false)
    player:SetAttribute("JumpUnlocked",false)
    for key in pairs(Economy.ArtifactPrices) do player:SetAttribute(key, 0) end
    local data = Progress:Load(player)
    if not data then
        if player.Parent==Players then
            player:Kick("Не удалось безопасно загрузить прогресс. Попробуйте войти снова через пару минут. Сохранённые данные не сброшены.")
        end
        return
    end
    -- The load-to-activation section does not yield; attributes become usable together.
    player:SetAttribute("Coins",data.Coins)
    player:SetAttribute("BackpackLevel",data.BackpackLevel)
    player:SetAttribute("Keys",data.Keys)
    player:SetAttribute("SprintUnlocked",data.SprintUnlocked)
    player:SetAttribute("JumpUnlocked",data.JumpUnlocked)
    player:SetAttribute("MaxInventory",Economy.Capacity(data.BackpackLevel))
    Progress:Activate(player)
end

local function canShop(player)
    local root=Safety.Root(player)
    if not root or not shopPrompt.Enabled or not Economy.IsReady(player)
        or (root.Position-terminal.Position).Magnitude>shopPrompt.MaxActivationDistance then return false end
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character}
    ray.RespectCanCollide=true
    local hit=workspace:Raycast(root.Position,terminal.Position-root.Position,ray)
    return not hit or hit.Instance:IsDescendantOf(terminal.Parent)
end

local function showShop(player)
    if not canShop(player) then return end
    local level = player:GetAttribute("BackpackLevel")
    remotes.OpenShop:FireClient(player, level, Economy.UpgradeCost(level), player:GetAttribute("MaxInventory"), Economy.UpgradeAmount,
        {Key=Economy.KeyPrice,Sprint=Config.SprintPrice,Jump=Config.JumpPrice})
end

shopPrompt.Triggered:Connect(showShop)
remotes.BuyUpgrade.OnServerEvent:Connect(function(player,kind)
    if kind==nil then kind="Backpack" end
    if kind~="Key" and kind~="Backpack" and kind~="Sprint" and kind~="Jump" then return end
    if not canShop(player) then
        remotes.Notify:FireClient(player,"Подойдите к терминалу магазина!",Color3.fromRGB(255,180,80))
        return
    end
    local now=os.clock()
    if now-(shopPurchases[player] or -math.huge)<.8 then return end
    shopPurchases[player]=now
    local success
    if kind=="Key" then success=Economy.TryBuyKey(player)
    elseif kind=="Backpack" then success=Economy.TryUpgrade(player)
    else success=Economy.TryBuyAbility(player,kind) end
    local message=not success and "Уже куплено или не хватает монет"
        or kind=="Key" and "Ключ куплен · ключей: "..player:GetAttribute("Keys")
        or kind=="Backpack" and "Рюкзак улучшен! Вместимость: "..player:GetAttribute("MaxInventory")
        or kind=="Sprint" and "Суперкроссовки открыты!" or "Пружинные ботинки открыты!"
    remotes.Notify:FireClient(player,message,success and Color3.fromRGB(140,235,200) or Color3.fromRGB(255,180,100))
    showShop(player)
end)

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player) shopPurchases[player]=nil;Progress:Close(player) end)
game:BindToClose(function() Progress:CloseAll() end)
for _, player in Players:GetPlayers() do task.spawn(initPlayer,player) end
task.spawn(function()
    while task.wait(1) do Progress:Autosave() end
end)
