local Catalog={}
Catalog.SpawnOrder={"Common","Idol","Rare","Legendary"}
Catalog.Order={"Common","Idol","Rare","Legendary","Relic"}
Catalog.Items={
    Common={Name="Самоцвет",Template="Gem",Price=25,Capacity=1,Risk=3,Description="Лёгкая находка",Color=Color3.fromRGB(75,240,170)},
    Idol={Name="Идол",Template="HeavyIdol",Price=200,Capacity=3,Risk=16,Description="Замедляет",Color=Color3.fromRGB(173,139,90)},
    Rare={Name="Кристалл",Template="CursedCrystal",Price=150,Capacity=1,Risk=12,Description="Выдаёт позицию",Color=Color3.fromRGB(185,95,255)},
    Legendary={Name="Корона",Template="GoldenCrown",Price=175,Capacity=1,Risk=14,Description="Оставляет след",Color=Color3.fromRGB(255,202,55)},
    Relic={Name="Реликвия",Template="KeeperToy",Price=1000,Capacity=3,Risk=45,Description="Любимая игрушка",Color=Color3.fromRGB(255,183,45)},
}
-- Markers retain their authored danger tier. Each expedition still contains 28 items.
Catalog.SpawnWeights={
    Common={Common=94,Idol=3,Rare=2,Legendary=1},
    Rare={Common=60,Idol=15,Rare=15,Legendary=10},
    Legendary={Common=20,Idol=28,Rare=27,Legendary=25},
}
Catalog.MinimumCommon=15
Catalog.RunSpeed=16
Catalog.WalkSpeed=10
Catalog.IdolSpeedMultiplier=.82
Catalog.RelicSpeedMultiplier=.9
Catalog.Crystal={Interval=12,WarningSeconds=1.8,FlashSeconds=.9,Radius=50}
Catalog.Trail={Lifetime=8,DetectDistance=18,Spacing=4,Interval=.35,RunningThreshold=12}
Catalog.DropCooldown=.4
return Catalog
