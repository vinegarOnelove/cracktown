
-- Since this faction is not a default, any player that wants to become part of this faction will need to be manually
-- whitelisted by an administrator.

FACTION.name = "Полицейский департамент"
FACTION.description = "Довольно злые люди, главное не будь особо черным!"
FACTION.color = Color(45, 145, 210)
FACTION.pay = 10 -- How much money every member of the faction gets paid at regular intervals.
FACTION.weapons = {"arc9_gekolt_cw_baliff","arc9_eft_melee_taran"} -- Weapons that every member of the faction should start with.
FACTION.isGloballyRecognized = true -- Makes it so that everyone knows the name of the characters in this faction.
FACTION.isDefault = true

-- Note that FACTION.models is optional. If it is not defined, it will use all the standard HL2 citizen models.
FACTION.models = {
	"models/player/gpd/sheriff_ancient/male_04.mdl",
	"models/player/gpd/sheriff_ancient/male_06.mdl",
	"models/player/gpd/sheriff_ancient/male_07.mdl",
	"models/player/gpd/sheriff_ancient/male_08.mdl",
	"models/player/gpd/sheriff_ancient/male_gta_02.mdl"
	
}

FACTION_POLICE = FACTION.index
