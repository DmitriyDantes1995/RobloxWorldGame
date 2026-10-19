local TweenService=game:GetService("TweenService")
local Safety=require(script.Parent.LairSafety)
local Config=require(script.Parent.LairConfig)
local Traps={}
Traps.__index=Traps

local FLOOR_WARNING=.8
local FLOOR_OPEN=12
local WALL_WARNING=1.2
local WALL_TRAVEL=1.4
local WALL_HOLD=7
local WALL_COOLDOWN=14

local function tween(part,duration,properties)
    local animation=TweenService:Create(part,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),properties)
    animation:Play()
    return animation
end

local function state(data,value,now,duration)
    data.state=value;data.untilTime=duration and now+duration or nil
    data.model:SetAttribute("State",value)
end

local function occupied(volume,actors)
    local half=volume.Size/2
    for _,root in ipairs(actors) do
        local p=volume.CFrame:PointToObjectSpace(root.Position)
        -- Include the body around its root, not just a single foot or touch event.
        if math.abs(p.X)<half.X+2 and math.abs(p.Z)<half.Z+2 and math.abs(p.Y)<half.Y+4 then return true end
    end
    return false
end

local function standingOn(part,root,height)
    local p=part.CFrame:PointToObjectSpace(root.Position)
    local half=part.Size/2
    if math.abs(p.X)>half.X or math.abs(p.Z)>half.Z or p.Y<half.Y or p.Y>half.Y+(height or 5) then return false end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={root.Parent}
    params.RespectCanCollide=true
    local hit=workspace:Raycast(root.Position,Vector3.new(0,-(height or 5)-1,0),params)
    return hit~=nil and hit.Instance==part
end

function Traps.new(scene,onGeometryChanged,keeper)
    local self=setmetatable({scene=scene,changed=onGeometryChanged,keeper=keeper,floors={},walls={}},Traps)
    for _,model in ipairs(scene.Traps.Floors:GetChildren()) do
        table.insert(self.floors,{model=model,slab=model.Slab,volume=model.Occupancy,cracks=model.Cracks:GetChildren()})
    end
    for _,model in ipairs(scene.Traps.Walls:GetChildren()) do
        table.insert(self.walls,{model=model,wall=model.Wall,plate=model.Plate,volume=model.Clearance,signals=model.Signals:GetChildren()})
    end
    self:Reset()
    return self
end

function Traps:Reset()
    self.active=false
    self.relicWalls={};self.relicFloors=false
    for _,floor in ipairs(self.floors) do
        if floor.animation then floor.animation:Cancel();floor.animation=nil end
        floor.slab.CFrame=floor.slab:GetAttribute("RestCFrame")
        floor.slab.Transparency=0;floor.slab.CanCollide=true;floor.slab.CanQuery=true
        for _,crack in ipairs(floor.cracks) do crack.Transparency=1 end
        state(floor,"Ready")
        if floor.model:FindFirstChild("Navigation") then floor.model.Navigation.Cost.Label="" end
        floor.keeperTrapped=false
    end
    for _,wall in ipairs(self.walls) do
        if wall.animation then wall.animation:Cancel();wall.animation=nil end
        wall.wall.CFrame=wall.wall:GetAttribute("OpenCFrame")
        wall.wall.CanCollide=true
        wall.plate.CFrame=wall.plate:GetAttribute("RestCFrame")
        wall.plate.Color=wall.plate:GetAttribute("RestColor")
        for _,signal in ipairs(wall.signals) do signal.Color=signal:GetAttribute("RestColor") end
        wall.nextAuto=nil;wall.released=true
        state(wall,"Open")
    end
    self.changed()
end

-- The escape owns requests, while the existing trap state machines own movement.
function Traps:SetRelicWalls(requests)
    for _,wall in self.walls do
        local request=requests[wall.model.Name]
        if request then
            self.relicWalls[wall.model.Name]=request
            if request.close and (wall.state=="Open" or wall.state=="Cooldown" or wall.state=="Warning") then
                wall.released=false
                state(wall,"Warning",os.clock(),Config.RelicWarningSeconds)
            elseif request.close and wall.state=="Closing" then
                self:OpenWall(wall,os.clock())
            elseif not request.close and (wall.state=="Closed" or wall.state=="Warning" or wall.state=="Closing") then
                self:OpenWall(wall,os.clock())
            end
        end
    end
end

function Traps:RelicWallsOpen(names)
    for _,wall in self.walls do
        if names[wall.model.Name] and wall.state~="Open" and wall.state~="Cooldown" then return false end
    end
    return true
end

function Traps:RelicWallsClosed(names)
    for _,wall in self.walls do
        if names[wall.model.Name] and wall.state~="Closed" then return false end
    end
    return true
end

function Traps:OpenWall(wall,now)
    if wall.animation then wall.animation:Cancel() end
    -- Remove the physical obstacle before invalidating any in-flight path computation.
    wall.wall.CanCollide=false
    wall.animation=tween(wall.wall,WALL_TRAVEL,{CFrame=wall.wall:GetAttribute("OpenCFrame")})
    state(wall,"Opening",now,WALL_TRAVEL)
    self.changed()
end

