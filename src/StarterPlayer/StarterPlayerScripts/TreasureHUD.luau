local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("TreasureCatalog"))

local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local openShopEvent = remotes:WaitForChild("OpenShop")
local buyUpgradeEvent = remotes:WaitForChild("BuyUpgrade")
local notifyEvent = remotes:WaitForChild("Notify")
local treasureAction = remotes:WaitForChild("TreasureAction")

-- === MAIN HUD ===
local gui = Instance.new("ScreenGui")
gui.Name = "TreasureHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- HUD container (top-left)
local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(0, 266, 0, 252)
hud.Position = UDim2.new(0, 16, 0, 16)
hud.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
hud.Parent = gui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 10)
hudCorner.Parent = hud

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(60, 60, 70)
hudStroke.Thickness = 2
hudStroke.Parent = hud

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 22)
title.Position = UDim2.new(0, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "СОКРОВИЩА"
title.TextColor3 = Color3.fromRGB(200, 200, 210)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = hud

local selectedKind = Catalog.Order[1]
local itemRows = {}
local updateHUD
for index, kind in ipairs(Catalog.Order) do
	local item = Catalog.Items[kind]
	local row = Instance.new("TextButton")
	row.Name = kind
	row.Size = UDim2.new(1, -16, 0, 27)
	row.Position = UDim2.new(0, 8, 0, 30 + (index - 1) * 30)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	row.BorderSizePixel = 0
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = hud

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 5)
	rc.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(0, 108, 1, 0)
	nameLabel.Position = UDim2.fromOffset(6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = item.Color
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = row

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.Size = UDim2.new(1, -146, 1, 0)
	description.Position = UDim2.fromOffset(112, 0)
	description.BackgroundTransparency = 1
	description.Text = item.Description
	description.TextSize = 10
	description.TextColor3 = Color3.fromRGB(185, 185, 195)
	description.Font = Enum.Font.Gotham
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.Parent = row

	local countLbl = Instance.new("TextLabel")
	countLbl.Name = "Count"
	countLbl.Size = UDim2.new(0, 32, 1, 0)
	countLbl.Position = UDim2.new(1, -36, 0, 0)
	countLbl.BackgroundTransparency = 1
	countLbl.Text = "0"
	countLbl.TextColor3 = item.Color
	countLbl.Font = Enum.Font.GothamBold
	countLbl.TextSize = 14
	countLbl.TextXAlignment = Enum.TextXAlignment.Right
	countLbl.Parent = row

	itemRows[kind] = {Button = row, Name = nameLabel, Count = countLbl}
	row.Activated:Connect(function()
		selectedKind = kind
		updateHUD()
	end)
end

local totalsLabel = Instance.new("TextLabel")
totalsLabel.Name = "Totals"
totalsLabel.Size = UDim2.new(1, -16, 0, 22)
totalsLabel.Position = UDim2.fromOffset(8, 150)
totalsLabel.BackgroundTransparency = 1
totalsLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
totalsLabel.Font = Enum.Font.GothamBold
totalsLabel.TextSize = 12
totalsLabel.Parent = hud
-- Inventory capacity bar
local invBarBg = Instance.new("Frame")
invBarBg.Name = "InvBarBg"
invBarBg.Size = UDim2.new(1, -16, 0, 15)
invBarBg.Position = UDim2.new(0, 8, 0, 176)
invBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
invBarBg.BorderSizePixel = 0
invBarBg.Parent = hud

local invBarCorner = Instance.new("UICorner")
invBarCorner.CornerRadius = UDim.new(0, 4)
invBarCorner.Parent = invBarBg

local invBarFill = Instance.new("Frame")
invBarFill.Name = "InvBarFill"
invBarFill.Size = UDim2.new(0, 0, 1, 0)
invBarFill.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
invBarFill.BorderSizePixel = 0
invBarFill.Parent = invBarBg

local invBarFillCorner = Instance.new("UICorner")
invBarFillCorner.CornerRadius = UDim.new(0, 4)
invBarFillCorner.Parent = invBarFill

local invLabel = Instance.new("TextLabel")
invLabel.Name = "InvLabel"
invLabel.Size = UDim2.new(1, 0, 0, 15)
invLabel.Position = UDim2.new(0, 0, 0, 176)
invLabel.BackgroundTransparency = 1
invLabel.Text = "0 / 10"
invLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
invLabel.Font = Enum.Font.GothamBold
invLabel.TextSize = 10
invLabel.Parent = hud

local dropButton = Instance.new("TextButton")
dropButton.Name = "DropSelected"
dropButton.Size = UDim2.new(1, -16, 0, 27)
dropButton.Position = UDim2.fromOffset(8, 197)
dropButton.BackgroundColor3 = Color3.fromRGB(57, 67, 82)
dropButton.BorderSizePixel = 0
dropButton.TextColor3 = Color3.fromRGB(230, 230, 240)
dropButton.Font = Enum.Font.GothamBold
dropButton.TextSize = 12
dropButton.Parent = hud
local dropCorner = Instance.new("UICorner")
dropCorner.CornerRadius = UDim.new(0, 5)
dropCorner.Parent = dropButton

local walkButton = Instance.new("TextButton")
walkButton.Name = "Walk"
walkButton.Size = UDim2.new(1, -16, 0, 22)
walkButton.Position = UDim2.fromOffset(8, 226)
walkButton.BackgroundTransparency = 1
walkButton.TextColor3 = Color3.fromRGB(190, 200, 210)
walkButton.Font = Enum.Font.Gotham
walkButton.TextSize = 11
walkButton.AutoButtonColor = false
walkButton.Parent = hud

local sprintButton=Instance.new("TextButton")
sprintButton.Name="Sprint";sprintButton.Size=UDim2.fromOffset(122,42);sprintButton.Position=UDim2.fromOffset(8,254)
sprintButton.BackgroundColor3=Color3.fromRGB(37,88,79);sprintButton.TextColor3=Color3.fromRGB(140,255,219)
sprintButton.Font=Enum.Font.GothamBold;sprintButton.TextSize=12;sprintButton.TextWrapped=true;sprintButton.BorderSizePixel=0;sprintButton.Parent=hud
local sprintCorner=Instance.new("UICorner");sprintCorner.CornerRadius=UDim.new(0,6);sprintCorner.Parent=sprintButton
local cannonLabel=Instance.new("TextLabel")
cannonLabel.Name="CannonStatus";cannonLabel.Size=UDim2.fromOffset(122,42);cannonLabel.Position=UDim2.fromOffset(136,254)
cannonLabel.BackgroundTransparency=1;cannonLabel.TextColor3=Color3.fromRGB(110,230,255);cannonLabel.TextWrapped=true
cannonLabel.Font=Enum.Font.GothamBold;cannonLabel.TextSize=11;cannonLabel.Parent=hud
hud.Size=UDim2.fromOffset(266,302)

-- === NOTIFICATION ===
local notifFrame = Instance.new("TextLabel")
notifFrame.Name = "Notification"
notifFrame.Size = UDim2.new(1, -24, 0, 64)
notifFrame.AnchorPoint = Vector2.new(.5, 0)
local notifLimit = Instance.new("UISizeConstraint")
notifLimit.MaxSize = Vector2.new(340, 64)
notifLimit.Parent = notifFrame
notifFrame.Position = UDim2.new(.5, 0, 0, 20)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
notifFrame.BackgroundTransparency = 0.1
notifFrame.BorderSizePixel = 0
notifFrame.Text = ""
notifFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
notifFrame.Font = Enum.Font.GothamBold
notifFrame.TextSize = 14
notifFrame.TextWrapped = true
notifFrame.Visible = false
notifFrame.Parent = gui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notifFrame

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(100, 100, 120)
notifStroke.Thickness = 2
notifStroke.Parent = notifFrame

local notifTween = nil
local notifVersion = 0
local function showNotification(text, color, duration)
	-- Invalidate the previous timer before cancelling its exit tween.
	notifVersion += 1
	local version = notifVersion
	if notifTween then notifTween:Cancel() end
	notifFrame.Text = text
	notifFrame.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	notifFrame.Position = UDim2.new(.5, 0, 0, UserInputService.TouchEnabled and 228 or 20)
	notifFrame.BackgroundTransparency = .1
	notifFrame.TextTransparency = 0
	notifFrame.Visible = true
	task.delay(duration or 3, function()
		if version ~= notifVersion then return end
		local hideTween = TweenService:Create(notifFrame, TweenInfo.new(.25), {BackgroundTransparency = 1, TextTransparency = 1})
		notifTween = hideTween
		hideTween:Play()
		hideTween.Completed:Wait()
		if version == notifVersion then
			notifFrame.Visible = false
		end
	end)
end

-- === SHOP UI ===
local shopGui = Instance.new("Frame")
shopGui.Name = "ShopUI"
shopGui.Size = UDim2.new(0, 320, 0, 240)
shopGui.Position = UDim2.new(0.5, -160, 0.5, -120)
shopGui.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
shopGui.BackgroundTransparency = 0.05
shopGui.BorderSizePixel = 0
shopGui.Visible = false
shopGui.Parent = gui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopGui

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(80, 120, 200)
shopStroke.Thickness = 3
shopStroke.Parent = shopGui

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "ShopTitle"
shopTitle.Size = UDim2.new(1, 0, 0, 32)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "🛒 МАГАЗИН УЛУЧШЕНИЙ"
shopTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 18
shopTitle.Parent = shopGui

-- Current level display
local shopInfo = Instance.new("TextLabel")
shopInfo.Name = "ShopInfo"
shopInfo.Size = UDim2.new(1, -24, 0, 40)
shopInfo.Position = UDim2.new(0, 12, 0, 40)
shopInfo.BackgroundTransparency = 1
shopInfo.Text = "Рюкзак: ур.0 | Вместимость: 10"
shopInfo.TextColor3 = Color3.fromRGB(200, 200, 210)
shopInfo.Font = Enum.Font.Gotham
shopInfo.TextSize = 14
shopInfo.Parent = shopGui

-- Upgrade cost label
local shopCost = Instance.new("TextLabel")
shopCost.Name = "ShopCost"
shopCost.Size = UDim2.new(1, -24, 0, 24)
shopCost.Position = UDim2.new(0, 12, 0, 88)
shopCost.BackgroundTransparency = 1
shopCost.Text = "Стоимость: 50 🪙"
shopCost.TextColor3 = Color3.fromRGB(255, 200, 60)
shopCost.Font = Enum.Font.GothamBold
shopCost.TextSize = 16
shopCost.Parent = shopGui

-- Upgrade benefit label
local shopBenefit = Instance.new("TextLabel")
shopBenefit.Name = "ShopBenefit"
shopBenefit.Size = UDim2.new(1, -24, 0, 20)
shopBenefit.Position = UDim2.new(0, 12, 0, 116)
shopBenefit.BackgroundTransparency = 1
shopBenefit.Text = "+5 к вместимости рюкзака"
shopBenefit.TextColor3 = Color3.fromRGB(120, 220, 120)
shopBenefit.Font = Enum.Font.Gotham
shopBenefit.TextSize = 13
shopBenefit.Parent = shopGui

-- Buy button
local buyBtn = Instance.new("TextButton")
buyBtn.Name = "BuyButton"
buyBtn.Size = UDim2.new(0, 200, 0, 40)
buyBtn.Position = UDim2.new(0.5, -100, 0, 150)
buyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
buyBtn.BorderSizePixel = 0
buyBtn.Text = "Купить"
buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyBtn.Font = Enum.Font.GothamBold
buyBtn.TextSize = 16
buyBtn.Parent = shopGui

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 8)
buyCorner.Parent = buyBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = shopGui

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Reuse the inventory controls; keep touch targets above the movement controls.
if UserInputService.TouchEnabled then
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.Position = UDim2.new(1, -10, 0, 8)
	hud.Size = UDim2.fromOffset(250, 222)
	title.TextScaled = true
	for index, kind in ipairs(Catalog.Order) do
		local row = itemRows[kind]
		row.Button.Size = UDim2.fromOffset(58, 46)
		row.Button.Position = UDim2.fromOffset(6 + (index - 1) * 60, 28)
		row.Button.Description.Visible = false
		row.Name.Size = UDim2.new(1, -2, 0, 23)
		row.Name.Position = UDim2.fromOffset(1, 3)
		row.Name.TextXAlignment = Enum.TextXAlignment.Center
		row.Name.TextSize = 11
		row.Count.Size = UDim2.new(1, 0, 0, 17)
		row.Count.Position = UDim2.fromOffset(0, 27)
		row.Count.TextXAlignment = Enum.TextXAlignment.Center
	end
	totalsLabel.Position = UDim2.fromOffset(6, 77)
	totalsLabel.Size = UDim2.new(1, -12, 0, 20)
	invBarBg.Position = UDim2.fromOffset(8, 101)
	invLabel.Position = UDim2.fromOffset(0, 101)
	dropButton.Position = UDim2.fromOffset(6, 121)
	dropButton.Size = UDim2.fromOffset(118, 46)
	dropButton.TextWrapped = true
	walkButton.Position = UDim2.fromOffset(128, 121)
	walkButton.Size = UDim2.fromOffset(116, 46)
	walkButton.BackgroundTransparency = .1
	walkButton.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	walkButton.TextWrapped = true
	sprintButton.Position=UDim2.fromOffset(6,171);sprintButton.Size=UDim2.fromOffset(118,44)
	cannonLabel.Position=UDim2.fromOffset(128,171);cannonLabel.Size=UDim2.fromOffset(116,44)
	buyBtn.Size = UDim2.fromOffset(200, 46)
	closeBtn.Size = UDim2.fromOffset(44, 44)
	closeBtn.Position = UDim2.new(1, -48, 0, 2)
	shopTitle.Size = UDim2.new(1, -50, 0, 32)
	shopTitle.TextSize = 14
