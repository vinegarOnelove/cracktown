
-- Since this faction is not a default, any player that wants to become part of this faction will need to be manually
-- whitelisted by an administrator.

FACTION.name = "Управление"
FACTION.description = "Очень злые люди! Разговоры с пришельцами, криптидами, похищение людей, все это их рук дело!"
FACTION.color = Color(0, 0, 0)
FACTION.pay = 75 -- How much money every member of the faction gets paid at regular intervals.
FACTION.isGloballyRecognized = false -- Makes it so that everyone knows the name of the characters in this faction.
FACTION.isDefault = false
FACTION.weapons = {'weapon_firem'}
function FACTION:OnCharacterCreated(client, character)
	local inventory = character:GetInventory()
	inventory:Add("melee_cultist", 1)
end
-- Note that FACTION.models is optional. If it is not defined, it will use all the standard HL2 citizen models.
FACTION.models = {
	"models/as/darkbrad.mdl",
	"models/as/necromancer.mdl",
	"models/as/necromancer_skeleton.mdl",
	"models/as/necromancerloomis.mdl",
	"models/as/playermodel/darkbrad.mdl"
	
}

FACTION_CONTROL = FACTION.index
