
-- You can define factions in the factions/ folder. You need to have at least one faction that is the default faction - i.e the
-- faction that will always be available without any whitelists and etc.

FACTION.name = "Жители"
FACTION.description = "Никто не знает как они сюда попали, и никто не знает что они здесь делают. Но, факт остается фактом, они тут есть."
FACTION.isDefault = true
FACTION.color = Color(230, 124, 0)
FACTION.models = {
    "models/charborg/charborg.mdl",
    "models/criken/criken.mdl",
	"models/mrduck/sentry/gangs/redneck/mapert_08.mdl",
	"models/mrduck/sentry/gangs/redneck/mapert_06.mdl",
	"models/mrduck/sentry/gangs/redneck/mapert_04.mdl",
	"models/mrduck/sentry/gangs/redneck/mapert_02.mdl"
}

-- You should define a global variable for this faction's index for easy access wherever you need. FACTION.index is
-- automatically set, so you can simply assign the value.

-- Note that the player's team will also have the same value as their current character's faction index. This means you can use
-- client:Team() == FACTION_CITIZEN to compare the faction of the player's current character.
FACTION_CITIZEN = FACTION.index
