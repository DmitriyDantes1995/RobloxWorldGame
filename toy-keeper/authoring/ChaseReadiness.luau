-- Edit-only command; these authored positions are already saved in ToyKeeper.rbxlx.
-- The route is wide and clear. Keep the night guard on his existing far patrol
-- corner so a strong thief has time to grab a box before the physical run begins.
assert(not game:GetService("RunService"):IsRunning(),"Use only in Edit")
local scene=workspace.ToyKeeper
local rig=scene.Keepers.Nightmare
local point=scene.PatrolPoints.Nightmare.Point3
local position=Vector3.new(point.Position.X,rig.HumanoidRootPart.Position.Y,point.Position.Z)
rig:PivotTo(CFrame.new(position)*rig:GetPivot().Rotation)
return rig:GetPivot()
