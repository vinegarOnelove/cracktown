ITEM.name = "Джин"
ITEM.model = Model("models/props_junk/glassjug01.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.description = "Немного хорошего джина. Вызывает головокружение, легкую эйфорию и непредсказуемые эффекты."
ITEM.category = "Варка"
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
        
        -- Случайный эффект (1 - урон, 2 - лечение)
        local randomEffect = math.random(1, 2)
        client:SetNetVar("ginEffectType", randomEffect)
        
        -- Эффекты на 30 секунд
        timer.Create(timerName, 30, 1, function()
            if IsValid(client) and client:SteamID() == steamID then
                client:SetNetVar("hasGinEffect", false)
                client:SetNetVar("ginEffectType", 0)
                client:SetWalkSpeed(ix.config.Get("walkSpeed"))
                client:SetRunSpeed(ix.config.Get("runSpeed"))
            end
        end)
        
        -- Устанавливаем эффект
        client:SetNetVar("hasGinEffect", true)
        client:SetNetVar("ginEffectStart", CurTime())
        
        -- Применяем мгновенный эффект в зависимости от типа
        if randomEffect == 1 then
            -- Урон (5-8 единиц)
            local damage = math.random(5, 8)
            client:TakeDamage(damage, client, client)
            client:Notify("Вы выпили джин! Чувствуете резкую боль! (-" .. damage .. " HP)")
            
        elseif randomEffect == 2 then
            -- Лечение (7-10 единиц)
            local heal = math.random(7, 10)
            client:SetHealth(math.min(client:Health() + heal, client:GetMaxHealth()))
            client:Notify("Вы выпили джин! Чувствуете прилив сил! (+" .. heal .. " HP)")
        end
        
        -- Звук употребления
        client:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(1,2) .. ".wav", 80, 100, 0.6)
        client:EmitSound("ambient/voices/cough" .. math.random(1,2) .. ".wav", 70, 105, 0.4)
        
        -- Случайная изысканная фраза
        if math.random(1, 3) == 1 then
            timer.Simple(1, function()
                if IsValid(client) then
                    local phrases = {
                        "Изысканный вкус...",
                        "Настоящий лондонский сухой...",
                        "Аромат можжевельника...",
                        "Для истинных ценителей...",
                        "Элегантно и крепко..."
                    }
                    client:ChatPrint(table.Random(phrases))
                end
            end)
        end
        
        return true
    end
}

-- Хук для удаления эффекта при смерти
hook.Add("PlayerDeath", "RemoveGinEffectOnDeath", function(client)
    if client:GetNetVar("hasGinEffect", false) then
        client:SetNetVar("hasGinEffect", false)
        client:SetNetVar("ginEffectType", 0)
        client:SetWalkSpeed(ix.config.Get("walkSpeed"))
        client:SetRunSpeed(ix.config.Get("runSpeed"))
        
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

-- Хук для применения постоянных эффектов
hook.Add("Think", "GinEffectsHandler", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasGinEffect", false) then
            local effectType = client:GetNetVar("ginEffectType", 0)
            
            -- Легкое дрожание камеры для эйфории
            if math.random(1, 100) > 75 then
                local angles = client:EyeAngles()
                angles.p = angles.p + math.Rand(-0.5, 0.5)
                angles.y = angles.y + math.Rand(-0.5, 0.5)
                client:SetEyeAngles(angles)
            end
            
            -- Легкое замедление движения для эффекта урона
            if effectType == 1 and (client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT)) then
                client:SetVelocity(client:GetAimVector() * -4)
            end
            
            -- Легкое ускорение для эффекта лечения
            if effectType == 2 and (client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT)) then
                client:SetVelocity(client:GetAimVector() * 2)
            end
            
        elseif not client:Alive() and client:GetNetVar("hasGinEffect", false) then
            -- Убираем эффект если игрок умер
            client:SetNetVar("hasGinEffect", false)
            client:SetNetVar("ginEffectType", 0)
        end
    end
end)

-- Хук для визуальных эффектов
hook.Add("RenderScreenspaceEffects", "GinVisualEffects", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetNetVar("hasGinEffect", false) then return end
    
    local effectType = client:GetNetVar("ginEffectType", 0)
    
    -- Легкое размытие движения для эйфории
    DrawMotionBlur(0.08, 0.25, 0.01)
    
    -- Цветовые эффекты в зависимости от типа
    if effectType == 1 then
        -- Фиолетово-красный оттенок для урона
        DrawColorModify({
            ["$pp_colour_addr"] = 0.04,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0.03,
            ["$pp_colour_brightness"] = -0.02,
            ["$pp_colour_contrast"] = 1.04,
            ["$pp_colour_colour"] = 0.96,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    elseif effectType == 2 then
        -- Золотисто-зеленый оттенок для лечения
        DrawColorModify({
            ["$pp_colour_addr"] = 0.02,
            ["$pp_colour_addg"] = 0.04,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.02,
            ["$pp_colour_contrast"] = 1.03,
            ["$pp_colour_colour"] = 1.04,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end
    
end)

-- Хук для случайных изысканных фраз
hook.Add("Think", "GinElegantMessages", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasGinEffect", false) then
            -- Редкие сообщения (раз в 25-35 секунд)
            if math.random(1, 3000) > 2998 then
                local messages = {
                    "Можжевеловый аромат кружит голову...",
                    "Истинно английский характер...",
                    "Для коктейлей и для души...",
                    "Сухость во рту и ясность мыслей...",
                    "Настоящий джин - это искусство...",
                    "Прозрачный как британское небо...",
                    "Аромат ботанических трав...",
                    "Изысканная крепость...",
                    "Для тех, кто ценит тонкий вкус...",
                    "Элегантное опьянение..."
                }
                client:ChatPrint(table.Random(messages))
            end
        end
    end
end)