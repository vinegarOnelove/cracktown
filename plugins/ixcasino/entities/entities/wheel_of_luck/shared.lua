ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Автомат Колесо Удачи"
ENT.Author = "<CODE BLUE>"
ENT.Contact = "Via Steam"
ENT.Spawnable = true
ENT.Category = "Helix"
ENT.AdminSpawnable = true

ENT.AutomaticFrameAdvance = true

ENT.WheelSides = 8

//A table that can convert an id to a string value, this is to check if someone wins
local idToString = {}
idToString[1] = "bonus"
idToString[2] = "raspberry"
idToString[3] = "coins"
idToString[4] = "diamond"
idToString[5] = "bar2"
idToString[6] = "bar"
idToString[7] = "seven"
idToString[8] = "nothing"

WOL_ITEM_CHANCE = {}
WOL_ITEM_CHANCE[1] = 1   -- Bonus
WOL_ITEM_CHANCE[2] = 50  -- Raspberry
WOL_ITEM_CHANCE[3] = 30  -- Coins
WOL_ITEM_CHANCE[4] = 10  -- Diamond
WOL_ITEM_CHANCE[5] = 60  -- Bar Two
WOL_ITEM_CHANCE[6] = 70  -- Bar One
WOL_ITEM_CHANCE[7] = 55  -- Seven
WOL_ITEM_CHANCE[8] = 65  -- Nothing

WOL_BONUS_ITEMS = {}

WOL_BONUS_ITEMS[1] = {cash = "jackpot", chance = 200} //The jackpot (Leave this here always)

local index = 2

//Used for register a new bonus item, there should be only 19.
function WOL_AddBonusItem(cashReward, chance)
	WOL_BONUS_ITEMS[index] = {cash = cashReward, chance = chance}
	index = index + 1
end

-- Hardcoded bonus items
WOL_AddBonusItem(100)
WOL_AddBonusItem(200)
WOL_AddBonusItem(400)
WOL_AddBonusItem(1000)
WOL_AddBonusItem(2500)
WOL_AddBonusItem(5000)
WOL_AddBonusItem(7500)
WOL_AddBonusItem(10000)
WOL_AddBonusItem(15000)
WOL_AddBonusItem(20000)
WOL_AddBonusItem(30000)
WOL_AddBonusItem(40000)
WOL_AddBonusItem(60000)
WOL_AddBonusItem(75000)
WOL_AddBonusItem(100000)
WOL_AddBonusItem(150000)
WOL_AddBonusItem(175000)
WOL_AddBonusItem(200000)
WOL_AddBonusItem(300000)

//Returns the string respresenting that ID
function WOL_IDToString(id)
	return idToString[id]
end


function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "BonusSpins" )
	self:NetworkVar( "Int", 1, "LastWin" )
	self:NetworkVar( "Entity", 1 , "ReelOne")
	self:NetworkVar( "Entity", 2 , "ReelTwo")
	self:NetworkVar( "Entity", 3 , "ReelThree")
	self:NetworkVar( "Int", 4 , "Jackpot")
end