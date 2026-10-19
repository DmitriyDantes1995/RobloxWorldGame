local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PlayerProgress = {}
PlayerProgress.__index = PlayerProgress

local LEASE_SECONDS = 180
local AUTOSAVE_SECONDS = 45
local LEASE_MARGIN = 15
local REQUEST_SECONDS = 20
local MAX_ATTEMPTS = 4
local WRITE_INTERVAL = 5
local MAX_INTEGER = 9007199254740991
local STORE_NAME = RunService:IsStudio() and "TreasureLairProgress_Studio_v1" or "TreasureLairProgress_v1"

local function integer(value)
    return type(value)=="number" and value>=0 and value<=MAX_INTEGER and value%1==0
end

local function valid(record)
    if type(record)~="table" or (record.Version~=1 and record.Version~=2 and record.Version~=3) or not integer(record.Coins)
        or not integer(record.BackpackLevel) or record.BackpackLevel>100 then return false end
    if (record.Version>=2 or record.Keys~=nil) and not integer(record.Keys) then return false end
    for _,key in {"SprintUnlocked","JumpUnlocked"} do
        if (record.Version==3 or record[key]~=nil) and type(record[key])~="boolean" then return false end
    end
    local session=record.Session
    return session==nil or (type(session)=="table" and type(session.Token)=="string" and integer(session.ExpiresAt))
end

-- A single store dependency keeps the session protocol testable without live cloud writes.
function PlayerProgress.new(store,budgetAvailable)
    return setmetatable({store=store,budgetAvailable=budgetAvailable,profiles={},rng=Random.new()},PlayerProgress)
end

local function pause(seconds,deadline)
    local untilTime=math.min(os.clock()+seconds,deadline)
    while os.clock()<untilTime do task.wait(math.min(.25,untilTime-os.clock())) end
end

function PlayerProgress:_request(profile,transform,deadline)
    local lastError="timeout"
    for attempt=1,MAX_ATTEMPTS do
        while os.clock()<deadline and not self.budgetAvailable() do task.wait(.25) end
        if os.clock()>=deadline then return nil,lastError end
        local rejected
        local ok,result=pcall(function()
            return self.store:UpdateAsync("Player_"..profile.player.UserId,function(old,info)
                -- Roblox may invoke this callback repeatedly after a conflicting write.
                rejected=nil
                if os.clock()>=deadline then rejected="timeout";return nil end
                local value,reason=transform(old)
                if not value then rejected=reason;return nil end
                return value,profile.player.UserId>0 and {profile.player.UserId} or {},info and info:GetMetadata() or {}
            end)
        end)
        if ok and result~=nil then return result end
        lastError=rejected or tostring(result)
        if rejected and rejected~="locked" then return nil,rejected end
        if attempt<MAX_ATTEMPTS then pause(2^(attempt-1)+self.rng:NextNumber(0,.5),deadline) end
    end
    return nil,lastError
end

function PlayerProgress:Load(player)
    if self.shutdownDeadline then return nil,"server closing" end
    if self.profiles[player] then return nil,"already loading" end
    local profile={player=player,token=HttpService:GenerateGUID(false),loading=true,nextWrite=0}
    self.profiles[player]=profile
    local deadline=math.min(os.clock()+REQUEST_SECONDS,self.shutdownDeadline or math.huge)
    local data,reason=self:_request(profile,function(old)
        if profile.closing then return nil,"cancelled" end
        if old==nil then old={Version=3,Coins=0,BackpackLevel=0,Keys=0,SprintUnlocked=false,JumpUnlocked=false} end
        if not valid(old) then return nil,"invalid data or unsupported version" end
        local lock=old.Session
        if lock and lock.Token~=profile.token and lock.ExpiresAt>os.time() then return nil,"locked" end
        local record=table.clone(old)
        -- Defaults apply only to valid legacy records after acquiring their session.
        record.Version=3;record.Keys=old.Keys or 0
        record.SprintUnlocked=old.SprintUnlocked==true;record.JumpUnlocked=old.JumpUnlocked==true
        record.Session={Token=profile.token,ExpiresAt=os.time()+LEASE_SECONDS}
        return record
    end,deadline)
    profile.loading=false
    if not data then
        self.profiles[player]=nil
        warn("[PlayerProgress] Load failed for "..player.UserId..": "..reason)
        return nil,reason
    end
    profile.loaded=true;profile.expiresAt=data.Session.ExpiresAt
    profile.initial={Coins=data.Coins,BackpackLevel=data.BackpackLevel,Keys=data.Keys,SprintUnlocked=data.SprintUnlocked,JumpUnlocked=data.JumpUnlocked}
    if profile.closing or player.Parent~=Players then
        self:Close(player)
        return nil,"cancelled"
    end
    return table.clone(profile.initial)
