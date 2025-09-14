ITEM.name = "Backpack"
ITEM.description = ""
ITEM.model = Model("models/jmod/props/backpack_3.mdl")
ITEM.width = 2
ITEM.height = 2
ITEM.iconCam = {
	pos = Vector(-96.76, 175.65, 3.65),
	ang = Angle(0.84, -62.26, 0),
	fov = 7.23
}

ITEM.functions.EquipArmor = {
    name = "Экипировать",
    tip = "Equip the armor.",
    icon = "icon16/arrow_up.png",
    OnRun = function(item)
        local client = item.player

        if (IsValid(client) and client:IsPlayer()) then
            local armorType = "Backpack" 
            JMod.EZ_Equip_Armor(client, armorType) -- Функция для экипировки брони
            return true
        end
        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:IsPlayer()
    end
}