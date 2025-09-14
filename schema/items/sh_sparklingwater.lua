ITEM.id = "sparkling_water"
ITEM.name = "Газировка"
ITEM.model = Model("models/props_junk/popcan01a.mdl")
ITEM.weight = 0.1
ITEM.skin = 1
ITEM.description = "Красная алюминиевая банка газировки."
ITEM.category = "Съедобное"
ITEM.illegal = false
ITEM.iconCam = {
	pos = Vector(509.64, 427.61, 310.24),
	ang = Angle(25, 220, 0),
	fov = 0.71
}
ITEM.exRender = true

ITEM.functions.Выпить = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(50)
		client:SetHealth(math.Clamp(client:Health() + 8, 0, client:GetMaxHealth()))
		client:EmitSound("npc/barnacle/barnacle_gulp2.wav", 75, 90, 0.35)
		return true
	end,
}
