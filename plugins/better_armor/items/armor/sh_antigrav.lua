ITEM.name = "Куб Гравитации"
ITEM.description = ""
ITEM.category = "Артефакты"
ITEM.model = "models/Combine_Helicopter/helicopter_bomb01.mdl"
ITEM.width = 2
ITEM.armorAmount = 5
ITEM.gasmask = false -- It will protect you from bad air
ITEM.height = 2
ITEM.gravityModifier = 0.2
ITEM.resistance = false

function ITEM:OnEquipped()
    if self.player then
        self.player:SetGravity(self.gravityModifier or 1)
    end
end

function ITEM:OnUnequipped()
    if self.player then
        self.player:SetGravity(1) -- Возвращаем стандартную гравитацию
    end
end