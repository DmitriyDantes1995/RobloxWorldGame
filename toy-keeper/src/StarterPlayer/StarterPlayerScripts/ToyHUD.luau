local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ProximityPromptService=game:GetService("ProximityPromptService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local Catalog=require(ReplicatedStorage:WaitForChild("ToyCatalog"))
local signal=ReplicatedStorage:WaitForChild("ToySignal")
local scene=workspace:WaitForChild("ToyKeeper")
local gui=Instance.new("ScreenGui")
gui.Name="ToyKeeperHUD";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;gui.Parent=player:WaitForChild("PlayerGui")
local function rounded(obj)
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,12);c.Parent=obj
end
local function panel(name,size,pos,parent)
    local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=Color3.fromRGB(25,29,48)
    f.BackgroundTransparency=.08;f.BorderSizePixel=0;f.Parent=parent or gui;rounded(f);return f
end
local function text(name,words,size,pos,parent,fontSize)
    local t=Instance.new("TextLabel");t.Name=name;t.Text=words;t.Size=size;t.Position=pos;t.BackgroundTransparency=1
    t.TextColor3=Color3.fromRGB(245,242,230);t.Font=Enum.Font.GothamMedium;t.TextSize=fontSize or 14
    t.TextWrapped=true;t.Parent=parent;return t
end
local function button(name,words,size,pos,parent,callback)
    local b=Instance.new("TextButton");b.Name=name;b.Text=words;b.Size=size;b.Position=pos
    b.BackgroundColor3=Color3.fromRGB(68,108,136);b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold
    b.TextSize=13;b.TextWrapped=true;b.BorderSizePixel=0;b.Parent=parent;rounded(b);b.Activated:Connect(callback);return b
end
local status=panel("Status",UDim2.fromOffset(280,74),UDim2.fromOffset(12,10))
local bank=text("Bank","TOY KEEPER",UDim2.new(1,-16,0,34),UDim2.fromOffset(8,2),status,18)
local movement=text("Movement","Загрузка…",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,38),status,13)
local temp=text("Temporary","",UDim2.new(1,-20,0,18),UDim2.fromOffset(10,85),gui,11)
temp.TextXAlignment=Enum.TextXAlignment.Left;temp.TextColor3=Color3.fromRGB(255,210,128)
local goal=text("Goal","Удерживай E у подарка → в свой сад → открыть",UDim2.new(1,-24,0,28),UDim2.new(0,12,1,-152),gui,14)
local toast=panel("Toast",UDim2.fromOffset(430,50),UDim2.new(.5,-215,1,-210))
local toastLabel=text("Message","",UDim2.new(1,-18,1,-8),UDim2.fromOffset(9,4),toast,14)
local toastUntil=0;toast.Visible=false
local function notify(words,duration)
    toastLabel.Text=words;toast.Visible=true;toastUntil=os.clock()+(duration or 3.5)
end
local chase=panel("Chase",UDim2.fromOffset(410,40),UDim2.new(.5,-205,0,106))
chase.BackgroundColor3=Color3.fromRGB(135,51,66);chase.Visible=false
local chaseLabel=text("Message","",UDim2.new(1,-12,1,0),UDim2.fromOffset(6,0),chase,15)
local homeArrow=text("HomeArrow","▲",UDim2.fromOffset(34,34),UDim2.new(.5,-17,1,-194),gui,28)
local homeDistance=text("HomeDistance","",UDim2.fromOffset(160,22),UDim2.new(.5,-80,1,-167),gui,12)
homeArrow.TextColor3=Color3.fromRGB(151,255,207)
local collection=panel("Collection",UDim2.fromOffset(520,440),UDim2.new(.5,-260,.5,-220))
collection.Visible=false;collection.ZIndex=5
text("Title","КОЛЛЕКЦИЯ • до четырёх гуляющих вариантов",UDim2.new(1,-70,0,44),UDim2.fromOffset(10,0),collection,14)
button("Close","×",UDim2.fromOffset(44,44),UDim2.new(1,-50,0,2),collection,function()collection.Visible=false end)
local rows=Instance.new("ScrollingFrame");rows.Name="Toys";rows.Size=UDim2.new(1,-20,1,-58)
rows.Position=UDim2.fromOffset(10,50);rows.BackgroundTransparency=1;rows.BorderSizePixel=0;rows.ScrollBarThickness=5;rows.Parent=collection
local packets={};local visuals={}
local visualFolder=Instance.new("Folder");visualFolder.Name="LocalLivingToys";visualFolder.Parent=workspace
local function refreshRows()
    for _,v in rows:GetChildren() do v:Destroy() end
    local packet=packets[player.UserId]
    local entries=packet and packet.Entries or {}
    local sorted=Catalog.CopyCollection(entries)
    table.sort(sorted,function(a,b)
        local ia,ib=table.find(Catalog.ToyOrder,a.Toy),table.find(Catalog.ToyOrder,b.Toy)
        return ia==ib and a.SizeMultiplier>b.SizeMultiplier or ia<ib
    end)
    local n=0
    for _,entry in sorted do
        n+=1
        local key=Catalog.Key(entry.Toy,entry.SizeMultiplier)
        local toy=Catalog.Toys[entry.Toy]
        local chosen=table.find(packet.Selected,key)~=nil
        local b=button(key,(chosen and "✓ " or "")..toy.Name.."  ×"..entry.SizeMultiplier.."  •  "..entry.Count.." шт.\n"..Catalog.Gifts[toy.Rarity].Name.."  +"..Catalog.ToyIncome(entry.Toy,entry.SizeMultiplier).."/с за штуку",UDim2.new(1,-8,0,54),UDim2.fromOffset(0,(n-1)*58),rows,function()signal:FireServer("Select",key)end)
        b.BackgroundColor3=Catalog.Gifts[toy.Rarity].Color:Lerp(Color3.fromRGB(25,29,48),chosen and .3 or .65)
    end
    if n==0 then text("Empty","Здесь будут твои живые игрушки.\nДубликаты тоже дают доход; каждый размер учитывается отдельно.",UDim2.new(1,-10,0,90),UDim2.fromOffset(0,10),rows,15) end
    rows.CanvasSize=UDim2.fromOffset(0,math.max(100,n*58))
