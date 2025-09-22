ITEM.name = "治疗/治疗"
ITEM.description = "Странный инопланетный объект неизвестного назначения. При активации излучает тёплую энергию."
ITEM.model = "models/gibs/manhack_gib03.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Артефакты"

-- Добавляем пользовательские данные для хранения времени перезарядки
ITEM.cooldownTime = 30 -- 30 секунд перезарядки

-- Добавляем возможность использовать предмет
ITEM.functions.Use = {
    name = "Использовать",
    icon = "icon16/heart.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем, не на перезарядке ли предмет
        local lastUsed = item:GetData("lastUsed", 0)
        if lastUsed + item.cooldownTime > CurTime() then
            client:Notify("Артефакт ещё не перезарядился!")
            return false
        end
        
        -- Восстанавливаем здоровье
        local currentHealth = client:Health()
        local maxHealth = client:GetMaxHealth() or 100
        local newHealth = math.min(currentHealth + 30, maxHealth)
        
        client:SetHealth(newHealth)
        
        -- Сохраняем время использования
        item:SetData("lastUsed", CurTime())
        
        -- Эффекты
        client:EmitSound("items/medshot4.wav") -- Звук лечения
        client:ScreenFade(SCREENFADE.IN, Color(0, 255, 0, 100), 0.5, 0.5) -- Зелёный экран
        
        -- Частицы (если на сервере есть частицы)
        if SERVER then
            local effectdata = EffectData()
            effectdata:SetOrigin(client:GetPos() + Vector(0, 0, 50))
            effectdata:SetEntity(client)
            util.Effect("cball_explode", effectdata, true, true)
        end
        
        -- Сообщение игроку
        client:Notify("Вы почувствовали прилив энергии! Здоровье восстановлено.")
        
        return false -- Не удаляем предмет
    end
}

-- Визуальные эффекты при наличии артефакта в инвентаре
if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local lastUsed = item:GetData("lastUsed", 0)
        local cooldownRemaining = lastUsed + item.cooldownTime - CurTime()
        
        if cooldownRemaining > 0 then
            -- Предмет на перезарядке - белый цвет
            surface.SetDrawColor(255, 255, 255, 100)
            
            -- Можно добавить индикатор перезарядки
            local progress = 1 - (cooldownRemaining / item.cooldownTime)
            local barHeight = 8 * progress
            surface.DrawRect(w - 14, h - 14 + (8 - barHeight), 8, barHeight)
        else
            -- Предмент готов к использованию - обычный цвет
            surface.SetDrawColor(255, 0, 255, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
    
    -- Добавляем отображение времени перезарядки при наведении
    function ITEM:PopulateTooltip(tooltip)
        local lastUsed = self:GetData("lastUsed", 0)
        local cooldownRemaining = lastUsed + self.cooldownTime - CurTime()
        
        if cooldownRemaining > 0 then
            local panel = tooltip:AddRowAfter("name", "cooldown")
            panel:SetText("Перезарядка: " .. math.Round(cooldownRemaining) .. " сек.")
            panel:SetTextColor(Color(255, 100, 100))
            panel:SizeToContents()
        else
            local panel = tooltip:AddRowAfter("name", "ready")
            panel:SetText("Готов к использованию")
            panel:SetTextColor(Color(100, 255, 100))
            panel:SizeToContents()
        end
    end
end