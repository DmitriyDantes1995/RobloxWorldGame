local Progress = require(script.Parent.PlayerProgress)
local Catalog = require(game:GetService("ReplicatedStorage").TreasureCatalog)
local Config = require(script.Parent.LairConfig)
local Economy = {}
Economy.ArtifactPrices = {}
for kind,item in pairs(Catalog.Items) do Economy.ArtifactPrices["Artifacts_"..kind]=item.Price end
Economy.BaseCapacity = 10
Economy.UpgradeAmount = 5
Economy.KeyPrice = 100

function Economy.UpgradeCost(level)
    return math.floor(50 * 1.5 ^ level)
end

function Economy.Capacity(level)
    return Economy.BaseCapacity + level * Economy.UpgradeAmount
end

function Economy.IsReady(player)
    return Progress:IsReady(player)
end

function Economy.GetUsed(player)
    local used = 0
    for kind,item in pairs(Catalog.Items) do used += (player:GetAttribute("Artifacts_"..kind) or 0)*item.Capacity end
    return used
end

function Economy.CanAdd(player, amount)
    return Economy.IsReady(player) and Economy.GetUsed(player) + (amount or 1) <= player:GetAttribute("MaxInventory")
end

function Economy.TryAddArtifact(player, rarity)
    local key = "Artifacts_" .. rarity
    local item=Catalog.Items[rarity]
    if not item or not Economy.CanAdd(player, item.Capacity) then return false end
    player:SetAttribute(key, (player:GetAttribute(key) or 0) + 1)
    return true
end

function Economy.TryRemoveArtifact(player,kind)
    if not Catalog.Items[kind] or not Economy.IsReady(player) then return false end
    local key="Artifacts_"..kind
    local count=player:GetAttribute(key) or 0
    if count<1 then return false end
    player:SetAttribute(key,count-1)
    return true
end

-- All carried treasure is undelivered; player attributes are the sole inventory.
function Economy.GetUndeliveredValue(player)
    local value = 0
    for key, price in pairs(Economy.ArtifactPrices) do
        value += (player:GetAttribute(key) or 0) * price
    end
    return value
end

local function removeCargo(player)
    local value, count = 0, 0
    for key, price in pairs(Economy.ArtifactPrices) do
        local amount = player:GetAttribute(key) or 0
        player:SetAttribute(key, 0)
        value += amount * price
        count += amount
    end
    return value, count
end

function Economy.Deliver(player)
    if not Economy.IsReady(player) then return 0, 0 end
    local value, count = removeCargo(player)
    if value > 0 then
        player:SetAttribute("Coins", player:GetAttribute("Coins") + value)
        Progress:RequestSave(player)
    end
    return value, count
end

function Economy.TryUpgrade(player)
    if not Economy.IsReady(player) then return false end
    local level = player:GetAttribute("BackpackLevel")
    local cost = Economy.UpgradeCost(level)
    local coins = player:GetAttribute("Coins")
    if coins < cost then return false end
    -- All mutations precede the asynchronous save; no yield or client-supplied price.
    player:SetAttribute("Coins", coins-cost)
    player:SetAttribute("BackpackLevel", level+1)
    player:SetAttribute("MaxInventory", Economy.Capacity(level+1))
    Progress:RequestSave(player)
    return true
end

function Economy.LoseUndelivered(player)
    return removeCargo(player)
end

function Economy.TryBuyKey(player)
    if not Economy.IsReady(player) then return false end
    local coins,keys=player:GetAttribute("Coins"),player:GetAttribute("Keys")
    if coins<Economy.KeyPrice or keys>=9007199254740991 then return false end
    player:SetAttribute("Coins",coins-Economy.KeyPrice)
    player:SetAttribute("Keys",keys+1)
    Progress:RequestSave(player)
    return true
end

function Economy.TryUseKey(player)
    if not Economy.IsReady(player) then return false end
    local keys=player:GetAttribute("Keys")
    if keys<1 then return false end
    player:SetAttribute("Keys",keys-1)
    Progress:RequestSave(player)
    return true
end

function Economy.TryBuyAbility(player,kind)
    if not Economy.IsReady(player) then return false end
    local key,price
    if kind=="Sprint" then key,price="SprintUnlocked",Config.SprintPrice
    elseif kind=="Jump" then key,price="JumpUnlocked",Config.JumpPrice
    else return false end
    local coins=player:GetAttribute("Coins")
    if player:GetAttribute(key) or coins<price then return false end
    player:SetAttribute("Coins",coins-price)
    player:SetAttribute(key,true)
    Progress:RequestSave(player)
    return true
end

return Economy