end
local odds=panel("Odds",UDim2.fromOffset(520,430),UDim2.new(.5,-260,.5,-215));odds.Visible=false;odds.ZIndex=6
text("Title","ШАНСЫ • результат выбирает сервер",UDim2.new(1,-70,0,44),UDim2.fromOffset(10,0),odds,14)
button("Close","×",UDim2.fromOffset(44,44),UDim2.new(1,-50,0,2),odds,function()odds.Visible=false end)
local oddsRows=Instance.new("ScrollingFrame");oddsRows.Size=UDim2.new(1,-20,1,-58);oddsRows.Position=UDim2.fromOffset(10,50)
oddsRows.BackgroundTransparency=1;oddsRows.BorderSizePixel=0;oddsRows.ScrollBarThickness=5;oddsRows.CanvasSize=UDim2.fromOffset(0,440);oddsRows.Parent=odds
for i,rarity in Catalog.Order do
    local gift=Catalog.Gifts[rarity];local words={}
    for _,entry in gift.Contents do table.insert(words,Catalog.Toys[entry[1]].Name.." "..entry[2].."%") end
    local l=text(rarity,gift.Name..": "..table.concat(words," / "),UDim2.new(1,-8,0,58),UDim2.fromOffset(0,(i-1)*62),oddsRows,13)
    l.TextColor3=gift.Color
end
local sizes={}
for _,s in Catalog.Sizes do
    local range=s.Min==s.Max and string.format("×%.2f",s.Min) or string.format("×%.2f–%.2f",s.Min,s.Max)
    table.insert(sizes,range.." • "..s.Weight.."%")
end
text("Sizes","СЛУЧАЙНЫЙ РАЗМЕР • шаг 0.01\n"..table.concat(sizes," / ").."\nРост X при открытии не меняет результат.",UDim2.new(1,-8,0,86),UDim2.fromOffset(0,252),oddsRows,13)
local zoneOdds={}
for _,zone in Catalog.Zones do
    local weights={}
    for _,rarity in Catalog.Order do table.insert(weights,tostring(zone.Weights[rarity])) end
    table.insert(zoneOdds,zone.Name..": "..table.concat(weights,"/"))
