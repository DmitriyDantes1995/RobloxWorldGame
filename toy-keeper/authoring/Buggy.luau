-- Run once in Edit. The saved model, not this authoring command, ships in the place.
local scene=workspace.ToyKeeper
assert(not scene:FindFirstChild("Buggy"),"Buggy already exists")
local car=Instance.new("Model");car.Name="Buggy"
local origin=CFrame.new(0,2.3,12)*CFrame.Angles(0,math.pi,0)
local teal=Color3.fromRGB(30,185,180)
local yellow=Color3.fromRGB(255,204,65)
local dark=Color3.fromRGB(30,39,51)
local root
local function part(name,size,cf,color,class,collide)
    local p=Instance.new(class or "Part");p.Name=name;p.Size=size;p.CFrame=origin*cf
    p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true
    p.CanCollide=collide==true;p.CanTouch=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    p.Massless=name~="Chassis";p.Parent=car
    if root then local w=Instance.new("WeldConstraint");w.Part0=root;w.Part1=p;w.Parent=p end
    return p
end
root=part("Chassis",Vector3.new(7.8,1,10.8),CFrame.identity,dark,"Part",true)
root.CustomPhysicalProperties=PhysicalProperties.new(2,.15,0)
root.RootPriority=127;car.PrimaryPart=root
part("Hood",Vector3.new(7.6,.9,3),CFrame.new(0,.8,-3.8),teal)
part("Nose",Vector3.new(7.5,.8,.5),CFrame.new(0,.9,-5.5),yellow)
part("RearDeck",Vector3.new(7.5,.7,2),CFrame.new(0,.8,4.3),teal)
for _,x in {-3.75,3.75}do
    part("SideRail",Vector3.new(.4,1.3,6.5),CFrame.new(x,.9,.1),teal)
    part("RollBar",Vector3.new(.35,4.5,.35),CFrame.new(x,2.8,2.5),yellow)
    part("RoofRail",Vector3.new(.35,.35,7),CFrame.new(x,5,-.6),yellow)
    part("FrontPillar",Vector3.new(.3,4.5,.3),CFrame.new(x,2.8,-3.8),yellow)
end
part("RoofBar",Vector3.new(7.8,.35,.35),CFrame.new(0,5,2.5),yellow)
part("WindshieldBar",Vector3.new(7.8,.35,.35),CFrame.new(0,5,-3.8),yellow)
for _,x in {-1.85,1.85}do
    part("SeatBack",Vector3.new(2.6,2.3,.5),CFrame.new(x,2.25,1.5),dark)
end
local driver=part("DriverSeat",Vector3.new(2.6,.6,2.4),CFrame.new(-1.85,1.25,.3),dark,"VehicleSeat")
driver.MaxSpeed=45;driver.Torque=0;driver.TurnSpeed=0;driver.HeadsUpDisplay=false
local passenger=part("PassengerSeat",Vector3.new(2.6,.6,2.4),CFrame.new(1.85,1.25,.3),dark,"Seat")
for _,seat in {driver,passenger}do
    local prompt=Instance.new("ProximityPrompt");prompt.Name="EnterPrompt"
    prompt.ActionText=seat==driver and "За руль"or"Сесть рядом"
    prompt.ObjectText="БАГГИ · 2 МЕСТА";prompt.MaxActivationDistance=9
    prompt.HoldDuration=.15;prompt.RequiresLineOfSight=false;prompt.Parent=seat
end
local steering=part("SteeringWheel",Vector3.new(.25,1.7,1.7),CFrame.new(-1.85,2.6,-1.8)*CFrame.Angles(0,0,math.rad(65)),dark)
steering.Shape=Enum.PartType.Cylinder
for index,position in {Vector3.new(-4.5,-.45,-3.4),Vector3.new(4.5,-.45,-3.4),Vector3.new(-4.5,-.45,3.4),Vector3.new(4.5,-.45,3.4)}do
    local tire=Instance.new("Part");tire.Name="Wheel"..index;tire.Shape=Enum.PartType.Cylinder
    tire.Size=Vector3.new(1.2,3.6,3.6);tire.CFrame=origin*CFrame.new(position)
    tire.Color=dark;tire.Material=Enum.Material.Rubber;tire.Anchored=true;tire.Massless=true
    tire.CanTouch=false;tire.CustomPhysicalProperties=PhysicalProperties.new(.7,.12,0);tire.Parent=car
    local motor=Instance.new("Motor6D");motor.Name="Axle";motor.Part0=root;motor.Part1=tire
    motor.C0=CFrame.new(position);motor.Parent=tire
    local hub=part("Hub"..index,Vector3.new(.12,1.8,1.8),CFrame.new(position+Vector3.new(position.X<0 and -.65 or .65,0,0)),yellow)
    hub.Shape=Enum.PartType.Cylinder
end
for _,x in {-2.7,2.7}do
    local light=part("Headlamp",Vector3.new(1.2,.55,.15),CFrame.new(x,1,-5.8),Color3.fromRGB(255,250,210))
    light.Material=Enum.Material.Neon
    local tail=part("TailLight",Vector3.new(1,.4,.15),CFrame.new(x,.8,5.35),Color3.fromRGB(255,80,70))
    tail.Material=Enum.Material.Neon
end
local labelPart=part("BuggySign",Vector3.new(5,.8,.12),CFrame.new(0,1.6,-5.8),dark)
local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Front;gui.PixelsPerStud=50;gui.Parent=labelPart
local label=Instance.new("TextLabel");label.Name="Label";label.Size=UDim2.fromScale(1,1)
label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBold;label.Text="TOY RIDER · 02"
label.TextColor3=yellow;label.TextScaled=true;label.Parent=gui
local attachment=Instance.new("Attachment");attachment.Name="DriveAttachment";attachment.Parent=root
local drive=Instance.new("LinearVelocity");drive.Name="Drive";drive.Attachment0=attachment
drive.RelativeTo=Enum.ActuatorRelativeTo.World;drive.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
drive.ForceLimitsEnabled=true;drive.ForceLimitMode=Enum.ForceLimitMode.PerAxis
drive.MaxAxesForce=Vector3.new(10000,0,10000);drive.VectorVelocity=Vector3.zero;drive.Parent=root
local upright=Instance.new("AlignOrientation");upright.Name="Steering";upright.Attachment0=attachment
upright.Mode=Enum.OrientationAlignmentMode.OneAttachment;upright.CFrame=origin.Rotation
upright.MaxTorque=100000;upright.MaxAngularVelocity=2.5;upright.Responsiveness=14;upright.Parent=root
local parkingPose=Instance.new("CFrameValue");parkingPose.Name="Parking";parkingPose.Value=origin;parkingPose.Parent=car
car.Parent=scene
local parking=Instance.new("Part");parking.Name="BuggyParking";parking.Size=Vector3.new(14,.08,17)
parking.CFrame=CFrame.new(0,.22,12);parking.Anchored=true;parking.CanCollide=false;parking.CanTouch=false
parking.Color=teal;parking.Material=Enum.Material.SmoothPlastic;parking.Transparency=.35;parking.Parent=scene.Geometry
local remote=game.ReplicatedStorage:FindFirstChild("ToyDrive")or Instance.new("RemoteEvent")
remote.Name="ToyDrive";remote.Parent=game.ReplicatedStorage
return {model=car:GetFullName(),parts=#car:GetChildren(),parking=tostring(origin.Position)}
