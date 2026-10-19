local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.TreasureCatalog)
local Config = require(script.Parent.LairConfig)
local Safety = require(script.Parent.LairSafety)
local Economy = require(script.Parent.GameEconomy)
local Monster = {}
Monster.__index = Monster

local function horizontal(v) return Vector3.new(v.X,0,v.Z) end

function Monster.new(scene,onCaught)
    local self=setmetatable({scene=scene,model=scene.Keeper,heat={},grace={},rng=Random.new(),
        phase=0,navVersion=0,lastPath=-math.huge,patrolIndex=1,onCaught=onCaught,
        lastEvidence=-math.huge,investigationReadyAt=0,lastTargetSwitch=-math.huge},Monster)
    self.root=self.model.HumanoidRootPart
    self.humanoid=self.model.Humanoid
    self.home=scene.MonsterHome.Position
    self.spawnCFrame=self.model:GetPivot()
    self.patrol=scene.PatrolPoints:GetChildren()
    table.sort(self.patrol,function(a,b) return a.Name<b.Name end)
    self.joints={}
    for _,motor in self.model:GetDescendants() do
        if motor:IsA("Motor6D") then self.joints[motor.Name]={motor=motor,base=motor.C0} end
    end
    self:SetState("Sleeping")
    return self
end

function Monster:Reset()
    table.clear(self.heat);table.clear(self.grace)
    self.target=nil;self.lastKnown=nil;self.lastSeen=nil;self.hiddenSince=nil;self.chaseStarted=nil
    self.investigationPosition=nil;self.investigationOwner=nil;self.lookUntil=nil
    self.lastEvidence=-math.huge;self.investigationReadyAt=0;self.lastTargetSwitch=-math.huge
    self.targetSince=nil;self.patrolIndex=1;self.phase=0
    self.dashReadyAt=0;self.openSince=nil;self.dashDirection=nil
    self.stunUntil=nil;self.escapeRoute=nil;self.stunKind=nil
    self.humanoid.AutoRotate=true
    self:SetState("Patrolling")
    -- Only called at server start or after all expedition participants have left.
    self.model:PivotTo(self.spawnCFrame)
    self.root.AssemblyLinearVelocity=Vector3.zero
    self.root.AssemblyAngularVelocity=Vector3.zero
    self.humanoid.WalkSpeed=Config.PatrolSpeed
    self.humanoid:MoveTo(self.root.Position)
    for _,data in pairs(self.joints) do data.motor.C0=data.base end
end

function Monster:ResetPath()
    self.navVersion+=1
    if self.blocked then self.blocked:Disconnect();self.blocked=nil end
    self.path=nil;self.waypoints=nil;self.pathIndex=2;self.computing=false
    self.lastPath=-math.huge;self.command=nil;self.progressPosition=self.root.Position;self.progressTime=os.clock()
end

function Monster:GeometryChanged()
    self:ResetPath()
    self.humanoid:MoveTo(self.root.Position)
end

function Monster:SetState(state)
    self.state=state;self.stateSince=os.clock()
    self.model:SetAttribute("State",state)
    self.model:SetAttribute("TargetUserId",self.target and self.target.UserId or 0)
    local words={Sleeping="Z z z",Patrolling="Моё логово…",Suspicious="Кто здесь?",Awakening="КТО ТАМ?!",Chasing="ВЕРНИ!",Returning="Проверю хранилище…"}
    words.DashPreparing="БЕРЕГИСЬ!";words.Dashing="ПОПАЛСЯ!";words.Staggered="Ух!.."
    words.Stunned="Звёзды…";words.Recovering="Поднимаюсь…";words.Escaping="Не уйдёшь!"
    local color=state=="Chasing" and Color3.fromRGB(255,104,113)
        or (state=="Awakening" or state=="DashPreparing") and Color3.fromRGB(255,150,65)
        or state=="Suspicious" and Color3.fromRGB(255,220,110) or Color3.fromRGB(167,225,255)
    self.model.EyeL.Color=color;self.model.EyeR.Color=color
    self.root.Mood.Label.Text=words[state]
    self:ResetPath()
end

function Monster:Eligible(player)
    local root=Safety.Root(player)
    if not root or os.clock()<(self.grace[player] or 0) then return nil end
    if not Safety.InLair(self.scene,root.Position) or Safety.InHide(self.scene,root.Position) then return nil end
    return root
