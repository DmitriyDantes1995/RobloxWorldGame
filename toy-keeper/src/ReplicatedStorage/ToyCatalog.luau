-- Shared source of truth: probabilities, toy identities, income and speed prices.
local Catalog = {}
Catalog.Order = {"Common", "Rare", "Epic", "Legendary"}
Catalog.Gifts = {
    Common = {Name="Обычный", Color=Color3.fromRGB(91,210,166), Contents={{"Bear",75},{"Bunny",25}}},
    Rare = {Name="Редкий", Color=Color3.fromRGB(80,174,255), Contents={{"MintBunny",35},{"Robot",25},{"RibbonGrin",22},{"WobbleCrank",18}}},
    Epic = {Name="Эпический", Color=Color3.fromRGB(191,121,255), Contents={{"Dino",40},{"Dragon",30},{"PuffMaw",30}}},
    Legendary = {Name="Легендарный", Color=Color3.fromRGB(255,202,76), Contents={{"MoonBear",40},{"StarDragon",25},{"TimberTap",35}}},
}
Catalog.LegacyToyOrder = {"Bear","Bunny","MintBunny","Robot","Dino","Dragon","MoonBear","StarDragon"}
Catalog.ToyOrder = {"Bear","Bunny","MintBunny","Robot","RibbonGrin","WobbleCrank","Dino","Dragon","PuffMaw","MoonBear","StarDragon","TimberTap"}
Catalog.Toys = {
    Bear={Name="Плюшик",Rarity="Common",Income=1},
    Bunny={Name="Прыг-скок",Rarity="Common",Income=2},
    MintBunny={Name="Мятный заяц",Rarity="Rare",Income=4},
    Robot={Name="Бип-Боп",Rarity="Rare",Income=6},
    Dino={Name="Кнопкозавр",Rarity="Epic",Income=10},
    Dragon={Name="Сонный дракон",Rarity="Epic",Income=15},
    MoonBear={Name="Лунный медведь",Rarity="Legendary",Income=25},
    StarDragon={Name="Звездокрыл",Rarity="Legendary",Income=45},
    RibbonGrin={Name="Лапшехохот",Rarity="Rare",Income=7,Motion="Slink"},
    PuffMaw={Name="Пухозуб",Rarity="Epic",Income=14,Motion="Bounce"},
    WobbleCrank={Name="Кривошестер",Rarity="Rare",Income=5,Motion="Windup"},
    TimberTap={Name="Бревнобрык",Rarity="Legendary",Income=32,Motion="Waddle"},
}
Catalog.Zones = {
    {Name="ПЛЮШЕВАЯ ЗОНА",Keeper="Plush",GuardName="Плюшевый Топотун",Weights={Common=90,Rare=10,Epic=0,Legendary=0},ChaseSpeed=15,PatrolSpeed=8,Warning=.55,Motion=3.5},
    {Name="ЗАВОДНАЯ ЗОНА",Keeper="Clockwork",GuardName="Заводной Перекрут",Weights={Common=40,Rare=48,Epic=12,Legendary=0},ChaseSpeed=22,PatrolSpeed=10,Warning=.45,Motion=7},
    {Name="КОШМАРНАЯ ЗОНА",Keeper="Nightmare",GuardName="Кошмарный Ночеглот",Weights={Common=10,Rare=35,Epic=45,Legendary=10},ChaseSpeed=30,PatrolSpeed=10,Warning=.35,Motion=5.5},
}
-- Bands preserve the old probability weights, but draw actual hundredth sizes.
Catalog.Sizes = {
    {Min=1,Max=1.59,Name="Обычный",Weight=70},
    {Min=1.6,Max=2.49,Name="Большой",Weight=22},
    {Min=2.5,Max=3.99,Name="Гигантский",Weight=7},
    {Min=4,Max=4,Name="Колоссальный",Weight=1},
}
Catalog.BootsRefund=300
Catalog.WorldScale=2
Catalog.WorldScaleLimit=2.2
Catalog.ToolMaxLevel=8
Catalog.Packaging={Health={Common=3,Rare=10,Epic=24,Legendary=48},HitInterval=.25}
Catalog.Catch={Windup=.18,FollowThrough=.55,GraceSeconds=2.4,HorizontalSpeed=86,VerticalSpeed=64,
    MaxHorizontalSpeed=90,MaxVerticalSpeed=72,MaxFallSpeed=95,Spin=2.5,LandingDelay=.15,MaxFlightSeconds=2.2}
Catalog.GiftRespawnSeconds=18
Catalog.VisibleToys=4
local LIMIT=9007199254740991
local firstPrices={120,360,900,2200,5000}
function Catalog.SpeedForLevel(level)
    if level<=5 then return 16+3*level end
    return 31+17*(1-math.exp(-(level-5)/12))
end
function Catalog.SpeedPrice(level)
    if level<5 then return firstPrices[level+1] end
    return math.min(LIMIT,math.ceil(5000*1.65^math.min(level-4,58)))
end
function Catalog.ToolPower(level) return 1.7^level end
function Catalog.ToolPrice(level)
    if level>=Catalog.ToolMaxLevel then return nil end
    return math.ceil(80*2.2^level)
end
function Catalog.BreakDuration(rarity,level,remaining)
    return math.max(.15,math.ceil((remaining or Catalog.Packaging.Health[rarity])/Catalog.ToolPower(level))*Catalog.Packaging.HitInterval)
end
function Catalog.Roll(entries, rng)
    local total=0
    for _,entry in entries do total+=entry[2] end
    local roll=rng:NextNumber(0,total)
    for _,entry in entries do
        if entry[2]>0 then
            roll-=entry[2]
            if roll<=0 then return entry[1] end
        end
    end
    return entries[#entries][1]
end
function Catalog.RollGift(zone,rng)
    local entries={}
    for _,id in Catalog.Order do table.insert(entries,{id,Catalog.Zones[zone].Weights[id]}) end
    return Catalog.Roll(entries,rng)
end
function Catalog.Size(multiplier)
    if type(multiplier)~="number" or multiplier~=multiplier or multiplier<1 or multiplier>4
        or math.abs(multiplier*100-math.round(multiplier*100))>1e-5 then return nil end
    local anchors={{1,1},{1.6,2},{2.5,4},{4,8}}
    local income=8
    for i=2,#anchors do
        local lo,hi=anchors[i-1],anchors[i]
        if multiplier<=hi[1] then income=lo[2]+(hi[2]-lo[2])*(multiplier-lo[1])/(hi[1]-lo[1]);break end
    end
    local name=Catalog.Sizes[1].Name
    for _,band in Catalog.Sizes do if multiplier>=band.Min then name=band.Name end end
    return {Multiplier=multiplier,Name=name,Income=income}
end
function Catalog.RollSize(rng)
    local entries={}
    for i,band in Catalog.Sizes do table.insert(entries,{i,band.Weight}) end
    local band=Catalog.Sizes[Catalog.Roll(entries,rng)]
    return rng:NextInteger(math.round(band.Min*100),math.round(band.Max*100))/100
end
function Catalog.Key(toy,size) return toy.."@"..tostring(size) end
function Catalog.ToyIncome(toy,size) return math.max(1,math.floor(Catalog.Toys[toy].Income*Catalog.Size(size).Income+.5)) end
function Catalog.CopyCollection(collection)
    local copy={}
    for i,entry in collection do copy[i]=table.clone(entry) end
    return copy
end
function Catalog.Income(collection)
    local income=0
    for _,entry in collection do income+=entry.Count*Catalog.ToyIncome(entry.Toy,entry.SizeMultiplier) end
    return income
end
return Catalog