-- Called only from the owning server loop; plates and periodic motion share one state machine.
function Traps:Step(players,now)
    local roots,actors={},{}
    for _,root in self.servantRoots or {} do table.insert(actors,root) end
    for _,player in ipairs(players) do
        local root=Safety.Root(player)
        if root then table.insert(roots,root);table.insert(actors,root) end
    end
    local keeper=self.scene.Keeper.HumanoidRootPart
    table.insert(actors,keeper)
    local active=self.scene:GetAttribute("ExpeditionState")=="Active"
    if active and not self.active then
        for _,wall in ipairs(self.walls) do wall.nextAuto=now+wall.model:GetAttribute("InitialDelay") end
    end
    self.active=active

    for _,floor in ipairs(self.floors) do
        local p=floor.volume.CFrame:PointToObjectSpace(keeper.Position)
        local inside=math.abs(p.X)<floor.volume.Size.X/2 and math.abs(p.Z)<floor.volume.Size.Z/2
        if not inside then floor.keeperTrapped=false end
        local escapeOnly=floor.model:GetAttribute("EscapeOnly")==true
        local enabled=not escapeOnly or self.relicFloors
        if not escapeOnly and floor.state=="Open" and inside and keeper.Position.Y<floor.slab:GetAttribute("RestCFrame").Position.Y+4 and not floor.keeperTrapped then
            floor.keeperTrapped=true
            self.keeper:Stun(Config.TrapStunSeconds,"Pit",{floor.model.EscapeStart.Position,floor.model.EscapeEnd.Position})
        end
        if floor.state=="Ready" and enabled then
            for _,root in ipairs(roots) do
                if standingOn(floor.slab,root) then
                    state(floor,"Warning",now,escapeOnly and Config.RelicWarningSeconds or FLOOR_WARNING)
                    for _,crack in ipairs(floor.cracks) do crack.Transparency=0 end
                    break
                end
            end
        elseif floor.state=="Warning" and now>=floor.untilTime
            and (not escapeOnly or not standingOn(floor.slab,keeper,8)) then
            floor.slab.CanCollide=false;floor.slab.CanQuery=false
            if escapeOnly then floor.model.Navigation.Cost.Label="KeeperBoundary" end
            local rest=floor.slab:GetAttribute("RestCFrame")
            local fallen=escapeOnly and CFrame.new(rest.Position.X,-16.5,rest.Position.Z)*rest.Rotation or rest-Vector3.new(0,7.5,0)
            floor.animation=tween(floor.slab,.35,{CFrame=fallen,Transparency=.8})
            for _,crack in ipairs(floor.cracks) do crack.Transparency=1 end
            state(floor,"Open",now,escapeOnly and Config.RelicFloorSeconds or FLOOR_OPEN)
            self.changed()
        elseif floor.state=="Open" and now>=floor.untilTime and not occupied(floor.volume,actors) then
            if floor.animation then floor.animation:Cancel();floor.animation=nil end
            floor.slab.CFrame=floor.slab:GetAttribute("RestCFrame")
            floor.slab.Transparency=0;floor.slab.CanCollide=true;floor.slab.CanQuery=true
            state(floor,"Ready")
            if escapeOnly then floor.model.Navigation.Cost.Label="" end
            self.changed()
        end
    end

    for _,wall in ipairs(self.walls) do
        local request=self.relicWalls[wall.model.Name]
        local escapeOnly=wall.model:GetAttribute("EscapeOnly")==true
        local pressed=false
        for _,root in ipairs(roots) do if standingOn(wall.plate,root) then pressed=true;break end end
        if not pressed then wall.released=true end
        if wall.state=="Open" then
            if request and request.close or not request and not escapeOnly and ((pressed and wall.released) or (active and wall.nextAuto and now>=wall.nextAuto)) then
                wall.released=false
                wall.plate.CFrame=wall.plate:GetAttribute("RestCFrame")-Vector3.new(0,.2,0)
                state(wall,"Warning",now,request and Config.RelicWarningSeconds or WALL_WARNING)
            end
        elseif wall.state=="Warning" then
            local color=math.floor(now*6)%2==0 and Color3.fromRGB(255,191,63) or Color3.fromRGB(255,90,45)
            wall.plate.Color=color
            for _,signal in ipairs(wall.signals) do signal.Color=color end
            if now>=wall.untilTime then
                if occupied(wall.volume,actors) then
                    -- Cancel a blocked attempt instead of keeping a warning armed indefinitely.
                    self:OpenWall(wall,now)
                else
                    wall.wall.CanCollide=false
                    wall.animation=tween(wall.wall,WALL_TRAVEL,{CFrame=wall.wall:GetAttribute("ClosedCFrame")})
                    state(wall,"Closing",now,WALL_TRAVEL)
                    self.changed()
                end
            end
        elseif wall.state=="Closing" then
            if occupied(wall.volume,actors) then self:OpenWall(wall,now)
            elseif now>=wall.untilTime then
                wall.wall.CFrame=wall.wall:GetAttribute("ClosedCFrame")
                wall.wall.CanCollide=true
                state(wall,"Closed",now,request and request.hold or WALL_HOLD)
                self.changed()
            end
        elseif wall.state=="Closed" and now>=wall.untilTime and not (request and request.close) then
            self:OpenWall(wall,now)
        elseif wall.state=="Opening" and now>=wall.untilTime then
            wall.wall.CFrame=wall.wall:GetAttribute("OpenCFrame")
            wall.wall.CanCollide=true
            wall.plate.CFrame=wall.plate:GetAttribute("RestCFrame")
            state(wall,"Cooldown",now,WALL_COOLDOWN)
            for _,signal in ipairs(wall.signals) do signal.Color=Color3.fromRGB(70,76,85) end
            wall.plate.Color=Color3.fromRGB(70,76,85)
        elseif wall.state=="Cooldown" and now>=wall.untilTime then
            state(wall,"Open")
            wall.nextAuto=now+wall.model:GetAttribute("Period")
            wall.plate.Color=wall.plate:GetAttribute("RestColor")
            for _,signal in ipairs(wall.signals) do signal.Color=signal:GetAttribute("RestColor") end
        end
    end
end

return Traps