end

-- BaseServer applies loaded attributes and derived capacity before activating economy access.
function PlayerProgress:Activate(player)
    local profile=self.profiles[player]
    if not profile or not profile.loaded or profile.closing or player.Parent~=Players then return false end
    profile.applied=true;profile.initial=nil
    profile.nextAutosave=os.clock()+self.rng:NextNumber(30,AUTOSAVE_SECONDS)
    player:SetAttribute("TemporaryProgress",self.temporary==true)
    player:SetAttribute("ProgressLoaded",true)
    return true
end

function PlayerProgress:IsReady(player)
    local profile=self.profiles[player]
    return profile~=nil and profile.applied==true and not profile.closing and not profile.lost
        and player.Parent==Players and os.time()<profile.expiresAt-LEASE_MARGIN
end

function PlayerProgress:_lose(profile,reason)
    profile.lost=true
    profile.player:SetAttribute("ProgressLoaded",false)
    warn("[PlayerProgress] Session stopped for "..profile.player.UserId..": "..reason)
    if profile.player.Parent==Players then
        profile.player:Kick("Соединение с сохранением потеряно. Зайдите снова через пару минут; сохранённый прогресс защищён.")
    end
end

function PlayerProgress:_write(profile,release,deadline)
    while (profile.loading or profile.busy) and os.clock()<deadline do task.wait(.1) end
    if self.profiles[profile.player]~=profile then return true end
    if profile.loading or profile.busy or not profile.loaded or profile.lost or os.clock()>=deadline then return false end
    if profile.closing and not release then return false end
    profile.busy=true
    local player=profile.player
    local data=profile.applied and {Coins=player:GetAttribute("Coins"),BackpackLevel=player:GetAttribute("BackpackLevel"),Keys=player:GetAttribute("Keys"),SprintUnlocked=player:GetAttribute("SprintUnlocked"),JumpUnlocked=player:GetAttribute("JumpUnlocked")} or profile.initial
    local writeId=HttpService:GenerateGUID(false)
    local saved,reason=self:_request(profile,function(old)
        if not valid(old) or not integer(data.Coins) or not integer(data.BackpackLevel) or data.BackpackLevel>100 or not integer(data.Keys)
            or type(data.SprintUnlocked)~="boolean" or type(data.JumpUnlocked)~="boolean" then
            return nil,"invalid data or unsupported version"
        end
        -- A release may have committed even if the response was lost. Acknowledge without rewriting.
        if release and old.LastWrite==writeId then return old end
        local lock=old.Session
        if not lock or lock.Token~=profile.token or lock.ExpiresAt<=os.time() then return nil,"session lost" end
        local record=table.clone(old)
        record.Version=3;record.Coins=data.Coins;record.BackpackLevel=data.BackpackLevel;record.Keys=data.Keys;record.LastWrite=writeId
        record.SprintUnlocked=data.SprintUnlocked;record.JumpUnlocked=data.JumpUnlocked
        record.Session=not release and {Token=profile.token,ExpiresAt=os.time()+LEASE_SECONDS} or nil
        return record
    end,deadline)
    profile.busy=false;profile.nextWrite=os.clock()+WRITE_INTERVAL
    -- A departing player's Close may time out while UpdateAsync is still yielding.
    -- Once that request drains, flush the newest attributes and release the lease.
    if not release and profile.closing then
        task.defer(function()
            if self.profiles[player]==profile and (not self.shutdownDeadline or os.clock()<self.shutdownDeadline) then
                self:Close(player)
            end
        end)
    end
    if saved then
        if not release then profile.expiresAt=saved.Session.ExpiresAt end
        profile.warned=false
        return true,true
    end
    if reason=="session lost" or reason=="invalid data or unsupported version" then self:_lose(profile,reason)
    elseif not profile.warned then
        profile.warned=true
        warn("[PlayerProgress] Save failed for "..player.UserId.."; retry pending: "..tostring(reason))
    end
    return false,true
