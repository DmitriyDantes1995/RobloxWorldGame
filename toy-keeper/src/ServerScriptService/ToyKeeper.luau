local Players=game:GetService("Players")
local Catalog=require(game:GetService("ReplicatedStorage").ToyCatalog)
local Keeper={}
Keeper.__index=Keeper
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
function Keeper.new(scene,model,points,settings,onCaught,inBase,onEscape)
    local cf,size=model:GetBoundingBox()
    local root=model.HumanoidRootPart
    local radius=math.max(math.abs(cf.X-root.Position.X)+size.X/2,math.abs(cf.Z-root.Position.Z)+size.Z/2)+.5
    local self=setmetatable({scene=scene,model=model,root=root,humanoid=model.Humanoid,
        settings=settings,onCaught=onCaught,inBase=inBase,onEscape=onEscape,pursuits={},notices={},
        patrolIndex=1,joints={},switchAt=0,radius=radius,height=size.Y},Keeper)
    self.points=points:GetChildren()
    table.sort(self.points,function(a,b)return a.Name<b.Name end)
    self.patrolIndex=self:NearestPatrolPoint()
    self.boundaryZ=scene.SafeZone.Position.Z+scene.SafeZone.Size.Z/2+radius+1
    local lane=scene.Corridor
    self.minX=lane.Position.X-lane.Size.X/2+radius
    self.maxX=lane.Position.X+lane.Size.X/2-radius
    self.maxZ=lane.Position.Z+lane.Size.Z/2-radius
    for _,v in model:GetDescendants()do
        if v:IsA("BasePart")then v.CollisionGroup="ToyGuard";if not v.Anchored then v:SetNetworkOwner(nil)end end
        if v:IsA("Motor6D")then self.joints[v.Name]={joint=v,base=v.C0}end
    end
    local attachment=Instance.new("Attachment");attachment.Name="NoticeFacing";attachment.Parent=root
    local facing=Instance.new("AlignOrientation");facing.Name="NoticeFacing";facing.Mode=Enum.OrientationAlignmentMode.OneAttachment
    facing.Attachment0=attachment;facing.MaxTorque=1e7;facing.Responsiveness=14;facing.Enabled=false;facing.Parent=root
    self.facing=facing
    local alert=Instance.new("Highlight");alert.Name="TheftAlert";alert.Adornee=model
    alert.FillTransparency=1;alert.OutlineTransparency=.15;alert.DepthMode=Enum.HighlightDepthMode.Occluded
    alert.Enabled=false;alert.Parent=model;self.alert=alert
    self:SetState("Guarding")
    return self
end
function Keeper:NearestPatrolPoint()
    local nearest,distance=1,math.huge
    for i,point in self.points do
        local gap=horizontal(self.root.Position-point.Position).Magnitude
        if gap<distance then nearest=i;distance=gap end
    end
    return nearest
end
function Keeper:SetState(state)
    self.state=state;self.model:SetAttribute("State",state)
    local chasing=state=="Chasing" or state=="Striking"
    if self.alert then
        self.alert.Enabled=chasing or state=="Alert"
        self.alert.OutlineColor=state=="Alert" and Color3.fromRGB(255,201,72) or Color3.fromRGB(255,90,78)
    end
    self.model.EyeL.Color=state=="Alert" and Color3.fromRGB(255,201,72) or chasing and Color3.fromRGB(255,90,78)or Color3.fromRGB(132,237,255)
    self.model.EyeR.Color=self.model.EyeL.Color
    self.root.Mood.Label.Text=self.settings.GuardName.."\n"..(state=="Alert" and "! ЭЙ! РУКИ ПРОЧЬ!" or chasing and "ВЕРНИ ПОДАРОК!"or state=="Returning"and "Назад к подаркам…"or "Можно смотреть. Не трогать!")
end
function Keeper:Root(player)
    local char=player.Character
    local h=char and char:FindFirstChildOfClass("Humanoid")
    if player.Parent~=Players or not player:GetAttribute("ProgressLoaded")or not h or h.Health<=0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end
function Keeper:StartChase(player,gift)
    local now=workspace:GetServerTimeNow()
    if not self:Root(player)or now<(player:GetAttribute("CatchGraceUntil")or 0)then return false end
    if self.pursuits[player]then return true end
    local notice=self.notices[player]
    if not notice or notice.gift~=gift then
        notice={gift=gift,warningUntil=now+self.settings.Warning};self.notices[player]=notice
    end
    self.pursuits[player]={warningUntil=notice.warningUntil,started=now}
    if not self.target then self.target=player;self:SetState(now<notice.warningUntil and "Alert" or "Chasing")end
    return true
end
function Keeper:RemovePlayer(player,reason)
    if reason then self.notices[player]=nil end
    if not self.pursuits[player]then return end
    self.pursuits[player]=nil
    if self.target==player then
        self.target=nil;self.model:SetAttribute("TargetUserId",0)
        self.patrolIndex=self:NearestPatrolPoint();self:SetState("Returning")
    end
    if reason then self.onEscape(player,reason,self.settings.GuardName)end
