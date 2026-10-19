local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(script.Parent.GameSystems.GameEconomy)
local Progress = require(script.Parent.GameSystems.PlayerProgress)
local Safety = require(script.Parent.GameSystems.LairSafety)
local Config = require(script.Parent.GameSystems.LairConfig)
local remotes = ReplicatedStorage.GameRemotes
local terminal = workspace.SafeBaseScene.SafeBase.ShopTerminal.TerminalBody
local shopPrompt = terminal.ShopPrompt
local keyStand = workspace.SafeBaseScene.SafeBase.KeyStand.Body
local keyPrompt = keyStand.BuyKey
local keyPurchases = {}
keyPrompt.ObjectText = "Ключ · "..Economy.KeyPrice.." монет"

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

local function showShop(player)
    if not Economy.IsReady(player) then return end
    local level = player:GetAttribute("BackpackLevel")
    remotes.OpenShop:FireClient(player, level, Economy.UpgradeCost(level), player:GetAttribute("MaxInventory"), Economy.UpgradeAmount,
        {Sprint=Config.SprintPrice,Jump=Config.JumpPrice})
end

shopPrompt.Triggered:Connect(showShop)
keyPrompt.Triggered:Connect(function(player)
    local root=Safety.Root(player)
    if not root or not keyPrompt.Enabled or not Economy.IsReady(player)
        or (root.Position-keyStand.Position).Magnitude>keyPrompt.MaxActivationDistance then return end
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character};ray.RespectCanCollide=true
    local hit=workspace:Raycast(root.Position,keyStand.Position-root.Position,ray)
    if hit and hit.Instance~=keyStand then return end
    local now=os.clock()
    if now-(keyPurchases[player] or -math.huge)<.8 then return end
    keyPurchases[player]=now
    if Economy.TryBuyKey(player) then
        remotes.Notify:FireClient(player,"Ключ куплен · ключей: "..player:GetAttribute("Keys"),Color3.fromRGB(255,218,110))
    else
        remotes.Notify:FireClient(player,"Для ключа нужно "..Economy.KeyPrice.." монет",Color3.fromRGB(255,150,100))
    end
end)
remotes.BuyUpgrade.OnServerEvent:Connect(function(player,kind)
    if not Economy.IsReady(player) then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not shopPrompt.Enabled or (root.Position-terminal.Position).Magnitude > shopPrompt.MaxActivationDistance then
        remotes.Notify:FireClient(player, "Подойдите к терминалу магазина!", Color3.fromRGB(255,180,80))
        return
    end
    if kind=="Sprint" or kind=="Jump" then
        if Economy.TryBuyAbility(player,kind) then
            remotes.Notify:FireClient(player,kind=="Sprint" and "Суперкроссовки открыты!" or "Пружинные ботинки открыты!",Color3.fromRGB(100,230,210))
        else remotes.Notify:FireClient(player,"Уже куплено или не хватает монет",Color3.fromRGB(255,180,100)) end
        showShop(player)
        return
    elseif kind~=nil and kind~="Backpack" then return end
    if not Economy.TryUpgrade(player) then
        remotes.Notify:FireClient(player, "Недостаточно монет!", Color3.fromRGB(255,80,80))
        return
    end
    remotes.Notify:FireClient(player, "Рюкзак улучшен! Вместимость: "..player:GetAttribute("MaxInventory"), Color3.fromRGB(100,200,255))
    showShop(player)
end)

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player) keyPurchases[player]=nil;Progress:Close(player) end)
game:BindToClose(function() Progress:CloseAll() end)
for _, player in Players:GetPlayers() do task.spawn(initPlayer,player) end
task.spawn(function()
    while task.wait(1) do Progress:Autosave() end
end)
