ITEM.name = "电话"
ITEM.description = "Загадочное устройство, способное искривлять пространство"
ITEM.model = "models/gibs/scanner_gib01.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Артефакты"

-- Добавляем пользовательские данные для хранения времени перезарядки
ITEM.cooldownTime = 120 -- 120 секунд перезарядки

-- Функция для поиска безопасного места для телепортации
local function FindSafeTeleportPosition(ply)
    local attempts = 0
    local maxAttempts = 50
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Генерируем случайную позицию в радиусе 1000 юнитов от игрока
        local randomPos = ply:GetPos() + Vector(
            math.random(-1000, 1000),
            math.random(-1000, 1000),
            math.random(200, 400) -- Добавляем высоту для безопасности
        )
        
        -- Трассировка вниз чтобы найти пол
        local traceDown = {
            start = randomPos,
            endpos = randomPos - Vector(0, 0, 1000),
            filter = ply,
            mask = MASK_SOLID_BRUSHONLY
        }
        
        local tr = util.TraceLine(traceDown)
        
        if tr.Hit then
            -- Проверяем, нет ли препятствий в точке назначения
            local traceCheck = {
                start = tr.HitPos + Vector(0, 0, 16),
                endpos = tr.HitPos + Vector(0, 0, 72), -- Высота игрока
                filter = ply,
                mask = MASK_SOLID
            }
            
            local trCheck = util.TraceLine(traceCheck)
            
            if not trCheck.Hit then
                -- Проверяем, чтобы под ногами была поверхность
                local groundTrace = {
                    start = tr.HitPos + Vector(0, 0, 1),
                    endpos = tr.HitPos - Vector(0, 0, 16),
                    filter = ply
                }
                
                local groundCheck = util.TraceLine(groundTrace)
                
                if groundCheck.Hit then
                    return tr.HitPos + Vector(0, 0, 16)
                end
            end
        end
    end
    
    return nil -- Не удалось найти безопасное место
end

-- Функция использования артефакта
ITEM.functions.Use = {
    name = "Активировать",
    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end
        
        -- Проверяем, не на перезарядке ли предмет
        local lastUsed = item:GetData("lastUsed", 0)
        if lastUsed + item.cooldownTime > CurTime() then
            ply:Notify("Артефакт ещё не перезарядился!")
            return false
        end
        
        -- Ищем безопасное место для телепортации
        local teleportPos = FindSafeTeleportPosition(ply)
        
        if teleportPos then
            -- Сохраняем время использования
            item:SetData("lastUsed", CurTime())
            
            -- Эффекты для визуализации телепортации (исходное место)
            local effectData = EffectData()
            effectData:SetEntity(ply)
            effectData:SetOrigin(ply:GetPos())
            util.Effect("cball_explode", effectData, true, true)
            
            ply:EmitSound("ambient/energy/weld1.wav", 75, 100, 0.5)
            
            -- Телепортируем игрока
            ply:SetPos(teleportPos)
            
            -- Эффекты в точке назначения
            timer.Simple(0.1, function()
                if IsValid(ply) then
                    local effectData2 = EffectData()
                    effectData2:SetEntity(ply)
                    effectData2:SetOrigin(teleportPos)
                    util.Effect("cball_explode", effectData2, true, true)
                    
                    ply:EmitSound("ambient/energy/weld1.wav", 75, 100, 0.5)
                end
            end)
            
            -- Сообщение игроку
            ply:Notify("Артефакт активирован! Вы телепортированы в случайное место.")
            
            -- Не удаляем артефакт после использования
            return false
        else
            -- Если не удалось найти безопасное место
            ply:Notify("Не удалось найти безопасное место для телепортации!")
            return false
        end
    end,
    
    OnCanRun = function(item)
        local ply = item.player
        return IsValid(ply) and ply:IsPlayer() and ply:Alive()
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