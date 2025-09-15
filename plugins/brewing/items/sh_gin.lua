ITEM.name = "Джин";
ITEM.model = Model("models/props_junk/glassjug01.mdl");
ITEM.width = 1;
ITEM.height = 1;
ITEM.description = "Немного хорошего джина.";
ITEM.category = "Варка";
ITEM.iconCam = {
	pos = Vector(126.1, 105.81, 82.63),
	ang = Angle(25, 220, 0),
	fov = 4.98
}
ITEM.exRender = true

-- Функция использования предмета
ITEM.functions.Consume = {
    name = "Выпить",
    OnRun = function(item)
        local client = item.player
        if not client:Alive() then return false end
        
        local steamID = client:SteamID()
        local timerName = "gin_effects_" .. steamID
        
        -- Удаляем старый таймер если есть
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
        
        -- Эффекты на 30 секунд
        timer.Create(timerName, 30, 1, function()
            if IsValid(client) and client:SteamID() == steamID then
                client:SetNetVar("hasGinEffect", false)
            end
        end)
        
        -- Устанавливаем эффект
        client:SetNetVar("hasGinEffect", true)
        
        -- Звук употребления
        client:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(1,2) .. ".wav", 75, 100, 0.5)
        
        -- Сообщение для игрока
        client:Notify("Вы выпили джин. Чувствуете легкое головокружение...")
        
        return true
    end
}

-- Хук для удаления эффекта при смерти
hook.Add("PlayerDeath", "RemoveGinEffectOnDeath", function(client)
    if client:GetNetVar("hasGinEffect", false) then
        client:SetNetVar("hasGinEffect", false)
        
        -- Удаляем таймер
        local timerName = "gin_effects_" .. client:SteamID()
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
end)

-- Хук для удаления эффекта при отключении игрока
hook.Add("PlayerDisconnected", "RemoveGinEffectOnDisconnect", function(client)
    local timerName = "gin_effects_" .. client:SteamID()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
end)

-- Хук для применения эффектов
hook.Add("Think", "GinEffectsHandler", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasGinEffect", false) then
            -- Случайное дрожание камеры (головокружение)
            if math.random(1, 100) > 70 then
                local angles = client:EyeAngles()
                angles.p = angles.p + math.Rand(-0.3, 0.3)
                angles.y = angles.y + math.Rand(-0.3, 0.3)
                client:SetEyeAngles(angles)
            end
            
        elseif not client:Alive() and client:GetNetVar("hasGinEffect", false) then
            -- Убираем эффект если игрок умер
            client:SetNetVar("hasGinEffect", false)
        end
    end
end)

-- Хук для цветовой коррекции
hook.Add("RenderScreenspaceEffects", "GinVisualEffects", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetNetVar("hasGinEffect", false) then return end
    
    -- Легкое размытие и цветовая коррекция
    DrawMotionBlur(1, 0.4, 0.01)
    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0.05,
        ["$pp_colour_addb"] = 0.1,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1.1,
        ["$pp_colour_colour"] = 0.9,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    })
end)