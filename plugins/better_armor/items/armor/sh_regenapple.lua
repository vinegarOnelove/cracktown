ITEM.name = "Яблоко Восстановления"
ITEM.description = ""
ITEM.category = "Артефакты"
ITEM.model = "models/gore/debris_goredebris02.mdl"
ITEM.width = 2
ITEM.armorAmount = 5
ITEM.gasmask = false
ITEM.height = 2
ITEM.resistance = false

-- Настройки регенерации
ITEM.regenRate = 5     -- Здоровье в секунду
ITEM.regenDelay = 5    -- Задержка после получения урона перед началом регенерации (в секундах)

-- Важно: Добавляем уникальные идентификаторы для таймеров и хуков, чтобы избежать конфликтов
ITEM.uniqueID = "AntiCubeRegen_" .. os.time() -- Генерируем уникальный ID на основе времени

function ITEM:OnEquipped()
    -- Проверяем, что player существует и валиден
    if not self.player or not IsValid(self.player) then
        ErrorNoHalt("Anti Cube: Player is nil or invalid on equip!\n")
        return
    end

    local ply = self.player
    local steamID = ply:SteamID64() or "unknown" -- Используем SteamID64 для уникальности

    -- Создаем таймер для регенерации с уникальным именем
    timer.Create("AntiCubeRegen_" .. steamID, 1, 0, function()
        -- Проверяем, что игрок всё ещё валиден и жив
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("AntiCubeRegen_" .. steamID)
            return
        end

        -- Проверяем задержку после получения урона
        if self.lastDamageTime and CurTime() - self.lastDamageTime < self.regenDelay then
            return
        end

        -- Восстанавливаем здоровье
        local currentHealth = ply:Health()
        local maxHealth = ply:GetMaxHealth()
        
        if currentHealth < maxHealth then
            local newHealth = math.min(maxHealth, currentHealth + self.regenRate)
            ply:SetHealth(newHealth)
        end
    end)

    -- Обработчик урона для отслеживания времени последнего получения урона
    hook.Add("EntityTakeDamage", "AntiCubeDamage_" .. steamID, function(target, dmgInfo)
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

    -- Удаляем таймер регенерации
    if timer.Exists("AntiCubeRegen_" .. steamID) then
        timer.Remove("AntiCubeRegen_" .. steamID)
    end

    -- Удаляем хук для обработки урона
    hook.Remove("EntityTakeDamage", "AntiCubeDamage_" .. steamID)

    self.lastDamageTime = nil
end