end

function PlayerProgress:Save(player)
    local profile=self.profiles[player]
    if not profile or profile.closing then return false end
    return self:_write(profile,false,math.min(os.clock()+REQUEST_SECONDS,self.shutdownDeadline or math.huge))
end

function PlayerProgress:RequestSave(player)
    local profile=self.profiles[player]
    if not profile or not profile.applied or profile.closing or profile.lost then return end
    profile.pending=true
    if profile.worker then return end
    profile.worker=true
    task.spawn(function()
        while self.profiles[player]==profile and profile.pending and not profile.closing and not profile.lost do
            while os.clock()<profile.nextWrite and not profile.closing do task.wait(.1) end
            if profile.closing then break end
            profile.pending=false
            if not self:Save(player) then profile.pending=true end
        end
        profile.worker=false
    end)
end

function PlayerProgress:Autosave()
    local now=os.clock()
    for player,profile in pairs(self.profiles) do
        if profile.applied and not profile.closing and not profile.lost then
            if os.time()>=profile.expiresAt-LEASE_MARGIN then self:_lose(profile,"lease expired")
            elseif now>=profile.nextAutosave then
                profile.nextAutosave=now+AUTOSAVE_SECONDS
                self:RequestSave(player)
            end
        end
    end
end

function PlayerProgress:Close(player,deadline)
    local profile=self.profiles[player]
    if not profile then return true end
    profile.closing=true
    player:SetAttribute("ProgressLoaded",false)
    deadline=math.min(deadline or os.clock()+25,self.shutdownDeadline or math.huge)
    local ok,attempted=self:_write(profile,true,deadline)
    -- An expired waiter does not own finalization: a deferred Close may still need this profile.
    if ok or attempted or profile.lost or (not profile.loading and not profile.loaded) then self.profiles[player]=nil end
    if not ok then warn("[PlayerProgress] Final save failed for "..player.UserId.."; retained cloud record and lease") end
    return ok
end

function PlayerProgress:CloseAll()
    self.shutdownDeadline=os.clock()+25
    local remaining=0
    for player in pairs(self.profiles) do
        remaining+=1
        task.spawn(function() self:Close(player,self.shutdownDeadline);remaining-=1 end)
    end
    while remaining>0 and os.clock()<self.shutdownDeadline do task.wait(.1) end
end

-- Select before any cloud request. Never use temporary data as recovery from a failed load.
-- This branch cannot run on Roblox servers, even if a place has no universe id.
if RunService:IsStudio() and game.GameId==0 then
    local records={}
    local memoryStore={}
    function memoryStore:UpdateAsync(key,transform)
        local record=transform(records[key])
        if record~=nil then records[key]=record end
        return record
    end
    local progress=PlayerProgress.new(memoryStore,function() return true end)
    progress.temporary=true
    warn("[PlayerProgress] Studio temporary progress: NOT SAVED. Unpublished local place; no DataStore access. Progress resets when Play stops.")
    return progress
end

-- Published Studio tests and Roblox servers retain strict cloud loading and session protection.
local liveStore={}
function liveStore:UpdateAsync(key,transform)
    return DataStoreService:GetDataStore(STORE_NAME):UpdateAsync(key,transform)
end
local function budgetAvailable()
    return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)>0
        and DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)>0
end

return PlayerProgress.new(liveStore,budgetAvailable)