end
text("Spawn","Подарки C/R/E/L (%):\n"..table.concat(zoneOdds," • "),UDim2.new(1,-8,0,90),UDim2.fromOffset(0,342),oddsRows,12)
local actions=panel("Actions",UDim2.fromOffset(520,64),UDim2.new(.5,-260,1,-76))
local openButton=button("Open","ОТКРЫТЬ",UDim2.fromOffset(120,48),UDim2.fromOffset(8,8),actions,function()signal:FireServer("Open")end)
local speedButton=button("Speed","🏃 СКОРОСТЬ",UDim2.fromOffset(120,48),UDim2.fromOffset(136,8),actions,function()signal:FireServer("Speed")end)
local strengthButton=button("Strength","💪 СИЛА",UDim2.fromOffset(120,48),UDim2.fromOffset(264,8),actions,function()signal:FireServer("Strength")end)
speedButton.BackgroundColor3=Color3.fromRGB(43,127,139)
speedButton.TextSize=11
strengthButton.BackgroundColor3=Color3.fromRGB(143,95,60)
strengthButton.TextSize=11
local collectionButton=button("Collection","КОЛЛЕКЦИЯ",UDim2.fromOffset(120,48),UDim2.fromOffset(392,8),actions,function()collection.Visible=not collection.Visible;odds.Visible=false end)
button("OddsButton","Шансы",UDim2.fromOffset(82,44),UDim2.new(1,-94,0,10),gui,function()odds.Visible=not odds.Visible;collection.Visible=false end)
local dropButton=button("Drop","Бросить [G]",UDim2.fromOffset(110,44),UDim2.new(1,-122,0,60),gui,function()signal:FireServer("Drop")end)
local revealPanel=panel("Opening",UDim2.fromOffset(620,520),UDim2.new(.5,-310,.5,-260));revealPanel.Visible=false;revealPanel.ZIndex=10
revealPanel.BackgroundTransparency=0
local multiplier=text("Multiplier","×1.00",UDim2.new(1,-20,0,42),UDim2.fromOffset(10,5),revealPanel,38)
local viewport=Instance.new("ViewportFrame");viewport.Name="Stage";viewport.Size=UDim2.new(1,-20,1,-145);viewport.Position=UDim2.fromOffset(10,48)
viewport.BackgroundTransparency=1;viewport.Ambient=Color3.fromRGB(185,190,218);viewport.LightColor=Color3.fromRGB(255,237,204)
viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.Parent=revealPanel
local stage=Instance.new("WorldModel");stage.Parent=viewport
local stageCamera=Instance.new("Camera");stageCamera.FieldOfView=40;stageCamera.Parent=viewport;viewport.CurrentCamera=stageCamera
local resultLabel=text("Result","",UDim2.new(1,-20,0,50),UDim2.new(0,10,1,-96),revealPanel,15)
local reveal
local function clearReveal()
    stage:ClearAllChildren();reveal=nil;revealPanel.Visible=false
    for _,v in revealPanel:GetChildren() do if v.Name=="Confetti" then v:Destroy() end end
end
local function skip()
    if not reveal then return end
    local shownAt=reveal.growSeconds+.25
    if os.clock()-reveal.started<shownAt then reveal.started=os.clock()-shownAt else clearReveal() end
end
button("Skip","Пропустить / готово",UDim2.new(1,-20,0,42),UDim2.new(0,10,1,-46),revealPanel,skip)
local flash=Instance.new("Frame");flash.Name="Flash";flash.BackgroundColor3=Color3.new(1,1,1);flash.BackgroundTransparency=1
flash.Size=UDim2.fromScale(1,1);flash.BorderSizePixel=0;flash.ZIndex=12;flash.Parent=revealPanel
local function openReveal(data)
    clearReveal();collection.Visible=false;odds.Visible=false;toast.Visible=false
    multiplier.Text="×0.10";multiplier.TextColor3=Catalog.Gifts[data.Gift].Color
    flash.BackgroundTransparency=1
    local gift=ReplicatedStorage.GiftModels[data.Gift]:Clone()
    local toy=ReplicatedStorage.ToyModels[data.Toy]:Clone()
    for _,m in {gift,toy} do
        for _,p in m:GetDescendants() do
            if p:IsA("ProximityPrompt") or p:IsA("PointLight") or p:IsA("Sparkles") then p:Destroy()
            elseif p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false end
        end
        m.Parent=stage
    end
    local giftBox,giftSize=gift:GetBoundingBox()
    local giftLift=gift:GetPivot().Position.Y-(giftBox.Position.Y-giftSize.Y/2)
    local offsets={}
    for _,part in gift:GetDescendants() do
        if part:IsA("BasePart") then offsets[part]={cf=gift:GetPivot():ToObjectSpace(part.CFrame),transparency=part.Transparency} end
    end
    local _,baseToySize=toy:GetBoundingBox()
    toy:ScaleTo(data.SizeMultiplier)
    local box,size=toy:GetBoundingBox()
    local lift=toy:GetPivot().Position.Y-(box.Position.Y-size.Y/2)
    gift:ScaleTo(.1)
    gift:PivotTo(CFrame.new(0,giftLift*.1,0))
    toy:PivotTo(CFrame.new(0,-200,0))
    reveal={data=data,gift=gift,toy=toy,lift=lift,height=size.Y,giftSize=giftSize,giftLift=giftLift,offsets=offsets,baseToySize=baseToySize,started=os.clock(),growSeconds=3+7*math.clamp((data.SizeMultiplier-1)/3,0,1),confetti={}}
    for i=1,data.SizeMultiplier>=2.5 and 28 or 12 do
        local bit=Instance.new("Frame");bit.Name="Confetti";bit.Size=UDim2.fromOffset(5+(i%3)*2,9)
        bit.BorderSizePixel=0;bit.BackgroundColor3=Catalog.Gifts[Catalog.Order[i%4+1]].Color;bit.Visible=false;bit.ZIndex=13;bit.Parent=revealPanel
        table.insert(reveal.confetti,{part=bit,vx=math.sin(i*2.4)*(90+i*3),vy=-150-(i%7)*20,spin=i*49})
    end
    resultLabel.Text="";revealPanel.Visible=true