end

-- Player coins label (for shop reference)
local shopCoins = Instance.new("TextLabel")
shopCoins.Name = "ShopCoins"
shopCoins.Size = UDim2.new(1, -24, 0, 20)
shopCoins.Position = UDim2.new(0, 12, 0, 200)
shopCoins.BackgroundTransparency = 1
shopCoins.Text = "У вас: 0 🪙"
shopCoins.TextColor3 = Color3.fromRGB(200, 200, 210)
shopCoins.Font = Enum.Font.Gotham
shopCoins.TextSize = 13
shopCoins.Parent = shopGui

-- Extend the same terminal panel; no separate shop or screen.
shopGui.Size=UDim2.fromOffset(320,300);shopGui.Position=UDim2.new(.5,-160,.5,-150)
shopInfo.Position=UDim2.fromOffset(12,36);shopInfo.Size=UDim2.new(1,-24,0,28)
shopCost.Position=UDim2.fromOffset(12,65);shopBenefit.Position=UDim2.fromOffset(12,90)
buyBtn.Position=UDim2.new(.5,-100,0,112);buyBtn.Size=UDim2.fromOffset(200,44)
shopCoins.Position=UDim2.fromOffset(12,272)
local abilityButtons={}
for index,kind in {"Sprint","Jump"} do
    local button=Instance.new("TextButton");button.Name="Buy"..kind
    button.Size=UDim2.fromOffset(296,44);button.Position=UDim2.fromOffset(12,160+(index-1)*52)
    button.BackgroundColor3=Color3.fromRGB(48,85,105);button.TextColor3=Color3.fromRGB(170,240,235)
    button.Font=Enum.Font.GothamBold;button.TextSize=13;button.TextWrapped=true;button.BorderSizePixel=0;button.Parent=shopGui
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=button
    button.Activated:Connect(function()if button.Active then buyUpgradeEvent:FireServer(kind) end end)
    abilityButtons[kind]=button
