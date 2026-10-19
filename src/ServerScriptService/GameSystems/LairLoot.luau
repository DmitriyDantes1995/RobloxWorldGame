local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Catalog=require(ReplicatedStorage.TreasureCatalog)
local Config=require(script.Parent.LairConfig)
local Economy=require(script.Parent.GameEconomy)
local Safety=require(script.Parent.LairSafety)
local Loot={}
local pool,active,carriers,trails={},{},{},{}
local rng=Random.new()
local scene,onTheft
local updateCarrier
local cannon,projectile
local resetCannon,returnCannon
local notify=ReplicatedStorage.GameRemotes.Notify

local function stateFor(player)
    local state=carriers[player]
    if not state then state={walking=false,visuals={},lastDrop=-math.huge};carriers[player]=state end
    return state
end

local function stopPulse(data)
    for _,tween in data.tweens or {} do tween:Cancel() end
    data.tweens={}
    data.phase=nil
end

local function pulse(data,phase)
    if data.phase==phase then return end
    stopPulse(data);data.phase=phase
    data.model:SetAttribute("CrystalPhase",phase)
    local warning=phase=="Warning"
    local flash=phase=="Flash"
    for _,part in data.model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color=Catalog.Items.Rare.Color
            if warning or flash then
                local tween=TweenService:Create(part,TweenInfo.new(flash and .12 or .3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
                    {Color=flash and Color3.fromRGB(255,240,255) or Color3.fromRGB(250,155,255)})
                table.insert(data.tweens,tween);tween:Play()
            end
        elseif part:IsA("PointLight") then
            part.Brightness=flash and 3 or warning and .7 or .25
            part.Range=flash and 13 or warning and 8 or 4
            local tween=TweenService:Create(part,TweenInfo.new(flash and .12 or warning and .3 or 1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
                {Brightness=flash and 6 or warning and 2.5 or .6})
            table.insert(data.tweens,tween);tween:Play()
        end
    end
end

local function disposeVisual(data)
    stopPulse(data);data.model:Destroy()
end

local function queryParams(player)
    local excludes={scene.Treasures,scene.Effects,scene.Keeper,scene.Servants}
    if player and player.Character then table.insert(excludes,player.Character) end
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    local rayExcludes=table.clone(excludes)
    for _,other in Players:GetPlayers() do if other.Character then table.insert(rayExcludes,other.Character) end end
    ray.FilterDescendantsInstances=rayExcludes;ray.RespectCanCollide=true
    local box=OverlapParams.new();box.FilterType=Enum.RaycastFilterType.Exclude
    box.FilterDescendantsInstances=excludes;box.RespectCanCollide=true
    return ray,box
end

local function floorPlacement(entry,position,ray)
    local hit=workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-15,0),ray)
    if not hit or hit.Normal.Y<.75 then return nil end
    local center=hit.Position+Vector3.new(0,entry.size.Y*.5+.08,0)
    return CFrame.new(center)*entry.boxOffset:Inverse(),center
end

local function attachVisual(player,state,kind,root)
    local item=Catalog.Items[kind]
    local model=ReplicatedStorage.ArtifactModels[item.Template]:Clone()
    model.Name="Carried"..kind
    local main=model.Artifact
    local offset=kind=="Idol" and CFrame.new(0,-.2,1.3)
        or kind=="Legendary" and CFrame.new(0,2.7,0)
        or CFrame.new(1.3,.65,0)
    model:PivotTo(root.CFrame*offset)
    for _,part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored=false;part.Massless=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            if part~=main then local weld=Instance.new("WeldConstraint");weld.Part0=main;weld.Part1=part;weld.Parent=main end
        end
    end
    local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=main;weld.Parent=main
    model.Parent=player.Character
    local data={model=model,tweens={}}
    state.visuals[kind]=data
    return data
end