end
local function rebuild(packet)
    local old=visuals[packet.UserId]
    if old then for _,v in old do v.model:Destroy() end end
    visuals[packet.UserId]={}
    local base=scene.Bases:FindFirstChild(packet.BaseId)
    if not base then return end
    for i,key in packet.Selected do
        local entry
        for _,v in packet.Entries do if Catalog.Key(v.Toy,v.SizeMultiplier)==key then entry=v;break end end
        if entry then
            local model=ReplicatedStorage.ToyModels[entry.Toy]:Clone();model:ScaleTo(math.min(entry.SizeMultiplier,Catalog.WorldScaleLimit));model.Parent=visualFolder
            local box,size=model:GetBoundingBox();local lift=model:GetPivot().Position.Y-(box.Position.Y-size.Y/2)
            local limbs={}
            for _,part in model:GetChildren() do if part:IsA("BasePart") and (part.Name=="Hand" or part.Name=="Foot" or part.Name=="Segment" or part.Name=="Wing") then
                table.insert(limbs,{part=part,offset=model:GetPivot():ToObjectSpace(part.CFrame)})
            end end
            table.insert(visuals[packet.UserId],{model=model,center=base.Garden.Position,phase=i*1.7,lift=lift,motion=Catalog.Toys[entry.Toy].Motion,limbs=limbs})
        end
    end
end
local giftModels={}
local captureVisuals={}
local captured={}
local escapedUntil=0
local impactUntil=0
local Debris=game:GetService("Debris")
local function caughtEffect(position)
    impactUntil=os.clock()+.4
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local a=Instance.new("Attachment");a.Position=Vector3.new(-.8,.4,0);a.Parent=root
        local b=Instance.new("Attachment");b.Position=Vector3.new(.8,.4,0);b.Parent=root
        local trail=Instance.new("Trail");trail.Name="ThrowTrail";trail.Attachment0=a;trail.Attachment1=b
        trail.Lifetime=.25;trail.LightEmission=1;trail.Color=ColorSequence.new(Color3.fromRGB(255,230,155))
        trail.Transparency=NumberSequence.new(0,1);trail.Parent=root
        Debris:AddItem(trail,.9);Debris:AddItem(a,1.2);Debris:AddItem(b,1.2)
    end
    local burst=Instance.new("Part");burst.Name="Impact";burst.Shape=Enum.PartType.Ball;burst.Size=Vector3.one*5
    burst.CFrame=CFrame.new(position);burst.Anchored=true;burst.CanCollide=false;burst.CanQuery=false;burst.CanTouch=false
    burst.Material=Enum.Material.Neon;burst.Color=Color3.fromRGB(255,219,123);burst.Transparency=.35;burst.Parent=visualFolder
    game:GetService("TweenService"):Create(burst,TweenInfo.new(.25),{Size=Vector3.one*13,Transparency=1}):Play()
    Debris:AddItem(burst,.3)
end
signal.OnClientEvent:Connect(function(action,data)
    if action=="Notify" then notify(data)
    elseif action=="Opened" then openReveal(data)
    elseif action=="Captured" then captured[data]=true
    elseif action=="Caught" then caughtEffect(data)
    elseif action=="Escaped" then escapedUntil=os.clock()+2.5
    elseif action=="Collection" then packets[data.UserId]=data;rebuild(data);if data.UserId==player.UserId then refreshRows() end
    elseif action=="CollectionRemoved" then
        if visuals[data] then for _,v in visuals[data] do v.model:Destroy() end end
        visuals[data]=nil;packets[data]=nil
    end
end)
-- Default Roblox prompts keep E, controller and native touch hold behavior.
local heldPrompts={}
local stoppedCaptures={}
local removeCaptureVisual
local gifts=scene:WaitForChild("Gifts")
local function watchGift(model)
    if not model:IsA("Model")then return end
    giftModels[model.Name]=model
    model.Destroying:Connect(function()if giftModels[model.Name]==model then giftModels[model.Name]=nil end end)