end

-- === UPDATE FUNCTIONS ===
updateHUD = function()
	local temporary = player:GetAttribute("TemporaryProgress") == true
	title.Text = temporary and "STUDIO: ПРОГРЕСС НЕ СОХРАНЯЕТСЯ" or "СОКРОВИЩА"
	title.TextSize = temporary and 11 or 14
	title.TextColor3 = temporary and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(200, 200, 210)
	local coins = player:GetAttribute("Coins") or 0
	local maxInv = player:GetAttribute("MaxInventory") or 0
	local used, value = 0, 0
	for _, kind in ipairs(Catalog.Order) do
		local item = Catalog.Items[kind]
		local count = player:GetAttribute("Artifacts_" .. kind) or 0
		used += count * item.Capacity
		value += count * item.Price
		local row = itemRows[kind]
		local selected = kind == selectedKind
		row.Name.Text = (selected and "› " or "  ") .. item.Name
		row.Count.Text = "×" .. count
		row.Button.BackgroundColor3 = selected and Color3.fromRGB(58, 69, 84) or Color3.fromRGB(40, 40, 45)
	end
	totalsLabel.Text = string.format("Банк %d · Несдано %d · Ключи %d", coins, value, player:GetAttribute("Keys") or 0)
	totalsLabel.TextScaled = true
	invLabel.Text = string.format(used > 0 and "Вернись на базу · вес %d / %d" or "Вес: %d / %d", used, maxInv)
	local canDrop = (player:GetAttribute("Artifacts_" .. selectedKind) or 0) > 0
	dropButton.Text = (UserInputService.TouchEnabled and "" or "[G] ") .. "Бросить: " .. Catalog.Items[selectedKind].Name
	dropButton.Active = canDrop
	dropButton.AutoButtonColor = canDrop
	dropButton.TextTransparency = canDrop and 0 or 0.55
	local walking = player:GetAttribute("Walking") == true
	walkButton.Text = (UserInputService.TouchEnabled and "" or "[Ctrl] ") .. "Тихий шаг: " .. (walking and "вкл." or "выкл.")
	walkButton.TextColor3 = walking and Color3.fromRGB(135, 225, 190) or Color3.fromRGB(190, 200, 210)

	-- Update bar fill
	local pct = maxInv > 0 and math.clamp(used / maxInv, 0, 1) or 0
	invBarFill.Size = UDim2.new(pct, 0, 1, 0)

	if used >= maxInv then
		invBarFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
		invLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	elseif used >= maxInv * 0.7 then
		invBarFill.BackgroundColor3 = Color3.fromRGB(220, 180, 80)
		invLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	else
		invBarFill.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
		invLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	end