updateCarrier=function(player)
    local state=stateFor(player)
    local root=Safety.Root(player)
    if state.character~=player.Character then
        for _,visual in pairs(state.visuals) do disposeVisual(visual) end
        state.visuals={};state.character=player.Character;state.nextFlash=nil;state.lastTrail=nil
        if state.sprintTrail then state.sprintTrail:Destroy();state.sprintTrail=nil end
        if state.sprintAttachments then for _,a in state.sprintAttachments do a:Destroy() end end
        state.sprintAttachments=nil;state.sprintUntil=nil;state.wasGrounded=false
        state.slowUntil=nil;state.slowReadyAt=nil
    end
    local idol=(player:GetAttribute("Artifacts_Idol") or 0)>0
    if root then
        local now=os.clock()
        if Safety.InBase(scene,root.Position) then state.slowUntil=nil;state.slowReadyAt=nil end
        local sprinting=now<(state.sprintUntil or 0)
        local slowed=now<(state.slowUntil or 0)
        player.Character.Humanoid.WalkSpeed=(sprinting and Catalog.RunSpeed*Config.SprintMultiplier or state.walking and Catalog.WalkSpeed or Catalog.RunSpeed)*(idol and Catalog.IdolSpeedMultiplier or 1)*(slowed and .75 or 1)
        player.Character.Humanoid.UseJumpPower=false
        player.Character.Humanoid.JumpHeight=player:GetAttribute("JumpUnlocked") and Config.JumpHeight or Config.BaseJumpHeight
        player:SetAttribute("Sprinting",sprinting)
        if state.sprintTrail then state.sprintTrail.Enabled=sprinting end
    end
    player:SetAttribute("Walking",state.walking)
    for _,kind in {"Idol","Rare","Legendary"} do
        local carried=root and (player:GetAttribute("Artifacts_"..kind) or 0)>0
        local visual=state.visuals[kind]
        if carried and not visual then visual=attachVisual(player,state,kind,root)
        elseif not carried and visual then disposeVisual(visual);state.visuals[kind]=nil end
    end
    if not state.visuals.Rare then state.nextFlash=nil;state.flashed=false end
    return state,root
end

function Loot.Slow(player)
    local state,root=updateCarrier(player)
    local now=os.clock()
    if not root or not Economy.IsReady(player) or Safety.InBase(scene,root.Position)
        or Safety.InHide(scene,root.Position) or not Safety.InLair(scene,root.Position)
        or now<(state.slowReadyAt or 0) then return false end
    state.slowUntil=now+1.4;state.slowReadyAt=now+8
    updateCarrier(player)
    notify:FireClient(player,"Слуга схватил за ботинок!",Color3.fromRGB(255,180,100),1.4)
    return true
end

function Loot.Sprint(player)
    local root=Safety.Root(player)
    local now=os.clock();local state=stateFor(player)
    if not root or not Economy.IsReady(player) or not player:GetAttribute("SprintUnlocked")
        or now<(state.sprintReadyAt or 0) then return false end
    state.sprintUntil=now+Config.SprintSeconds
    state.sprintReadyAt=now+Config.SprintCooldown
    player:SetAttribute("SprintEndsAt",workspace:GetServerTimeNow()+Config.SprintSeconds)
    player:SetAttribute("SprintReadyAt",workspace:GetServerTimeNow()+Config.SprintCooldown)
    if not state.sprintTrail then
        local a=Instance.new("Attachment");a.Name="SprintLeft";a.Position=Vector3.new(-1,-1,1);a.Parent=root
        local b=Instance.new("Attachment");b.Name="SprintRight";b.Position=Vector3.new(1,-1,1);b.Parent=root
        local trail=Instance.new("Trail");trail.Name="SprintTrail";trail.Attachment0=a;trail.Attachment1=b
        trail.Color=ColorSequence.new(Color3.fromRGB(80,255,213));trail.Lifetime=.3;trail.FaceCamera=true
        trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})
        trail.Parent=root;state.sprintTrail=trail;state.sprintAttachments={a,b}
    end
    updateCarrier(player)
    return true
end

function Loot.SetWalking(player,walking)
    if type(walking)~="boolean" then return end
    if walking and (not Economy.IsReady(player) or not Safety.Root(player)) then return end
    stateFor(player).walking=walking
    updateCarrier(player)
end