end
gifts.ChildAdded:Connect(watchGift)
for _,model in gifts:GetChildren()do watchGift(model)end
local function refreshPrompt(prompt)
    local model=prompt:FindFirstAncestorOfClass("Model")
    if model and model.Parent==gifts and not heldPrompts[prompt] then
        -- Native Triggered ends holding locally. Leave time for server event delivery;
        -- the authoritative progress/award still finishes at the exact configured duration.
        prompt.HoldDuration=Catalog.CaptureDuration(model:GetAttribute("Rarity"),player:GetAttribute("StrengthLevel")or 0)+Catalog.Capture.PromptReleaseBuffer
    end
end
ProximityPromptService.PromptShown:Connect(refreshPrompt)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    heldPrompts[prompt]=true
    local model=prompt:FindFirstAncestorOfClass("Model")
    if model then stoppedCaptures[model]=nil end
end)
local function stopLocalCapture(prompt)
    heldPrompts[prompt]=nil
    local model=prompt:FindFirstAncestorOfClass("Model")
    if model and model.Parent==gifts then
        stoppedCaptures[model]=true
        local v=captureVisuals[model]
        if v and model:GetAttribute("CaptureUserId")==player.UserId then removeCaptureVisual(model,v)end
    end
end
ProximityPromptService.PromptButtonHoldEnded:Connect(stopLocalCapture)
ProximityPromptService.PromptHidden:Connect(stopLocalCapture)
gifts.ChildRemoved:Connect(function(model)stoppedCaptures[model]=nil end)
player:GetAttributeChangedSignal("StrengthLevel"):Connect(function()
    for _,model in giftModels do refreshPrompt(model.Box.Prompt)end
end)
removeCaptureVisual=function(model,v)
    if model.Parent then for _,part in model:GetDescendants()do
        if part:IsA("BasePart")then part.LocalTransparencyModifier=0 end
    end end
    for _,attachment in v.anchors do attachment:Destroy()end
    v.proxy:Destroy();captureVisuals[model]=nil
end
local function makeCaptureVisual(model)
    local proxy=model:Clone();proxy.Name="PullingGift"
    for _,part in proxy:GetDescendants()do
        if part:IsA("ProximityPrompt")or part:IsA("BillboardGui")then part:Destroy()
        elseif part:IsA("BasePart")then
            part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
        end
    end
    proxy.Parent=visualFolder
    for _,part in model:GetDescendants()do if part:IsA("BasePart")then part.LocalTransparencyModifier=1 end end
    local v={proxy=proxy,origin=model:GetPivot(),anchors={}}
    for _,side in {-1,1}do
        local anchor=Instance.new("Attachment");anchor.Position=Vector3.new(side*2.1,-2.5,0);anchor.Parent=model.Box
        table.insert(v.anchors,anchor)
        local endPoint=Instance.new("Attachment");endPoint.Position=Vector3.new(side*2.1,.1,0);endPoint.Parent=proxy.Box
        local ribbon=Instance.new("Beam");ribbon.Attachment0=anchor;ribbon.Attachment1=endPoint
        ribbon.Width0=.22;ribbon.Width1=.22;ribbon.FaceCamera=true;ribbon.Color=ColorSequence.new(Color3.fromRGB(255,226,163))
        ribbon.Parent=proxy.Box
    end
    local billboard=Instance.new("BillboardGui");billboard.Name="CaptureProgress";billboard.Size=UDim2.fromOffset(174,44)
    billboard.StudsOffsetWorldSpace=Vector3.new(0,4.3,0);billboard.AlwaysOnTop=true;billboard.Adornee=proxy.Box;billboard.Parent=proxy
    local bg=panel("Progress",UDim2.fromScale(1,1),UDim2.fromScale(0,0),billboard)
    v.label=text("Progress","",UDim2.new(1,0,0,27),UDim2.fromScale(0,0),bg,13)
    local track=panel("Track",UDim2.new(1,-16,0,8),UDim2.fromOffset(8,30),bg)
    v.fill=panel("Fill",UDim2.fromScale(0,1),UDim2.fromScale(0,0),track)
    v.fill.BackgroundColor3=Color3.fromRGB(255,210,105)
    captureVisuals[model]=v
    return v
