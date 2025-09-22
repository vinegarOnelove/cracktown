ITEM.name = "跳转"
ITEM.description = "Странный инопланетный объект неизвестного назначения. Нарушает земное притяжение в локальной области"
ITEM.model = "models/gibs/scanner_gib02.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Артефакты"

-- Добавляем пользовательские данные для хранения времени перезарядки
ITEM.cooldownTime = 30 -- 30 секунд перезарядки

ITEM.functions.Use = {
    name = "Активировать",
    OnRun = function(item)
        local client = item.player
        
        -- Проверка валидности игрока
        if not IsValid(client) or not client:IsPlayer() then
            return false
        end
        
        -- Проверяем, не на перезарядке ли предмет
        local lastUsed = item:GetData("lastUsed", 0)
        if lastUsed + item.cooldownTime > CurTime() then
            client:Notify("Артефакт ещё не перезарядился!")
            return false
        end
        
        -- Эффект подбрасывания и изменения гравитации
        local vel = client:GetVelocity()
        client:SetVelocity(vel + Vector(0, 0, 300)) -- Подбрасываем игрока вверх
        
        -- Сохраняем оригинальную гравитацию если еще не сохранили
        if not client.ixOriginalGravity then
            client.ixOriginalGravity = client:GetGravity()
        end
        
        -- Устанавливаем пониженную гравитацию
        client:SetGravity(0.3)
        
        -- Сохраняем время использования
        item:SetData("lastUsed", CurTime())
        
        -- Уведомление игроку
        client:Notify("Артефакт создал антигравитационное поле!")
        
        -- Звуковой эффект
        client:EmitSound("ambient/energy/weld1.wav")
        
        -- Визуальный эффект вокруг игрока
        local effect = EffectData()
        effect:SetEntity(client)
        effect:SetMagnitude(2)
        effect:SetScale(1)
        util.Effect("electricity_arc", effect)
        
        -- Таймер для восстановления нормальной гравитации через 10 секунд
        timer.Create("artifact_gravity_reset_" .. client:SteamID64(), 10, 1, function()
            if IsValid(client) then
                client:SetGravity(client.ixOriginalGravity or 1)
                client.ixOriginalGravity = nil
                client:Notify("Гравитация вернулась")
            end
        end)
        
        -- Предмет НЕ исчезает после использования
        return false
    end,
    
    -- Функция проверки возможности использования
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:IsPlayer() and client:Alive()
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
            
            -- Индикатор перезарядки
            local progress = 1 - (cooldownRemaining / item.cooldownTime)
            local barHeight = 8 * progress
            surface.DrawRect(w - 14, h - 14 + (8 - barHeight), 8, barHeight)
        else
            -- Предмет готов к использованию - обычный цвет
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