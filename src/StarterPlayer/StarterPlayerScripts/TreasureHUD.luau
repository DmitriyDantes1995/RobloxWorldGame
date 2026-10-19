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
local function shopObject(class,name,parent,properties)
    local object=Instance.new(class)
    object.Name=name
    for key,value in properties do object[key]=value end
    object.Parent=parent
    return object
end
local function round(object,radius)
    shopObject("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius)})
end
local ink=Color3.fromRGB(237,231,211)
local gold=Color3.fromRGB(234,190,95)
local shopGui=shopObject("Frame","ShopUI",gui,{
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-24,1,-24),
    BackgroundColor3=Color3.fromRGB(27,35,39),BorderSizePixel=0,Visible=false,ZIndex=5})
round(shopGui,14)
shopObject("UISizeConstraint","SizeLimit",shopGui,{MaxSize=Vector2.new(680,660)})
shopObject("UIStroke","Border",shopGui,{Color=Color3.fromRGB(128,105,62),Thickness=2})
local shopTitle=shopObject("TextLabel","ShopTitle",shopGui,{
    Position=UDim2.fromOffset(20,10),Size=UDim2.new(1,-84,0,28),BackgroundTransparency=1,
    Text="ЛАВКА ИСКАТЕЛЯ",TextColor3=gold,Font=Enum.Font.GothamBold,TextSize=20,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6})
local shopCoins=shopObject("TextLabel","ShopCoins",shopGui,{
    Position=UDim2.fromOffset(20,41),Size=UDim2.new(1,-40,0,25),BackgroundTransparency=1,
    Text="",TextColor3=ink,Font=Enum.Font.GothamMedium,TextSize=15,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6})
local closeBtn=shopObject("TextButton","CloseButton",shopGui,{
    Position=UDim2.new(1,-54,0,10),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(68,76,76),
    Text="×",TextColor3=ink,Font=Enum.Font.GothamBold,TextSize=26,BorderSizePixel=0,ZIndex=6})
round(closeBtn,8)
local shopScroll=shopObject("ScrollingFrame","Products",shopGui,{
    Position=UDim2.fromOffset(12,76),Size=UDim2.new(1,-24,1,-88),BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=5,ScrollBarImageColor3=gold,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=6})
shopObject("UIPadding","Padding",shopScroll,{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,10),PaddingBottom=UDim.new(0,8)})
local grid=shopObject("UIGridLayout","Grid",shopScroll,{CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder})
local products={
    {Kind="Key",Name="Ключ сокровищницы",Copy="Открой закрытый тайник",Color=gold},
    {Kind="Backpack",Name="Походный рюкзак",Copy="Больше добычи за вылазку",Color=Color3.fromRGB(223,158,99)},
    {Kind="Sprint",Name="Суперкроссовки",Copy="Рывок скорости · Shift",Color=Color3.fromRGB(99,221,189)},
    {Kind="Jump",Name="Пружинные ботинки",Copy="Выше прыжок · новые пути",Color=Color3.fromRGB(147,185,255)},
}
local cards={}
local shopState
local pendingUntil=0
local refreshShop
local previews=ReplicatedStorage:WaitForChild("ShopPreviews")
for index,product in ipairs(products) do
    local card=shopObject("Frame",product.Kind,shopScroll,{LayoutOrder=index,BackgroundColor3=Color3.fromRGB(40,49,52),BorderSizePixel=0,ZIndex=6})
    round(card,10)
    local view=shopObject("ViewportFrame","Preview",card,{
        Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,122),BackgroundColor3=Color3.fromRGB(21,29,34),
        BorderSizePixel=0,Ambient=Color3.fromRGB(168,176,191),LightColor=Color3.fromRGB(255,235,204),
        LightDirection=Vector3.new(-1,-1,-1),ZIndex=7})
    round(view,8)
    shopObject("UIStroke","PreviewBorder",view,{Color=product.Color,Thickness=1,Transparency=.45})
    local world=shopObject("WorldModel","Merchandise",view,{})
    local model=previews:WaitForChild(product.Kind):Clone()
    for _,object in model:GetDescendants() do
        if object:IsA("BasePart") then
            object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
        elseif object:IsA("LuaSourceContainer") then object:Destroy() end
    end
    model.Parent=world
    local center,size=model:GetBoundingBox()
    local camera=shopObject("Camera","Camera",view,{FieldOfView=35})
    view.CurrentCamera=camera
    local radius=size.Magnitude*.5
    local distance=radius/math.sin(math.rad(camera.FieldOfView*.5))*1.12
    camera.CFrame=CFrame.lookAt(center.Position+Vector3.new(.7,.45,1).Unit*distance,center.Position)
    local name=shopObject("TextLabel","ProductName",card,{
        Position=UDim2.fromOffset(12,139),Size=UDim2.new(1,-24,0,36),BackgroundTransparency=1,
        Text=product.Name,TextColor3=ink,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        Font=Enum.Font.GothamBold,TextSize=16,ZIndex=7})
    local copy=shopObject("TextLabel","Description",card,{
        Position=UDim2.fromOffset(12,177),Size=UDim2.new(1,-24,0,32),BackgroundTransparency=1,
        Text=product.Copy,TextColor3=Color3.fromRGB(177,191,191),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=12,ZIndex=7})
    local status=shopObject("TextLabel","Status",card,{
        Position=UDim2.fromOffset(12,211),Size=UDim2.new(1,-24,0,25),BackgroundTransparency=1,
        Text="",TextColor3=product.Color,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.GothamMedium,TextSize=13,ZIndex=7})
    local button=shopObject("TextButton","Buy",card,{
        Position=UDim2.fromOffset(10,241),Size=UDim2.new(1,-20,0,46),BackgroundColor3=Color3.fromRGB(74,123,105),
        Text="",TextColor3=ink,Font=Enum.Font.GothamBold,TextSize=14,BorderSizePixel=0,ZIndex=7})
    round(button,7)
    cards[product.Kind]={Button=button,Status=status}
    button.Activated:Connect(function()
        if not button.Active or os.clock()<pendingUntil then return end
        -- One intentional purchase at a time, including repeatable keys.
        pendingUntil=os.clock()+1
        refreshShop()
        buyUpgradeEvent:FireServer(product.Kind)
        task.delay(1,function()refreshShop()end)
    end)