end
local function releaseBurst(model)
    local glow=Instance.new("Highlight");glow.FillColor=Color3.fromRGB(255,233,150);glow.FillTransparency=.35
    glow.OutlineTransparency=1;glow.Adornee=model;glow.Parent=visualFolder
    TweenService:Create(glow,TweenInfo.new(.22),{FillTransparency=1}):Play();Debris:AddItem(glow,.25)
end
UserInputService.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.G then signal:FireServer("Drop")
    elseif input.KeyCode==Enum.KeyCode.Space and reveal then skip() end
end)
local function update()
    local level=player:GetAttribute("SpeedLevel") or 0
    bank.Text=player:GetAttribute("ProgressLoaded") and "● "..(player:GetAttribute("Coins") or 0).."  +"..(player:GetAttribute("Income") or 0).."/с" or "Загрузка профиля…"
    local strengthLevel=player:GetAttribute("StrengthLevel") or 0
    movement.Text=string.format("🏃 %.1f  •  💪 Сила %d",Catalog.SpeedForLevel(level),strengthLevel)
    temp.Text=player:GetAttribute("TemporaryProgress") and "STUDIO • прогресс исчезнет после Stop" or ""
    local pending=player:GetAttribute("PendingGift") or "";local carry=player:GetAttribute("CarriedGift") or ""
    openButton.Text=pending~="" and "ОТКРЫТЬ [E]" or "НАЙДИ ПОДАРОК"
    local speedPrice=Catalog.SpeedPrice(level);local strengthPrice=Catalog.StrengthPrice(strengthLevel)
    speedButton.Text="🏃 Скорость "..level.."\nКупить • "..speedPrice
    strengthButton.Text=strengthPrice and "💪 Сила "..strengthLevel.." • "..strengthPrice.."\nБыстрее забирай подарки" or "💪 СИЛА MAX\nБыстрее забирай подарки"
    dropButton.Visible=carry~=""
    goal.Text=pending~="" and "Подарок дома! Открой у бирюзового стола." or carry~="" and "Беги в свой светящийся сад!" or "Удерживай E / кнопку у подарка → в свой сад → открыть"
end
player.AttributeChanged:Connect(function(name)update();if name=="ProgressLoaded" and player:GetAttribute(name) then signal:FireServer("Sync") end end)
local function resize()
    local v=workspace.CurrentCamera.ViewportSize
    local aw=math.min(520,v.X-20);actions.Size=UDim2.fromOffset(aw,64);actions.Position=UDim2.new(.5,-aw/2,1,-76)
    local bw=(aw-40)/4
    for i,b in {openButton,speedButton,strengthButton,collectionButton} do b.Size=UDim2.fromOffset(bw,48);b.Position=UDim2.fromOffset(8+(i-1)*(bw+8),8) end
    for _,p in {collection,odds,revealPanel} do
        local w=math.min(p==revealPanel and 620 or 520,v.X-24);local h=math.min(p==revealPanel and 520 or 440,v.Y-24)
        p.Size=UDim2.fromOffset(w,h);p.Position=UDim2.new(.5,-w/2,.5,-h/2)
    end
    local tw=math.min(430,v.X-24);toast.Size=UDim2.fromOffset(tw,44);toast.Position=UDim2.new(.5,-tw/2,1,v.Y<480 and -130 or -252)
    local cw=math.min(410,v.X-24);chase.Size=UDim2.fromOffset(cw,40);chase.Position=UDim2.new(.5,-cw/2,0,106)
    status.Size=UDim2.fromOffset(math.min(280,v.X-116),74)
    homeArrow.Position=v.Y<480 and UDim2.new(.5,-17,0,148) or UDim2.new(.5,-17,1,-194)
    homeDistance.Position=v.Y<480 and UDim2.new(.5,-80,0,180) or UDim2.new(.5,-80,1,-167)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize();update();refreshRows();signal:FireServer("Sync")
-- Presentation only: the server has already fixed data.SizeMultiplier.
local function revealScale(r,t)
    local target=r.data.SizeMultiplier
    local alpha=math.clamp(t/r.growSeconds,0,1)
    if alpha>=1 then return target end
    -- Positive progress only: grow from a small box and ease into the exact
    -- awarded size. Never show a larger multiplier and then take it away.
    local value=.1+(target-.1)*(1-(1-alpha)^1.35)
    return math.min(target,math.round(value*100)/100)