function Loot.ClearCarried(player)
    if returnCannon then returnCannon(player) end
    for _,entry in pool do
        if entry.owner==player then entry.owner=nil;entry.taken=true;active[entry.model]=nil;entry.model.Parent=nil end
    end
    local state=carriers[player]
    if state then
        state.sprintUntil=nil;state.slowUntil=nil;state.slowReadyAt=nil
        for _,visual in pairs(state.visuals) do disposeVisual(visual) end
        state.visuals={};state.nextFlash=nil;state.flashed=false;state.lastTrail=nil
        updateCarrier(player)
    end
end

function Loot.RemovePlayer(player)
    Loot.ClearCarried(player)
    local state=carriers[player]
    if state then for _,visual in pairs(state.visuals) do disposeVisual(visual) end end
    carriers[player]=nil
end

function Loot.Collect(player,model)
    local entry=active[model]
    local root=Safety.Root(player)
    if not entry or entry.taken or not root or not model.Parent or not Economy.IsReady(player) then return false end
    if entry.vault and not entry.vault.Door:GetAttribute("Open") then return false end
    if not entry.prompt.Enabled or (root.Position-entry.part.Position).Magnitude>Config.PickupDistance then return false end
    local ray=queryParams(player)
    if workspace:Raycast(root.Position,entry.part.Position-root.Position,ray) then return false end
    if not Economy.TryAddArtifact(player,entry.rarity) then
        notify:FireClient(player,"Не хватает места в рюкзаке",Color3.fromRGB(255,130,100));return false
    end
    -- Shared item ownership and attribute count change without yielding.
    local firstTheft=not entry.stolen
    entry.stolen=true;entry.owner=player;entry.taken=true
    active[model]=nil;entry.prompt.Enabled=false;model.Parent=nil;stopPulse(entry)
    updateCarrier(player)
    local item=Catalog.Items[entry.rarity]
    local state=stateFor(player)
    local hint=not state.hasCollected and "Это ещё не деньги — доставь груз на базу." or item.Description
    state.hasCollected=true
    notify:FireClient(player,string.format("%s · %d монет\n%s",item.Name,item.Price,hint),item.Color,4)
    -- Dropping and taking the same object again cannot farm suspicion.
    if firstTheft and onTheft then onTheft(player,item.Risk,entry.part.Position) end
    return true
end

local function dropPlacement(player,entry,root)
    local ray,box=queryParams(player)
    local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z).Unit
    local right=Vector3.new(-forward.Z,0,forward.X)
    for _,offset in {forward*3.5,right*3.5,-right*3.5,-forward*3.5,forward*2.5} do
        local probe=root.Position+offset
        if not workspace:Raycast(root.Position,probe-root.Position,ray) then
            local cf,center=floorPlacement(entry,probe,ray)
            if cf and #workspace:GetPartBoundsInBox(CFrame.new(center),entry.size+Vector3.new(.2,0,.2),box)==0 then
                local clear=true
                for _,other in pairs(active) do
                    local otherCF=other.model:GetBoundingBox()
                    local delta=center-otherCF.Position
                    if math.abs(delta.X)<(entry.size.X+other.size.X)*.5+.2
                        and math.abs(delta.Z)<(entry.size.Z+other.size.Z)*.5+.2
                        and math.abs(delta.Y)<(entry.size.Y+other.size.Y)*.5+.2 then clear=false;break end
                end
                if clear then return cf end
            end
        end
    end
    return nil
end

function Loot.Drop(player,kind)
    if type(kind)~="string" or not Catalog.Items[kind] or not Economy.IsReady(player) then return false end
    local root=Safety.Root(player)
    if not root or (player:GetAttribute("Artifacts_"..kind) or 0)<1 then return false end
    local state=stateFor(player)
    local now=os.clock()
    if now-state.lastDrop<Catalog.DropCooldown then return false end
    state.lastDrop=now
    local entry
    for _,candidate in pool do if candidate.owner==player and candidate.rarity==kind then entry=candidate;break end end
    if not entry then return false end
    local cf=dropPlacement(player,entry,root)
    if not cf then notify:FireClient(player,"Рядом нет места для предмета",Color3.fromRGB(255,190,100));return false end
    if not Economy.TryRemoveArtifact(player,kind) then return false end
    entry.owner=nil;entry.taken=false
    entry.model:PivotTo(cf);entry.model.Parent=scene.Treasures;entry.prompt.Enabled=true;active[entry.model]=entry
    if kind=="Rare" then pulse(entry,"Quiet") end
    updateCarrier(player)
    return true
