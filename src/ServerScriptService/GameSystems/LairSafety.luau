local Safety = {}
local function inside(part, position)
    local p = part.CFrame:PointToObjectSpace(position)
    local h = part.Size * 0.5
    return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
function Safety.Root(player)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then return nil end
    return root
end
function Safety.InBase(scene, position)
    return inside(scene.Zones.Base, position)
end
function Safety.InHide(scene, position)
    for _, zone in ipairs(scene.Zones.Hides:GetChildren()) do
        if inside(zone, position) then return true end
    end
    return false
end
function Safety.InLair(scene, position)
    for _, zone in ipairs(scene.Zones.Lair:GetChildren()) do
        if inside(zone, position) then return true end
    end
    return false
end
function Safety.InExpedition(scene,position)
    if Safety.InLair(scene,position) or Safety.InHide(scene,position) then return true end
    for _,zone in scene.Zones.ExpeditionAccess:GetChildren() do
        if inside(zone,position) then return true end
    end
    return false
end
return Safety