end
-- Short procedural effort pose, scaled to the actual capture; no movement lock.
local posed={}
RunService.PreSimulation:Connect(function()
    local active={}
    local now=workspace:GetServerTimeNow()
    for _,owner in Players:GetPlayers()do
        local model=giftModels[owner:GetAttribute("CapturingGift")or ""]
        local character=owner.Character
        if model and character and not (owner==player and stoppedCaptures[model])then
            local duration=model:GetAttribute("CaptureDuration")or 1
            local alpha=math.clamp((now-(model:GetAttribute("CaptureStartedAt")or now))/duration,0,1)
            for _,joint in character:GetDescendants()do
                if joint:IsA("Motor6D")then
                    local shoulder=joint.Name:find("Shoulder")
                    local waist=joint.Name=="Waist"or joint.Name=="RootJoint"
                    if shoulder or waist then
                        local base=joint.Transform
                        posed[joint]=posed[joint]or base;active[joint]=true
                        local strain=math.sin(alpha*math.pi*8)*.07
                        joint.Transform=posed[joint]*CFrame.Angles(shoulder and -1.1+alpha*.35+strain or -.13+strain*.3,0,0)
                    end
                end
            end
        end
    end
    for joint,base in posed do if not active[joint]then
        if joint.Parent then joint.Transform=base end
        posed[joint]=nil
    end end
end)
RunService.RenderStepped:Connect(function()
    local now=os.clock()
    status.Visible=not reveal;temp.Visible=not reveal;actions.Visible=not reveal;gui.OddsButton.Visible=not reveal
    dropButton.Visible=not reveal and (player:GetAttribute("CarriedGift") or "")~=""
    if reveal then toast.Visible=false end
    if toast.Visible and now>=toastUntil then toast.Visible=false end
    local chasing=player:GetAttribute("Chasing")==true
    chase.Visible=not reveal and (chasing or now<escapedUntil)
    chase.BackgroundColor3=chasing and Color3.fromRGB(135,51,66) or Color3.fromRGB(44,115,88)
    chaseLabel.Text=chasing and (player:GetAttribute("ChaseGuard") or "Хранитель").." • БЕГИ НА БАЗУ!" or "СПАСЁН! Ты в безопасности"
    local gift=giftModels[player:GetAttribute("CapturingGift")or ""]
    if gift and stoppedCaptures[gift]then gift=nil end
    local serverNow=workspace:GetServerTimeNow()
    for model,v in captureVisuals do
        if not model.Parent or not model:GetAttribute("CaptureUserId")or (model:GetAttribute("CaptureUserId")==player.UserId and stoppedCaptures[model])then removeCaptureVisual(model,v)end
    end
    for name,model in giftModels do
        local started=model:GetAttribute("CaptureStartedAt")
        if started and model:GetAttribute("CaptureUserId")and not (model:GetAttribute("CaptureUserId")==player.UserId and stoppedCaptures[model])then
            local v=captureVisuals[model]or makeCaptureVisual(model)
            local duration=model:GetAttribute("CaptureDuration")or 1
            local alpha=math.clamp((serverNow-started)/duration,0,1)
            local strain=math.sin((serverNow-started)*23)
            local resistance=(.15-.05*alpha)*strain
            v.proxy:PivotTo(v.origin*CFrame.new(resistance,.9*alpha^1.6,0)*CFrame.Angles(alpha*.16,math.sin((serverNow-started)*17)*.025,strain*.065+alpha*.07))
            v.fill.Size=UDim2.fromScale(alpha,1)
            v.fill.BackgroundColor3=Color3.fromRGB(255,210,105):Lerp(Color3.fromRGB(130,255,175),math.clamp((alpha-.7)/.3,0,1))
            v.label.Text=string.format(alpha>=.8 and "ЕЩЁ ЧУТЬ-ЧУТЬ • %d%%" or "ВЫТЯГИВАЕТ • %d%%",math.floor(alpha*100))
        end
        if captured[name]then releaseBurst(model);captured[name]=nil end
    end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local baseId=player:GetAttribute("BaseId");local base=baseId and scene.Bases:FindFirstChild(baseId)
    local guide=root and base and ((player:GetAttribute("CarriedGift") or "")~="" or chasing)
    homeArrow.Visible=guide==true and not reveal;homeDistance.Visible=guide==true and not reveal
    goal.Visible=not reveal and not guide and not gift
    if guide then
        local delta=base.Spawn.Position-root.Position
        local localDirection=workspace.CurrentCamera.CFrame:VectorToObjectSpace(delta)
        homeArrow.Rotation=math.deg(math.atan2(localDirection.X,-localDirection.Z))
        homeDistance.Text="ТВОЙ САД • "..math.floor(delta.Magnitude).." studs"
    end
    for _,toys in visuals do for _,v in toys do
        local t=now*.35+v.phase
        local bounce=math.abs(math.sin(now*(v.motion=="Windup" and 7 or 4)+v.phase))*(v.motion=="Bounce" and .55 or .15)
        local roll=v.motion=="Waddle" and math.sin(now*4)*.18 or v.motion=="Slink" and math.sin(now*2)*.1 or 0
        local cf=CFrame.new(v.center+Vector3.new(math.sin(t)*6*Catalog.WorldScale,v.lift+.12+bounce,math.cos(t*.7)*3.5*Catalog.WorldScale))*CFrame.Angles(0,-t,roll)
        v.model:PivotTo(cf)
        for i,limb in v.limbs do limb.part.CFrame=cf*limb.offset*CFrame.Angles(math.sin(now*(v.motion=="Windup" and 7 or 4)+i)*.18,0,0) end
    end end
    if now<impactUntil then
        local strength=(impactUntil-now)/.4
        workspace.CurrentCamera.CFrame*=CFrame.new(math.sin(now*95)*.23*strength,math.cos(now*110)*.18*strength,0)*CFrame.Angles(0,0,math.sin(now*70)*.025*strength)
    end
    if reveal then
        local r=reveal;local t=now-r.started;local data=r.data
        local openAt=r.growSeconds
        local progress=math.clamp(t/openAt,0,1)
        -- One numeric value drives both the text and the complete model each frame.
        local scale=revealScale(r,t)
        multiplier.Text=string.format("×%.2f",scale)
        multiplier.TextColor3=Catalog.Gifts[data.Gift].Color
        r.gift:ScaleTo(scale)
        local opened=t>=openAt
        local pop=math.clamp((t-openAt)/.22,0,1)
        local bounce=not opened and math.abs(math.sin(t*18))*.2*Catalog.WorldScale*(1-progress) or 0
        local cf=CFrame.new(0,r.giftLift*scale+bounce,0)*CFrame.Angles(0,.35+math.sin(t*5)*.07*(1-progress),math.sin(t*8)*.04*(1-progress))
        r.gift:PivotTo(cf)
        for part,offset in r.offsets do
            local localCF=CFrame.new(offset.cf.Position*scale)*offset.cf.Rotation
            if part.Name=="Lid" or part.Name:sub(1,3)=="Bow" then
                localCF=CFrame.new(0,pop*12*Catalog.WorldScale,0)*localCF*CFrame.Angles(pop*.7,0,pop*.4)
            end
            part.CFrame=cf*localCF
            part.Transparency=offset.transparency+(1-offset.transparency)*pop
        end
        r.toy:PivotTo(CFrame.new(0,opened and r.lift+math.sin(pop*math.pi)*Catalog.WorldScale or -200,0)*CFrame.Angles(0,math.pi+math.sin(t*2)*.12,0))
        -- Frame the same x4 envelope for every result, so size differences remain visible.
        local aspect=math.max(.5,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
        local envelope=r.giftSize:Lerp(r.baseToySize,pop)*4
        local height=math.max(envelope.Y,envelope.X/aspect)
        local distance=height/(2*math.tan(math.rad(stageCamera.FieldOfView/2)))*1.18+envelope.Z*.5
        local targetY=(r.giftSize.Y*scale*(1-pop)+r.height*pop)*.5
        stageCamera.CFrame=CFrame.lookAt(Vector3.new(0,targetY+distance*.18,distance),Vector3.new(0,targetY,0))
        if opened then
            resultLabel.Text=Catalog.Toys[data.Toy].Name.." • "..Catalog.Gifts[data.Gift].Name.."\n"..Catalog.Size(data.SizeMultiplier).Name..string.format(" ×%.2f",data.SizeMultiplier).."  •  +"..data.Income.." монет/с"
        end
        flash.BackgroundTransparency=opened and math.clamp((t-openAt)/.16,0,1) or 1
        for _,bit in r.confetti do
            bit.part.Visible=opened
            local ct=math.max(0,t-openAt)
            bit.part.Position=UDim2.new(.5,bit.vx*ct,.45,bit.vy*ct+180*ct*ct)
            bit.part.Rotation=bit.spin*ct;bit.part.BackgroundTransparency=math.clamp(ct-.5,0,1)
        end
        if data.SizeMultiplier>=2.5 and t>=openAt and t<openAt+.2 then
            workspace.CurrentCamera.CFrame*=CFrame.new(math.sin(t*130)*.04*data.SizeMultiplier,math.cos(t*150)*.035*data.SizeMultiplier,0)
        end
        if t>=openAt+1.3 then clearReveal() end
    end
end)