end
local function layoutShop()
    local width=shopScroll.AbsoluteSize.X-14
    local columns=width>=480 and 2 or 1
    grid.CellSize=UDim2.new(0,math.floor((width-(columns-1)*12)/columns),0,298)
    shopTitle.TextSize=shopGui.AbsoluteSize.X<400 and 16 or 20
end
shopScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutShop)
layoutShop()

-- Reuse the inventory controls; keep touch targets above the movement controls.
if UserInputService.TouchEnabled then
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.Position = UDim2.new(1, -10, 0, 8)
	hud.Size = UDim2.fromOffset(250, 222)
	title.TextScaled = true
	for index, kind in ipairs(Catalog.Order) do
		local row = itemRows[kind]
		row.Button.Size = UDim2.fromOffset(46, 46)
		row.Button.Position = UDim2.fromOffset(6 + (index - 1) * 48, 28)
		row.Button.Description.Visible = false
		row.Name.Size = UDim2.new(1, -2, 0, 23)
		row.Name.Position = UDim2.fromOffset(1, 3)
		row.Name.TextXAlignment = Enum.TextXAlignment.Center
		row.Name.TextSize = 10
		row.Name.TextScaled = true
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

else
	local extra = (#Catalog.Order - 4) * 30
	hud.Size += UDim2.fromOffset(0, extra)
	for _,control in {totalsLabel, invBarBg, invLabel, dropButton, walkButton, sprintButton, cannonLabel} do
		control.Position += UDim2.fromOffset(0, extra)
	end
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

refreshShop=function()
    if not shopState then return end
    local coins=player:GetAttribute("Coins") or 0
    local level=player:GetAttribute("BackpackLevel") or 0
    shopCoins.Text=string.format("Банк: %d монет",coins)
    for _,product in ipairs(products) do
        local kind=product.Kind
        local card=cards[kind]
        local owned=(kind=="Sprint" or kind=="Jump") and player:GetAttribute(kind.."Unlocked")==true
        local price=kind=="Backpack" and shopState.Cost or shopState.Prices[kind]
        local pending=os.clock()<pendingUntil
        local enabled=not owned and not pending and coins>=price and player:GetAttribute("ProgressLoaded")==true
        card.Status.Text=kind=="Key" and string.format("В наличии: %d",player:GetAttribute("Keys") or 0)
            or kind=="Backpack" and string.format("Уровень %d · +%d места",level,shopState.Amount)
            or owned and "Приобретено навсегда" or "Постоянное улучшение"
        card.Button.Text=owned and "Приобретено" or pending and "Покупка…"
            or coins<price and string.format("Нужно %d монет",price) or string.format("Купить · %d монет",price)
        card.Button.Active=enabled
        card.Button.AutoButtonColor=enabled
        card.Button.BackgroundColor3=enabled and Color3.fromRGB(64,123,101) or Color3.fromRGB(60,68,70)
        card.Button.TextColor3=owned and Color3.fromRGB(136,216,180) or enabled and ink or Color3.fromRGB(164,172,173)
    end
end

-- Attributes update balances and ownership immediately; prices come only from the server.
player.AttributeChanged:Connect(function()
    updateHUD()
    refreshShop()
end)
openShopEvent.OnClientEvent:Connect(function(level,cost,currentMax,upgradeAmount,prices)
    shopState={Level=level,Cost=cost,Capacity=currentMax,Amount=upgradeAmount,Prices=prices}
    refreshShop()
    shopGui.Visible=true
end)
closeBtn.Activated:Connect(function()shopGui.Visible=false end)

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
