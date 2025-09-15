
ITEM.name = "Кусок мозга"
ITEM.model = Model("models/gore/head_headbitfrontright.mdl")
ITEM.description = "Кусок человеческого мозга, полон серого вещества."
ITEM.width = 1 -- Width and height refer to how many grid spaces this item takes up.
ITEM.height = 1
ITEM.exRender = true
ITEM.iconCam = {
	pos = Vector(509.64, 427.61, 310.24),
	ang = Angle(24.9, 220.23, 0),
	fov = 0.48
}


-- Items will be purchasable through the business menu. To disable the purchasing of this item, we specify ITEM.noBusiness.
ITEM.noBusiness = true

-- If you'd rather have the item only purchasable by a specific criteria, then you can specify it as such.
-- Make sure you haven't defined ITEM.noBusiness if you are going to be doing this.
--[[
ITEM.factions = {FACTION_POLICE} -- Only a certain faction can buy this.
ITEM.classes = {FACTION_POLICE_CHIEF} -- Only a certain class can buy this.
ITEM.flag = "z" -- Only a character having a certain flag can buy this.
]]

-- If the item is purchasable, then you'll probably want to set a price for it:
--[[
ITEM.price = 5
]]

-- You can define additional actions for this item as such:
ITEM.functions.Съесть = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.min(client:Health() + 10, client:GetMaxHealth()))
		client:EmitSound("physics/flesh/flesh_squishy_impact_hard1.wav", 75, 90, 0.35)
		client:EmitSound("vo/ravenholm/madlaugh01.wav", 75, 90, 0.35)
		return true
	end,
}
