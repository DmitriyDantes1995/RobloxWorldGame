local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.ToyCatalog)
local PhysicsService=game:GetService("PhysicsService")
local Keeper=require(script.Parent.ToyKeeper)
local Vehicle=require(script.Parent.ToyVehicle)
local Game={}
Game.__index=Game
local LIMIT=9007199254740991
local function rootOf(player)
    local char=player.Character
    local h=char and char:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and char:FindFirstChild("HumanoidRootPart") or nil
end
local function inside(part,pos)
    local p=part.CFrame:PointToObjectSpace(pos)
    return math.abs(p.X)<=part.Size.X/2 and math.abs(p.Y)<=part.Size.Y/2 and math.abs(p.Z)<=part.Size.Z/2
end
function Game.new(scene,progress,signal)
    for _,name in {"ToyGuard","ToyPlayer"}do
        if not PhysicsService:IsCollisionGroupRegistered(name)then PhysicsService:RegisterCollisionGroup(name)end
    end
    PhysicsService:CollisionGroupSetCollidable("ToyGuard","ToyGuard",false)
    PhysicsService:CollisionGroupSetCollidable("ToyGuard","ToyPlayer",false)
    local self=setmetatable({scene=scene,progress=progress,signal=signal,rng=Random.new(),
        slots={},capturing={},carried={},plots={},cooldowns={},recovering={},selected={},customDisplay={},syncAt={},keepers={},lastIncome=workspace:GetServerTimeNow()},Game)
    for index,settings in Catalog.Zones do
        self.keepers[index]=Keeper.new(scene,scene.Keepers[settings.Keeper],scene.PatrolPoints[settings.Keeper],settings,
            function(p,keeper) self:Catch(p,keeper) end,function(pos) return inside(scene.SafeZone,pos) end,
            function(p,reason,name)
                if reason=="Safe" then
                    self:EndChases(p)
                    self:Notify(p,"СПАСЁН! Хранитель остался за границей сада.")
                    self.signal:FireClient(p,"Escaped")
                end
            end)
    end
    for _,point in scene.GiftPoints:GetChildren() do
        local slot={point=point,readyAt=0}
        table.insert(self.slots,slot);self:SpawnGift(slot)
    end
    for _,plot in scene.Bases:GetChildren() do
        plot.OpenStation.Prompt.Triggered:Connect(function(p) self:TryOpen(p) end)
        plot.SpeedStation.Prompt.Triggered:Connect(function(p) self:TryBuy(p) end)
        plot.StrengthStation.Prompt.Triggered:Connect(function(p) self:TryBuy(p,"Strength") end)
    end
    signal.OnServerEvent:Connect(function(player,action,argument)
        -- Remote requests never carry rarity, award identity, balance or price.
        if action=="Open" then self:TryOpen(player)
        elseif action=="Speed" then self:TryBuy(player)
        elseif action=="Strength" then self:TryBuy(player,"Strength")
        elseif action=="Drop" then self:Drop(player)
        elseif action=="Select" then self:SelectToy(player,argument)
        elseif action=="Sync" and self.progress:IsReady(player) then
            local now=workspace:GetServerTimeNow()
            if now>=(self.syncAt[player] or 0) then
                self.syncAt[player]=now+1
                for owner in self.plots do self:BroadcastCollection(owner,player) end
            end
        end
    end)
    return self
end
function Game:Notify(player,text)
    self.signal:FireClient(player,"Notify",text)
end
function Game:EndChases(player,reason)
    for _,keeper in self.keepers do keeper:RemovePlayer(player,reason) end
    self:UpdateChase(player)