end

local function updateShopUI(level, cost, currentMax, upgradeAmount, prices)
	shopInfo.Text = string.format("Рюкзак: ур.%d | Вместимость: %d", level, currentMax)
	shopCost.Text = string.format("Стоимость: %d 🪙", cost)
	shopBenefit.Text = string.format("+%d к вместимости рюкзака", upgradeAmount)
	
	local coins = player:GetAttribute("Coins") or 0
	for kind,button in abilityButtons do
		local owned=player:GetAttribute(kind.."Unlocked")==true
		local price=prices[kind]
		button.Text=(kind=="Sprint" and "Суперкроссовки" or "Пружинные ботинки")..(owned and " · Куплено" or " · "..price.." монет")
		button.Active=not owned and coins>=price;button.AutoButtonColor=button.Active
		button.TextTransparency=owned and .25 or 0
	end
	shopCoins.Text = "У вас: " .. coins .. " 🪙"
	
	if coins >= cost then
		buyBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
		buyBtn.Text = "Купить"
		buyBtn.Active = true
		buyBtn.AutoButtonColor = true
	else
		buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		buyBtn.Text = "Недостаточно монет"
		buyBtn.Active = false
		buyBtn.AutoButtonColor = false
	end
end

-- === EVENTS ===
local shopState
player.AttributeChanged:Connect(function()
    updateHUD()
    if shopGui.Visible and shopState then updateShopUI(table.unpack(shopState)) end
end)
-- OpenShop from server
openShopEvent.OnClientEvent:Connect(function(level, cost, currentMax, upgradeAmount, prices)
	shopState = {level, cost, currentMax, upgradeAmount, prices}
	updateShopUI(table.unpack(shopState))
	shopGui.Visible = true
end)