end
function Keeper:Navigate(goal)
    -- The entire rig fits within this authored, obstacle-free strip. Do not deform
    -- navigation waypoints or launch asynchronous maze paths on an open floor.
    local destination=Vector3.new(math.clamp(goal.X,self.minX,self.maxX),self.root.Position.Y,math.clamp(goal.Z,self.boundaryZ,self.maxZ))
    self.humanoid:MoveTo(destination)
end
function Keeper:Step(now)
    local best,bestScore
    for player in self.pursuits do
        local root=self:Root(player)
        if not root or ((player:GetAttribute("CarriedGift")or "")=="" and (player:GetAttribute("CapturingGift")or "")=="")then self:RemovePlayer(player)
        elseif self.inBase(root.Position)then self:RemovePlayer(player,"Safe")
        else
            local score=horizontal(root.Position-self.root.Position).Magnitude
            if not bestScore or score<bestScore then best=player;bestScore=score end
        end
    end
    local currentRoot=self.target and self:Root(self.target)
    local currentGap=currentRoot and horizontal(currentRoot.Position-self.root.Position).Magnitude or math.huge
    if best and (not self.target or (now>=self.switchAt and best~=self.target and bestScore+Catalog.Guard.TargetSwitchMargin<currentGap))then
        self.target=best;self.switchAt=now+Catalog.Guard.TargetSwitchSeconds;self:SetState("Chasing")
    end
    local pursuit=self.target and self.pursuits[self.target]
    self.facing.Enabled=false
    local goal
    if pursuit then
        local root=self:Root(self.target)
        self.model:SetAttribute("TargetUserId",self.target.UserId)
        self.humanoid.WalkSpeed=now<pursuit.warningUntil and 0 or self.settings.ChaseSpeed
        goal=root.Position
        if not self.strike then
            local warning=now<pursuit.warningUntil
            local state=warning and "Alert" or "Chasing"
            if self.state~=state then self:SetState(state)end
            local direction=horizontal(root.Position-self.root.Position)
            if warning and direction.Magnitude>.1 then
                self.facing.CFrame=CFrame.lookAt(Vector3.zero,direction)
                self.facing.Enabled=true
            end
        end
        if now>=pursuit.warningUntil and now>=(self.target:GetAttribute("CatchGraceUntil")or 0)
            and horizontal(root.Position-self.root.Position).Magnitude<self.radius+1.5
            and math.abs(root.Position.Y-self.root.Position.Y)<self.height*.6 and not self.strike then
            self.strike={player=self.target,hitAt=now+Catalog.Catch.Windup,endsAt=now+Catalog.Catch.Windup+Catalog.Catch.FollowThrough}
            self:SetState("Striking")
        end
    else
        self.humanoid.WalkSpeed=self.settings.PatrolSpeed
        goal=self.points[self.patrolIndex].Position
        if horizontal(self.root.Position-goal).Magnitude<4 then
            if self.state=="Returning"then self:SetState("Guarding")end
            self.patrolIndex=self.patrolIndex%#self.points+1;goal=self.points[self.patrolIndex].Position
        end
    end
    local strike=self.strike
    if strike then
        self.humanoid.WalkSpeed=0;self.humanoid:MoveTo(self.root.Position)
        if not strike.hit and now>=strike.hitAt then
            strike.hit=true
            local victim=self:Root(strike.player)
            if victim and self.pursuits[strike.player]and not self.inBase(victim.Position)
                and horizontal(victim.Position-self.root.Position).Magnitude<self.radius+5
                and math.abs(victim.Position.Y-self.root.Position.Y)<self.height*.6 then self.onCaught(strike.player,self)end
        end
        if now>=strike.endsAt then self.strike=nil;self:SetState(self.target and "Chasing"or "Returning")end
    elseif goal then self:Navigate(goal)end
    local moving=horizontal(self.root.AssemblyLinearVelocity).Magnitude>1
    local kind=self.settings.Keeper
    for name,data in self.joints do
        local phase=now*self.settings.Motion
        local swing=moving and math.sin(phase)*.3 or math.sin(now*1.5)*.025
        local yaw,roll=0,0
        if kind=="Plush" then
            swing*=1.6;roll=math.sin(phase)*.09
            if name=="RootJoint" then swing=0;roll=moving and math.sin(phase)*.09 or 0 end
        elseif kind=="Clockwork" then
            swing=moving and math.floor(math.sin(phase)*3)/3*.5 or 0
            yaw=math.sin(now*3)>.8 and .12 or 0
            roll=math.sin(phase*2)*.045
        else
            swing*=1.3
            if name:find("Shoulder") then swing=-.55+math.sin(phase)*.22;roll=.13 end
            if name=="RootJoint" then swing=moving and -.18 or -.06 end
        end
        if name=="Left Hip" or name=="Right Shoulder" then swing=-swing end
        if name=="Neck" then swing=math.sin(now*(kind=="Clockwork" and 5 or 1.8))*.08 end
        if self.strike then
            local stage=now<self.strike.hitAt and -1 or 1
            if name:find("Shoulder") then swing=stage*1.35;roll=0
            elseif name=="RootJoint" then swing=stage*.2 end
        end
        data.joint.C0=data.base*CFrame.Angles(swing,yaw,roll)
    end
end
return Keeper
