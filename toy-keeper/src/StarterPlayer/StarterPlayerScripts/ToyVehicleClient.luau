local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local car=workspace:WaitForChild("ToyKeeper"):WaitForChild("Buggy")
local driver=car:WaitForChild("DriverSeat")
local passenger=car:WaitForChild("PassengerSeat")
local remote=game.ReplicatedStorage:WaitForChild("ToyDrive")
local gui=Instance.new("ScreenGui");gui.Name="ToyVehicleHUD";gui.ResetOnSpawn=false
gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;gui.Parent=player:WaitForChild("PlayerGui")
local hint=Instance.new("TextLabel");hint.Size=UDim2.new(0,360,0,48)
hint.Position=UDim2.new(.5,-180,0,94);hint.BackgroundColor3=Color3.fromRGB(24,41,49)
hint.BackgroundTransparency=.12;hint.TextColor3=Color3.fromRGB(255,235,170)
hint.Font=Enum.Font.GothamBold;hint.TextSize=14;hint.TextWrapped=true;hint.Visible=false;hint.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=hint
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed<.08 then return end
    elapsed=0
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat=humanoid and humanoid.SeatPart
    hint.Visible=seat==driver or seat==passenger
    if seat==driver then
        remote:FireServer(driver.ThrottleFloat,driver.SteerFloat)
        hint.Text=UserInputService.TouchEnabled and "БАГГИ · джойстик — ехать\nПрыжок — выйти"or"БАГГИ · WASD — ехать\nПробел — выйти"
    elseif seat==passenger then
        hint.Text=UserInputService.TouchEnabled and "ПАССАЖИР · приятной поездки!\nПрыжок — выйти"or"ПАССАЖИР · приятной поездки!\nПробел — выйти"
    end
end)