-- Buy button
buyBtn.Activated:Connect(function()
	if not buyBtn.Active then return end
	buyUpgradeEvent:FireServer()
end)

-- Close button
closeBtn.Activated:Connect(function()
	shopGui.Visible = false
end)

-- Notify from server
notifyEvent.OnClientEvent:Connect(function(text, color, duration)
	showNotification(text, color, duration)
end)

local function dropSelected()
	if (player:GetAttribute("Artifacts_" .. selectedKind) or 0) > 0 then
		treasureAction:FireServer("Drop", selectedKind)
	end
end
dropButton.Activated:Connect(dropSelected)

-- Input holds are transient; only the server's Walking attribute drives presentation.
local heldControls = {}
local touchWalking = false
local requestedWalking = false
local function requestWalk(force)
	local walking = touchWalking or heldControls[Enum.KeyCode.LeftControl] == true or heldControls[Enum.KeyCode.RightControl] == true
	if force or walking ~= requestedWalking then
		requestedWalking = walking
		treasureAction:FireServer("Walk", walking)
	end
end
local function clearWalk()
	table.clear(heldControls)
	touchWalking = false
	requestWalk(true)
end
walkButton.Activated:Connect(function()
	if not UserInputService.TouchEnabled then return end
	touchWalking = not touchWalking
	requestWalk(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.G then
		dropSelected()
	elseif key==Enum.KeyCode.LeftShift or key==Enum.KeyCode.RightShift then
		treasureAction:FireServer("Sprint")
	elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
		heldControls[key] = true
		requestWalk(false)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if heldControls[input.KeyCode] then
		heldControls[input.KeyCode] = nil
		requestWalk(false)
	end
end)
UserInputService.WindowFocusReleased:Connect(clearWalk)
player.CharacterAdded:Connect(clearWalk)

-- Attributes replicate independently and update the HUD as soon as they arrive.
updateHUD()

-- One brief goal per join; no new saved tutorial state or blocking dialogue.
local welcomed = false
local function welcome()
	if welcomed or player:GetAttribute("ProgressLoaded") ~= true then return end
	welcomed = true
	showNotification("Войди в логово по золотым стрелкам.\nВозьми сокровище и вернись на базу.", Color3.fromRGB(160, 245, 218), 7)
end
player:GetAttributeChangedSignal("ProgressLoaded"):Connect(welcome)
welcome()

sprintButton.Activated:Connect(function()treasureAction:FireServer("Sprint")end)
local lair=workspace:WaitForChild("SafeBaseScene"):WaitForChild("TreasureLair")
local boundTools=setmetatable({},{__mode="k"})
local function bindTool(tool)
    if not tool:IsA("Tool") or tool.Name~="AncientCannon" or boundTools[tool] then return end
    boundTools[tool]=true
    tool.Activated:Connect(function()
        if tool.Parent~=player.Character then return end
        local muzzle=tool.Handle.Muzzle.WorldPosition
        local aim=UserInputService.TouchEnabled and workspace.CurrentCamera.CFrame.LookVector
            or player:GetMouse().Hit.Position-muzzle
        if aim.Magnitude>.1 then treasureAction:FireServer("FireCannon",aim.Unit) end
    end)
end
local function watchCharacter(character)
    character.ChildAdded:Connect(bindTool)
    for _,child in character:GetChildren() do bindTool(child) end
end
local backpack=player:WaitForChild("Backpack");backpack.ChildAdded:Connect(bindTool)
for _,child in backpack:GetChildren() do bindTool(child) end
player.CharacterAdded:Connect(watchCharacter);if player.Character then watchCharacter(player.Character) end
local previousSprint=false
RunService.RenderStepped:Connect(function()
    local owned=player:GetAttribute("SprintUnlocked")==true
    local sprinting=player:GetAttribute("Sprinting")==true
    local remaining=math.max(0,(player:GetAttribute("SprintReadyAt") or 0)-workspace:GetServerTimeNow())
    sprintButton.Text=not owned and "Кроссовки\nв магазине" or sprinting and "Ускорение!" or remaining>0 and string.format("Откат %.0f с",math.ceil(remaining))
        or (UserInputService.TouchEnabled and "Ускорение" or "[Shift] Ускорение")
    sprintButton.Active=owned and remaining==0;sprintButton.AutoButtonColor=sprintButton.Active
    local charges=lair:GetAttribute("CannonCharges") or 0
    cannonLabel.Text=lair:GetAttribute("CannonFired") and "Пушка\nразряжена" or string.format("Пушка\nзаряды %d / 2",charges)
    if sprinting~=previousSprint then
        previousSprint=sprinting
        TweenService:Create(workspace.CurrentCamera,TweenInfo.new(.2),{FieldOfView=sprinting and 82 or 70}):Play()
    end
end)