end

local function assignModel(entry,kind)
    if entry.model and entry.rarity==kind then return end
    if entry.model then active[entry.model]=nil;stopPulse(entry);entry.model:Destroy() end
    local item=Catalog.Items[kind]
    local model=ReplicatedStorage.ArtifactModels[item.Template]:Clone()
    model.Name="Treasure_"..entry.slot
    model:SetAttribute("LairTreasure",true);model:SetAttribute("Rarity",kind);model:SetAttribute("SellValue",item.Price)
    local part=model.Artifact
    for _,v in model:GetDescendants() do
        if v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.CanTouch=false end
    end
    local bounds,size=model:GetBoundingBox()
    local prompt=Instance.new("ProximityPrompt")
    prompt.Name="TreasurePrompt";prompt.ActionText="Взять"
    prompt.ObjectText=string.format("%s · %d монет · %s",item.Name,item.Price,item.Description)
    prompt.MaxActivationDistance=Config.PickupDistance;prompt.HoldDuration=.3;prompt.RequiresLineOfSight=false;prompt.Parent=part
    entry.model=model;entry.part=part;entry.prompt=prompt;entry.rarity=kind
    entry.size=size;entry.boxOffset=model:GetPivot():ToObjectSpace(bounds);entry.phase=nil;entry.tweens={}
    prompt.Triggered:Connect(function(player)Loot.Collect(player,model)end)
end

