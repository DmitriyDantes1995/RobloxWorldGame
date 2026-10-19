local Config=require(script.Parent.LairConfig)
local Safety=require(script.Parent.LairSafety)
local Expedition={}
Expedition.__index=Expedition

function Expedition.new(scene,resetLair)
    local self=setmetatable({scene=scene,resetLair=resetLair,members={},state="Ready"},Expedition)
    scene:SetAttribute("ExpeditionState","Ready")
    return self
end

function Expedition:SetState(state)
    self.state=state
    self.scene:SetAttribute("ExpeditionState",state)
end

-- LairServer supplies one current player snapshot and a monotonic timestamp per tick.
function Expedition:Step(players,now)
    if self.state=="Resetting" then return end
    local members={}
    for _,player in players do
        local root=Safety.Root(player)
        if root and not Safety.InBase(self.scene,root.Position)
            and (self.members[player] or Safety.InExpedition(self.scene,root.Position)) then
            members[player]=true
        end
    end
    self.members=members
    if next(members) then
        self.resetAt=nil
        if self.state~="Active" then self:SetState("Active") end
    elseif self.state=="Active" then
        self.resetAt=now+Config.ExpeditionResetSeconds
        self:SetState("Completed")
    elseif self.state=="Completed" and now>=self.resetAt then
        self:SetState("Resetting")
        -- This callback does not yield: occupancy cannot change halfway through a reset.
        self.resetLair()
        self.resetAt=nil
        self:SetState("Ready")
    end
end

return Expedition
