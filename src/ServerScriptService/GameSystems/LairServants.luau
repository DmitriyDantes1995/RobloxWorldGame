local PathfindingService=game:GetService("PathfindingService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Safety=require(script.Parent.LairSafety)
local Economy=require(script.Parent.GameEconomy)
local Servants={}
Servants.__index=Servants

local function arrived(a,b)
    local d=a-b
    return Vector3.new(d.X,0,d.Z).Magnitude<2 and math.abs(d.Y)<3
end

function Servants:GeometryChanged()
    for _,actor in self.actors do
        actor.revision+=1;actor.waypoints=nil;actor.goal=nil;actor.nextPath=0
        actor.humanoid:MoveTo(actor.root.Position)
    end
end

local function state(actor,name)
    actor.state=name;actor.model:SetAttribute("State",name)
    local alert=name=="Notice" or name=="Chase"
    for _,eye in {actor.model.EyeL,actor.model.EyeR} do
        eye.Color=alert and Color3.fromRGB(255,110,65) or Color3.fromRGB(145,245,235)
    end
end

function Servants:Reset()
    self:GeometryChanged()
    for _,actor in self.actors do
        actor.target=nil;actor.lastSeen=nil;actor.noticeReady=0;actor.recoverUntil=0;actor.patrolIndex=1
        actor.root.AssemblyLinearVelocity=Vector3.zero;actor.root.AssemblyAngularVelocity=Vector3.zero
        actor.model:PivotTo(actor.home);actor.humanoid:MoveTo(actor.root.Position)
        state(actor,"Patrol")
    end
end

function Servants:Eligible(player)
    if player.Parent~=Players or not Economy.IsReady(player) then return nil end
    local root=Safety.Root(player)
    if not root or Safety.InBase(self.scene,root.Position) or Safety.InHide(self.scene,root.Position)
        or not Safety.InLair(self.scene,root.Position) then return nil end
    return root
end

function Servants:Visible(actor,root)
    local hit=workspace:Raycast(actor.model.Head.Position,root.Position-actor.model.Head.Position,self.ray)
    return not hit or hit.Instance:IsDescendantOf(root.Parent)
end

function Servants:Move(actor,goal,speed,now)
    actor.humanoid.WalkSpeed=speed
    if arrived(actor.root.Position,goal) then actor.humanoid:MoveTo(actor.root.Position);return true end
    if now>=actor.nextPath and not actor.computing then
        actor.nextPath=now+1
        if not actor.goal or (goal-actor.goal).Magnitude>3 or not actor.waypoints or now>=(actor.pathExpires or 0) then
            actor.goal=goal;actor.pathExpires=now+2;actor.revision+=1
            local revision=actor.revision
            local origin=actor.root.Position
            actor.computing=true
            task.spawn(function()
                local path=PathfindingService:CreatePath({AgentRadius=1.2,AgentHeight=3,AgentCanJump=false,AgentCanClimb=true,WaypointSpacing=3})
                local ok=pcall(function()path:ComputeAsync(origin,goal)end)
                actor.computing=false
                if revision~=actor.revision or not actor.model.Parent then return end
                if ok and path.Status==Enum.PathStatus.Success then
                    actor.waypoints=path:GetWaypoints();actor.waypointIndex=2
                else actor.waypoints=nil end
            end)
        end
    end
    local points=actor.waypoints
    if points then
        local point=points[actor.waypointIndex]
        while point and arrived(actor.root.Position,point.Position) do
            actor.waypointIndex+=1;point=points[actor.waypointIndex]
        end
        if point then actor.humanoid:MoveTo(point.Position)
        else actor.waypoints=nil;actor.goal=nil;actor.humanoid:MoveTo(actor.root.Position) end
    else actor.humanoid:MoveTo(actor.root.Position) end
    return false
end

local function retreat(actor,now)
    actor.target=nil;actor.recoverUntil=now+5
    actor.revision+=1;actor.waypoints=nil;actor.goal=nil;actor.nextPath=0
    actor.humanoid:MoveTo(actor.root.Position)
    state(actor,"Retreat")
end

function Servants:Step(players,now)
    for _,actor in self.actors do
        if actor.state=="Patrol" then
            if now>=actor.noticeReady then
                local nearest,distance=nil,18
                for _,player in players do
                    local root=self:Eligible(player)
                    if root then
                        local d=(root.Position-actor.root.Position).Magnitude
                        if d<distance and (root.Position-actor.home.Position).Magnitude<=40 and self:Visible(actor,root) then
                            nearest=player;distance=d
                        end
                    end
                end
                if nearest then
                    actor.target=nearest;actor.lastSeen=Safety.Root(nearest).Position
                    actor.noticeUntil=now+.55;actor.chaseUntil=now+4.55;actor.noticeReady=now+10
                    actor.revision+=1;actor.waypoints=nil;actor.goal=nil
                    actor.humanoid:MoveTo(actor.root.Position)
                    state(actor,"Notice")
                    self.keeper:Investigate(nearest,actor.lastSeen)
                end
            end
            if actor.state=="Patrol" then
                local point=actor.patrol[actor.patrolIndex]
                if self:Move(actor,point.Position,7,now) then actor.patrolIndex=actor.patrolIndex%#actor.patrol+1 end
            end
        elseif actor.state=="Notice" or actor.state=="Chase" then
            local root=actor.target and self:Eligible(actor.target)
            if not root or now>=actor.chaseUntil or (actor.root.Position-actor.home.Position).Magnitude>40
                or (root.Position-actor.home.Position).Magnitude>40 then retreat(actor,now)
            else
                local visible=self:Visible(actor,root)
                if visible then actor.lastSeen=root.Position end
                if actor.state=="Notice" then
                    if now>=actor.noticeUntil then state(actor,"Chase");actor.nextPath=0 end
                else
                    local delta=root.Position-actor.root.Position
                    if visible and Vector3.new(delta.X,0,delta.Z).Magnitude<=3 and math.abs(delta.Y)<=3 then
                        self.slow(actor.target);retreat(actor,now)
                    elseif self:Move(actor,actor.lastSeen,18.5,now) and not visible then retreat(actor,now) end
                end
            end
        elseif actor.state=="Retreat" then
            if self:Move(actor,actor.home.Position,10,now) then
                state(actor,"Recover")
                actor.recoverUntil=math.max(actor.recoverUntil,now+2)
            end
        elseif actor.state=="Recover" and now>=actor.recoverUntil then state(actor,"Patrol") end
    end
end

function Servants.new(scene,keeper,slow)
    local self=setmetatable({scene=scene,keeper=keeper,slow=slow,actors={}},Servants)
    self.ray=RaycastParams.new();self.ray.FilterType=Enum.RaycastFilterType.Exclude
    self.ray.FilterDescendantsInstances={scene.Servants,scene.Treasures,scene.Effects};self.ray.RespectCanCollide=true
    local models=scene.Servants:GetChildren()
    assert(#models==2,"Prepare exactly two guardian servants in Edit")
    for _,model in models do
        local root=model.HumanoidRootPart;local humanoid=model.Humanoid
        root.Anchored=false
        root:SetNetworkOwner(nil)
        local patrol=scene.ServantPatrolPoints[model.Name]:GetChildren();table.sort(patrol,function(a,b)return a.Name<b.Name end)
        assert(#patrol>0,"Servant requires explicit patrol points")
        table.insert(self.actors,{model=model,root=root,humanoid=humanoid,home=model:GetPivot(),patrol=patrol,
            revision=0,nextPath=0,computing=false,joints={model.HumanoidRootPart.BodyJoint,model.Head.Neck,model.Torso.ArmLJoint,model.Torso.ArmRJoint,model.Torso.LegLJoint,model.Torso.LegRJoint}})
    end
    for _,actor in self.actors do
        actor.rest={}
        for i,joint in actor.joints do actor.rest[i]=joint.C0 end
    end
    self:Reset()
    local connection
    connection=RunService.Heartbeat:Connect(function()
        if not scene.Parent then connection:Disconnect();return end
        local t=os.clock()
        for _,actor in self.actors do
            local moving=Vector3.new(actor.root.AssemblyLinearVelocity.X,0,actor.root.AssemblyLinearVelocity.Z).Magnitude>1
            local phase=t*(actor.state=="Chase" and 19 or 10)
            local swing=moving and math.sin(phase)*.7 or math.sin(t*2)*.07
            local alert=actor.state=="Notice"
            local joints=actor.joints
            joints[1].C0=actor.rest[1]*CFrame.new(0,math.sin(t*3)*.045,0)
            joints[2].C0=actor.rest[2]*CFrame.Angles(alert and -.3 or math.sin(t*2)*.05,0,alert and .15 or 0)
            joints[3].C0=actor.rest[3]*CFrame.Angles(alert and -1.5 or swing,0,-.15)
            joints[4].C0=actor.rest[4]*CFrame.Angles(alert and -1.5 or -swing,0,.15)
            joints[5].C0=actor.rest[5]*CFrame.Angles(-swing,0,0);joints[6].C0=actor.rest[6]*CFrame.Angles(swing,0,0)
        end
    end)
    return self
end
return Servants