local function chooseTypes()
    local types,counts={},{}
    for _,kind in Catalog.Order do counts[kind]=0 end
    for i,entry in pool do
        if entry.fixedKind then
            types[i]=entry.fixedKind;counts[entry.fixedKind]+=1
            continue
        end
        local weights=Catalog.SpawnWeights[entry.danger]
        local sum=0;for _,kind in Catalog.Order do sum+=weights[kind] end
        local draw=rng:NextNumber()*sum
        local kind=Catalog.Order[#Catalog.Order]
        for _,candidate in Catalog.Order do draw-=weights[candidate];if draw<0 then kind=candidate;break end end
        types[i]=kind;counts[kind]+=1
    end
    -- Keep gems most common, reserving rarities for deeper authored slots.
    for i,entry in pool do
        if counts.Common>=Catalog.MinimumCommon then break end
        if not entry.fixedKind and types[i]~="Common" then counts[types[i]]-=1;types[i]="Common";counts.Common+=1 end
    end
    for _,kind in {"Idol","Rare","Legendary"} do
        if counts[kind]==0 then
            for i=#pool,1,-1 do
                local previous=types[i]
                if not pool[i].fixedKind and (previous=="Common" and counts.Common>Catalog.MinimumCommon or previous~="Common" and counts[previous]>1) then
                    counts[previous]-=1;types[i]=kind;counts[kind]+=1;break
                end
            end
        end
    end
    return types
end

function Loot.Reset()
    for player,state in carriers do
        state.slowUntil=nil;state.slowReadyAt=nil
        updateCarrier(player)
    end
    if resetCannon then resetCannon() end
    for _,trace in trails do trace.part:Destroy() end
    for _,effect in scene.Effects:GetChildren() do effect:Destroy() end
    table.clear(trails);table.clear(active)
    local types=chooseTypes()
    local changed=false
    for i,entry in pool do
        local point=entry.points[rng:NextInteger(1,#entry.points)]
        if point~=entry.point then changed=true end
        entry.nextPoint=point
    end
    if not changed then
        local entry=pool[rng:NextInteger(1,#pool)]
        entry.nextPoint=entry.points[table.find(entry.points,entry.point)%#entry.points+1]
    end
    local ray=queryParams()
    for i,entry in pool do
        entry.point=entry.nextPoint;entry.nextPoint=nil;entry.owner=nil;entry.stolen=false;entry.taken=false
        assignModel(entry,types[i])
        local cf=assert(floorPlacement(entry,entry.point.Position,ray),"Prepared treasure point has no floor")
        entry.model:PivotTo(cf)
        entry.model.Parent=scene.Treasures;entry.prompt.Enabled=true;active[entry.model]=entry
        if entry.rarity=="Rare" then pulse(entry,"Quiet") end
    end
end

local function leaveTrail(player,state,root,now)
    if state.lastTrail and (root.Position-state.lastTrail).Magnitude<Catalog.Trail.Spacing then return end
    if now<(state.nextTrail or 0) then return end
    local ray=queryParams(player)
    local floor=workspace:Raycast(root.Position,Vector3.new(0,-7,0),ray)
    if not floor or floor.Normal.Y<.75 then return end
    local part=Instance.new("Part");part.Name="CrownTrace";part.Size=Vector3.new(1,.05,1.6)
    part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
    part.Material=Enum.Material.Neon;part.Color=Catalog.Items.Legendary.Color
    local _,yaw=root.CFrame:ToOrientation()
    part.CFrame=CFrame.new(floor.Position+Vector3.new(0,.07,0))*CFrame.Angles(0,yaw,0)
    part:SetAttribute("OwnerUserId",player.UserId);part.Parent=scene.Effects
    table.insert(trails,{part=part,owner=player,expires=now+Catalog.Trail.Lifetime,seen=false})
    state.lastTrail=root.Position;state.nextTrail=now+Catalog.Trail.Interval
end

function Loot.Step(players,now,keeper)
    for _,player in players do
        local state,root=updateCarrier(player)
        if root then
            if Safety.InBase(scene,root.Position) then returnCannon(player) end
            local humanoid=player.Character.Humanoid
            local grounded=humanoid.FloorMaterial~=Enum.Material.Air
            if state.wasGrounded and not grounded and root.AssemblyLinearVelocity.Y>8 and player:GetAttribute("JumpUnlocked") then
                local ring=Instance.new("Part");ring.Name="JumpBurst";ring.Shape=Enum.PartType.Cylinder
                ring.Size=Vector3.new(.1,2,2);ring.CFrame=CFrame.new(root.Position-Vector3.new(0,2.7,0))*CFrame.Angles(0,0,math.pi/2)
                ring.Anchored=true;ring.CanCollide=false;ring.CanTouch=false;ring.CanQuery=false;ring.Material=Enum.Material.Neon
                ring.Color=Color3.fromRGB(100,225,255);ring.Parent=scene.Effects
                TweenService:Create(ring,TweenInfo.new(.35),{Size=Vector3.new(.1,7,7),Transparency=1}):Play()
                game:GetService("Debris"):AddItem(ring,.4)
            end
            state.wasGrounded=grounded
            local crystal=state.visuals.Rare
            if crystal then
                state.nextFlash=state.nextFlash or now+Catalog.Crystal.Interval
                if now>=state.nextFlash then
                    pulse(crystal,"Flash")
                    if not state.flashed then state.flashed=keeper:OnEvidence(player,root.Position,"Crystal") end
                    if now>=state.nextFlash+Catalog.Crystal.FlashSeconds then
                        state.nextFlash=now+Catalog.Crystal.Interval;state.flashed=false;pulse(crystal,"Quiet")
                    end
                elseif now>=state.nextFlash-Catalog.Crystal.WarningSeconds then pulse(crystal,"Warning")
                else pulse(crystal,"Quiet") end
            end
            local velocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
            if state.visuals.Legendary and not state.walking and velocity>=Catalog.Trail.RunningThreshold
                and Safety.InExpedition(scene,root.Position) then leaveTrail(player,state,root,now) end
        end
    end
    local candidates={}
    for i=#trails,1,-1 do
        local trace=trails[i]
        if now>=trace.expires then trace.part:Destroy();table.remove(trails,i)
        else
            trace.part.Transparency=1-(trace.expires-now)/Catalog.Trail.Lifetime
            if not trace.seen then
                local distance=(keeper.root.Position-trace.part.Position).Magnitude
                if distance<=Catalog.Trail.DetectDistance then table.insert(candidates,{trace=trace,distance=distance}) end
            end
        end
    end
    table.sort(candidates,function(a,b)return a.distance<b.distance end)
    for _,candidate in candidates do
        local trace=candidate.trace
        if keeper:OnEvidence(trace.owner,trace.part.Position,"Trail") then trace.seen=true;break end
    end
end

local function canInteract(player,part,prompt)
    local root=Safety.Root(player)
    if not root or not Economy.IsReady(player) or not prompt.Enabled or (root.Position-part.Position).Magnitude>prompt.MaxActivationDistance then return false end
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character,scene.ExpeditionItems};ray.RespectCanCollide=true
    return workspace:Raycast(root.Position,part.Position-root.Position,ray)==nil
end

local function cancelProjectile()
    if projectile then projectile.connection:Disconnect();projectile.part:Destroy();projectile=nil end
end

local function placeCannon()
    local tool=cannon.tool
    tool.Parent=scene.ExpeditionItems
    for _,p in tool:GetDescendants() do if p:IsA('BasePart') then p.Anchored=true;p.AssemblyLinearVelocity=Vector3.zero end end
    for _,p in tool:GetDescendants() do if p:IsA('BasePart') then p.CFrame=p:GetAttribute('RestCFrame') end end
    tool.Handle.Pickup.Enabled=not scene:GetAttribute('CannonFired')
end

returnCannon=function(player)
    if cannon and (cannon.tool.Parent==player.Character or cannon.tool.Parent==player:FindFirstChild('Backpack')) then placeCannon() end
end

resetCannon=function()
    cancelProjectile()
    scene:SetAttribute('CannonCharges',0);scene:SetAttribute('CannonFired',false)
    for _,part in cannon.charges do part.Transparency=0;part.Pickup.Enabled=true;part.Glow.Enabled=true end
    placeCannon()
end

local function startCannon()
    cannon={tool=scene.ExpeditionItems.AncientCannon,charges=scene.ExpeditionItems.Charges:GetChildren()}
    local tool=cannon.tool
    tool.Handle.Pickup.Triggered:Connect(function(player)
        if tool.Parent~=scene.ExpeditionItems or scene:GetAttribute('CannonFired')
            or not scene.VaultDoors.CrownVault.Door:GetAttribute('Open') or not canInteract(player,tool.Handle,tool.Handle.Pickup) then return end
        local backpack=player:FindFirstChild('Backpack');if not backpack then return end
        tool.Handle.Pickup.Enabled=false
        for _,p in tool:GetDescendants() do if p:IsA('BasePart') then p.Anchored=false end end
        tool.Parent=backpack
        player.Character.Humanoid:EquipTool(tool)
        notify:FireClient(player,'Древняя пушка · нужны два синих заряда',Color3.fromRGB(110,240,255))
    end)
    for _,part in cannon.charges do
        part.Pickup.Triggered:Connect(function(player)
            if scene:GetAttribute('CannonFired') or not canInteract(player,part,part.Pickup) then return end
            part.Pickup.Enabled=false;part.Transparency=1;part.Glow.Enabled=false
            scene:SetAttribute('CannonCharges',scene:GetAttribute('CannonCharges')+1)
            notify:FireClient(player,'Общий заряд пушки '..scene:GetAttribute('CannonCharges')..' / 2',Color3.fromRGB(110,240,255))
        end)
    end
    resetCannon()
end

function Loot.FireCannon(player,direction,keeper)
    if typeof(direction)~='Vector3' or direction.X~=direction.X or direction.Y~=direction.Y or direction.Z~=direction.Z
        or direction.Magnitude<.9 or direction.Magnitude>1.1 then return false end
    if not cannon or cannon.tool.Parent~=player.Character or not Safety.Root(player) or not Economy.IsReady(player)
        or scene:GetAttribute('CannonFired') then return false end
    if scene:GetAttribute('CannonCharges')<2 then
        notify:FireClient(player,'Нужно найти два синих заряда',Color3.fromRGB(110,240,255));return false
    end
    -- Debit the shared shot before starting any asynchronous projectile work.
    scene:SetAttribute('CannonFired',true);scene:SetAttribute('CannonCharges',0)
    direction=direction.Unit
    local origin=cannon.tool.Handle.Muzzle.WorldPosition
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    local excludes={scene.Effects,scene.Treasures,scene.ExpeditionItems,cannon.tool,scene.Servants}
    for _,p in Players:GetPlayers() do if p.Character then table.insert(excludes,p.Character) end end
    params.FilterDescendantsInstances=excludes;params.RespectCanCollide=true
    local clipped=workspace:Raycast(player.Character.HumanoidRootPart.Position,origin-player.Character.HumanoidRootPart.Position,params)
    if clipped then origin=clipped.Position-direction*.9 end
    local ball=Instance.new('Part');ball.Name='CannonPulse';ball.Shape=Enum.PartType.Ball;ball.Size=Vector3.new(1.8,1.8,1.8)
    ball.Anchored=true;ball.CanCollide=false;ball.CanTouch=false;ball.CanQuery=false;ball.Material=Enum.Material.Neon
    ball.Color=Color3.fromRGB(95,245,255);ball.CFrame=CFrame.new(origin);ball.Parent=scene.Effects
    local light=Instance.new('PointLight');light.Color=ball.Color;light.Range=17;light.Brightness=4;light.Parent=ball
    local shot={part=ball,distance=0,position=origin};projectile=shot
    shot.connection=RunService.Heartbeat:Connect(function(dt)
        local delta=direction*math.min(Config.CannonSpeed*dt,Config.CannonRange-shot.distance)
        local hit=clipped or workspace:Spherecast(shot.position,.9,delta,params)
        if hit then
            ball.Position=hit.Position
            if hit.Instance:IsDescendantOf(keeper.model) then
                keeper:Stun(Config.CannonStunSeconds,'Cannon',nil,player.Parent==Players and player or nil,direction)
            end
            shot.connection:Disconnect();projectile=nil
            TweenService:Create(ball,TweenInfo.new(.3),{Size=Vector3.new(9,9,9),Transparency=1}):Play()
            game:GetService('Debris'):AddItem(ball,.35)
        else
            shot.position+=delta;shot.distance+=delta.Magnitude;ball.Position=shot.position
            if shot.distance>=Config.CannonRange then cancelProjectile() end
        end
    end)
    notify:FireClient(player,'Разряд! Пушка разряжена до следующей экспедиции.',Color3.fromRGB(110,240,255))
    return true
end

function Loot.Start(lair,callback)
    assert(not scene,"LairLoot already started")
    scene=lair;onTheft=callback
    local groups={}
    for _,point in scene.TreasurePoints:GetChildren() do
        local slot=point:GetAttribute("Slot")
        local kind,vaultId=point:GetAttribute("GuaranteedKind"),point:GetAttribute("VaultId")
        assert(not kind or Catalog.Items[kind],"Unknown guaranteed treasure kind")
        if not groups[slot] then
            local vault=vaultId and scene.VaultDoors[vaultId]
            groups[slot]={slot=slot,points={},danger=point:GetAttribute("Rarity"),fixedKind=kind,vault=vault,vaultId=vaultId}
        end
        assert(groups[slot].fixedKind==kind and groups[slot].vaultId==vaultId,"Slot points disagree on vault or guaranteed kind")
        table.insert(groups[slot].points,point)
    end
    for _,group in pairs(groups) do
        table.sort(group.points,function(a,b)return a.Name<b.Name end);table.insert(pool,group)
    end
    local tier={Common=1,Rare=2,Legendary=3}
    table.sort(pool,function(a,b)return tier[a.danger]==tier[b.danger] and a.slot<b.slot or tier[a.danger]<tier[b.danger] end)
    startCannon()
    Loot.Reset()
end
return Loot
