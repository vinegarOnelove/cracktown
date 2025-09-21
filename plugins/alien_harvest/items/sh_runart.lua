ITEM.name = "伤口"
ITEM.description = "Странный инопланетный объект. При активации заставляет время течь быстрее вокруг владельца"
ITEM.model = "models/gibs/scanner_gib05.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Артефакты"

-- Добавляем пользовательские данные для хранения времени перезарядки
ITEM.cooldownTime = 60 -- 60 секунд перезарядки (после окончания эффекта)

ITEM.functions.Use = {
    name = "Активировать",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем, не на перезарядке ли предмет
        local lastUsed = item:GetData("lastUsed", 0)
        if lastUsed + item.cooldownTime > CurTime() then
            client:Notify("Артефакт ещё не перезарядился!")
            return false
        end
        
        -- Даём временное усиление скорости
        if SERVER then
            -- Сохраняем оригинальные скорости если еще не сохранили
            if not client.ixOriginalRunSpeed then
                client.ixOriginalRunSpeed = client:GetRunSpeed()
                client.ixOriginalWalkSpeed = client:GetWalkSpeed()
            end
            
            -- Увеличиваем скорость бега
            client:SetRunSpeed(client.ixOriginalRunSpeed * 1.5)
            client:SetWalkSpeed(client.ixOriginalWalkSpeed * 1.5)
            
            -- Сохраняем время использования
            item:SetData("lastUsed", CurTime())
            
            -- Эффекты
            client:EmitSound("ambient/energy/zap1.wav")
            
            -- Создаём таймер для снятия эффекта через 30 секунд
            timer.Create("artifact_speed_" .. client:SteamID64(), 30, 1, function()
                if IsValid(client) then
                    -- Возвращаем оригинальные скорости
                    client:SetRunSpeed(client.ixOriginalRunSpeed or ix.config.Get("runSpeed"))
                    client:SetWalkSpeed(client.ixOriginalWalkSpeed or ix.config.Get("walkSpeed"))
                    client.ixOriginalRunSpeed = nil
                    client.ixOriginalWalkSpeed = nil
                    client:Notify("Эффект артефакта закончился.")
                end
            end)
            
            client:Notify("Вы чувствуете невероятную скорость! Эффект продлится 30 секунд.")
        end
        
        return false -- Не удаляем предмет
    end,
    
    -- Функция проверки возможности использования
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:IsPlayer() and client:Alive()
    end
}

-- Убедимся, что эффект снимается если игрок выходит
hook.Add("PlayerDisconnected", "RemoveArtifactEffect", function(ply)
    if timer.Exists("artifact_speed_" .. ply:SteamID64()) then
        timer.Remove("artifact_speed_" .. ply:SteamID64())
    end
end)

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