local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Progress=require(script.Parent.ToyProgress)
local Game=require(script.Parent.ToyGame)
local gameLoop=Game.new(workspace.ToyKeeper,Progress,ReplicatedStorage.ToySignal)

local function joined(player)
    player:SetAttribute("ProgressLoaded",false)
    local data,reason=Progress:Load(player)
    if not data then
        if player.Parent==Players then player:Kick("Не удалось загрузить прогресс: "..tostring(reason)..". Попробуй позже.") end
        return
    end
    if not gameLoop:AddPlayer(player,data) then
        Progress:Close(player)
        if player.Parent==Players then player:Kick("Все четыре сада заняты. Выбери другой сервер.") end
        return
    end
    player.CharacterAdded:Connect(function(character) gameLoop:CharacterAdded(player,character) end)
    if player.Character then task.spawn(function() gameLoop:CharacterAdded(player,player.Character) end) end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    gameLoop:RemovePlayer(player)
    Progress:Close(player)
end)
for _,player in Players:GetPlayers() do task.spawn(joined,player) end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed<.1 then return end
    elapsed=0
    gameLoop:Step(workspace:GetServerTimeNow())
    Progress:Autosave()
end)
game:BindToClose(function() Progress:CloseAll() end)
