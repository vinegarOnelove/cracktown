
CLASS.name = "Гвардеец"
CLASS.faction = FACTION_POLICE
CLASS.limit = 2
function CLASS:OnSet(client)
	local character = client:GetCharacter()

	if (character) then
		character:SetModel("models/arachnit/random/georgian_riot_police/georgian_riot_police_player.mdl")
		  	local inventory = character:GetInventory()
  	local itemFilter = {"riot_shield"}
  	if (inventory:HasItems(itemFilter)) then
	  return
  	else
	  	inventory:Add("riot_shield", 1)
  	end
end

-- This function will be called whenever the client wishes to become part of this class. If you'd rather have it so this class
-- has to be set manually by an administrator, you can simply return false to disallow regular users switching to this class.
-- Note that CLASS.isDefault does not add a whitelist like FACTION.isDefault does, which is why we need to use CLASS:OnCanBe.
function CLASS:OnCanBe(client)
	return false
end

CLASS_POLICE_CHIEF = CLASS.index