end

function Monster:Visible(root)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={self.model,self.scene.Treasures}
    params.RespectCanCollide=true
    local origin=self.model.Head.Position
    local hit=workspace:Raycast(origin,root.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(root.Parent)
end

function Monster:Awaken(player,root)
    self.investigationPosition=nil;self.investigationOwner=nil;self.lookUntil=nil
    self.target=player;self.lastKnown=root.Position;self.lastSeen=os.clock()
    self.targetSince=os.clock();self.lastTargetSwitch=self.targetSince
    local facing=horizontal(root.Position-self.root.Position)
    if facing.Magnitude>.1 then self.root.CFrame=CFrame.lookAt(self.root.Position,self.root.Position+facing) end
    self:SetState("Awakening")
    self.humanoid:MoveTo(self.root.Position)
end

-- Sweep the keeper's body, not a center ray; neither dash nor knockback ignores walls.
function Monster:ClearAhead(direction,distance)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    local excludes={self.model,self.scene.Treasures,self.scene.Effects}
    for _,p in Players:GetPlayers() do if p.Character then table.insert(excludes,p.Character) end end
    params.FilterDescendantsInstances=excludes;params.RespectCanCollide=true
    return workspace:Blockcast(CFrame.new(self.root.Position),Vector3.new(5,9,5),direction*distance,params)==nil
end

function Monster:Stun(seconds,kind,escapeRoute,attacker,direction)
    local now=os.clock()
    self.stunUntil=math.max(self.stunUntil or 0,now+seconds)
    self.stunKind=kind;self.escapeRoute=escapeRoute or self.escapeRoute;self.escapeIndex=1
    self.investigationOwner=nil;self.investigationPosition=nil;self.lookUntil=nil
    if attacker then
        self.heat[attacker]=(self.heat[attacker] or 0)+45
        self.target=attacker
        local root=Safety.Root(attacker);if root then self.lastKnown=root.Position end
    end
    self.openSince=nil;self.dashDirection=nil;self.humanoid.AutoRotate=false
    self:SetState("Stunned");self.humanoid.WalkSpeed=0;self.humanoid:MoveTo(self.root.Position)
    if direction then
        local push=horizontal(direction)
        if push.Magnitude>.1 then
            push=push.Unit
            if self:ClearAhead(push,8) then self.root:ApplyImpulse((push*Config.CannonKnockback+Vector3.new(0,8,0))*self.root.AssemblyMass) end
        end
    end
end

function Monster:ResumeHunt()
    self.humanoid.AutoRotate=true;self.stunUntil=nil;self.stunKind=nil;self.escapeRoute=nil
    self.dashReadyAt=os.clock()+Config.DashCooldown
    local root=self.target and self:Eligible(self.target)
    if root and self:Visible(root) then
        self.lastKnown=root.Position;self.lastSeen=os.clock();self.chaseStarted=os.clock()
        self.targetSince=os.clock();self:SetState("Chasing")
    elseif self.lastKnown and Safety.InLair(self.scene,self.lastKnown) then
        self.investigationPosition=self.lastKnown;self.investigationOwner=self.target;self.target=nil;self.lookUntil=nil
        self:SetState("Suspicious")
    else self:Finish() end
end

function Monster:MissDash()
    self.humanoid.AutoRotate=true;self.dashDirection=nil;self.openSince=nil
    self.dashReadyAt=os.clock()+Config.DashCooldown;self:SetState("Staggered")
    self.humanoid.WalkSpeed=Config.DashMissSpeed;self.humanoid:MoveTo(self.root.Position)
end

function Monster:Investigate(player,position)
    local now=os.clock()
    if now<self.investigationReadyAt or not Safety.InLair(self.scene,position) then return false end
    if self.state~="Patrolling" and self.state~="Sleeping" and self.state~="Returning" and self.state~="Suspicious" then return false end
    self.investigationOwner=player;self.investigationPosition=position;self.lookUntil=nil
    if self.state~="Suspicious" then self:SetState("Suspicious") else self:ResetPath() end
    return true
end

function Monster:OnTheft(player,risk,position)
    self.heat[player]=(self.heat[player] or 0)+risk
    -- Theft raises suspicion, never supplies a live target through walls.
    if self.state~="Patrolling" and self.state~="Sleeping" and self.state~="Returning" and self.state~="Suspicious" then return end
    local heat=self.heat[player]
    if heat<Config.InvestigationMinHeat then return end
    local chance=math.clamp(Config.InvestigationBaseChance+(heat-Config.InvestigationMinHeat)*Config.InvestigationChancePerHeat,0,Config.InvestigationMaxChance)
    if self.rng:NextNumber()<chance then self:Investigate(player,position) end
end

function Monster:OnEvidence(player,position,kind)
    local radius=kind=="Crystal" and Catalog.Crystal.Radius or kind=="Trail" and Catalog.Trail.DetectDistance
    if not radius or (position-self.root.Position).Magnitude>radius then return false end
    local now=os.clock()
    if now-self.lastEvidence<Config.EvidenceNoticeSeconds then return false end
    if self.state~="Patrolling" and self.state~="Sleeping" and self.state~="Returning" and self.state~="Suspicious" then return false end
    if not Safety.InLair(self.scene,position) then return false end
    if kind=="Trail" then
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={self.model,self.scene.Treasures}
        params.RespectCanCollide=true
        local origin=self.model.Head.Position
        local destination=position+Vector3.new(0,.5,0)
        local hit=workspace:Raycast(origin,destination-origin,params)
        if hit and (hit.Position-destination).Magnitude>.75 then return false end
    end
    local root=kind=="Crystal" and self:Eligible(player)
    if root and self:Visible(root) then
        self:Awaken(player,root)
    elseif not self:Investigate(player,position) then
        return false
    end
    self.lastEvidence=now
    return true
end

function Monster:Finish()
    self.humanoid.AutoRotate=true;self.dashDirection=nil;self.openSince=nil
    if self.target then self.heat[self.target]=0 end
    self.target=nil;self.hiddenSince=nil;self.lastKnown=nil;self.targetSince=nil
    self.investigationPosition=nil;self.investigationOwner=nil;self.lookUntil=nil
    self:SetState("Returning")
end

function Monster:Catch(player)
    local root=self:Eligible(player)
    if not root then return end
    local _,count=Economy.LoseUndelivered(player)
    if self.onCaught then self.onCaught(player) end
    self.grace[player]=os.clock()+Config.RecoverySeconds
    player.Character:PivotTo(self.scene.BaseReturn.CFrame)
    root.AssemblyLinearVelocity=Vector3.zero
    ReplicatedStorage.GameRemotes.Notify:FireClient(player,
        count>0 and "Хозяин забрал сокровища. Ты снова на базе!" or "Хозяин проводил тебя на базу!",Color3.fromRGB(255,193,119))
    self:Finish()
end

function Monster:ComputePath(goal)
    if self.computing then return end
    self.computing=true;self.lastPath=os.clock();self.pathGoal=goal
    local version=self.navVersion
    local start=self.root.Position-Vector3.new(0,4,0)
    task.spawn(function()
        local path=PathfindingService:CreatePath({AgentRadius=Config.AgentRadius,AgentHeight=Config.AgentHeight,
            AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=4,Costs={KeeperBoundary=math.huge}})
        local ok=pcall(function() path:ComputeAsync(start,goal) end)
        if self.destroyed or version~=self.navVersion then return end
        self.computing=false
        if self.blocked then self.blocked:Disconnect();self.blocked=nil end
        if ok and path.Status==Enum.PathStatus.Success then
            self.path=path;self.waypoints=path:GetWaypoints();self.pathIndex=2;self.command=nil
            self.blocked=path.Blocked:Connect(function(index)
                if index>=self.pathIndex then self:ResetPath() end
            end)
        else
            -- A failed path means wait/replan, never a straight-line move through geometry.
            self.path=nil;self.waypoints=nil;self.command=nil
            self.humanoid:MoveTo(self.root.Position)
        end
    end)
end

function Monster:Move(goal,speed)
    self.humanoid.WalkSpeed=speed
    if horizontal(goal-self.root.Position).Magnitude<3 and math.abs(goal.Y-self.root.Position.Y)<6 then
        self.humanoid:MoveTo(self.root.Position);return true
    end
    local now=os.clock()
    if now-self.lastPath>=Config.RepathSeconds and (not self.waypoints or (goal-self.pathGoal).Magnitude>5) then
        self:ComputePath(goal)
    end
    local point=self.waypoints and self.waypoints[self.pathIndex]
    while point and horizontal(point.Position-self.root.Position).Magnitude<2.6
        and math.abs(point.Position.Y-(self.root.Position.Y-5))<3 do
        self.pathIndex+=1;point=self.waypoints[self.pathIndex]
    end
    if point then
        if not self.command or (self.command-point.Position).Magnitude>.1 then
            self.command=point.Position;self.humanoid:MoveTo(point.Position)
        end
        if horizontal(self.root.Position-self.progressPosition).Magnitude>1 then
            self.progressPosition=self.root.Position;self.progressTime=now
        elseif now-self.progressTime>2 then
            -- Navmesh corner points can sit closer to a wall than the physical body can reach.
            -- Recomputing that same corner forever never recovers. Walk to a nearby later
            -- waypoint only when the full body sweep is clear and it is on the same floor.
            for i=math.min(self.pathIndex+6,#self.waypoints),self.pathIndex+1,-1 do
                local candidate=self.waypoints[i].Position
                local delta=horizontal(candidate-self.root.Position)
                if delta.Magnitude>1 and delta.Magnitude<=12 and math.abs(candidate.Y-(self.root.Position.Y-5))<2
                    and self:ClearAhead(delta.Unit,delta.Magnitude) then
                    self.pathIndex=i;self.command=nil
                    self.progressPosition=self.root.Position;self.progressTime=now
                    return false
                end
            end
            self:ResetPath()
        end
    elseif not self.computing then
        self.waypoints=nil
    end
    return false
end

function Monster:VisibleTarget(exclude)
    local selected,selectedRoot,bestScore
    for _,player in Players:GetPlayers() do
        local root=player~=exclude and self:Eligible(player)
        local d=root and (root.Position-self.root.Position).Magnitude
        if root and d<=Config.DetectionDistance and self:Visible(root) then
            local score=d-math.min(self.heat[player] or 0,80)*Config.TargetHeatWeight
            if not bestScore or score<bestScore then selected=player;selectedRoot=root;bestScore=score end
        end
    end
    return selected,selectedRoot,bestScore
end

function Monster:FindTarget()
    local player,root=self:VisibleTarget()
    if player then self:Awaken(player,root) end
end

function Monster:SwitchTarget(now)
    if now-self.lastTargetSwitch<Config.TargetSwitchSeconds then return end
    local player,root,score=self:VisibleTarget(self.target)
    if not player then return end
    local current=self:Eligible(self.target)
    local currentVisible=current and self:Visible(current)
    local currentScore=current and (current.Position-self.root.Position).Magnitude
        -math.min(self.heat[self.target] or 0,80)*Config.TargetHeatWeight or math.huge
    local better=score+Config.TargetSwitchMargin<currentScore
    local share=now-self.targetSince>=Config.TargetFocusSeconds and score<=currentScore+Config.TargetSwitchMargin
    if currentVisible and not better and not share then return end
    self.target=player;self.lastKnown=root.Position;self.lastSeen=now;self.hiddenSince=nil
    self.targetSince=now;self.lastTargetSwitch=now
    self.model:SetAttribute("TargetUserId",player.UserId)
    self:ResetPath()
    -- A switch does not restart the chase limit or replay the wake animation.
end

function Monster:Step(dt)
    local now=os.clock()
    for player,heat in pairs(self.heat) do
        self.heat[player]=heat>Config.SuspicionDecay*dt and heat-Config.SuspicionDecay*dt or nil
    end
    if self.state=="Stunned" then
        self.humanoid.WalkSpeed=0
        if now>=self.stunUntil then self:SetState("Recovering") end
        return
    elseif self.state=="Recovering" then
        if now-self.stateSince>=Config.RecoverSeconds then
            self.humanoid.AutoRotate=true
            if self.escapeRoute then self:SetState("Escaping") else self:ResumeHunt() end
        end
        return
    elseif self.state=="Escaping" then
        local point=self.escapeRoute[self.escapeIndex]
        if (horizontal(point-self.root.Position)).Magnitude<2.5 and math.abs(point.Y-self.root.Position.Y)<3 then
            self.escapeIndex+=1;point=self.escapeRoute[self.escapeIndex]
        end
        if not point then self:ResumeHunt()
        else self.humanoid.WalkSpeed=Config.ReturnSpeed;self.humanoid:MoveTo(point) end
        return
    elseif self.state=="DashPreparing" then
        self.humanoid.WalkSpeed=0;self.humanoid:MoveTo(self.root.Position)
        if now-self.stateSince>=Config.DashPrepareSeconds then
            if self:ClearAhead(self.dashDirection,6) then self:SetState("Dashing") else self:MissDash() end
        end
        return
    elseif self.state=="Dashing" then
        local root=self.target and self:Eligible(self.target)
        if root and (root.Position-self.root.Position).Magnitude<=Config.CatchRadius and self:Visible(root) then self:Catch(self.target)
        elseif now-self.stateSince>=Config.DashSeconds or not self:ClearAhead(self.dashDirection,Config.DashSpeed*dt+2) then self:MissDash()
        else self.humanoid.WalkSpeed=Config.DashSpeed;self.humanoid:MoveTo(self.root.Position+self.dashDirection*8) end
        return
    elseif self.state=="Staggered" then
        if now-self.stateSince>=Config.DashMissSeconds then self:ResumeHunt() end
        return
    elseif self.state=="Sleeping" then
        self.humanoid:MoveTo(self.root.Position)
        if now-self.stateSince>=Config.RestSeconds then self:SetState("Patrolling") end
        self:FindTarget()
    elseif self.state=="Suspicious" then
        self:FindTarget()
        if self.state~="Suspicious" then return end
        if now-self.stateSince>=Config.InvestigationMaxSeconds or self.lookUntil and now>=self.lookUntil then
            self.investigationPosition=nil;self.investigationOwner=nil;self.lookUntil=nil
            self.investigationReadyAt=now+Config.InvestigationCooldown
            self:SetState("Returning")
        elseif self.lookUntil then
            self.humanoid:MoveTo(self.root.Position)
        elseif self:Move(self.investigationPosition,Config.InvestigationSpeed) then
            self.lookUntil=now+Config.InvestigationLookSeconds
        end
    elseif self.state=="Patrolling" then
        self:FindTarget()
        if self.state=="Patrolling" and self:Move(self.patrol[self.patrolIndex].Position,Config.PatrolSpeed) then
            self.patrolIndex=self.patrolIndex%#self.patrol+1
            self:ResetPath()
        end
    elseif self.state=="Awakening" then
        if not self:Eligible(self.target) then self:Finish()
        elseif now-self.stateSince>=Config.AwakeningSeconds then
            self.chaseStarted=now;self.lastSeen=now;self:SetState("Chasing")
        end
    elseif self.state=="Chasing" then
        self:SwitchTarget(now)
        local root=self.target and Safety.Root(self.target)
        if not root or not Safety.InLair(self.scene,root.Position) then self:Finish()
        elseif Safety.InHide(self.scene,root.Position) then
            self.humanoid:MoveTo(self.root.Position)
            self.command=nil
            self.hiddenSince=self.hiddenSince or now
            if now-self.hiddenSince>=Config.HideBreakSeconds then self:Finish() end
        else
            self.hiddenSince=nil
            local visible=self:Visible(root)
            if visible then self.lastSeen=now;self.lastKnown=root.Position end
            local distance=(root.Position-self.root.Position).Magnitude
            if now-self.lastSeen>Config.LoseSightSeconds then
                self:ResumeHunt()
            elseif now-self.chaseStarted>Config.MaxChaseSeconds or distance>Config.MaxChaseDistance then self:Finish()
            elseif visible and distance<=Config.CatchRadius then self:Catch(self.target)
            else
                local direction=horizontal(root.Position-self.root.Position)
                local open=visible and math.abs(root.Position.Y-(self.root.Position.Y-2))<4
                    and distance>=Config.DashMinDistance and distance<=Config.DashMaxDistance
                    and direction.Magnitude>.1 and direction.Unit:Dot(self.root.CFrame.LookVector)>.8
                    and self:ClearAhead(direction.Unit,math.min(distance,Config.DashSpeed*Config.DashSeconds))
                self.openSince=open and (self.openSince or now) or nil
                if self.openSince and now-self.openSince>=Config.DashOpenSeconds and now>=(self.dashReadyAt or 0) then
                    self.dashDirection=direction.Unit;self.humanoid.AutoRotate=false;self:SetState("DashPreparing")
                else self:Move(self.lastKnown,Config.ChaseSpeed) end
            end
        end
    elseif self.state=="Returning" then
        self:FindTarget()
        if self.state=="Returning" and self:Move(self.home,Config.ReturnSpeed) then self:SetState("Sleeping") end
    end
end

function Monster:Animate(dt)
    local speed=horizontal(self.root.AssemblyLinearVelocity).Magnitude
    local moving=speed>0.65
    self.phase+=dt*(moving and speed*.72 or 1.5)
    local run=self.state=="Chasing" or self.state=="Dashing"
    local suspicious=self.state=="Suspicious"
    local swing=moving and math.sin(self.phase)*math.rad(run and 82 or 38) or math.sin(self.phase)*.05
    local raise=self.state=="Awakening" and math.rad(-105) or suspicious and -.3 or 0
    local pose={
        ["Left Hip"]=CFrame.Angles(swing,0,0),["Right Hip"]=CFrame.Angles(-swing,0,0),
        ["Left Shoulder"]=CFrame.Angles(-swing+raise,0,-.1),["Right Shoulder"]=CFrame.Angles(swing+raise,0,.1),
        Neck=CFrame.Angles(self.state=="Sleeping" and .15 or suspicious and -.12 or -.05,
            math.sin(self.phase*(suspicious and 1.1 or .5))*(suspicious and .5 or .09),0),
        RootJoint=CFrame.new(0,moving and math.abs(math.sin(self.phase))*.12 or math.sin(self.phase)*.06,0)
            *CFrame.Angles(run and -.12 or suspicious and -.06 or 0,0,moving and math.sin(self.phase)*.04 or 0),
    }
    if self.state=="DashPreparing" then
        pose.RootJoint=CFrame.new(0,-1.3,0)*CFrame.Angles(-.45,0,0)
        pose["Left Hip"]=CFrame.Angles(-.8,0,-.1);pose["Right Hip"]=CFrame.Angles(.8,0,.1)
        pose["Left Shoulder"]=CFrame.Angles(.9,0,-.3);pose["Right Shoulder"]=CFrame.Angles(.9,0,.3)
    elseif self.state=="Staggered" then
        pose.RootJoint=CFrame.Angles(.3,0,math.sin((os.clock()-self.stateSince)*9)*.4)
        pose["Left Shoulder"]=CFrame.Angles(-1.4,0,-.6);pose["Right Shoulder"]=CFrame.Angles(-1.4,0,.6)
    elseif self.state=="Stunned" or self.state=="Recovering" then
        local fall=self.state=="Recovering" and 1-math.clamp((os.clock()-self.stateSince)/Config.RecoverSeconds,0,1) or 1
        pose.RootJoint=CFrame.new(0,-2*fall,0)*CFrame.Angles(0,0,(self.stunKind=="Cannon" and 1.25 or .45)*fall)
        pose["Left Shoulder"]=CFrame.Angles(-1.1*fall,0,-.6);pose["Right Shoulder"]=CFrame.Angles(-1.1*fall,0,.6)
        pose["Left Hip"]=CFrame.Angles(-.9*fall,0,0);pose["Right Hip"]=CFrame.Angles(.9*fall,0,0)
    end
    local alpha=1-math.exp(-12*dt)
    for name,data in pairs(self.joints) do data.motor.C0=data.motor.C0:Lerp(data.base*pose[name],alpha) end
end

function Monster:Start()
    self.root.Anchored=false;self.root:SetNetworkOwner(nil)
    self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
    self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,false)
    self.animation=RunService.Heartbeat:Connect(function(dt)
        if self.model.Parent then self:Animate(dt) end
    end)
    self.removing=Players.PlayerRemoving:Connect(function(player)
        self.heat[player]=nil;self.grace[player]=nil
        local recovering=self.state=="Stunned" or self.state=="Recovering" or self.state=="Escaping"
        if self.investigationOwner==player then
            self.investigationOwner=nil;self.investigationPosition=nil;self.lookUntil=nil
            if not recovering then self:SetState("Returning") end
        end
        if self.target==player then
            if recovering then self.target=nil else self:Finish() end
        end
    end)
    task.spawn(function()
        local last=os.clock()
        while self.model.Parent do
            task.wait(Config.ThinkSeconds)
            local now=os.clock();self:Step(now-last);last=now
        end
        self.destroyed=true;self.navVersion+=1
        self.animation:Disconnect();self.removing:Disconnect()
        if self.blocked then self.blocked:Disconnect() end
    end)
end

return Monster
