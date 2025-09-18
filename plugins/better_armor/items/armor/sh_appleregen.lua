ITEM.name = "Яблоко Регенерации"
ITEM.description = "При контакте восстанавливает ткани"
ITEM.model = "models/props_junk/watermelon01.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Arts"
ITEM.price = 100

-- Параметры регенерации
ITEM.healthRegenAmount = 1
ITEM.regenInterval = 1

-- Локальные переменные для каждого экземпляра
ITEM.regenTimers = {} -- Таблица для хранения таймеров по SteamID игроков

-- Функция запуска регенерации
function ITEM:StartRegeneration(client)
    if not IsValid(client) or not client:Alive() then
        return
    end

    local steamID = client:SteamID()
    
    -- Останавливаем существующий таймер, если он есть
    self:StopRegeneration(client)
    
    -- Создаем новый таймер
    regenTimers[steamID] = timer.Create("HealthRegen_" .. steamID, self.regenInterval, 0, function()
        if IsValid(client) and client:Alive() and client:Health() < client:GetMaxHealth() then
            -- Восстанавливаем здоровье
            local newHealth = math.min(client:Health() + self.healthRegenAmount, client:GetMaxHealth())
            client:SetHealth(newHealth)
            
            -- Визуальный эффект (только на сервере)
            if SERVER then
                local effect = EffectData()
                effect:SetEntity(client)
                util.Effect("healthvial", effect, true, true)
            end
        else
            -- Останавливаем регенерацию, если игрок умер или здоровье полное
            self:StopRegeneration(client)
        end
    end)
end

-- Функция остановки регенерации
function ITEM:StopRegeneration(client)
    if not IsValid(client) then return end
    
    local steamID = client:SteamID()
    
    if regenTimers[steamID] then
        timer.Remove("HealthRegen_" .. steamID)
        regenTimers[steamID] = nil
    end
end

-- При экипировке предмета
function ITEM:OnEquipped()
    if SERVER then
        local client = self.player
        
        if IsValid(client) then
            self:StartRegeneration(client)
            
            -- Сообщение игроку (опционально)
            client:Notify("Вы надели Яблоко Регенерации. Начинается восстановление здоровья.")
        end
    end
end

-- При снятии предмета
function ITEM:OnUnequipped()
    if SERVER then
        local client = self.player
        
        if IsValid(client) then
            self:StopRegeneration(client)
            
            -- Сообщение игроку (опционально)
            client:Notify("Вы сняли Яблоко Регенерации. Восстановление здоровья остановлено.")
        end
    end
end

-- При смене персонажа (обработка через хук)
hook.Add("PlayerCharacterChanged", "AppleRegen_CharacterChange", function(client, oldChar, newChar)
    if SERVER then
        -- Для всех предметов "Яблоко Регенерации" в инвентаре игрока
        local inventory = newChar:GetInventory()
        local items = inventory:GetItems()
        
        for _, item in pairs(items) do
            if item.uniqueID == "AppleRegen" and item:IsEquipped() then
                item:StopRegeneration(client)
                item:StartRegeneration(client)
            end
        end
    end
end)

-- При смерти игрока
function ITEM:PlayerDeath(client)
    if SERVER then
        self:StopRegeneration(client)
    end
end

-- При возрождении игрока
function ITEM:PlayerSpawn(client)
    if SERVER then
        if self:IsEquipped() then
            self:StartRegeneration(client)
        end
    end
end

-- При удалении предмета
function ITEM:OnRemoved()
    if SERVER then
        local client = self.player
        
        if IsValid(client) then
            self:StopRegeneration(client)
        end
    end
end

-- Проверка возможности экипировки
function ITEM:CanEquip(client)
    if CLIENT then return true end
    
    -- Проверяем, не экипировано ли уже яблоко
    local inventory = client:GetCharacter():GetInventory()
    local items = inventory:GetItems()
    
    for _, item in pairs(items) do
        if item.uniqueID == self.uniqueID and item:IsEquipped() then
            client:Notify("Вы уже экипировали Яблоко Регенерации!")
            return false
        end
    end
    
    return true
end

-- Проверка возможности снятия
function ITEM:CanUnequip(client)
    return true -- Всегда можно снять
end