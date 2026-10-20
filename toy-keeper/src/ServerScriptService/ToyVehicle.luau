local Players=game:GetService("Players")
local PhysicsService=game:GetService("PhysicsService")
local Vehicle={}
Vehicle.__index=Vehicle

-- Detach the victim before a guard applies an impulse to the character assembly.
function Vehicle.Eject(humanoid)
    local seat=humanoid and humanoid.SeatPart
    if not seat then return false end
    for _,weld in seat:GetChildren()do
        if weld:IsA("Weld")and weld.Name=="SeatWeld"
            and weld.Part1 and weld.Part1:IsDescendantOf(humanoid.Parent)then weld:Destroy()end
    end
    humanoid.Sit=false
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    return true
end

local function finiteAxis(value)
    return type(value)=="number"and value==value and math.abs(value)<=1
end

function Vehicle.new(scene)
    local car=scene:WaitForChild("Buggy")
    local self=setmetatable({car=car,root=car.Chassis,driverSeat=car.DriverSeat,passengerSeat=car.PassengerSeat,
        throttle=0,steer=0,speed=0,lastInput=-math.huge,lastPacket=-math.huge,emptyBadSince=nil,wheelAngle=0},Vehicle)
    self.parking=car.Parking.Value
    self.heading=self.parking.Rotation
    for _,name in {"ToyVehicle","ToyGuard","ToyPlayer"}do
        if not PhysicsService:IsCollisionGroupRegistered(name)then PhysicsService:RegisterCollisionGroup(name)end
    end
    PhysicsService:CollisionGroupSetCollidable("ToyVehicle","ToyPlayer",false)
    PhysicsService:CollisionGroupSetCollidable("ToyVehicle","ToyGuard",false)
    for _,part in car:GetDescendants()do
        if part:IsA("BasePart")then part.CollisionGroup="ToyVehicle";part.Anchored=false end
    end
    self.root:SetNetworkOwner(nil)
    self.drive=self.root.Drive;self.orientation=self.root.Steering
    self.raycast=RaycastParams.new();self.raycast.FilterType=Enum.RaycastFilterType.Exclude
    self.raycast.FilterDescendantsInstances={car,scene.Keepers,scene.Bases,scene.Gifts}
    self.raycast.RespectCanCollide=true
    self.raycast.CollisionGroup="ToyVehicle"
    for _,seat in {self.driverSeat,self.passengerSeat}do
        seat.EnterPrompt.Triggered:Connect(function(player)self:Enter(player,seat)end)
        seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            seat.EnterPrompt.Enabled=seat.Occupant==nil
            if seat==self.driverSeat then
                self.throttle=0;self.steer=0;self.lastInput=-math.huge;self.lastPacket=-math.huge
            end
            self.root:SetNetworkOwner(nil)
        end)
    end
    game.ReplicatedStorage.ToyDrive.OnServerEvent:Connect(function(player,throttle,steer)
        self:Input(player,throttle,steer,workspace:GetServerTimeNow())
    end)
    Players.PlayerRemoving:Connect(function(player)
        for _,seat in {self.driverSeat,self.passengerSeat}do
            if seat.Occupant and seat.Occupant.Parent==player.Character then Vehicle.Eject(seat.Occupant)end
        end
    end)
    return self
end

function Vehicle:Enter(player,seat)
    if seat~=self.driverSeat and seat~=self.passengerSeat then return false end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health<=0 or humanoid.SeatPart or seat.Occupant
        or not player:GetAttribute("ProgressLoaded")or humanoid.PlatformStand
        or workspace:GetServerTimeNow()<(player:GetAttribute("CatchGraceUntil")or 0)
        or(root.Position-seat.Position).Magnitude>10 then return false end
    seat:Sit(humanoid)
    return true
end

function Vehicle:Input(player,throttle,steer,now)
    local occupant=self.driverSeat.Occupant
    if not occupant or occupant.Health<=0 or occupant.Parent~=player.Character
        or not player:GetAttribute("ProgressLoaded")or not finiteAxis(throttle)or not finiteAxis(steer)
        or now-self.lastPacket<.035 then return false end
    self.lastPacket=now;self.lastInput=now;self.throttle=throttle;self.steer=steer
    return true
end

function Vehicle:Step(now,dt)
    dt=math.min(dt,.1)
    local occupant=self.driverSeat.Occupant
    if occupant and occupant.Health<=0 then Vehicle.Eject(occupant);occupant=nil end
    local valid=occupant and now-self.lastInput<=.75
    local throttle=valid and self.throttle or 0
    local steer=valid and self.steer or 0
    local target=throttle*(throttle>=0 and self.driverSeat.MaxSpeed or 18)
    local rate=throttle==0 and 55 or(self.speed*target<0 and 65 or 28)
    self.speed+=math.clamp(target-self.speed,-rate*dt,rate*dt)
    local grounded=workspace:Raycast(self.root.Position,Vector3.new(0,-4,0),self.raycast)~=nil
    local forward=self.root.CFrame.LookVector*Vector3.new(1,0,1)
    if forward.Magnitude<.01 then forward=self.parking.LookVector else forward=forward.Unit end
    local turn=steer*math.clamp(self.speed/12,-1,1)*1.65*dt
    -- Accumulate the requested heading; rebuilding it from the lagging body each
    -- frame would continually erase most of the turn before physics can follow.
    self.heading*=CFrame.Angles(0,-turn,0)
    self.orientation.CFrame=self.heading
    local mass=self.root.AssemblyMass
    self.drive.MaxAxesForce=Vector3.new(mass*65,0,mass*65)
    self.orientation.MaxTorque=mass*2500
    self.drive.VectorVelocity=forward*self.speed
    self.drive.Enabled=grounded
    self.orientation.Enabled=grounded and self.root.CFrame.UpVector.Y>.3
    self.wheelAngle=(self.wheelAngle+self.speed*dt/1.8)%(2*math.pi)
    for i=1,4 do
        local axle=self.car["Wheel"..i].Axle
        local position=Vector3.new(i%2==1 and -4.5 or 4.5,-.45,i<=2 and -3.4 or 3.4)
        axle.C0=CFrame.new(position)*CFrame.Angles(self.wheelAngle,0,0)
    end
    local pos=self.root.Position
    local bad=self.root.CFrame.UpVector.Y<.3 or pos.Y<-12 or math.abs(pos.X)>100 or pos.Z< -83 or pos.Z>353
    if not self.driverSeat.Occupant and not self.passengerSeat.Occupant and bad then
        self.emptyBadSince=self.emptyBadSince or now
        if now-self.emptyBadSince>=5 then
            -- A player standing on the parking space must not be hit by the reset.
            local clear=true
            for _,player in Players:GetPlayers()do
                local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and(root.Position-self.parking.Position).Magnitude<12 then clear=false;break end
            end
            if clear then
                self.car:PivotTo(self.parking);self.root.AssemblyLinearVelocity=Vector3.zero
                self.root.AssemblyAngularVelocity=Vector3.zero;self.speed=0;self.throttle=0;self.steer=0
                self.heading=self.parking.Rotation;self.orientation.CFrame=self.heading;self.emptyBadSince=nil
            end
        end
    else self.emptyBadSince=nil end
end

return Vehicle
