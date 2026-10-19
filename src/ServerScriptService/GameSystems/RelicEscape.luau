local TweenService=game:GetService("TweenService")
local Config=require(script.Parent.LairConfig)
local Escape={}
Escape.__index=Escape

function Escape.new(scene,traps,keeper,carrier)
    local self=setmetatable({scene=scene,model=scene.RelicEscape,traps=traps,keeper=keeper,carrier=carrier,lights={},mechanism={}},Escape)
    for _,part in scene.Geometry:GetDescendants() do
        if part:IsA("PointLight") then table.insert(self.lights,{light=part,color=part.Color,brightness=part.Brightness}) end
    end
    self.rest=self.model.Pedestal.CFrame
    self.mechanismCenter=self.model.Mechanism:GetPivot()
    for _,part in self.model.Mechanism:GetChildren() do table.insert(self.mechanism,{part=part,rest=part.CFrame}) end
    self:Reset()
    return self
end

function Escape:Reset()
    if self.animation then self.animation:Cancel();self.animation=nil end
    for _,data in self.mechanism do
        if data.animation then data.animation:Cancel();data.animation=nil end
        data.part.CFrame=data.rest
    end
    self.started=false;self.scenario=0;self.phase=nil;self.nextPhase=nil;self.waitingForClosure=false
    self.model.Pedestal.CFrame=self.rest
    for _,data in self.lights do data.light.Color=data.color;data.light.Brightness=data.brightness end
    self.scene:SetAttribute("RelicEscapeActive",false)
    self.scene:SetAttribute("RelicEscapeScenario",0)
    self.scene:SetAttribute("RelicEscapePhase","")
    self.keeper.relicCarrier=nil
    self.traps.relicFloors=false
    self.model.ReturnCover.CanCollide=true;self.model.ReturnCover.Transparency=0
end

function Escape:SetPhase(phase,now,hold)
    self.phase=phase
    self.scene:SetAttribute("RelicEscapePhase",phase)
    local requests={ArchiveWall={close=false},BoilerWall={close=false},VaultWall={close=false},VaultNorthGate={close=false}}
    if phase=="UpperDetour" then
        requests.VaultWall={close=true,hold=hold};requests.VaultNorthGate={close=true,hold=hold}
    elseif phase=="WestClosed" then requests.VaultWall={close=true,hold=hold}
    elseif phase=="EastClosed" then requests.BoilerWall={close=true,hold=hold} end
    self.closing={}
    for name,request in requests do if request.close then self.closing[name]=true end end
    self.traps:SetRelicWalls(requests)
    self.holdDuration=hold;self.waitingForClosure=hold~=nil
    self.nextPhase=not hold and now+Config.RelicOpenSeconds or nil
end

function Escape:Start(player,position)
    if self.started then return false end
    self.started=true
    local choice=math.floor(Config.RelicScenario)
    self.scenario=choice>=1 and choice<=3 and choice or Random.new():NextInteger(1,3)
    self.scene:SetAttribute("RelicEscapeActive",true)
    self.scene:SetAttribute("RelicEscapeScenario",self.scenario)
    self.animation=TweenService:Create(self.model.Pedestal,TweenInfo.new(.75,Enum.EasingStyle.Back,Enum.EasingDirection.In),{CFrame=self.rest-Vector3.new(0,1.5,0)})
    self.animation:Play()
    for _,data in self.mechanism do
        local target=self.mechanismCenter*CFrame.Angles(math.pi*.75,0,0)*self.mechanismCenter:ToObjectSpace(data.rest)
        data.animation=TweenService:Create(data.part,TweenInfo.new(1.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{CFrame=target})
        data.animation:Play()
    end
    self.keeper.relicCarrier=player
    self.keeper:BeginRelicHunt(position)
    for _,data in self.lights do
        data.light.Color=Color3.fromRGB(255,133,64)
        data.light.Brightness=math.max(data.brightness,1)
    end
    local now=os.clock()
    if self.scenario==1 then self:SetPhase("UpperDetour",now,Config.RelicFirstBlockSeconds)
    elseif self.scenario==2 then
        self.traps.relicFloors=true
        self:SetPhase("Underground",now,nil)
        self.nextPhase=nil
    else self:SetPhase("WestClosed",now,Config.RelicFirstBlockSeconds) end
    return true
end

function Escape:Step(players,now)
    -- The return hatch opens from below; it is not a free downward shortcut in A.
    local open=self.started and self.scenario==2
    local occupied=false
    local cover=self.model.ReturnCover
    for _,player in players do
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local p=cover.CFrame:PointToObjectSpace(root.Position)
            if math.abs(p.X)<6 and math.abs(p.Z)<6 then
                if p.Y< -2 and p.Y> -27 then open=true end
                if math.abs(p.Y)<5 then occupied=true end
            end
        end
    end
    if open or not occupied then cover.CanCollide=not open;cover.Transparency=open and .85 or 0 end
    if not self.started then return end
    self.keeper.relicCarrier=self.carrier()
    if self.waitingForClosure and self.traps:RelicWallsClosed(self.closing) then
        self.waitingForClosure=false;self.nextPhase=now+self.holdDuration
    end
    if not self.nextPhase or now<self.nextPhase then return end
    if self.phase=="UpperDetour" then
        self:SetPhase("UpperOpening",now,nil)
    elseif self.phase=="UpperOpening" then
        if self.traps:RelicWallsOpen({VaultWall=true,VaultNorthGate=true}) then self:SetPhase("UpperDetour",now,Config.RelicBlockSeconds) end
    elseif self.phase=="WestClosed" then
        self:SetPhase("WestOpening",now,nil)
    elseif self.phase=="WestOpening" then
        if self.traps:RelicWallsOpen({VaultWall=true}) then self:SetPhase("EastClosed",now,Config.RelicBlockSeconds) end
    elseif self.phase=="EastClosed" then self:SetPhase("EastOpening",now,nil)
    elseif self.phase=="EastOpening" and self.traps:RelicWallsOpen({BoilerWall=true}) then
        self:SetPhase("WestClosed",now,Config.RelicBlockSeconds)
    end
end

return Escape
