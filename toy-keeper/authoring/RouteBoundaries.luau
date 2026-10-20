-- Edit-only authoring, not a runtime Script. The saved place already contains these parts.
-- Keep players inside the same free strip used by the full guard bodies.
local scene=workspace.ToyKeeper
assert(not game:GetService("RunService"):IsRunning(),"Author route boundaries in Edit only")
local old=scene.Geometry:FindFirstChild("RouteBoundaries")
if old then old:Destroy()end
local folder=Instance.new("Folder");folder.Name="RouteBoundaries"
local function part(name,size,position,color,transparency,collidable)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position
    p.Anchored=true;p.CanCollide=collidable;p.CanTouch=false;p.CanQuery=collidable
    p.Color=color;p.Transparency=transparency or 0
    p.Material=transparency and Enum.Material.Glass or Enum.Material.SmoothPlastic
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=folder
end
local colors={Color3.fromRGB(108,192,162),Color3.fromRGB(213,167,83),Color3.fromRGB(154,126,201)}
for zone,color in colors do
    local z=(zone-.5)*116
    for _,side in {-1,1}do
        part("Glass"..zone.."_"..side,Vector3.new(1,14,116),Vector3.new(side*73,7,z),color,.72,true)
        for _,y in {.6,14}do
            part("Rail"..zone.."_"..side.."_"..y,Vector3.new(1.4,.6,116),Vector3.new(side*73,y,z),color,nil,false)
        end
    end
end
for _,z in {0,116,232,348}do
    for _,side in {-1,1}do
        part("Post"..side.."_"..z,Vector3.new(1.8,14.6,1.8),Vector3.new(side*73,7.3,z),colors[math.clamp(math.ceil(z/116),1,3)],nil,false)
    end
end
-- Close the entrances to the decorative side strips and the far floor buffer too.
for _,side in {-1,1}do
    part("GardenSideGlass"..side,Vector3.new(31,14,1),Vector3.new(side*88,7,.5),colors[1],.72,true)
    part("GardenSideRail"..side,Vector3.new(31,.6,1.4),Vector3.new(side*88,14,.5),colors[1],nil,false)
end
part("EndGlass",Vector3.new(147,14,1),Vector3.new(0,7,348),colors[3],.72,true)
part("EndRail",Vector3.new(147,.6,1.4),Vector3.new(0,14,348),colors[3],nil,false)
folder.Parent=scene.Geometry
return folder
