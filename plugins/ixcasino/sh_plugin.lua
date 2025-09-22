local PLUGIN = PLUGIN

PLUGIN.name = "IX: Division Casino"
PLUGIN.author = "Division X | In Memory of Code Blue"
PLUGIN.description = "Adds blues slots with helix compatibility, even persists the Slots and Jackpot in the Map"

game.AddParticles( "particles/wol_money_effects.pcf")

ix.config.Add("doubleOrNothingBet", 500, "Current double or nothing bet.", nil, {
	data = {min = 1, max = 9999},
	category = PLUGIN.name
})

ix.config.Add("wheelOfLuckBet", 500, "Current wheel of luck bet.", nil, {
	data = {min = 1, max = 9999},
	category = PLUGIN.name
})

ix.config.Add("doubleOrNothingMinJackpot", 50000, "Current double or nothing bet.", nil, {
	data = {min = 0, max = 100000},
	category = PLUGIN.name
})

ix.config.Add("wheelOfLuckMinJackpot", 50000, "Current wheel of luck min jackpot.", nil, {
	data = {min = 0, max = 100000},
	category = PLUGIN.name
})

ix.config.Add("doubleOrNothingMaxJackpot", 100000, "Current double or nothing bet.", nil, {
	data = {min = 0, max = 1000000},
	category = PLUGIN.name
})

ix.config.Add("wheelOfLuckMaxJackpot", 100000, "Current wheel of luck max jackpot.", nil, {
	data = {min = 0, max = 1000000},
	category = PLUGIN.name
})

ix.config.Add("doubleOrNothingChance", 50, "Current double or nothing chance.", nil, {
	data = {min = 1, max = 100},
	category = PLUGIN.name
})

ix.config.Add("doubleOrNothingJackpotAdd", 50, "Percantage of bet that goes into the jackpot.", nil, {
	data = {min = 1, max = 100},
	category = PLUGIN.name
})

ix.config.Add("wheelOfLuckJackpotAdd", 50, "Percantage of bet that goes into the jackpot.", nil, {
	data = {min = 1, max = 100},
	category = PLUGIN.name
})

ix.util.Include("sv_data.lua")