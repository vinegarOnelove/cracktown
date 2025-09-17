ITEM.name = "Регенерирующийся Металл"
ITEM.description = ""
ITEM.category = "Артефакты"
ITEM.model = "models/props_debris/metal_panelchunk02d.mdl"
ITEM.width = 2
ITEM.armorAmount = 0
ITEM.gasmask = false
ITEM.height = 2
ITEM.resistance = false

-- Настройки регенерации брони
ITEM.regenRate = 5     -- Броня в секунду
ITEM.regenDelay = 5    -- Задержка после получения урона перед началом регенерации (в секундах)
ITEM.maxArmor = 50    -- Максимальное значение брони

function ITEM:OnEquipped()
    -- Проверяем, что player существует и валиден
    if not self.player or not IsValid(self.player) then
        ErrorNoHalt("Anti Cube: Player is nil or invalid on equip!\n")
        return
    end

    local ply = self.player
    local steamID = ply:SteamID64() or "unknown" -- Используем SteamID64 для уникальности

    -- Инициализируем время последнего получения урона
    self.lastDamageTime = 0

    -- Создаем таймер для регенерации брони с уникальным именем
    timer.Create("AntiCubeArmorRegen_" .. steamID, 1, 0, function()
        -- Проверяем, что игрок всё ещё валиден и жив
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("AntiCubeArmorRegen_" .. steamID)
            return
        end

        -- Проверяем задержку после получения урона
        if self.lastDamageTime and CurTime() - self.lastDamageTime < self.regenDelay then
            return
        end

        -- Восстанавливаем броню
        local currentArmor = ply:Armor()
        
        if currentArmor < self.maxArmor then
            local newArmor = math.min(self.maxArmor, currentArmor + self.regenRate)
            ply:SetArmor(newArmor)
        end
    end)

    -- Обработчик урона для отслеживания времени последнего получения урона
    self.damageHookName = "AntiCubeArmorDamage_" .. steamID
    hook.Add("EntityTakeDamage", self.damageHookName, function(target, dmgInfo)
        if target == ply then
            self.lastDamageTime = CurTime()
        end
    end)
end

function ITEM:OnUnequipped()
    -- Проверяем, что player существует и валиден
    if not self.player or not IsValid(self.player) then
        ErrorNoHalt("Anti Cube: Player is nil or invalid on unequip!\n")
        return
    end

    local ply = self.player
    local steamID = ply:SteamID64() or "unknown"

    -- Удаляем таймер регенерации брони
    if timer.Exists("AntiCubeArmorRegen_" .. steamID) then
        timer.Remove("AntiCubeArmorRegen_" .. steamID)
    end

    -- Удаляем хук для обработки урона
    if self.damageHookName then
        hook.Remove("EntityTakeDamage", self.damageHookName)
        self.damageHookName = nil
    end

    self.lastDamageTime = nil
end