end
function Game:UpdateChase(player)
    local names={}
    for _,keeper in self.keepers do if keeper.pursuits[player]then table.insert(names,keeper.settings.GuardName)end end
    player:SetAttribute("Chasing",#names>0)
    player:SetAttribute("ChaseGuard",table.concat(names," + "))
end
function Game:BroadcastCollection(player,recipient)
    local collection=self.progress:GetCollection(player)
    if not collection then return end
    if not self.customDisplay[player] then
        local sorted=Catalog.CopyCollection(collection)
        table.sort(sorted,function(a,b)
            local aScore=table.find(Catalog.Order,Catalog.Toys[a.Toy].Rarity)*100+a.SizeMultiplier
            local bScore=table.find(Catalog.Order,Catalog.Toys[b.Toy].Rarity)*100+b.SizeMultiplier
            if aScore==bScore then return a.Toy<b.Toy end
            return aScore>bScore
        end)
        self.selected[player]={}
        for i=1,math.min(Catalog.VisibleToys,#sorted) do
            table.insert(self.selected[player],Catalog.Key(sorted[i].Toy,sorted[i].SizeMultiplier))
        end
    end
    local packet={UserId=player.UserId,BaseId=self.plots[player].Name,Entries=Catalog.CopyCollection(collection),Selected=table.clone(self.selected[player])}
    if recipient then self.signal:FireClient(recipient,"Collection",packet)
    else self.signal:FireAllClients("Collection",packet) end
end
function Game:SelectToy(player,key)
    if type(key)~="string" or #key>80 or not self.progress:IsReady(player) or not self:TakeAction(player) then return false end
    local owned=false
    for _,entry in self.progress:GetCollection(player) do if Catalog.Key(entry.Toy,entry.SizeMultiplier)==key then owned=true;break end end
    if not owned then return false end
    local selected=self.selected[player]
    local index=table.find(selected,key)
    if index then table.remove(selected,index)
    elseif #selected<Catalog.VisibleToys then table.insert(selected,key)
    else self:Notify(player,"В саду четыре игрушки. Сначала убери одну из прогулки.");return false end
    self.customDisplay[player]=true;self:BroadcastCollection(player)
    return true
end
function Game:InOwnBase(player)
    local root=rootOf(player)
    local plot=self.plots[player]
    return root and plot and inside(plot.Area,root.Position)
end
function Game:CanUse(player,station)
    if not self.progress:IsReady(player) then return false end
    local root=rootOf(player)
    if not root or (root.Position-station.Position).Magnitude>12 then return false end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={player.Character,self.scene.Gifts}
    params.RespectCanCollide=true
    local hit=workspace:Raycast(root.Position,station.Position-root.Position,params)
    return not hit or hit.Instance==station
end
function Game:TakeAction(player)
    local now=workspace:GetServerTimeNow()
    if now<(self.cooldowns[player] or 0) then return false end
    self.cooldowns[player]=now+.35
    return true
end
function Game:SpawnGift(slot)
    local zone=tonumber(slot.point.Name:match("^Z(%d)"))
    local rarity=Catalog.RollGift(zone,self.rng)
    local model=ReplicatedStorage.GiftModels[rarity]:Clone()
    model.Name=slot.point.Name
    model:SetAttribute("Rarity",rarity);model:SetAttribute("Zone",zone)
    slot.size=Catalog.RollSize(self.rng)
    model:SetAttribute("SizeMultiplier",slot.size)
    model:PivotTo(slot.point.CFrame*CFrame.new(0,1.45*Catalog.WorldScale,0))
    model.Parent=self.scene.Gifts
    slot.model=model;slot.rarity=rarity;slot.zone=zone;slot.owner=nil;slot.readyAt=nil;slot.captor=nil
    local prompt=model.Box.Prompt
    prompt.ActionText="Вытянуть подарок";prompt.HoldDuration=Catalog.CaptureDuration(rarity,0)+Catalog.Capture.PromptReleaseBuffer
    prompt.MaxActivationDistance=Catalog.Capture.Distance;prompt.ClickablePrompt=true
    prompt.PromptButtonHoldBegan:Connect(function(p)self:BeginCapture(p,slot)end)
    prompt.PromptButtonHoldEnded:Connect(function(p)self:EndCapture(p,slot)end)
    prompt.Triggered:Connect(function(p)
        local job=self.capturing[p]
        if job and job.slot==slot then self:AdvanceCapture(job,workspace:GetServerTimeNow())end
    end)
end
function Game:CancelCapture(player)
    local job=self.capturing[player]
    if not job then return end
    self.capturing[player]=nil
    if job.slot.captor==player then
        job.slot.captor=nil
        job.slot.model:SetAttribute("CaptureUserId",nil)
        job.slot.model:SetAttribute("CaptureStartedAt",nil)
        job.slot.model:SetAttribute("CaptureDuration",nil)
    end
    player:SetAttribute("CapturingGift","")
    if not self.carried[player] then self:EndChases(player)end
end
function Game:BeginCapture(player,slot)
    if not slot.model or slot.owner or (slot.captor and slot.captor~=player)
        or not slot.model.Box.Prompt.Enabled or self.carried[player] or self.recovering[player]
        or not self.progress:IsReady(player) or player:GetAttribute("PendingGift")~=""
        or workspace:GetServerTimeNow()<(player:GetAttribute("CatchGraceUntil")or 0)
        or not self:CanUse(player,slot.model.Box) then return false end
    if self.capturing[player]and self.capturing[player].slot==slot then return true end
    self:CancelCapture(player)
    local now=workspace:GetServerTimeNow()
    local duration=Catalog.CaptureDuration(slot.rarity,player:GetAttribute("StrengthLevel"))
    local job={player=player,slot=slot,started=now,duration=duration,character=player.Character}
    self.capturing[player]=job;slot.captor=player
    slot.model:SetAttribute("CaptureDuration",duration)
    slot.model:SetAttribute("CaptureStartedAt",now)
    slot.model:SetAttribute("CaptureUserId",player.UserId)
    player:SetAttribute("CapturingGift",slot.model.Name)
    self.keepers[slot.zone]:StartChase(player,slot.model)
    self:UpdateChase(player)
    return true
end
function Game:CaptureValid(job)
    local player,slot=job.player,job.slot
    return self.capturing[player]==job and slot.captor==player and not slot.owner and slot.model
        and slot.model.Box.Prompt.Enabled and not self.carried[player] and not self.recovering[player]
        and player.Character==job.character and self.progress:IsReady(player)
        and workspace:GetServerTimeNow()>=(player:GetAttribute("CatchGraceUntil")or 0)
        and player:GetAttribute("PendingGift")=="" and self:CanUse(player,slot.model.Box)
end
function Game:AdvanceCapture(job,now)
    if self.capturing[job.player]~=job then return end
    if not self:CaptureValid(job)then self:CancelCapture(job.player);return end
    if now-job.started>=job.duration then self:TryPickup(job.player,job.slot,job)end
end
function Game:EndCapture(player,slot)
    local job=self.capturing[player]
    if job and job.slot==slot then
        self:AdvanceCapture(job,workspace:GetServerTimeNow())
        self:CancelCapture(player)
    end
end
function Game:TryPickup(player,slot,job)
    -- Only a live server reservation that has completed its full duration can award.
    if not job or job.slot~=slot or not self:CaptureValid(job)
        or workspace:GetServerTimeNow()-job.started<job.duration then return false end
    local root=rootOf(player)
    slot.owner=player;self.carried[player]=slot
    self:CancelCapture(player) -- carrier is already set, so the existing chase continues
    slot.model.Box.Prompt.Enabled=false
    slot.model:PivotTo(root.CFrame*CFrame.new(0,.5,-2.3*Catalog.WorldScale))
    for _,part in slot.model:GetDescendants() do if part:IsA("BasePart") then part.Anchored=false end end
    local weld=Instance.new("WeldConstraint")
    weld.Name="CarryWeld";weld.Part0=root;weld.Part1=slot.model.Box;weld.Parent=slot.model.Box
    player:SetAttribute("CarriedGift",slot.rarity)
    self:ApplyUpgrades(player)
    self.signal:FireAllClients("Captured",slot.model.Name)
    self:Notify(player,"Схватил! Беги в свой сад.")
    return true
end
function Game:Detach(slot)
    local weld=slot.model.Box:FindFirstChild("CarryWeld")
    if weld then weld:Destroy() end
    for _,part in slot.model:GetDescendants() do if part:IsA("BasePart") then part.Anchored=true end end
    local player=slot.owner
    if player then self.carried[player]=nil;player:SetAttribute("CarriedGift","");self:ApplyUpgrades(player) end
    slot.owner=nil
end
function Game:DropPosition(root)
    local rays=RaycastParams.new()
    rays.FilterType=Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances={self.scene.Geometry,self.scene.Bases}
    rays.RespectCanCollide=true
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances=rays.FilterDescendantsInstances
    overlap.RespectCanCollide=true
    for _,offset in {root.CFrame.LookVector*4*Catalog.WorldScale,Vector3.zero,root.CFrame.RightVector*4*Catalog.WorldScale,-root.CFrame.RightVector*4*Catalog.WorldScale,-root.CFrame.LookVector*4*Catalog.WorldScale} do
        local wall=offset.Magnitude>0 and workspace:Raycast(root.Position,offset,rays)
        local candidate=wall and wall.Position+wall.Normal*1.8*Catalog.WorldScale or root.Position+offset
        local ground=workspace:Raycast(candidate+Vector3.new(0,2,0),Vector3.new(0,-48,0),rays)
        if ground and ground.Normal.Y>.8 then
            local position=ground.Position+Vector3.new(0,1.45*Catalog.WorldScale,0)
            if #workspace:GetPartBoundsInBox(CFrame.new(position+Vector3.new(0,.35*Catalog.WorldScale,0)),Vector3.new(2.8,3.2,2.8)*Catalog.WorldScale,overlap)==0 then
                return position
            end
        end
    end
    return nil
end
function Game:Drop(player,forced)
    local slot=self.carried[player]
    if not slot then return false end
    if not forced and (not self.progress:IsReady(player) or not self:TakeAction(player)) then return false end
    local root=rootOf(player)
    local position=root and self:DropPosition(root)
    if not position and not forced then self:Notify(player,"Здесь тесно. Отойди от мебели, чтобы бросить подарок.");return false end
    -- Death in the void or a fully occupied corner must not strand a shared gift.
    position=position or slot.point.Position+Vector3.new(0,1.45*Catalog.WorldScale,0)
    self:Detach(slot)
    self:EndChases(player,"Resolved")
    slot.model:PivotTo(CFrame.new(position))
    slot.model.Box.Prompt.Enabled=true
    return true
end
-- Choose a clear physical arc before applying the impulse. Furniture is checked along
-- the whole flight, not just at its destination; there is no character teleport.
function Game:ThrowVelocity(root,keeper)
    local config=Catalog.Catch
    local away=root.Position-keeper.root.Position
    away=Vector3.new(away.X,0,away.Z)
    away=away.Magnitude>.1 and away.Unit or -keeper.root.CFrame.LookVector
    local rays=RaycastParams.new();rays.FilterType=Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances={self.scene.Geometry,self.scene.Bases};rays.RespectCanCollide=true
    local best,bestDistance
    for _,power in {1,.72,.45} do
        for _,angle in {0,math.pi/4,-math.pi/4,math.pi/2,-math.pi/2,math.pi} do
            local direction=CFrame.Angles(0,angle,0):VectorToWorldSpace(away)
            local velocity=direction*config.HorizontalSpeed*power+Vector3.new(0,config.VerticalSpeed*power,0)
            local previous=root.Position
            local clear=true
            local flight=2*velocity.Y/workspace.Gravity
            for step=1,12 do
                local t=flight*step/12
                local position=root.Position+velocity*t-Vector3.new(0,workspace.Gravity*t*t/2,0)
                if workspace:Spherecast(previous,2,position-previous,rays) then clear=false;break end
                previous=position
            end
            local floor=clear and workspace:Raycast(previous+Vector3.new(0,2,0),Vector3.new(0,-12,0),rays)
            local distance=(previous-root.Position).Magnitude
            if floor and floor.Normal.Y>.8 and (not bestDistance or distance>bestDistance) then
                best=velocity;bestDistance=distance
            end
        end
        if best then return best end
    end
    -- A crowded corner gets a small upward physical shove until a full arc is free.
    return Vector3.new(0,config.VerticalSpeed*.45,0)
end
function Game:FinishRecovery(player)
    local recovery=self.recovering[player]
    if not recovery then return end
    self.recovering[player]=nil
    local humanoid=recovery.humanoid
    if humanoid.Parent then
        humanoid.PlatformStand=false;humanoid.AutoRotate=true
        if humanoid.Health>0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    if recovery.root.Parent then
        recovery.root.AssemblyAngularVelocity=Vector3.zero
        recovery.root:SetNetworkOwnershipAuto()
    end
    self:ApplyUpgrades(player)
end
function Game:Catch(player,keeper)
    local now=workspace:GetServerTimeNow()
    local root=rootOf(player)
    if not root or (not self.carried[player] and not self.capturing[player])or not self.progress:IsReady(player) or self.recovering[player]
        or now<(player:GetAttribute("CatchGraceUntil") or 0) or inside(self.scene.SafeZone,root.Position) then return false end
    local velocity=self:ThrowVelocity(root,keeper)
    self:CancelCapture(player);self:Drop(player,true);self:EndChases(player)
    player:SetAttribute("CatchGraceUntil",now+Catalog.Catch.GraceSeconds)
    local humanoid=root.Parent:FindFirstChildOfClass("Humanoid")
    Vehicle.Eject(humanoid)
    self.recovering[player]={root=root,humanoid=humanoid,started=now}
    humanoid.WalkSpeed=0;humanoid.PlatformStand=true;humanoid.AutoRotate=false
    root:SetNetworkOwner(nil)
    root:ApplyImpulse(root.AssemblyMass*(velocity-root.AssemblyLinearVelocity))
    root.AssemblyAngularVelocity=Vector3.new(Catalog.Catch.Spin,.8,0)
    self.signal:FireClient(player,"Caught",root.Position)
    self:Notify(player,"УХ! Охранник заметил попытку. Отступи и попробуй снова!")
    return true
end
function Game:StepRecovery(player,now)
    local recovery=self.recovering[player]
    if not recovery then return end
    local root=recovery.root
    if not root.Parent or recovery.humanoid.Health<=0 or player.Character~=root.Parent then self:FinishRecovery(player);return end
    local v=root.AssemblyLinearVelocity
    local flat=Vector3.new(v.X,0,v.Z)
    local config=Catalog.Catch
    if flat.Magnitude>config.MaxHorizontalSpeed then flat=flat.Unit*config.MaxHorizontalSpeed end
    root.AssemblyLinearVelocity=flat+Vector3.new(0,math.clamp(v.Y,-config.MaxFallSpeed,config.MaxVerticalSpeed),0)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={self.scene.Geometry,self.scene.Bases};params.RespectCanCollide=true
    local ground=workspace:Raycast(root.Position,Vector3.new(0,-3.8,0),params)
    if now-recovery.started>.25 and v.Y<=2 and ground then
        recovery.landedAt=recovery.landedAt or now
    end
    if (recovery.landedAt and now>=recovery.landedAt+config.LandingDelay) or now-recovery.started>=config.MaxFlightSeconds then self:FinishRecovery(player) end
end
function Game:Deliver(player)
    local slot=self.carried[player]
    if not slot or not self.progress:IsReady(player) or not self:InOwnBase(player) then return false end
    if player:GetAttribute("PendingGift")~="" then return false end
    -- Commit the delivered identity first; there is no yield or second carried balance.
    player:SetAttribute("PendingGift",slot.rarity)
    player:SetAttribute("PendingGiftSize",slot.size)
    self:Detach(slot);slot.model:Destroy();slot.model=nil
    slot.readyAt=workspace:GetServerTimeNow()+Catalog.GiftRespawnSeconds
    self:EndChases(player,"Safe")
    self.progress:RequestSave(player)
    self:Notify(player,"Доставлено! Подойди к столу «ОТКРЫТЬ» в своём саду.")
    return true
end
function Game:TryOpen(player)
    local plot=self.plots[player]
    if not plot or not self:InOwnBase(player) or not self:CanUse(player,plot.OpenStation) then return false end
    local rarity=player:GetAttribute("PendingGift")
    if not Catalog.Gifts[rarity] or not self:TakeAction(player) then return false end
    local id=Catalog.Roll(Catalog.Gifts[rarity].Contents,self.rng)
    local size=player:GetAttribute("PendingGiftSize")
    if not Catalog.Size(size)then return false end
    local collection=self.progress:GetCollection(player)
    local existing
    for _,entry in collection do if entry.Toy==id and entry.SizeMultiplier==size then existing=entry;break end end
    if existing and existing.Count>=LIMIT then return false end
    -- Award before visual feedback; repeat, death and disconnect cannot duplicate the opening.
    player:SetAttribute("PendingGift","");player:SetAttribute("PendingGiftSize",0)
    if existing then existing.Count+=1 else table.insert(collection,{Toy=id,SizeMultiplier=size,Count=1}) end
    player:SetAttribute("Income",Catalog.Income(collection))
    self.progress:RequestSave(player)
    self:BroadcastCollection(player)
    self.signal:FireClient(player,"Opened",{Toy=id,Gift=rarity,SizeMultiplier=size,Income=Catalog.ToyIncome(id,size)})
    return true,id
end
function Game:TryBuy(player,kind)
    local plot=self.plots[player]
    if kind~=nil and kind~="Strength"then return false end
    local strength=kind=="Strength"
    if not plot or not self:InOwnBase(player)or not self:CanUse(player,strength and plot.StrengthStation or plot.SpeedStation)or not self:TakeAction(player)then return false end
    local attribute=strength and "StrengthLevel"or "SpeedLevel"
    local level=player:GetAttribute(attribute)
    if level>=LIMIT then return false end
    local price=strength and Catalog.StrengthPrice(level)or Catalog.SpeedPrice(level)
    if strength and level>=Catalog.StrengthMaxLevel then return false end
    if not price then return false end
    local coins=player:GetAttribute("Coins")
    if coins<price then self:Notify(player,"Нужно "..price.." монет. Игрушки приносят доход каждую секунду.");return false end
    player:SetAttribute("Coins",coins-price);player:SetAttribute(attribute,level+1)
    self:ApplyUpgrades(player);self.progress:RequestSave(player)
    self:Notify(player,strength and "Сила выросла — быстрее забирай подарки!"or string.format("Скорость %.1f — пора бежать дальше!",Catalog.SpeedForLevel(level+1)))
    return true
end
function Game:ApplyUpgrades(player)
    local root=rootOf(player)
    if not root then return end
    local character=root.Parent
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed=self.recovering[player]and 0 or Catalog.SpeedForLevel(player:GetAttribute("SpeedLevel"))
    humanoid.UseJumpPower=false;humanoid.JumpHeight=7.2
    local slot=self.carried[player]
    if slot and not self.recovering[player] then
        humanoid.WalkSpeed*=Catalog.CarryMultiplier(slot.rarity,player:GetAttribute("StrengthLevel"))
    end
end
function Game:AddPlayer(player,data)
    local used={}
    for _,plot in self.plots do used[plot]=true end
    local plots=self.scene.Bases:GetChildren()
    table.sort(plots,function(a,b) return a.Name<b.Name end)
    local plot
    for _,candidate in plots do if not used[candidate] then plot=candidate;break end end
    if not plot then return false end
    self.plots[player]=plot
    plot:SetAttribute("OwnerUserId",player.UserId)
    plot.Sign.SurfaceGui.Label.Text=player.DisplayName.."\nЖИВОЙ САД"
    player.RespawnLocation=plot.Spawn
    player:SetAttribute("BaseId",plot.Name)
    player:SetAttribute("Coins",data.Coins);player:SetAttribute("SpeedLevel",data.SpeedLevel)
    player:SetAttribute("BootsCompensated",data.BootsCompensated)
    player:SetAttribute("BootsUnlocked",data.BootsUnlocked) -- preserved legacy purchase, never used for movement
    player:SetAttribute("StrengthLevel",data.StrengthLevel);player:SetAttribute("CapturingGift","")
    player:SetAttribute("PendingGift",data.PendingGift);player:SetAttribute("PendingGiftSize",data.PendingGiftSize);player:SetAttribute("CarriedGift","")
    player:SetAttribute("Chasing",false);player:SetAttribute("ChaseGuard","");player:SetAttribute("CatchGraceUntil",0)
    if not self.progress:Activate(player) then self:RemovePlayer(player);return false end
    player:SetAttribute("Income",Catalog.Income(self.progress:GetCollection(player)))
    self.selected[player]={};self:BroadcastCollection(player)
    return true
end
function Game:CharacterAdded(player,character)
    local root=character:WaitForChild("HumanoidRootPart",10)
    local humanoid=character:WaitForChild("Humanoid",10)
    if not root or not humanoid or player.Character~=character then return end
    local function assign(part)if part:IsA("BasePart")then part.CollisionGroup="ToyPlayer"end end
    for _,part in character:GetDescendants()do assign(part)end
    character.DescendantAdded:Connect(assign)
    local plot=self.plots[player]
    if plot then character:PivotTo(plot.Spawn.CFrame*CFrame.new(0,4,0)) end
    self:ApplyUpgrades(player)
    humanoid.Died:Connect(function()
        self:CancelCapture(player);self:Drop(player,true);self:EndChases(player);self:FinishRecovery(player)
    end)
end
function Game:RemovePlayer(player)
    self:CancelCapture(player);self:Drop(player,true);self:EndChases(player);self:FinishRecovery(player)
    for _,keeper in self.keepers do keeper.notices[player]=nil end
    local plot=self.plots[player]
    if plot then plot:SetAttribute("OwnerUserId",nil);plot.Sign.SurfaceGui.Label.Text="СВОБОДНЫЙ\nЖИВОЙ САД" end
    self.plots[player]=nil;self.cooldowns[player]=nil;self.recovering[player]=nil
    self.selected[player]=nil;self.customDisplay[player]=nil;self.syncAt[player]=nil
    self.signal:FireAllClients("CollectionRemoved",player.UserId)
end
function Game:Step(now)
    for _,job in self.capturing do self:AdvanceCapture(job,now)end
    for player in self.plots do
        local root=rootOf(player)
        player:SetAttribute("AtBase",root~=nil and self:InOwnBase(player)==true)
        if root and self.carried[player] then self:Deliver(player) end
        self:StepRecovery(player,now)
    end
    local seconds=math.floor(now-self.lastIncome)
    if seconds>=1 then
        self.lastIncome+=seconds
        for player in self.plots do
            if self.progress:IsReady(player) then
                local income=player:GetAttribute("Income")
                player:SetAttribute("Coins",math.min(LIMIT,player:GetAttribute("Coins")+income*seconds))
            end
        end
    end
    for _,slot in self.slots do if not slot.model and now>=(slot.readyAt or math.huge) then self:SpawnGift(slot) end end
    for _,keeper in self.keepers do keeper:Step(now) end
    for player in self.plots do self:UpdateChase(player) end
end
return Game
